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

type stageAdvance struct {
	ID          string `json:"id"`
	FromStage   string `json:"from_stage"`
	ToStage     string `json:"to_stage"`
	DecidedBy   string `json:"decided_by"`
	Rationale   string `json:"rationale"`
	DecisionRef string `json:"decision_ref"`
	IdempotencyKey string `json:"idempotency_key"`
	OccurredAt  string `json:"occurred_at"`
}

type action struct {
	ID        string `json:"id"`
	Type      string `json:"type"`
	By        string `json:"by"`
	Reference string `json:"reference,omitempty"`
	OccurredAt string `json:"occurred_at"`
}

type process struct {
	ID           string         `json:"id"`
	Workflow     string         `json:"workflow"`
	Stages       []string       `json:"stages"`
	CurrentStage string         `json:"current_stage"`
	Status       string         `json:"status"`
	Advances     []stageAdvance `json:"advances"`
	CompletedBy  string         `json:"completed_by,omitempty"`
	Actions      []action       `json:"actions"`
}

type store struct {
	sync.Mutex
	Processes map[string]*process `json:"processes"`
	file      string
}

func main() {
	addr := flag.String("addr", ":8100", "HTTP listen address")
	dataFile := flag.String("data-file", "process-domain-data.json", "JSON persistence file")
	flag.Parse()
	s := load(*dataFile)
	log.Printf("process-domain adapter listening on %s", *addr)
	log.Fatal(http.ListenAndServe(*addr, newMux(s)))
}

func newMux(s *store) *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { write(w, http.StatusOK, map[string]string{"status": "ok", "service": "process-domain-adapter"}) })
	mux.HandleFunc("/v1/processes/", s.processes)
	mux.HandleFunc("/v1/notifications/", s.notifications)
	return mux
}

func load(file string) *store {
	s := &store{file: file, Processes: map[string]*process{"proc-0001": {ID: "proc-0001", Workflow: "onboarding", Stages: []string{"request", "review", "approve", "complete"}, CurrentStage: "request", Status: "initiated"}}}
	b, err := os.ReadFile(file)
	if err == nil { _ = json.Unmarshal(b, s) }
	return s
}

func (s *store) save() {
	_ = os.MkdirAll(filepath.Dir(s.file), 0755)
	b, _ := json.MarshalIndent(s, "", "  ")
	_ = os.WriteFile(s.file, b, 0600)
}

func (s *store) processes(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/v1/processes/"), "/")
	s.Lock()
	p, ok := s.Processes[parts[0]]
	s.Unlock()
	if !ok { write(w, http.StatusNotFound, map[string]string{"error": "process_not_found"}); return }
	switch {
	case len(parts) == 1 && r.Method == http.MethodGet:
		s.Lock(); defer s.Unlock()
		write(w, http.StatusOK, p)
	case len(parts) == 2 && parts[1] == "advance" && r.Method == http.MethodPost:
		s.advance(w, r, p)
	case len(parts) == 2 && parts[1] == "complete" && r.Method == http.MethodPost:
		s.complete(w, r, p)
	default:
		write(w, http.StatusNotFound, map[string]string{"error": "not_found"})
	}
}

func (s *store) advance(w http.ResponseWriter, r *http.Request, p *process) {
	var input struct{ FromStage string `json:"from_stage"`; ToStage string `json:"to_stage"`; DecidedBy string `json:"decided_by"`; Rationale string `json:"rationale"`; DecisionRef string `json:"decision_ref"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.FromStage == "" || input.ToStage == "" || input.DecidedBy == "" || input.Rationale == "" || input.DecisionRef == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "from_stage_to_stage_decided_by_rationale_decision_ref_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	for _, a := range p.Advances { if a.IdempotencyKey == input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"process": p, "advance": a, "replayed": true}); return } }
	if p.Status == "completed" { write(w, http.StatusConflict, map[string]string{"error": "process_already_completed"}); return }
	if p.CurrentStage != input.FromStage { write(w, http.StatusConflict, map[string]string{"error": "stage_mismatch_current_is_" + p.CurrentStage}); return }
	next := ""
	for i, st := range p.Stages {
		if st == input.FromStage && i+1 < len(p.Stages) { next = p.Stages[i+1]; break }
	}
	if next != input.ToStage { write(w, http.StatusConflict, map[string]string{"error": "stage_mismatch_next_is_" + next}); return }
	a := stageAdvance{ID: "advance-" + input.IdempotencyKey, FromStage: input.FromStage, ToStage: input.ToStage, DecidedBy: input.DecidedBy, Rationale: input.Rationale, DecisionRef: input.DecisionRef, IdempotencyKey: input.IdempotencyKey, OccurredAt: time.Now().UTC().Format(time.RFC3339)}
	p.Advances = append(p.Advances, a)
	p.CurrentStage = input.ToStage
	if p.CurrentStage == p.Stages[len(p.Stages)-1] { p.Status = "awaiting-outcome" }
	p.Actions = append(p.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "advance", By: input.DecidedBy, Reference: input.DecisionRef, OccurredAt: a.OccurredAt})
	s.save(); write(w, http.StatusOK, map[string]any{"process": p, "advance": a, "replayed": false})
}

func (s *store) complete(w http.ResponseWriter, r *http.Request, p *process) {
	var input struct{ CompletedBy string `json:"completed_by"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.CompletedBy == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "completed_by_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	if p.Status == "completed" { write(w, http.StatusConflict, map[string]string{"error": "process_already_completed"}); return }
	if p.CurrentStage != p.Stages[len(p.Stages)-1] { write(w, http.StatusForbidden, map[string]string{"error": "outcome_not_reached_terminal_stage_required"}); return }
	if len(p.Advances) == 0 { write(w, http.StatusForbidden, map[string]string{"error": "no_stage_advances_recorded"}); return }
	p.Status = "completed"
	p.CompletedBy = input.CompletedBy
	p.Actions = append(p.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "complete", By: input.CompletedBy, OccurredAt: time.Now().UTC().Format(time.RFC3339)})
	s.save(); write(w, http.StatusOK, map[string]any{"process": p, "replayed": false})
}

func (s *store) notifications(w http.ResponseWriter, r *http.Request) { s.Lock(); defer s.Unlock(); id := strings.TrimPrefix(r.URL.Path, "/v1/notifications/"); p, ok := s.Processes[id]; if !ok { write(w, http.StatusNotFound, map[string]string{"error": "process_not_found"}); return }; pending := []string{}; if p.Status == "completed" { pending = append(pending, "process-outcome-notification-pending:"+p.ID) }; write(w, http.StatusOK, map[string]any{"process_id": id, "notifications": pending}) }

func write(w http.ResponseWriter, status int, v any) { w.Header().Set("Content-Type", "application/json"); w.WriteHeader(status); _ = json.NewEncoder(w).Encode(v) }
