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

type scenario struct {
	ID          string `json:"id"`
	Description string `json:"description"`
}

type runRecord struct {
	ID            string `json:"id"`
	Outcome       string `json:"outcome"`
	EvidenceRef   string `json:"evidence_ref"`
	RecordedBy    string `json:"recorded_by"`
	Immutable     bool   `json:"immutable"`
	IdempotencyKey string `json:"idempotency_key"`
	OccurredAt    string `json:"occurred_at"`
}

type reviewDecision struct {
	ID            string `json:"id"`
	Decision      string `json:"decision"`
	DecidedBy     string `json:"decided_by"`
	Rationale     string `json:"rationale"`
	DecisionRef   string `json:"decision_ref"`
	IdempotencyKey string `json:"idempotency_key"`
	OccurredAt    string `json:"occurred_at"`
}

type action struct {
	ID        string `json:"id"`
	Type      string `json:"type"`
	By        string `json:"by"`
	Reference string `json:"reference,omitempty"`
	OccurredAt string `json:"occurred_at"`
}

type proposal struct {
	ID          string          `json:"id"`
	Capability  string          `json:"capability"`
	Scope       string          `json:"scope"`
	Status      string          `json:"status"`
	ReviewGroup []string        `json:"review_group"`
	Scenarios   []scenario      `json:"scenarios"`
	Runs        []runRecord     `json:"runs"`
	Decision    *reviewDecision `json:"decision,omitempty"`
	Actions     []action        `json:"actions"`
}

type store struct {
	sync.Mutex
	Proposals map[string]*proposal `json:"proposals"`
	file      string
}

func main() {
	addr := flag.String("addr", ":8097", "HTTP listen address")
	dataFile := flag.String("data-file", "simulation-domain-data.json", "JSON persistence file")
	flag.Parse()
	s := load(*dataFile)
	log.Printf("simulation-domain adapter listening on %s", *addr)
	log.Fatal(http.ListenAndServe(*addr, newMux(s)))
}

func newMux(s *store) *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { write(w, http.StatusOK, map[string]string{"status": "ok", "service": "simulation-domain-adapter"}) })
	mux.HandleFunc("/v1/proposals/", s.proposals)
	mux.HandleFunc("/v1/runs/", s.runs)
	mux.HandleFunc("/v1/notifications/", s.notifications)
	return mux
}

func load(file string) *store {
	s := &store{file: file, Proposals: map[string]*proposal{"proposal-sim-0001": {ID: "proposal-sim-0001", Capability: "automated-zone-inspection", Scope: "zone-alpha", Status: "proposed", ReviewGroup: []string{"reviewer-a", "reviewer-b"}}}}
	b, err := os.ReadFile(file)
	if err == nil { _ = json.Unmarshal(b, s) }
	return s
}

func (s *store) save() {
	_ = os.MkdirAll(filepath.Dir(s.file), 0755)
	b, _ := json.MarshalIndent(s, "", "  ")
	_ = os.WriteFile(s.file, b, 0600)
}

func (s *store) proposals(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/v1/proposals/"), "/")
	s.Lock()
	p, ok := s.Proposals[parts[0]]
	s.Unlock()
	if !ok { write(w, http.StatusNotFound, map[string]string{"error": "proposal_not_found"}); return }
	switch {
	case len(parts) == 1 && r.Method == http.MethodGet:
		s.Lock(); defer s.Unlock()
		write(w, http.StatusOK, p)
	case len(parts) == 2 && parts[1] == "scenarios" && r.Method == http.MethodPost:
		s.addScenario(w, r, p)
	case len(parts) == 2 && parts[1] == "runs" && r.Method == http.MethodPost:
		s.recordRun(w, r, p)
	case len(parts) == 2 && parts[1] == "decisions" && r.Method == http.MethodPost:
		s.decide(w, r, p)
	case len(parts) == 2 && parts[1] == "release" && r.Method == http.MethodPost:
		s.release(w, r, p)
	default:
		write(w, http.StatusNotFound, map[string]string{"error": "not_found"})
	}
}

func (s *store) addScenario(w http.ResponseWriter, r *http.Request, p *proposal) {
	var input struct{ ScenarioID string `json:"scenario_id"`; Description string `json:"description"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.ScenarioID == "" || input.Description == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "scenario_id_description_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	if p.Status != "proposed" { write(w, http.StatusConflict, map[string]string{"error": "proposal_not_proposed"}); return }
	for _, sc := range p.Scenarios { if sc.ID == input.ScenarioID { write(w, http.StatusOK, map[string]any{"proposal": p, "scenario": sc, "replayed": true}); return } }
	sc := scenario{ID: input.ScenarioID, Description: input.Description}
	p.Scenarios = append(p.Scenarios, sc)
	p.Actions = append(p.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "scenario", By: "simulation-engineer", Reference: input.ScenarioID, OccurredAt: time.Now().UTC().Format(time.RFC3339)})
	s.save(); write(w, http.StatusOK, map[string]any{"proposal": p, "scenario": sc, "replayed": false})
}

func (s *store) recordRun(w http.ResponseWriter, r *http.Request, p *proposal) {
	var input struct{ RunID string `json:"run_id"`; Outcome string `json:"outcome"`; EvidenceRef string `json:"evidence_ref"`; RecordedBy string `json:"recorded_by"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.RunID == "" || input.Outcome == "" || input.EvidenceRef == "" || input.RecordedBy == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "run_id_outcome_evidence_ref_recorded_by_and_idempotency_key_are_required"}); return }
	if input.Outcome != "pass" && input.Outcome != "fail" && input.Outcome != "inconclusive" { write(w, http.StatusBadRequest, map[string]string{"error": "outcome_must_be_pass_fail_or_inconclusive"}); return }
	s.Lock(); defer s.Unlock()
	for _, rn := range p.Runs { if rn.IdempotencyKey == input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"proposal": p, "run": rn, "replayed": true}); return } }
	if len(p.Runs) > 0 { write(w, http.StatusConflict, map[string]string{"error": "evidence_already_recorded_immutable"}); return }
	rn := runRecord{ID: "run-" + input.RunID, Outcome: input.Outcome, EvidenceRef: input.EvidenceRef, RecordedBy: input.RecordedBy, Immutable: true, IdempotencyKey: input.IdempotencyKey, OccurredAt: time.Now().UTC().Format(time.RFC3339)}
	p.Runs = append(p.Runs, rn)
	p.Status = "evidence"
	p.Actions = append(p.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "simulation-run", By: input.RecordedBy, Reference: rn.EvidenceRef, OccurredAt: rn.OccurredAt})
	s.save(); write(w, http.StatusOK, map[string]any{"proposal": p, "run": rn, "replayed": false})
}

func (s *store) decide(w http.ResponseWriter, r *http.Request, p *proposal) {
	var input struct{ Decision string `json:"decision"`; DecidedBy string `json:"decided_by"`; Rationale string `json:"rationale"`; DecisionRef string `json:"decision_ref"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.Decision == "" || input.DecidedBy == "" || input.Rationale == "" || input.DecisionRef == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "decision_decided_by_rationale_decision_ref_and_idempotency_key_are_required"}); return }
	if input.Decision != "approve" && input.Decision != "reject" && input.Decision != "revise" { write(w, http.StatusBadRequest, map[string]string{"error": "decision_must_be_approve_reject_or_revise"}); return }
	s.Lock(); defer s.Unlock()
	if p.Decision != nil && p.Decision.IdempotencyKey == input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"proposal": p, "decision": p.Decision, "replayed": true}); return }
	if len(p.Runs) == 0 { write(w, http.StatusForbidden, map[string]string{"error": "simulation_evidence_required_before_decision"}); return }
	if !contains(p.ReviewGroup, input.DecidedBy) { write(w, http.StatusForbidden, map[string]string{"error": "not_review_group_member"}); return }
	d := &reviewDecision{ID: "decision-" + input.IdempotencyKey, Decision: input.Decision, DecidedBy: input.DecidedBy, Rationale: input.Rationale, DecisionRef: input.DecisionRef, IdempotencyKey: input.IdempotencyKey, OccurredAt: time.Now().UTC().Format(time.RFC3339)}
	p.Decision = d
	p.Status = "decided"
	p.Actions = append(p.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "review-decision", By: input.DecidedBy, Reference: input.DecisionRef, OccurredAt: d.OccurredAt})
	s.save(); write(w, http.StatusOK, map[string]any{"proposal": p, "decision": d, "replayed": false})
}

func (s *store) release(w http.ResponseWriter, r *http.Request, p *proposal) {
	var input struct{ ReleasedBy string `json:"released_by"`; DecisionRef string `json:"decision_ref"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.ReleasedBy == "" || input.DecisionRef == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "released_by_decision_ref_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	for _, a := range p.Actions { if a.Type == "release" && a.ID == "action-"+input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"proposal": p, "replayed": true}); return } }
	if p.Decision == nil || p.Decision.Decision != "approve" { write(w, http.StatusForbidden, map[string]string{"error": "release_requires_approval"}); return }
	if input.DecisionRef != p.Decision.DecisionRef { write(w, http.StatusForbidden, map[string]string{"error": "decision_ref_mismatch"}); return }
	p.Status = "released"
	p.Actions = append(p.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "release", By: input.ReleasedBy, Reference: input.DecisionRef, OccurredAt: time.Now().UTC().Format(time.RFC3339)})
	s.save(); write(w, http.StatusOK, map[string]any{"proposal": p, "replayed": false})
}

func contains(list []string, v string) bool {
	for _, x := range list { if x == v { return true } }
	return false
}

func (s *store) runs(w http.ResponseWriter, r *http.Request) { s.Lock(); defer s.Unlock(); id := strings.TrimPrefix(r.URL.Path, "/v1/runs/"); for _, p := range s.Proposals { for _, rn := range p.Runs { if rn.ID == id { write(w, http.StatusOK, rn); return } } }; write(w, http.StatusNotFound, map[string]string{"error": "run_not_found"}) }

func (s *store) notifications(w http.ResponseWriter, r *http.Request) { s.Lock(); defer s.Unlock(); id := strings.TrimPrefix(r.URL.Path, "/v1/notifications/"); p, ok := s.Proposals[id]; if !ok { write(w, http.StatusNotFound, map[string]string{"error": "proposal_not_found"}); return }; pending := []string{}; if p.Status == "released" { pending = append(pending, "release-notification-pending:"+p.ID) }; write(w, http.StatusOK, map[string]any{"proposal_id": id, "notifications": pending}) }

func write(w http.ResponseWriter, status int, v any) { w.Header().Set("Content-Type", "application/json"); w.WriteHeader(status); _ = json.NewEncoder(w).Encode(v) }
