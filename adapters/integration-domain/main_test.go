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

const intWork = "/v1/work/work-0001"
const intCheck = "/v1/integrations/partner-shipping/checks"

func TestIntegrationHealth(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "GET", "/healthz", "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
}

func TestIntegrationSeed(t *testing.T) {
	_, mux := newTestServer(t)
	rec, body := do(t, mux, "GET", intWork, "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	if body["status"] != "inflight" { t.Fatalf("expected inflight, got %v", body["status"]) }
}

func TestIntegrationResumeBeforePreserveDenied(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", intWork+"/resume", `{"resumed_by":"integration-owner","idempotency_key":"r-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestIntegrationResumeBeforeVerifyDenied(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", intWork+"/preserve", `{"preserved_by":"integration-owner","preserved_ref":"process://test","idempotency_key":"p-v1"}`)
	rec, _ := do(t, mux, "POST", intWork+"/resume", `{"resumed_by":"integration-owner","idempotency_key":"r-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestIntegrationFullFlow(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", intWork+"/preserve", `{"preserved_by":"integration-owner","preserved_ref":"process://test","idempotency_key":"p-v1"}`)
	do(t, mux, "POST", intCheck, `{"checked_by":"integration-owner","verified":true,"evidence_ref":"evidence://test","idempotency_key":"c-v1"}`)
	rec, body := do(t, mux, "POST", intWork+"/resume", `{"resumed_by":"integration-owner","idempotency_key":"r-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	w := body["work"].(map[string]any)
	if w["status"] != "resumed" { t.Fatalf("expected resumed, got %v", w["status"]) }
	rec, body = do(t, mux, "POST", intWork+"/complete", `{"completed_by":"integration-owner","idempotency_key":"cm-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	w = body["work"].(map[string]any)
	if w["status"] != "completed" { t.Fatalf("expected completed, got %v", w["status"]) }
}

func TestIntegrationSilentRerunDenied(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", intWork+"/preserve", `{"preserved_by":"integration-owner","preserved_ref":"process://test","idempotency_key":"p-v1"}`)
	do(t, mux, "POST", intCheck, `{"checked_by":"integration-owner","verified":true,"evidence_ref":"evidence://test","idempotency_key":"c-v1"}`)
	do(t, mux, "POST", intWork+"/resume", `{"resumed_by":"integration-owner","idempotency_key":"r-v1"}`)
	do(t, mux, "POST", intWork+"/complete", `{"completed_by":"integration-owner","idempotency_key":"cm-v1"}`)
	rec, _ := do(t, mux, "POST", intWork+"/complete", `{"completed_by":"integration-owner","idempotency_key":"cm2-v1"}`)
	if rec.Code != http.StatusConflict { t.Fatalf("expected 409, got %d", rec.Code) }
}

func TestIntegrationNonOwnerCheckDenied(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", intCheck, `{"checked_by":"outsider","verified":true,"evidence_ref":"evidence://test","idempotency_key":"c-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestIntegrationCompleteBeforeResumeDenied(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", intWork+"/complete", `{"completed_by":"integration-owner","idempotency_key":"cm-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}
