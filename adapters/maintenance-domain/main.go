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
	ID            string `json:"id"`
	Decision      string `json:"decision"`
	DecidedBy     string `json:"decided_by"`
	DecisionRef   string `json:"decision_ref"`
	IdempotencyKey string `json:"idempotency_key"`
	OccurredAt    string `json:"occurred_at"`
}

type safetyReview struct {
	ID            string `json:"id"`
	ReviewedBy    string `json:"reviewed_by"`
	Outcome       string `json:"outcome"`
	SafetyRef     string `json:"safety_ref"`
	IdempotencyKey string `json:"idempotency_key"`
	OccurredAt    string `json:"occurred_at"`
}

type workOrder struct {
	ID         string `json:"id"`
	Signal     string `json:"signal"`
	Scope      string `json:"scope"`
	ApprovedBy string `json:"approved_by"`
	ApprovalRef string `json:"approval_ref"`
	Status     string `json:"status"`
}

type action struct {
	ID        string `json:"id"`
	Type      string `json:"type"`
	By        string `json:"by"`
	Reference string `json:"reference,omitempty"`
	OccurredAt string `json:"occurred_at"`
}

type signal struct {
	ID             string      `json:"id"`
	Asset          string      `json:"asset"`
	Level          string      `json:"level"`
	Status         string      `json:"status"`
	ValidatedBy    string      `json:"validated_by,omitempty"`
	Confirmed      bool        `json:"confirmed"`
	ValidationNote string      `json:"validation_note,omitempty"`
	Decision       *decision   `json:"decision,omitempty"`
	Safety         *safetyReview `json:"safety,omitempty"`
	WorkOrder      *workOrder  `json:"work_order,omitempty"`
	Actions        []action    `json:"actions"`
}

type asset struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	Zone   string `json:"zone"`
	Status string `json:"status"`
}

type store struct {
	sync.Mutex
	Signals    map[string]*signal `json:"signals"`
	Assets     map[string]*asset  `json:"assets"`
	WorkOrders map[string]*workOrder `json:"work_orders"`
	file       string
}

func main() {
	addr := flag.String("addr", ":8095", "HTTP listen address")
	dataFile := flag.String("data-file", "maintenance-domain-data.json", "JSON persistence file")
	flag.Parse()
	s := load(*dataFile)
	log.Printf("maintenance-domain adapter listening on %s", *addr)
	log.Fatal(http.ListenAndServe(*addr, newMux(s)))
}

func newMux(s *store) *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { write(w, http.StatusOK, map[string]string{"status": "ok", "service": "maintenance-domain-adapter"}) })
	mux.HandleFunc("/v1/assets/", s.assets)
	mux.HandleFunc("/v1/signals/", s.signals)
	mux.HandleFunc("/v1/workorders/", s.workorders)
	mux.HandleFunc("/v1/notifications/", s.notifications)
	return mux
}

func load(file string) *store {
	s := &store{file: file, Signals: map[string]*signal{"signal-pm-0001": {ID: "signal-pm-0001", Asset: "asset-pump-01", Level: "elevated", Status: "pending"}}, Assets: map[string]*asset{"asset-pump-01": {ID: "asset-pump-01", Name: "Cooling Pump 01", Zone: "zone-b", Status: "running"}}, WorkOrders: map[string]*workOrder{}}
	b, err := os.ReadFile(file)
	if err == nil { _ = json.Unmarshal(b, s) }
	return s
}

func (s *store) save() {
	_ = os.MkdirAll(filepath.Dir(s.file), 0755)
	b, _ := json.MarshalIndent(s, "", "  ")
	_ = os.WriteFile(s.file, b, 0600)
}

func (s *store) signals(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/v1/signals/"), "/")
	s.Lock()
	sig, ok := s.Signals[parts[0]]
	s.Unlock()
	if !ok { write(w, http.StatusNotFound, map[string]string{"error": "signal_not_found"}); return }
	switch {
	case len(parts) == 1 && r.Method == http.MethodGet:
		s.Lock(); defer s.Unlock()
		write(w, http.StatusOK, sig)
	case len(parts) == 2 && parts[1] == "validate" && r.Method == http.MethodPost:
		s.validate(w, r, sig)
	case len(parts) == 2 && parts[1] == "decisions" && r.Method == http.MethodPost:
		s.decide(w, r, sig)
	case len(parts) == 2 && parts[1] == "safety-reviews" && r.Method == http.MethodPost:
		s.safety(w, r, sig)
	case len(parts) == 2 && parts[1] == "work-orders" && r.Method == http.MethodPost:
		s.createWorkOrder(w, r, sig)
	default:
		write(w, http.StatusNotFound, map[string]string{"error": "not_found"})
	}
}

func (s *store) validate(w http.ResponseWriter, r *http.Request, sig *signal) {
	var input struct{ ValidatedBy string `json:"validated_by"`; Confirmed bool `json:"confirmed"`; Note string `json:"note"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.ValidatedBy == "" || input.Note == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "validated_by_note_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	if input.ValidatedBy != "maintenance-manager" { write(w, http.StatusForbidden, map[string]string{"error": "only_maintenance_manager_can_validate"}); return }
	for _, a := range sig.Actions { if a.Type == "validate" && a.ID == "action-"+input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"signal": sig, "replayed": true}); return } }
	if sig.Status != "pending" { write(w, http.StatusConflict, map[string]string{"error": "signal_already_validated"}); return }
	sig.Status = "validated"
	sig.ValidatedBy = input.ValidatedBy
	sig.Confirmed = input.Confirmed
	sig.ValidationNote = input.Note
	sig.Actions = append(sig.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "validate", By: input.ValidatedBy, OccurredAt: time.Now().UTC().Format(time.RFC3339)})
	s.save(); write(w, http.StatusOK, map[string]any{"signal": sig, "replayed": false})
}

func (s *store) decide(w http.ResponseWriter, r *http.Request, sig *signal) {
	var input struct{ Decision string `json:"decision"`; DecidedBy string `json:"decided_by"`; DecisionRef string `json:"decision_ref"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.Decision == "" || input.DecidedBy == "" || input.DecisionRef == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "decision_decided_by_decision_ref_and_idempotency_key_are_required"}); return }
	if input.Decision != "monitor" && input.Decision != "inspect" && input.Decision != "repair" && input.Decision != "defer" && input.Decision != "stop" { write(w, http.StatusBadRequest, map[string]string{"error": "unsupported_decision"}); return }
	s.Lock(); defer s.Unlock()
	for _, d := range []*decision{sig.Decision} { if d != nil && d.IdempotencyKey == input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"signal": sig, "decision": d, "replayed": true}); return } }
	if sig.Status != "validated" { write(w, http.StatusConflict, map[string]string{"error": "signal_must_be_validated_first"}); return }
	if sig.Confirmed == false && input.Decision == "stop" { write(w, http.StatusForbidden, map[string]string{"error": "unconfirmed_prediction_cannot_trigger_stop"}); return }
	d := &decision{ID: "decision-" + input.IdempotencyKey, Decision: input.Decision, DecidedBy: input.DecidedBy, DecisionRef: input.DecisionRef, IdempotencyKey: input.IdempotencyKey, OccurredAt: time.Now().UTC().Format(time.RFC3339)}
	sig.Decision = d
	sig.Actions = append(sig.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "decision", By: input.DecidedBy, Reference: input.DecisionRef, OccurredAt: d.OccurredAt})
	s.save(); write(w, http.StatusOK, map[string]any{"signal": sig, "decision": d, "replayed": false})
}

func (s *store) safety(w http.ResponseWriter, r *http.Request, sig *signal) {
	var input struct{ ReviewedBy string `json:"reviewed_by"`; Outcome string `json:"outcome"`; SafetyRef string `json:"safety_ref"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.ReviewedBy == "" || input.Outcome == "" || input.SafetyRef == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "reviewed_by_outcome_safety_ref_and_idempotency_key_are_required"}); return }
	if input.ReviewedBy != "safety-authority" { write(w, http.StatusForbidden, map[string]string{"error": "only_safety_authority_can_review"}); return }
	if input.Outcome != "approve" && input.Outcome != "block" { write(w, http.StatusBadRequest, map[string]string{"error": "outcome_must_be_approve_or_block"}); return }
	s.Lock(); defer s.Unlock()
	if sig.Safety != nil && sig.Safety.IdempotencyKey == input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"signal": sig, "safety": sig.Safety, "replayed": true}); return }
	sr := &safetyReview{ID: "safety-" + input.IdempotencyKey, ReviewedBy: input.ReviewedBy, Outcome: input.Outcome, SafetyRef: input.SafetyRef, IdempotencyKey: input.IdempotencyKey, OccurredAt: time.Now().UTC().Format(time.RFC3339)}
	sig.Safety = sr
	sig.Actions = append(sig.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "safety-review", By: input.ReviewedBy, Reference: input.SafetyRef, OccurredAt: sr.OccurredAt})
	s.save(); write(w, http.StatusOK, map[string]any{"signal": sig, "safety": sr, "replayed": false})
}

func (s *store) createWorkOrder(w http.ResponseWriter, r *http.Request, sig *signal) {
	var input struct{ Scope string `json:"scope"`; ApprovedBy string `json:"approved_by"`; ApprovalRef string `json:"approval_ref"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.Scope == "" || input.ApprovedBy == "" || input.ApprovalRef == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "scope_approved_by_approval_ref_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	if sig.WorkOrder != nil && sig.WorkOrder.ID == "wo-"+input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"signal": sig, "work_order": sig.WorkOrder, "replayed": true}); return }
	if sig.Status != "validated" { write(w, http.StatusForbidden, map[string]string{"error": "signal_not_validated_prediction_is_not_a_fault"}); return }
	if sig.Decision == nil { write(w, http.StatusForbidden, map[string]string{"error": "no_maintenance_decision"}); return }
	if (sig.Decision.Decision == "repair" || sig.Decision.Decision == "stop") && (sig.Safety == nil || sig.Safety.Outcome != "approve") { write(w, http.StatusForbidden, map[string]string{"error": "safety_review_required_for_intrusive_work"}); return }
	if sig.Decision.Decision == "monitor" || sig.Decision.Decision == "inspect" || sig.Decision.Decision == "defer" { write(w, http.StatusBadRequest, map[string]string{"error": "decision_does_not_require_work_order"}); return }
	wo := &workOrder{ID: "wo-" + input.IdempotencyKey, Signal: sig.ID, Scope: input.Scope, ApprovedBy: input.ApprovedBy, ApprovalRef: input.ApprovalRef, Status: "scheduled"}
	sig.WorkOrder = wo
	s.WorkOrders[wo.ID] = wo
	sig.Actions = append(sig.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "work-order", By: input.ApprovedBy, Reference: input.ApprovalRef, OccurredAt: time.Now().UTC().Format(time.RFC3339)})
	s.save(); write(w, http.StatusOK, map[string]any{"signal": sig, "work_order": wo, "replayed": false})
}

func (s *store) assets(w http.ResponseWriter, r *http.Request) { s.Lock(); defer s.Unlock(); id := strings.TrimPrefix(r.URL.Path, "/v1/assets/"); a, ok := s.Assets[id]; if !ok { write(w, http.StatusNotFound, map[string]string{"error": "asset_not_found"}); return }; write(w, http.StatusOK, a) }

func (s *store) workorders(w http.ResponseWriter, r *http.Request) { s.Lock(); defer s.Unlock(); id := strings.TrimPrefix(r.URL.Path, "/v1/workorders/"); wo, ok := s.WorkOrders[id]; if !ok { write(w, http.StatusNotFound, map[string]string{"error": "work_order_not_found"}); return }; write(w, http.StatusOK, wo) }

func (s *store) notifications(w http.ResponseWriter, r *http.Request) { s.Lock(); defer s.Unlock(); id := strings.TrimPrefix(r.URL.Path, "/v1/notifications/"); sig, ok := s.Signals[id]; if !ok { write(w, http.StatusNotFound, map[string]string{"error": "signal_not_found"}); return }; pending := []string{}; if sig.WorkOrder != nil { pending = append(pending, "work-order-notification-pending:"+sig.WorkOrder.ID) }; write(w, http.StatusOK, map[string]any{"signal_id": id, "notifications": pending}) }

func write(w http.ResponseWriter, status int, v any) { w.Header().Set("Content-Type", "application/json"); w.WriteHeader(status); _ = json.NewEncoder(w).Encode(v) }
