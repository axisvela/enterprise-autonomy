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

const custBase = "/v1/cases/cs-0001"

func TestCustomerHealth(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "GET", "/healthz", "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
}

func TestCustomerSeed(t *testing.T) {
	_, mux := newTestServer(t)
	rec, body := do(t, mux, "GET", custBase, "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	if body["status"] != "open" { t.Fatalf("expected open, got %v", body["status"]) }
}

func TestCustomerUnverifiedClaimRejected(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", custBase+"/facts", `{"claim":"unverified","source":"x","verified":false,"idempotency_key":"f-v1"}`)
	if rec.Code != http.StatusUnprocessableEntity { t.Fatalf("expected 422, got %d", rec.Code) }
}

func TestCustomerCompensationWithoutConsentDenied(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", custBase+"/resolutions", `{"type":"compensation","amount":40,"approved_by":"service-lead","approval_ref":"approval://test","consent_ref":"consent://test","idempotency_key":"c-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestCustomerCompensationWithoutApprovalDenied(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", custBase+"/consent", `{"customer":"cust-1001","decision":"approve","consent_ref":"consent://test","idempotency_key":"con-v1"}`)
	rec, _ := do(t, mux, "POST", custBase+"/resolutions", `{"type":"compensation","amount":40,"approved_by":"","approval_ref":"","consent_ref":"consent://test","idempotency_key":"c-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestCustomerFullFlow(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", custBase+"/facts", `{"claim":"overcharge","source":"billing","verified":true,"idempotency_key":"f-v1"}`)
	do(t, mux, "POST", custBase+"/consent", `{"customer":"cust-1001","decision":"approve","consent_ref":"consent://test","idempotency_key":"con-v1"}`)
	rec, body := do(t, mux, "POST", custBase+"/resolutions", `{"type":"compensation","amount":40,"approved_by":"service-lead","approval_ref":"approval://test","consent_ref":"consent://test","idempotency_key":"c-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	c := body["case"].(map[string]any)
	if c["status"] != "resolving" { t.Fatalf("expected resolving, got %v", c["status"]) }
	rec, body = do(t, mux, "POST", custBase+"/close", `{"closed_by":"service-lead","idempotency_key":"cl-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	c = body["case"].(map[string]any)
	if c["status"] != "resolved" { t.Fatalf("expected resolved, got %v", c["status"]) }
}

func TestCustomerCloseWithoutResolutionDenied(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", custBase+"/close", `{"closed_by":"service-lead","idempotency_key":"cl-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestCustomerAccountCredited(t *testing.T) {
	s, mux := newTestServer(t)
	do(t, mux, "POST", custBase+"/facts", `{"claim":"overcharge","source":"billing","verified":true,"idempotency_key":"f-v1"}`)
	do(t, mux, "POST", custBase+"/consent", `{"customer":"cust-1001","decision":"approve","consent_ref":"consent://test","idempotency_key":"con-v1"}`)
	do(t, mux, "POST", custBase+"/resolutions", `{"type":"compensation","amount":40,"approved_by":"service-lead","approval_ref":"approval://test","consent_ref":"consent://test","idempotency_key":"c-v1"}`)
	s.Lock()
	a := s.Accounts["acct-2001"]
	s.Unlock()
	if a.Balance != 80 { t.Fatalf("expected balance 80, got %d", a.Balance) }
}
