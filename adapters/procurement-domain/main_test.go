package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func do(t *testing.T, mux http.Handler, method, path, body string) (*httptest.ResponseRecorder, map[string]any) {
	t.Helper()
	var rdr *bytes.Reader
	if body == "" { rdr = bytes.NewReader(nil) } else { rdr = bytes.NewReader([]byte(body)) }
	req := httptest.NewRequest(method, path, rdr)
	if body != "" { req.Header.Set("Content-Type", "application/json") }
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	var out map[string]any
	if rec.Body.Len() > 0 { _ = json.Unmarshal(rec.Body.Bytes(), &out) }
	return rec, out
}

func newTestServer(t *testing.T) (*store, http.Handler) {
	t.Helper()
	s := load(t.TempDir() + "/data.json")
	return s, newMux(s)
}

const procBase = "/v1/requests/preq-0001"

func TestProcurementHealth(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "GET", "/healthz", "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
}

func TestProcurementSubmit(t *testing.T) {
	_, mux := newTestServer(t)
	rec, body := do(t, mux, "POST", procBase+"/submit", `{"requester":"e-1001","idempotency_key":"sub-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	req := body["request"].(map[string]any)
	if req["status"] != "submitted" { t.Fatalf("expected submitted, got %v", req["status"]) }
}

func TestProcurementSubmitMismatch(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", procBase+"/submit", `{"requester":"other","idempotency_key":"sub-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestProcurementSelfApprovalDenied(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", procBase+"/submit", `{"requester":"e-1001","idempotency_key":"sub-v1"}`)
	rec, _ := do(t, mux, "POST", procBase+"/approvals", `{"role":"finance","approver":"e-1001","decision":"approve","approval_ref":"approval://test","idempotency_key":"self-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestProcurementBothRolesApprove(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", procBase+"/submit", `{"requester":"e-1001","idempotency_key":"sub-v1"}`)
	do(t, mux, "POST", procBase+"/approvals", `{"role":"finance","approver":"finance-lead","decision":"approve","approval_ref":"approval://test","idempotency_key":"fin-v1"}`)
	rec, body := do(t, mux, "POST", procBase+"/approvals", `{"role":"procurement","approver":"procurement-owner","decision":"approve","approval_ref":"approval://test","idempotency_key":"pr-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	req := body["request"].(map[string]any)
	if req["status"] != "approved" { t.Fatalf("expected approved, got %v", req["status"]) }
}

func TestProcurementUnapprovedPurchaseDenied(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", procBase+"/submit", `{"requester":"e-1001","idempotency_key":"sub-v1"}`)
	rec, _ := do(t, mux, "POST", procBase+"/purchase-actions", `{"supplier":"supplier-b","approved_by":"procurement-owner","approval_ref":"approval://test","idempotency_key":"buy-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestProcurementFullFlow(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", procBase+"/submit", `{"requester":"e-1001","idempotency_key":"sub-v1"}`)
	do(t, mux, "POST", procBase+"/approvals", `{"role":"finance","approver":"finance-lead","decision":"approve","approval_ref":"approval://test","idempotency_key":"fin-v1"}`)
	do(t, mux, "POST", procBase+"/approvals", `{"role":"procurement","approver":"procurement-owner","decision":"approve","approval_ref":"approval://test","idempotency_key":"pr-v1"}`)
	rec, body := do(t, mux, "POST", procBase+"/purchase-actions", `{"supplier":"supplier-b","approved_by":"procurement-owner","approval_ref":"approval://test","idempotency_key":"buy-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	po := body["po"].(map[string]any)
	if po["id"] != "po-preq-0001-supplier-b" { t.Fatalf("unexpected po: %v", po["id"]) }
	rec, body = do(t, mux, "POST", procBase+"/receipts", `{"received_by":"warehouse-receiver","accepted":true,"idempotency_key":"rcv-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	req := body["request"].(map[string]any)
	if req["status"] != "closed" { t.Fatalf("expected closed, got %v", req["status"]) }
}

func TestProcurementBudgetDeducted(t *testing.T) {
	s, mux := newTestServer(t)
	do(t, mux, "POST", procBase+"/submit", `{"requester":"e-1001","idempotency_key":"sub-v1"}`)
	do(t, mux, "POST", procBase+"/approvals", `{"role":"finance","approver":"finance-lead","decision":"approve","approval_ref":"approval://test","idempotency_key":"fin-v1"}`)
	do(t, mux, "POST", procBase+"/approvals", `{"role":"procurement","approver":"procurement-owner","decision":"approve","approval_ref":"approval://test","idempotency_key":"pr-v1"}`)
	do(t, mux, "POST", procBase+"/purchase-actions", `{"supplier":"supplier-b","approved_by":"procurement-owner","approval_ref":"approval://test","idempotency_key":"buy-v1"}`)
	s.Lock()
	b := s.Budgets["budget-0001"]
	s.Unlock()
	if b.Available != 4780 { t.Fatalf("expected budget 4780, got %d", b.Available) }
}
