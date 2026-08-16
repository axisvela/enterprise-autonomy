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

type reconnectCheck struct {
	ID            string `json:"id"`
	CheckedBy     string `json:"checked_by"`
	Verified      bool   `json:"verified"`
	EvidenceRef   string `json:"evidence_ref"`
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

type integration struct {
	ID          string          `json:"id"`
	Status      string          `json:"status"`
	LastSeen    string          `json:"last_seen"`
	OutageSince string          `json:"outage_since,omitempty"`
	Check       *reconnectCheck `json:"check,omitempty"`
	Actions     []action        `json:"actions"`
}

type workItem struct {
	ID           string   `json:"id"`
	Affects      string   `json:"affects"`
	Status       string   `json:"status"`
	PreservedBy  string   `json:"preserved_by,omitempty"`
	PreservedRef string   `json:"preserved_ref,omitempty"`
	ResumedBy    string   `json:"resumed_by,omitempty"`
	CompletedBy  string   `json:"completed_by,omitempty"`
	Actions      []action `json:"actions"`
}

type store struct {
	sync.Mutex
	Integrations map[string]*integration `json:"integrations"`
	Work         map[string]*workItem    `json:"work"`
	file         string
}

func main() {
	addr := flag.String("addr", ":8096", "HTTP listen address")
	dataFile := flag.String("data-file", "integration-domain-data.json", "JSON persistence file")
	flag.Parse()
	s := load(*dataFile)
	log.Printf("integration-domain adapter listening on %s", *addr)
	log.Fatal(http.ListenAndServe(*addr, newMux(s)))
}

func newMux(s *store) *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { write(w, http.StatusOK, map[string]string{"status": "ok", "service": "integration-domain-adapter"}) })
	mux.HandleFunc("/v1/integrations/", s.integrations)
	mux.HandleFunc("/v1/work/", s.work)
	mux.HandleFunc("/v1/notifications/", s.notifications)
	return mux
}

func load(file string) *store {
	s := &store{file: file, Integrations: map[string]*integration{"partner-shipping": {ID: "partner-shipping", Status: "down", LastSeen: "2026-08-16T09:58:00Z", OutageSince: "2026-08-16T10:00:00Z"}}, Work: map[string]*workItem{"work-0001": {ID: "work-0001", Affects: "order-123", Status: "inflight"}}}
	b, err := os.ReadFile(file)
	if err == nil { _ = json.Unmarshal(b, s) }
	return s
}

func (s *store) save() {
	_ = os.MkdirAll(filepath.Dir(s.file), 0755)
	b, _ := json.MarshalIndent(s, "", "  ")
	_ = os.WriteFile(s.file, b, 0600)
}

func (s *store) integrations(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/v1/integrations/"), "/")
	s.Lock()
	it, ok := s.Integrations[parts[0]]
	s.Unlock()
	if !ok { write(w, http.StatusNotFound, map[string]string{"error": "integration_not_found"}); return }
	switch {
	case len(parts) == 1 && r.Method == http.MethodGet:
		s.Lock(); defer s.Unlock()
		write(w, http.StatusOK, it)
	case len(parts) == 2 && parts[1] == "checks" && r.Method == http.MethodPost:
		s.check(w, r, it)
	default:
		write(w, http.StatusNotFound, map[string]string{"error": "not_found"})
	}
}

func (s *store) work(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/v1/work/"), "/")
	s.Lock()
	wi, ok := s.Work[parts[0]]
	s.Unlock()
	if !ok { write(w, http.StatusNotFound, map[string]string{"error": "work_not_found"}); return }
	switch {
	case len(parts) == 1 && r.Method == http.MethodGet:
		s.Lock(); defer s.Unlock()
		write(w, http.StatusOK, wi)
	case len(parts) == 2 && parts[1] == "preserve" && r.Method == http.MethodPost:
		s.preserve(w, r, wi)
	case len(parts) == 2 && parts[1] == "resume" && r.Method == http.MethodPost:
		s.resume(w, r, wi)
	case len(parts) == 2 && parts[1] == "complete" && r.Method == http.MethodPost:
		s.complete(w, r, wi)
	default:
		write(w, http.StatusNotFound, map[string]string{"error": "not_found"})
	}
}

func (s *store) check(w http.ResponseWriter, r *http.Request, it *integration) {
	var input struct{ CheckedBy string `json:"checked_by"`; Verified bool `json:"verified"`; EvidenceRef string `json:"evidence_ref"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.CheckedBy == "" || input.EvidenceRef == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "checked_by_evidence_ref_and_idempotency_key_are_required"}); return }
	if input.CheckedBy != "integration-owner" { write(w, http.StatusForbidden, map[string]string{"error": "only_integration_owner_can_check"}); return }
	s.Lock(); defer s.Unlock()
	if it.Check != nil && it.Check.IdempotencyKey == input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"integration": it, "check": it.Check, "replayed": true}); return }
	ck := &reconnectCheck{ID: "check-" + input.IdempotencyKey, CheckedBy: input.CheckedBy, Verified: input.Verified, EvidenceRef: input.EvidenceRef, IdempotencyKey: input.IdempotencyKey, OccurredAt: time.Now().UTC().Format(time.RFC3339)}
	it.Check = ck
	if input.Verified { it.Status = "checked" }
	it.Actions = append(it.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "reconnect-check", By: input.CheckedBy, Reference: input.EvidenceRef, OccurredAt: ck.OccurredAt})
	s.save(); write(w, http.StatusOK, map[string]any{"integration": it, "check": ck, "replayed": false})
}

func (s *store) preserve(w http.ResponseWriter, r *http.Request, wi *workItem) {
	var input struct{ PreservedBy string `json:"preserved_by"`; PreservedRef string `json:"preserved_ref"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.PreservedBy == "" || input.PreservedRef == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "preserved_by_preserved_ref_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	for _, a := range wi.Actions { if a.Type == "preserve" && a.ID == "action-"+input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"work": wi, "replayed": true}); return } }
	if wi.Status != "inflight" { write(w, http.StatusConflict, map[string]string{"error": "work_not_inflight"}); return }
	wi.Status = "preserved"
	wi.PreservedBy = input.PreservedBy
	wi.PreservedRef = input.PreservedRef
	wi.Actions = append(wi.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "preserve", By: input.PreservedBy, Reference: input.PreservedRef, OccurredAt: time.Now().UTC().Format(time.RFC3339)})
	s.save(); write(w, http.StatusOK, map[string]any{"work": wi, "replayed": false})
}

func (s *store) resume(w http.ResponseWriter, r *http.Request, wi *workItem) {
	var input struct{ ResumedBy string `json:"resumed_by"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.ResumedBy == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "resumed_by_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	for _, a := range wi.Actions { if a.Type == "resume" && a.ID == "action-"+input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"work": wi, "replayed": true}); return } }
	if wi.Status != "preserved" { write(w, http.StatusForbidden, map[string]string{"error": "work_not_preserved"}); return }
	verified := false
	for _, it := range s.Integrations {
		if it.Check != nil && it.Check.Verified && it.Status == "checked" { verified = true }
	}
	if !verified { write(w, http.StatusForbidden, map[string]string{"error": "integration_not_verified"}); return }
	wi.Status = "resumed"
	wi.ResumedBy = input.ResumedBy
	wi.Actions = append(wi.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "resume", By: input.ResumedBy, OccurredAt: time.Now().UTC().Format(time.RFC3339)})
	s.save(); write(w, http.StatusOK, map[string]any{"work": wi, "replayed": false})
}

func (s *store) complete(w http.ResponseWriter, r *http.Request, wi *workItem) {
	var input struct{ CompletedBy string `json:"completed_by"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.CompletedBy == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "completed_by_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	for _, a := range wi.Actions { if a.Type == "complete" && a.ID == "action-"+input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"work": wi, "replayed": true}); return } }
	if wi.Status == "completed" { write(w, http.StatusConflict, map[string]string{"error": "action_already_completed_no_silent_rerun"}); return }
	if wi.Status != "resumed" { write(w, http.StatusForbidden, map[string]string{"error": "work_not_resumed"}); return }
	wi.Status = "completed"
	wi.CompletedBy = input.CompletedBy
	wi.Actions = append(wi.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "complete", By: input.CompletedBy, OccurredAt: time.Now().UTC().Format(time.RFC3339)})
	s.save(); write(w, http.StatusOK, map[string]any{"work": wi, "replayed": false})
}

func (s *store) notifications(w http.ResponseWriter, r *http.Request) { s.Lock(); defer s.Unlock(); id := strings.TrimPrefix(r.URL.Path, "/v1/notifications/"); if wi, ok := s.Work[id]; ok { pending := []string{}; if wi.Status == "completed" { pending = append(pending, "outage-recovery-notification-pending:"+wi.ID) }; write(w, http.StatusOK, map[string]any{"work_id": id, "notifications": pending}); return }; write(w, http.StatusNotFound, map[string]string{"error": "work_not_found"}) }

func write(w http.ResponseWriter, status int, v any) { w.Header().Set("Content-Type", "application/json"); w.WriteHeader(status); _ = json.NewEncoder(w).Encode(v) }
