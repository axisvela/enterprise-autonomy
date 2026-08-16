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

type stepRun struct {
	ID           string `json:"id"`
	Step         string `json:"step"`
	ExecutedBy   string `json:"executed_by"`
	EvidenceRef  string `json:"evidence_ref"`
	IdempotencyKey string `json:"idempotency_key"`
	OccurredAt   string `json:"occurred_at"`
}

type deviation struct {
	ID           string `json:"id"`
	Action       string `json:"action"`
	ToStep       string `json:"to_step,omitempty"`
	ApprovedBy   string `json:"approved_by"`
	ApprovalRef  string `json:"approval_ref"`
	IdempotencyKey string `json:"idempotency_key"`
	OccurredAt   string `json:"occurred_at"`
}

type deployment struct {
	ID          string      `json:"id"`
	Workflow    string      `json:"workflow"`
	Steps       []string    `json:"steps"`
	CurrentStep string      `json:"current_step"`
	Status      string      `json:"status"`
	StepsRun    []stepRun   `json:"steps_run"`
	Deviations  []deviation `json:"deviations"`
}

type store struct {
	sync.Mutex
	Deployments map[string]*deployment `json:"deployments"`
	file        string
}

func main() {
	addr := flag.String("addr", ":8102", "HTTP listen address")
	dataFile := flag.String("data-file", "deployment-domain-data.json", "JSON persistence file")
	flag.Parse()
	s := load(*dataFile)
	log.Printf("deployment-domain adapter listening on %s", *addr)
	log.Fatal(http.ListenAndServe(*addr, newMux(s)))
}

func newMux(s *store) *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { write(w, http.StatusOK, map[string]string{"status": "ok", "service": "deployment-domain-adapter"}) })
	mux.HandleFunc("/v1/deployments/", s.deployments)
	mux.HandleFunc("/v1/notifications/", s.notifications)
	return mux
}

func load(file string) *store {
	s := &store{file: file, Deployments: map[string]*deployment{
		"dep-0001": {
			ID: "dep-0001", Workflow: "release-pipeline",
			Steps: []string{"checkout", "build", "test", "approve", "production"},
			CurrentStep: "checkout", Status: "initiated",
		},
	}}
	b, err := os.ReadFile(file)
	if err == nil { _ = json.Unmarshal(b, s) }
	return s
}

func (s *store) save() {
	_ = os.MkdirAll(filepath.Dir(s.file), 0755)
	b, _ := json.MarshalIndent(s, "", "  ")
	_ = os.WriteFile(s.file, b, 0600)
}

func (s *store) deployments(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/v1/deployments/"), "/")
	s.Lock()
	d, ok := s.Deployments[parts[0]]
	s.Unlock()
	if !ok { write(w, http.StatusNotFound, map[string]string{"error": "deployment_not_found"}); return }
	switch {
	case len(parts) == 1 && r.Method == http.MethodGet:
		s.Lock(); defer s.Unlock()
		write(w, http.StatusOK, d)
	case len(parts) == 2 && parts[1] == "steps" && r.Method == http.MethodPost:
		s.steps(w, r, d)
	case len(parts) == 2 && parts[1] == "deviations" && r.Method == http.MethodPost:
		s.deviations(w, r, d)
	default:
		write(w, http.StatusNotFound, map[string]string{"error": "not_found"})
	}
}

func (s *store) nextStep(d *deployment) string {
	done := map[string]bool{}
	for _, r := range d.StepsRun { done[r.Step] = true }
	for _, st := range d.Steps {
		if !done[st] { return st }
	}
	return ""
}

func (s *store) steps(w http.ResponseWriter, r *http.Request, d *deployment) {
	var input struct{ Step string `json:"step"`; ExecutedBy string `json:"executed_by"`; EvidenceRef string `json:"evidence_ref"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.Step == "" || input.ExecutedBy == "" || input.EvidenceRef == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "step_executed_by_evidence_ref_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	for _, run := range d.StepsRun { if run.IdempotencyKey == input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"deployment": d, "step_run": run, "replayed": true}); return } }
	if d.Status == "released" || d.Status == "rolled-back" { write(w, http.StatusConflict, map[string]string{"error": "deployment_already_released_immutable"}); return }
	if d.Status == "paused" { write(w, http.StatusForbidden, map[string]string{"error": "deployment_paused_deviation_review_required"}); return }
	for _, run := range d.StepsRun { if run.Step == input.Step { write(w, http.StatusConflict, map[string]string{"error": "step_already_executed_immutable"}); return } }
	next := s.nextStep(d)
	if input.Step != next { write(w, http.StatusConflict, map[string]string{"error": "step_out_of_sequence_next_is_" + next}); return }
	run := stepRun{ID: "step-" + input.IdempotencyKey, Step: input.Step, ExecutedBy: input.ExecutedBy, EvidenceRef: input.EvidenceRef, IdempotencyKey: input.IdempotencyKey, OccurredAt: time.Now().UTC().Format(time.RFC3339)}
	d.StepsRun = append(d.StepsRun, run)
	d.CurrentStep = input.Step
	if input.Step == d.Steps[len(d.Steps)-1] { d.Status = "released" } else if d.Status != "rolled-back" { d.Status = "in-flight" }
	s.save(); write(w, http.StatusOK, map[string]any{"deployment": d, "step_run": run, "replayed": false})
}

func (s *store) deviations(w http.ResponseWriter, r *http.Request, d *deployment) {
	var input struct{ Action string `json:"action"`; ToStep string `json:"to_step"`; ApprovedBy string `json:"approved_by"`; ApprovalRef string `json:"approval_ref"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.Action == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "action_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	for _, dv := range d.Deviations { if dv.IdempotencyKey == input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"deployment": d, "deviation": dv, "replayed": true}); return } }
	if d.Status == "released" || d.Status == "rolled-back" { write(w, http.StatusConflict, map[string]string{"error": "deployment_already_released_immutable"}); return }
	if input.ApprovedBy == "" || input.ApprovalRef == "" { write(w, http.StatusForbidden, map[string]string{"error": "deviation_requires_human_approval"}); return }
	if input.Action == "skip" && input.ToStep == "" { write(w, http.StatusBadRequest, map[string]string{"error": "to_step_required_for_skip"}); return }
	dv := deviation{ID: "deviation-" + input.IdempotencyKey, Action: input.Action, ToStep: input.ToStep, ApprovedBy: input.ApprovedBy, ApprovalRef: input.ApprovalRef, IdempotencyKey: input.IdempotencyKey, OccurredAt: time.Now().UTC().Format(time.RFC3339)}
	d.Deviations = append(d.Deviations, dv)
	switch input.Action {
	case "pause":
		d.Status = "paused"
	case "skip":
		if input.ToStep == d.Steps[len(d.Steps)-1] { d.Status = "released" } else { d.Status = "in-flight" }
		d.CurrentStep = input.ToStep
	case "rollback":
		d.Status = "rolled-back"
		d.CurrentStep = ""
	}
	s.save(); write(w, http.StatusOK, map[string]any{"deployment": d, "deviation": dv, "replayed": false})
}

func (s *store) notifications(w http.ResponseWriter, r *http.Request) {
	s.Lock(); defer s.Unlock()
	id := strings.TrimPrefix(r.URL.Path, "/v1/notifications/")
	d, ok := s.Deployments[id]
	if !ok { write(w, http.StatusNotFound, map[string]string{"error": "deployment_not_found"}); return }
	pending := []string{}
	if d.Status == "released" { pending = append(pending, "release-notification-pending:"+d.ID) }
	if d.Status == "paused" { pending = append(pending, "deviation-review-notification-pending:"+d.ID) }
	write(w, http.StatusOK, map[string]any{"deployment_id": id, "notifications": pending})
}

func write(w http.ResponseWriter, status int, v any) { w.Header().Set("Content-Type", "application/json"); w.WriteHeader(status); _ = json.NewEncoder(w).Encode(v) }
