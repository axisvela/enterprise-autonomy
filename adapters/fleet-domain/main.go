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

type exception struct {
	ID        string `json:"id"`
	Type      string `json:"type"`
	Detail    string `json:"detail"`
	RaisedBy  string `json:"raised_by"`
	OccurredAt string `json:"occurred_at"`
}

type review struct {
	ID          string `json:"id"`
	ReviewedBy  string `json:"reviewed_by"`
	Decision    string `json:"decision"`
	ApprovalRef string `json:"approval_ref"`
	OccurredAt  string `json:"occurred_at"`
}

type action struct {
	ID        string `json:"id"`
	Type      string `json:"type"`
	By        string `json:"by"`
	Reference string `json:"reference,omitempty"`
	OccurredAt string `json:"occurred_at"`
}

type mission struct {
	ID         string     `json:"id"`
	Zone       string     `json:"zone"`
	Objective  string     `json:"objective"`
	Status     string     `json:"status"`
	Operator   string     `json:"operator"`
	Boundary   []string   `json:"boundary"`
	Position   string     `json:"position,omitempty"`
	Exception  *exception `json:"exception,omitempty"`
	Review     *review    `json:"review,omitempty"`
	Actions    []action   `json:"actions"`
}

type store struct {
	sync.Mutex
	Missions map[string]*mission `json:"missions"`
	file     string
}

func main() {
	addr := flag.String("addr", ":8099", "HTTP listen address")
	dataFile := flag.String("data-file", "fleet-domain-data.json", "JSON persistence file")
	flag.Parse()
	s := load(*dataFile)
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { write(w, http.StatusOK, map[string]string{"status": "ok", "service": "fleet-domain-adapter"}) })
	mux.HandleFunc("/v1/missions/", s.missions)
	mux.HandleFunc("/v1/notifications/", s.notifications)
	log.Printf("fleet-domain adapter listening on %s", *addr)
	log.Fatal(http.ListenAndServe(*addr, mux))
}

func load(file string) *store {
	s := &store{file: file, Missions: map[string]*mission{"mission-alpha-001": {ID: "mission-alpha-001", Zone: "zone-alpha", Objective: "inspect racks", Status: "planned", Operator: "ops-lead", Boundary: []string{"zone-alpha"}}}}
	b, err := os.ReadFile(file)
	if err == nil { _ = json.Unmarshal(b, s) }
	return s
}

func (s *store) save() {
	_ = os.MkdirAll(filepath.Dir(s.file), 0755)
	b, _ := json.MarshalIndent(s, "", "  ")
	_ = os.WriteFile(s.file, b, 0600)
}

func (s *store) missions(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/v1/missions/"), "/")
	s.Lock()
	m, ok := s.Missions[parts[0]]
	s.Unlock()
	if !ok { write(w, http.StatusNotFound, map[string]string{"error": "mission_not_found"}); return }
	switch {
	case len(parts) == 1 && r.Method == http.MethodGet:
		s.Lock(); defer s.Unlock()
		write(w, http.StatusOK, m)
	case len(parts) == 2 && parts[1] == "start" && r.Method == http.MethodPost:
		s.start(w, r, m)
	case len(parts) == 2 && parts[1] == "telemetry" && r.Method == http.MethodPost:
		s.telemetry(w, r, m)
	case len(parts) == 2 && parts[1] == "exceptions" && r.Method == http.MethodPost:
		s.raiseException(w, r, m)
	case len(parts) == 2 && parts[1] == "reviews" && r.Method == http.MethodPost:
		s.review(w, r, m)
	case len(parts) == 2 && parts[1] == "complete" && r.Method == http.MethodPost:
		s.complete(w, r, m)
	default:
		write(w, http.StatusNotFound, map[string]string{"error": "not_found"})
	}
}

func (s *store) start(w http.ResponseWriter, r *http.Request, m *mission) {
	var input struct{ StartedBy string `json:"started_by"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.StartedBy == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "started_by_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	if input.StartedBy != m.Operator { write(w, http.StatusForbidden, map[string]string{"error": "not_mission_operator"}); return }
	for _, a := range m.Actions { if a.Type == "start" && a.ID == "action-"+input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"mission": m, "replayed": true}); return } }
	if m.Status != "planned" { write(w, http.StatusConflict, map[string]string{"error": "mission_not_planned"}); return }
	m.Status = "running"
	m.Position = m.Zone
	m.Actions = append(m.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "start", By: input.StartedBy, OccurredAt: time.Now().UTC().Format(time.RFC3339)})
	s.save(); write(w, http.StatusOK, map[string]any{"mission": m, "replayed": false})
}

func (s *store) telemetry(w http.ResponseWriter, r *http.Request, m *mission) {
	var input struct{ Position string `json:"position"`; Status string `json:"status"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.Position == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "position_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	if m.Status != "running" && m.Status != "resumed" { write(w, http.StatusConflict, map[string]string{"error": "mission_not_active"}); return }
	if !contains(m.Boundary, input.Position) { write(w, http.StatusForbidden, map[string]string{"error": "boundary_deviation_mission_frozen"}); return }
	m.Position = input.Position
	if input.Status == "exception" { m.Status = "paused" }
	m.Actions = append(m.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "telemetry", By: "fleet-runtime", Reference: input.Position, OccurredAt: time.Now().UTC().Format(time.RFC3339)})
	s.save(); write(w, http.StatusOK, map[string]any{"mission": m, "replayed": false})
}

func (s *store) raiseException(w http.ResponseWriter, r *http.Request, m *mission) {
	var input struct{ Type string `json:"type"`; Detail string `json:"detail"`; RaisedBy string `json:"raised_by"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.Type == "" || input.Detail == "" || input.RaisedBy == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "type_detail_raised_by_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	for _, a := range m.Actions { if a.Type == "exception" && a.ID == "action-"+input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"mission": m, "replayed": true}); return } }
	if m.Status != "running" && m.Status != "resumed" { write(w, http.StatusConflict, map[string]string{"error": "mission_not_active"}); return }
	ex := &exception{ID: "exception-" + input.IdempotencyKey, Type: input.Type, Detail: input.Detail, RaisedBy: input.RaisedBy, OccurredAt: time.Now().UTC().Format(time.RFC3339)}
	m.Exception = ex
	m.Status = "paused"
	m.Actions = append(m.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "exception", By: input.RaisedBy, Reference: input.Type, OccurredAt: ex.OccurredAt})
	s.save(); write(w, http.StatusOK, map[string]any{"mission": m, "exception": ex, "replayed": false})
}

func (s *store) review(w http.ResponseWriter, r *http.Request, m *mission) {
	var input struct{ ReviewedBy string `json:"reviewed_by"`; Decision string `json:"decision"`; ApprovalRef string `json:"approval_ref"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.ReviewedBy == "" || input.Decision == "" || input.ApprovalRef == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "reviewed_by_decision_approval_ref_and_idempotency_key_are_required"}); return }
	if input.Decision != "resume" && input.Decision != "adjust" && input.Decision != "cancel" { write(w, http.StatusBadRequest, map[string]string{"error": "decision_must_be_resume_adjust_or_cancel"}); return }
	s.Lock(); defer s.Unlock()
	if m.Review != nil && m.Review.ID == "review-"+input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"mission": m, "review": m.Review, "replayed": true}); return }
	if m.Status != "paused" { write(w, http.StatusForbidden, map[string]string{"error": "operator_review_required_mission_must_be_paused"}); return }
	if input.ReviewedBy != m.Operator { write(w, http.StatusForbidden, map[string]string{"error": "not_mission_operator"}); return }
	if m.Exception == nil { write(w, http.StatusConflict, map[string]string{"error": "no_exception_to_review"}); return }
	rv := &review{ID: "review-" + input.IdempotencyKey, ReviewedBy: input.ReviewedBy, Decision: input.Decision, ApprovalRef: input.ApprovalRef, OccurredAt: time.Now().UTC().Format(time.RFC3339)}
	m.Review = rv
	switch input.Decision {
	case "resume":
		m.Status = "resumed"
	case "adjust":
		m.Status = "resumed"
	case "cancel":
		m.Status = "cancelled"
	}
	m.Actions = append(m.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "review", By: input.ReviewedBy, Reference: input.ApprovalRef, OccurredAt: rv.OccurredAt})
	s.save(); write(w, http.StatusOK, map[string]any{"mission": m, "review": rv, "replayed": false})
}

func (s *store) complete(w http.ResponseWriter, r *http.Request, m *mission) {
	var input struct{ CompletedBy string `json:"completed_by"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.CompletedBy == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "completed_by_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	if m.Status != "running" && m.Status != "resumed" { write(w, http.StatusForbidden, map[string]string{"error": "mission_not_active"}); return }
	m.Status = "completed"
	m.Actions = append(m.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "complete", By: input.CompletedBy, OccurredAt: time.Now().UTC().Format(time.RFC3339)})
	s.save(); write(w, http.StatusOK, map[string]any{"mission": m, "replayed": false})
}

func contains(list []string, v string) bool {
	for _, x := range list { if x == v { return true } }
	return false
}

func (s *store) notifications(w http.ResponseWriter, r *http.Request) { s.Lock(); defer s.Unlock(); id := strings.TrimPrefix(r.URL.Path, "/v1/notifications/"); m, ok := s.Missions[id]; if !ok { write(w, http.StatusNotFound, map[string]string{"error": "mission_not_found"}); return }; pending := []string{}; if m.Exception != nil { pending = append(pending, "operator-review-pending:"+m.Exception.ID) }; if m.Status == "completed" { pending = append(pending, "mission-complete-notification-pending:"+m.ID) }; write(w, http.StatusOK, map[string]any{"mission_id": id, "notifications": pending}) }

func write(w http.ResponseWriter, status int, v any) { w.Header().Set("Content-Type", "application/json"); w.WriteHeader(status); _ = json.NewEncoder(w).Encode(v) }
