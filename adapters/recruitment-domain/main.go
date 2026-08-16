package main

import (
	"encoding/json"
	"flag"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

type decision struct {
	ID             string `json:"id"`
	Stage          string `json:"stage"`
	Decision       string `json:"decision"`
	Candidate      string `json:"candidate"`
	DecidedBy      string `json:"decided_by"`
	ActorType      string `json:"actor_type"`
	Rationale      string `json:"rationale"`
	DecisionRef    string `json:"decision_ref"`
	IdempotencyKey string `json:"idempotency_key"`
	OccurredAt     string `json:"occurred_at"`
}

type offer struct {
	ID        string `json:"id"`
	Candidate string `json:"candidate"`
	OfferedBy string `json:"offered_by"`
	OfferRef  string `json:"offer_ref"`
	Status    string `json:"status"`
}

type action struct {
	ID        string `json:"id"`
	Type      string `json:"type"`
	By        string `json:"by"`
	ActorType string `json:"actor_type,omitempty"`
	Reference string `json:"reference,omitempty"`
	OccurredAt string `json:"occurred_at"`
}

type requisition struct {
	ID            string     `json:"id"`
	Role          string     `json:"role"`
	Location      string     `json:"location"`
	HiringManager string     `json:"hiring_manager"`
	TALead        string     `json:"ta_lead"`
	BudgetRef     string     `json:"budget_ref"`
	Status        string     `json:"status"`
	Criteria      []string   `json:"criteria"`
	Candidates    []string   `json:"candidates"`
	Decisions     []decision `json:"decisions"`
	Offer         *offer     `json:"offer,omitempty"`
	Actions       []action   `json:"actions"`
}

type evalRecord struct {
	Stage string `json:"stage"`
	Score int    `json:"score"`
	By    string `json:"by"`
}

type candidate struct {
	ID         string      `json:"id"`
	Evaluation []evalRecord `json:"evaluation"`
}

type store struct {
	sync.Mutex
	Requisitions map[string]*requisition `json:"requisitions"`
	Candidates   map[string]*candidate   `json:"candidates"`
	file         string
}

func main() {
	addr := flag.String("addr", ":8094", "HTTP listen address")
	dataFile := flag.String("data-file", "recruitment-domain-data.json", "JSON persistence file")
	flag.Parse()
	s := load(*dataFile)
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { write(w, http.StatusOK, map[string]string{"status": "ok", "service": "recruitment-domain-adapter"}) })
	mux.HandleFunc("/v1/requisitions/", s.requisitions)
	mux.HandleFunc("/v1/candidates/", s.candidates)
	mux.HandleFunc("/v1/notifications/", s.notifications)
	log.Printf("recruitment-domain adapter listening on %s", *addr)
	log.Fatal(http.ListenAndServe(*addr, mux))
}

func load(file string) *store {
	s := &store{file: file, Requisitions: map[string]*requisition{"req-0001": {ID: "req-0001", Role: "Senior Platform Engineer", Location: "Remote", HiringManager: "hiring-manager-1", TALead: "ta-lead-1", BudgetRef: "budget-rec-0001", Status: "draft", Candidates: []string{"cand-a", "cand-b", "cand-c"}}}, Candidates: map[string]*candidate{"cand-a": {ID: "cand-a"}, "cand-b": {ID: "cand-b"}, "cand-c": {ID: "cand-c"}}}
	b, err := os.ReadFile(file)
	if err == nil { _ = json.Unmarshal(b, s) }
	return s
}

func (s *store) save() {
	_ = os.MkdirAll(filepath.Dir(s.file), 0755)
	b, _ := json.MarshalIndent(s, "", "  ")
	_ = os.WriteFile(s.file, b, 0600)
}

func (s *store) requisitions(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/v1/requisitions/"), "/")
	s.Lock()
	req, ok := s.Requisitions[parts[0]]
	s.Unlock()
	if !ok { write(w, http.StatusNotFound, map[string]string{"error": "requisition_not_found"}); return }
	switch {
	case len(parts) == 1 && r.Method == http.MethodGet:
		s.Lock(); defer s.Unlock()
		write(w, http.StatusOK, req)
	case len(parts) == 2 && parts[1] == "validate" && r.Method == http.MethodPost:
		s.validate(w, r, req)
	case len(parts) == 2 && parts[1] == "decisions" && r.Method == http.MethodPost:
		s.decide(w, r, req)
	case len(parts) == 2 && parts[1] == "offers" && r.Method == http.MethodPost:
		s.offer(w, r, req)
	default:
		write(w, http.StatusNotFound, map[string]string{"error": "not_found"})
	}
}

func (s *store) validate(w http.ResponseWriter, r *http.Request, req *requisition) {
	var input struct{ ValidatedBy string `json:"validated_by"`; Criteria []string `json:"criteria"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.ValidatedBy == "" || len(input.Criteria) == 0 || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "validated_by_criteria_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	for _, a := range req.Actions { if a.Type == "validate" && a.ID == "action-"+input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"requisition": req, "replayed": true}); return } }
	if input.ValidatedBy != req.TALead { write(w, http.StatusForbidden, map[string]string{"error": "only_ta_lead_can_validate"}); return }
	if req.Status != "draft" { write(w, http.StatusConflict, map[string]string{"error": "requisition_not_draft"}); return }
	req.Criteria = input.Criteria
	req.Status = "validated"
	req.Actions = append(req.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "validate", By: input.ValidatedBy, OccurredAt: time.Now().UTC().Format(time.RFC3339)})
	s.save(); write(w, http.StatusOK, map[string]any{"requisition": req, "replayed": false})
}

func (s *store) decide(w http.ResponseWriter, r *http.Request, req *requisition) {
	var input struct{ Stage string `json:"stage"`; Decision string `json:"decision"`; Candidate string `json:"candidate"`; DecidedBy string `json:"decided_by"`; ActorType string `json:"actor_type"`; Rationale string `json:"rationale"`; DecisionRef string `json:"decision_ref"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.Stage == "" || input.Candidate == "" || input.DecidedBy == "" || input.ActorType == "" || input.Rationale == "" || input.DecisionRef == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "stage_decision_candidate_decided_by_actor_type_rationale_decision_ref_and_idempotency_key_are_required"}); return }
	if input.Stage != "shortlist" && input.Stage != "selection" && input.Stage != "offer" { write(w, http.StatusBadRequest, map[string]string{"error": "unsupported_stage"}); return }
	if input.ActorType == "automated" { write(w, http.StatusForbidden, map[string]string{"error": "automation_cannot_make_hiring_decisions"}); return }
	s.Lock(); defer s.Unlock()
	for _, d := range req.Decisions { if d.IdempotencyKey == input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"requisition": req, "decision": d, "replayed": true}); return } }
	if !contains(req.Candidates, input.Candidate) { write(w, http.StatusBadRequest, map[string]string{"error": "candidate_not_in_requisition"}); return }
	if input.Stage == "shortlist" && req.Status != "validated" && req.Status != "shortlisting" { write(w, http.StatusConflict, map[string]string{"error": "requisition_must_be_validated"}); return }
	if input.Stage == "selection" && req.Status != "shortlisting" { write(w, http.StatusConflict, map[string]string{"error": "shortlist_decisions_required_first"}); return }
	if input.Stage == "offer" && req.Status != "selection" { write(w, http.StatusConflict, map[string]string{"error": "selection_decision_required_first"}); return }
	d := decision{ID: "decision-" + input.IdempotencyKey, Stage: input.Stage, Decision: input.Decision, Candidate: input.Candidate, DecidedBy: input.DecidedBy, ActorType: input.ActorType, Rationale: input.Rationale, DecisionRef: input.DecisionRef, IdempotencyKey: input.IdempotencyKey, OccurredAt: time.Now().UTC().Format(time.RFC3339)}
	req.Decisions = append(req.Decisions, d)
	req.Actions = append(req.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "decision-" + input.Stage, By: input.DecidedBy, ActorType: input.ActorType, Reference: input.DecisionRef, OccurredAt: d.OccurredAt})
	switch input.Stage {
	case "shortlist":
		if req.Status == "validated" { req.Status = "shortlisting" }
	case "selection":
		if req.Status == "shortlisting" { req.Status = "selection" }
	case "offer":
		if req.Status == "selection" { req.Status = "offer" }
	}
	s.save(); write(w, http.StatusOK, map[string]any{"requisition": req, "decision": d, "replayed": false})
}

func contains(list []string, v string) bool {
	for _, x := range list { if x == v { return true } }
	return false
}

func (s *store) offer(w http.ResponseWriter, r *http.Request, req *requisition) {
	var input struct{ Candidate string `json:"candidate"`; OfferedBy string `json:"offered_by"`; OfferRef string `json:"offer_ref"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.Candidate == "" || input.OfferedBy == "" || input.OfferRef == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "candidate_offered_by_offer_ref_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	if req.Offer != nil && req.Offer.ID == "offer-"+input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"requisition": req, "offer": req.Offer, "replayed": true}); return }
	if req.Status != "offer" { write(w, http.StatusConflict, map[string]string{"error": "offer_decision_required_first"}); return }
	hasOfferDecision := false
	for _, d := range req.Decisions { if d.Stage == "offer" && d.Candidate == input.Candidate && d.Decision == "offer" { hasOfferDecision = true; break } }
	if !hasOfferDecision { write(w, http.StatusForbidden, map[string]string{"error": "no_offer_decision_for_candidate"}); return }
	o := &offer{ID: "offer-" + input.IdempotencyKey, Candidate: input.Candidate, OfferedBy: input.OfferedBy, OfferRef: input.OfferRef, Status: "issued"}
	req.Offer = o
	req.Status = "closed"
	req.Actions = append(req.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "offer", By: input.OfferedBy, Reference: input.OfferRef, OccurredAt: time.Now().UTC().Format(time.RFC3339)})
	s.save(); write(w, http.StatusOK, map[string]any{"requisition": req, "offer": o, "replayed": false})
}

func (s *store) candidates(w http.ResponseWriter, r *http.Request) { s.Lock(); defer s.Unlock(); id := strings.TrimPrefix(r.URL.Path, "/v1/candidates/"); c, ok := s.Candidates[id]; if !ok { write(w, http.StatusNotFound, map[string]string{"error": "candidate_not_found"}); return }; write(w, http.StatusOK, c) }

func (s *store) notifications(w http.ResponseWriter, r *http.Request) { s.Lock(); defer s.Unlock(); id := strings.TrimPrefix(r.URL.Path, "/v1/notifications/"); req, ok := s.Requisitions[id]; if !ok { write(w, http.StatusNotFound, map[string]string{"error": "requisition_not_found"}); return }; pending := []string{}; if req.Offer != nil { pending = append(pending, "offer-notification-pending:"+req.Offer.ID) }; for _, d := range req.Decisions { if d.Stage == "shortlist" && d.Decision == "reject" { pending = append(pending, "rejection-notification-pending:"+d.Candidate) } }; write(w, http.StatusOK, map[string]any{"requisition_id": id, "notifications": pending}) }

func write(w http.ResponseWriter, status int, v any) { w.Header().Set("Content-Type", "application/json"); w.WriteHeader(status); _ = json.NewEncoder(w).Encode(v) }
