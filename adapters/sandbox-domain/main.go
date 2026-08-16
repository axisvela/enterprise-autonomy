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

type experiment struct {
	ID            string `json:"id"`
	Scope         string `json:"scope"`
	Outcome       string `json:"outcome"`
	EvidenceRef   string `json:"evidence_ref"`
	RecordedBy    string `json:"recorded_by"`
	IdempotencyKey string `json:"idempotency_key"`
	OccurredAt    string `json:"occurred_at"`
}

type policyDecision struct {
	ID            string `json:"id"`
	Decision      string `json:"decision"`
	DecidedBy     string `json:"decided_by"`
	Rationale     string `json:"rationale"`
	PolicyRef     string `json:"policy_ref"`
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
	ID          string            `json:"id"`
	Capability  string            `json:"capability"`
	SandboxScope string           `json:"sandbox_scope"`
	Status      string            `json:"status"`
	ReviewGroup []string          `json:"review_group"`
	Experiments []experiment      `json:"experiments"`
	Decision    *policyDecision   `json:"decision,omitempty"`
	Applied     bool              `json:"applied"`
	Actions     []action          `json:"actions"`
}

type store struct {
	sync.Mutex
	Proposals map[string]*proposal `json:"proposals"`
	file      string
}

func main() {
	addr := flag.String("addr", ":8101", "HTTP listen address")
	dataFile := flag.String("data-file", "sandbox-domain-data.json", "JSON persistence file")
	flag.Parse()
	s := load(*dataFile)
	log.Printf("sandbox-domain adapter listening on %s", *addr)
	log.Fatal(http.ListenAndServe(*addr, newMux(s)))
}

func newMux(s *store) *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { write(w, http.StatusOK, map[string]string{"status": "ok", "service": "sandbox-domain-adapter"}) })
	mux.HandleFunc("/v1/proposals/", s.proposals)
	mux.HandleFunc("/v1/notifications/", s.notifications)
	return mux
}

func load(file string) *store {
	s := &store{file: file, Proposals: map[string]*proposal{"proposal-sandbox-0001": {ID: "proposal-sandbox-0001", Capability: "batch-report-generation", SandboxScope: "report-generation-scope", Status: "proposed", ReviewGroup: []string{"reviewer-a", "reviewer-b"}}}}
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
	case len(parts) == 2 && parts[1] == "experiments" && r.Method == http.MethodPost:
		s.recordExperiment(w, r, p)
	case len(parts) == 2 && parts[1] == "decisions" && r.Method == http.MethodPost:
		s.decide(w, r, p)
	case len(parts) == 2 && parts[1] == "apply" && r.Method == http.MethodPost:
		s.apply(w, r, p)
	default:
		write(w, http.StatusNotFound, map[string]string{"error": "not_found"})
	}
}

func (s *store) recordExperiment(w http.ResponseWriter, r *http.Request, p *proposal) {
	var input struct{ ExperimentID string `json:"experiment_id"`; Scope string `json:"scope"`; Outcome string `json:"outcome"`; EvidenceRef string `json:"evidence_ref"`; RecordedBy string `json:"recorded_by"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.ExperimentID == "" || input.Scope == "" || input.Outcome == "" || input.EvidenceRef == "" || input.RecordedBy == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "experiment_id_scope_outcome_evidence_ref_recorded_by_and_idempotency_key_are_required"}); return }
	if input.Outcome != "pass" && input.Outcome != "fail" && input.Outcome != "inconclusive" { write(w, http.StatusBadRequest, map[string]string{"error": "outcome_must_be_pass_fail_or_inconclusive"}); return }
	s.Lock(); defer s.Unlock()
	for _, ex := range p.Experiments { if ex.IdempotencyKey == input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"proposal": p, "experiment": ex, "replayed": true}); return } }
	if p.Status != "proposed" && p.Status != "experimenting" { write(w, http.StatusConflict, map[string]string{"error": "proposal_not_explorable"}); return }
	if input.Scope != p.SandboxScope { write(w, http.StatusForbidden, map[string]string{"error": "sandbox_boundary_experiment_outside_scope"}); return }
	ex := experiment{ID: "experiment-" + input.ExperimentID, Scope: input.Scope, Outcome: input.Outcome, EvidenceRef: input.EvidenceRef, RecordedBy: input.RecordedBy, IdempotencyKey: input.IdempotencyKey, OccurredAt: time.Now().UTC().Format(time.RFC3339)}
	p.Experiments = append(p.Experiments, ex)
	if p.Status == "proposed" { p.Status = "experimenting" }
	p.Actions = append(p.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "experiment", By: input.RecordedBy, Reference: input.EvidenceRef, OccurredAt: ex.OccurredAt})
	s.save(); write(w, http.StatusOK, map[string]any{"proposal": p, "experiment": ex, "replayed": false})
}

func (s *store) decide(w http.ResponseWriter, r *http.Request, p *proposal) {
	var input struct{ Decision string `json:"decision"`; DecidedBy string `json:"decided_by"`; Rationale string `json:"rationale"`; PolicyRef string `json:"policy_ref"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.Decision == "" || input.DecidedBy == "" || input.Rationale == "" || input.PolicyRef == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "decision_decided_by_rationale_policy_ref_and_idempotency_key_are_required"}); return }
	if input.Decision != "release" && input.Decision != "restrict" && input.Decision != "reject" { write(w, http.StatusBadRequest, map[string]string{"error": "decision_must_be_release_restrict_or_reject"}); return }
	s.Lock(); defer s.Unlock()
	if p.Decision != nil && p.Decision.IdempotencyKey == input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"proposal": p, "decision": p.Decision, "replayed": true}); return }
	if p.Decision != nil { write(w, http.StatusConflict, map[string]string{"error": "policy_already_recorded_immutable"}); return }
	if len(p.Experiments) == 0 { write(w, http.StatusForbidden, map[string]string{"error": "experiment_evidence_required_before_policy"}); return }
	if !contains(p.ReviewGroup, input.DecidedBy) { write(w, http.StatusForbidden, map[string]string{"error": "not_designated_reviewer"}); return }
	d := &policyDecision{ID: "policy-" + input.IdempotencyKey, Decision: input.Decision, DecidedBy: input.DecidedBy, Rationale: input.Rationale, PolicyRef: input.PolicyRef, IdempotencyKey: input.IdempotencyKey, OccurredAt: time.Now().UTC().Format(time.RFC3339)}
	p.Decision = d
	p.Status = "decided"
	p.Actions = append(p.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "policy-decision", By: input.DecidedBy, Reference: input.PolicyRef, OccurredAt: d.OccurredAt})
	s.save(); write(w, http.StatusOK, map[string]any{"proposal": p, "decision": d, "replayed": false})
}

func (s *store) apply(w http.ResponseWriter, r *http.Request, p *proposal) {
	var input struct{ AppliedBy string `json:"applied_by"`; PolicyRef string `json:"policy_ref"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.AppliedBy == "" || input.PolicyRef == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "applied_by_policy_ref_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	for _, a := range p.Actions { if a.Type == "apply" && a.ID == "action-"+input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"proposal": p, "replayed": true}); return } }
	if p.Decision == nil { write(w, http.StatusForbidden, map[string]string{"error": "policy_decision_required_before_apply"}); return }
	if input.PolicyRef != p.Decision.PolicyRef { write(w, http.StatusForbidden, map[string]string{"error": "policy_ref_mismatch"}); return }
	if p.Decision.Decision == "reject" { write(w, http.StatusConflict, map[string]string{"error": "rejected_proposal_cannot_be_applied"}); return }
	p.Applied = true
	if p.Decision.Decision == "release" { p.Status = "released" } else { p.Status = "restricted" }
	p.Actions = append(p.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "apply", By: input.AppliedBy, Reference: input.PolicyRef, OccurredAt: time.Now().UTC().Format(time.RFC3339)})
	s.save(); write(w, http.StatusOK, map[string]any{"proposal": p, "replayed": false})
}

func contains(list []string, v string) bool {
	for _, x := range list { if x == v { return true } }
	return false
}

func (s *store) notifications(w http.ResponseWriter, r *http.Request) { s.Lock(); defer s.Unlock(); id := strings.TrimPrefix(r.URL.Path, "/v1/notifications/"); p, ok := s.Proposals[id]; if !ok { write(w, http.StatusNotFound, map[string]string{"error": "proposal_not_found"}); return }; pending := []string{}; if p.Applied { pending = append(pending, "policy-apply-notification-pending:"+p.ID) }; write(w, http.StatusOK, map[string]any{"proposal_id": id, "notifications": pending}) }

func write(w http.ResponseWriter, status int, v any) { w.Header().Set("Content-Type", "application/json"); w.WriteHeader(status); _ = json.NewEncoder(w).Encode(v) }
