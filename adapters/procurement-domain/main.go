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

type approval struct {
	ID            string `json:"id"`
	Role          string `json:"role"`
	Approver      string `json:"approver"`
	Decision      string `json:"decision"`
	ApprovalRef   string `json:"approval_ref"`
	IdempotencyKey string `json:"idempotency_key"`
	OccurredAt    string `json:"occurred_at"`
}

type po struct {
	ID       string `json:"id"`
	Supplier string `json:"supplier"`
	Amount   int    `json:"amount"`
	Status   string `json:"status"`
}

type receipt struct {
	ID         string `json:"id"`
	ReceivedBy string `json:"received_by"`
	Accepted   bool   `json:"accepted"`
}

type action struct {
	ID             string `json:"id"`
	Type           string `json:"type"`
	ApprovedBy     string `json:"approved_by"`
	ApprovalRef    string `json:"approval_ref"`
	IdempotencyKey string `json:"idempotency_key"`
	OccurredAt     string `json:"occurred_at"`
}

type request struct {
	ID         string     `json:"id"`
	Requester  string     `json:"requester"`
	Item       string     `json:"item"`
	Quantity   int        `json:"quantity"`
	CostCenter string     `json:"cost_center"`
	BudgetRef  string     `json:"budget_ref"`
	Status     string     `json:"status"`
	Approvals  []approval `json:"approvals"`
	PO         *po        `json:"po,omitempty"`
	Receipt    *receipt   `json:"receipt,omitempty"`
	Actions    []action   `json:"actions"`
}

type budget struct {
	ID         string `json:"id"`
	CostCenter string `json:"cost_center"`
	Available  int    `json:"available"`
	Currency   string `json:"currency"`
}

type supplier struct {
	ID        string `json:"id"`
	Preferred bool   `json:"preferred"`
	Price     int    `json:"price"`
}

type store struct {
	sync.Mutex
	Requests  map[string]*request  `json:"requests"`
	Budgets   map[string]*budget   `json:"budgets"`
	Suppliers map[string]*supplier `json:"suppliers"`
	file      string
}

func main() {
	addr := flag.String("addr", ":8092", "HTTP listen address")
	dataFile := flag.String("data-file", "procurement-domain-data.json", "JSON persistence file")
	flag.Parse()
	s := load(*dataFile)
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { write(w, http.StatusOK, map[string]string{"status": "ok", "service": "procurement-domain-adapter"}) })
	mux.HandleFunc("/v1/requests/", s.requests)
	mux.HandleFunc("/v1/budget/", s.budget)
	mux.HandleFunc("/v1/suppliers/", s.suppliers)
	mux.HandleFunc("/v1/pos/", s.pos)
	log.Printf("procurement-domain adapter listening on %s", *addr)
	log.Fatal(http.ListenAndServe(*addr, mux))
}

func load(file string) *store {
	s := &store{file: file, Requests: map[string]*request{}, Budgets: map[string]*budget{"budget-0001": {ID: "budget-0001", CostCenter: "CC-1001", Available: 5000, Currency: "USD"}}, Suppliers: map[string]*supplier{"supplier-a": {ID: "supplier-a", Preferred: false, Price: 240}, "supplier-b": {ID: "supplier-b", Preferred: true, Price: 220}}}
	s.Requests["preq-0001"] = &request{ID: "preq-0001", Requester: "e-1001", Item: "desk-chair-ergo", Quantity: 1, CostCenter: "CC-1001", BudgetRef: "budget-0001", Status: "draft"}
	b, err := os.ReadFile(file)
	if err == nil { _ = json.Unmarshal(b, s) }
	return s
}

func (s *store) save() {
	_ = os.MkdirAll(filepath.Dir(s.file), 0755)
	b, _ := json.MarshalIndent(s, "", "  ")
	_ = os.WriteFile(s.file, b, 0600)
}

func (s *store) requests(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/v1/requests/"), "/")
	s.Lock()
	req, ok := s.Requests[parts[0]]
	s.Unlock()
	if !ok { write(w, http.StatusNotFound, map[string]string{"error": "request_not_found"}); return }
	switch {
	case len(parts) == 1 && r.Method == http.MethodGet:
		s.getRequest(w, req)
	case len(parts) == 2 && parts[1] == "submit" && r.Method == http.MethodPost:
		s.submit(w, r, req)
	case len(parts) == 2 && parts[1] == "approvals" && r.Method == http.MethodPost:
		s.approve(w, r, req)
	case len(parts) == 2 && parts[1] == "purchase-actions" && r.Method == http.MethodPost:
		s.purchase(w, r, req)
	case len(parts) == 2 && parts[1] == "receipts" && r.Method == http.MethodPost:
		s.receive(w, r, req)
	default:
		write(w, http.StatusNotFound, map[string]string{"error": "not_found"})
	}
}

func (s *store) getRequest(w http.ResponseWriter, req *request) {
	s.Lock(); defer s.Unlock()
	write(w, http.StatusOK, req)
}

func (s *store) submit(w http.ResponseWriter, r *http.Request, req *request) {
	var input struct{ Requester string `json:"requester"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.Requester == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "requester_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	if req.Requester != input.Requester { write(w, http.StatusForbidden, map[string]string{"error": "requester_mismatch"}); return }
	for _, a := range req.Actions { if a.Type == "submit" && a.IdempotencyKey == input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"request": req, "replayed": true}); return } }
	if req.Status != "draft" { write(w, http.StatusConflict, map[string]string{"error": "request_not_draft"}); return }
	req.Actions = append(req.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "submit", ApprovedBy: input.Requester, IdempotencyKey: input.IdempotencyKey, OccurredAt: time.Now().UTC().Format(time.RFC3339)})
	req.Status = "submitted"
	s.save(); write(w, http.StatusOK, map[string]any{"request": req, "replayed": false})
}

func (s *store) approve(w http.ResponseWriter, r *http.Request, req *request) {
	var input struct{ Role string `json:"role"`; Approver string `json:"approver"`; Decision string `json:"decision"`; ApprovalRef string `json:"approval_ref"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.Role == "" || input.Approver == "" || input.Decision == "" || input.ApprovalRef == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "role_approver_decision_approval_ref_and_idempotency_key_are_required"}); return }
	if input.Role != "finance" && input.Role != "procurement" { write(w, http.StatusBadRequest, map[string]string{"error": "unsupported_role"}); return }
	if input.Decision != "approve" && input.Decision != "reject" { write(w, http.StatusBadRequest, map[string]string{"error": "decision_must_be_approve_or_reject"}); return }
	s.Lock(); defer s.Unlock()
	if input.Approver == req.Requester { write(w, http.StatusForbidden, map[string]string{"error": "segregation_of_duties_requester_cannot_approve_own_request"}); return }
	for _, a := range req.Approvals { if a.IdempotencyKey == input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"request": req, "approval": a, "replayed": true}); return } }
	a := approval{ID: "approval-" + input.IdempotencyKey, Role: input.Role, Approver: input.Approver, Decision: input.Decision, ApprovalRef: input.ApprovalRef, IdempotencyKey: input.IdempotencyKey, OccurredAt: time.Now().UTC().Format(time.RFC3339)}
	req.Approvals = append(req.Approvals, a)
	if input.Decision == "reject" { req.Status = "rejected" } else if hasApproval(req, "finance") && hasApproval(req, "procurement") { req.Status = "approved" }
	s.save(); write(w, http.StatusOK, map[string]any{"request": req, "approval": a, "replayed": false})
}

func hasApproval(req *request, role string) bool {
	for _, a := range req.Approvals { if a.Role == role && a.Decision == "approve" { return true } }
	return false
}

func (s *store) purchase(w http.ResponseWriter, r *http.Request, req *request) {
	var input struct{ Supplier string `json:"supplier"`; ApprovedBy string `json:"approved_by"`; ApprovalRef string `json:"approval_ref"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.Supplier == "" || input.ApprovedBy == "" || input.ApprovalRef == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "supplier_approved_by_approval_ref_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	for _, a := range req.Actions { if a.Type == "purchase" && a.IdempotencyKey == input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"request": req, "po": req.PO, "replayed": true}); return } }
	if req.Status != "approved" { write(w, http.StatusForbidden, map[string]string{"error": "request_not_approved"}); return }
	if !hasApproval(req, "finance") || !hasApproval(req, "procurement") { write(w, http.StatusForbidden, map[string]string{"error": "required_approvals_missing"}); return }
	sup, ok := s.Suppliers[input.Supplier]
	if !ok { write(w, http.StatusBadRequest, map[string]string{"error": "supplier_not_found"}); return }
	b := s.Budgets[req.BudgetRef]
	if b.Available < sup.Price { write(w, http.StatusUnprocessableEntity, map[string]string{"error": "insufficient_budget"}); return }
	poID := "po-" + req.ID + "-" + input.Supplier
	req.PO = &po{ID: poID, Supplier: input.Supplier, Amount: sup.Price, Status: "ordered"}
	b.Available -= sup.Price
	req.Actions = append(req.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "purchase", ApprovedBy: input.ApprovedBy, ApprovalRef: input.ApprovalRef, IdempotencyKey: input.IdempotencyKey, OccurredAt: time.Now().UTC().Format(time.RFC3339)})
	req.Status = "ordered"
	s.save(); write(w, http.StatusOK, map[string]any{"request": req, "po": req.PO, "replayed": false})
}

func (s *store) receive(w http.ResponseWriter, r *http.Request, req *request) {
	var input struct{ ReceivedBy string `json:"received_by"`; Accepted bool `json:"accepted"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.ReceivedBy == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "received_by_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	if req.Receipt != nil && req.Receipt.ID == "receipt-"+input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"request": req, "receipt": req.Receipt, "replayed": true}); return }
	if req.PO == nil { write(w, http.StatusForbidden, map[string]string{"error": "no_purchase_order"}); return }
	rec := &receipt{ID: "receipt-" + input.IdempotencyKey, ReceivedBy: input.ReceivedBy, Accepted: input.Accepted}
	req.Receipt = rec
	req.Actions = append(req.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "receive", ApprovedBy: input.ReceivedBy, IdempotencyKey: input.IdempotencyKey, OccurredAt: time.Now().UTC().Format(time.RFC3339)})
	if input.Accepted { req.PO.Status = "received" } else { req.PO.Status = "discrepancy" }
	req.Status = "closed"
	s.save(); write(w, http.StatusOK, map[string]any{"request": req, "receipt": rec, "replayed": false})
}

func (s *store) budget(w http.ResponseWriter, r *http.Request) { s.Lock(); defer s.Unlock(); id := strings.TrimPrefix(r.URL.Path, "/v1/budget/"); b, ok := s.Budgets[id]; if !ok { write(w, http.StatusNotFound, map[string]string{"error": "budget_not_found"}); return }; write(w, http.StatusOK, b) }

func (s *store) suppliers(w http.ResponseWriter, r *http.Request) { s.Lock(); defer s.Unlock(); id := strings.TrimPrefix(r.URL.Path, "/v1/suppliers/"); sup, ok := s.Suppliers[id]; if !ok { write(w, http.StatusNotFound, map[string]string{"error": "supplier_not_found"}); return }; write(w, http.StatusOK, sup) }

func (s *store) pos(w http.ResponseWriter, r *http.Request) { s.Lock(); defer s.Unlock(); id := strings.TrimPrefix(r.URL.Path, "/v1/pos/"); for _, req := range s.Requests { if req.PO != nil && req.PO.ID == id { write(w, http.StatusOK, req.PO); return } }; write(w, http.StatusNotFound, map[string]string{"error": "po_not_found"}) }

func write(w http.ResponseWriter, status int, v any) { w.Header().Set("Content-Type", "application/json"); w.WriteHeader(status); _ = json.NewEncoder(w).Encode(v) }
