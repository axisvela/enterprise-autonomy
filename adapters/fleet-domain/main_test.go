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

const fleetBase = "/v1/missions/mission-alpha-001"

func TestFleetHealth(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "GET", "/healthz", "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
}

func TestFleetSeed(t *testing.T) {
	_, mux := newTestServer(t)
	rec, body := do(t, mux, "GET", fleetBase, "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	if body["status"] != "planned" { t.Fatalf("expected planned, got %v", body["status"]) }
}

func TestFleetTelemetryBeforeStartRejected(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", fleetBase+"/telemetry", `{"position":"zone-alpha","status":"running","idempotency_key":"t-v1"}`)
	if rec.Code != http.StatusConflict { t.Fatalf("expected 409, got %d", rec.Code) }
}

func TestFleetBoundaryDeviationFrozen(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", fleetBase+"/start", `{"started_by":"ops-lead","idempotency_key":"s-v1"}`)
	rec, _ := do(t, mux, "POST", fleetBase+"/telemetry", `{"position":"zone-omega","status":"running","idempotency_key":"t-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestFleetReviewWithoutPauseDenied(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", fleetBase+"/start", `{"started_by":"ops-lead","idempotency_key":"s-v1"}`)
	rec, _ := do(t, mux, "POST", fleetBase+"/reviews", `{"reviewed_by":"ops-lead","decision":"resume","approval_ref":"approval://test","idempotency_key":"r-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestFleetFullFlow(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", fleetBase+"/start", `{"started_by":"ops-lead","idempotency_key":"s-v1"}`)
	do(t, mux, "POST", fleetBase+"/telemetry", `{"position":"zone-alpha","status":"running","idempotency_key":"t-v1"}`)
	rec, body := do(t, mux, "POST", fleetBase+"/exceptions", `{"type":"obstacle","detail":"rack-07 blocked","raised_by":"fleet-runtime","idempotency_key":"e-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	m := body["mission"].(map[string]any)
	if m["status"] != "paused" { t.Fatalf("expected paused, got %v", m["status"]) }
	rec, body = do(t, mux, "POST", fleetBase+"/reviews", `{"reviewed_by":"ops-lead","decision":"resume","approval_ref":"approval://test","idempotency_key":"r-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	m = body["mission"].(map[string]any)
	if m["status"] != "resumed" { t.Fatalf("expected resumed, got %v", m["status"]) }
	rec, body = do(t, mux, "POST", fleetBase+"/complete", `{"completed_by":"ops-lead","idempotency_key":"c-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	m = body["mission"].(map[string]any)
	if m["status"] != "completed" { t.Fatalf("expected completed, got %v", m["status"]) }
}

func TestFleetNonOperatorReviewDenied(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", fleetBase+"/start", `{"started_by":"ops-lead","idempotency_key":"s-v1"}`)
	do(t, mux, "POST", fleetBase+"/exceptions", `{"type":"obstacle","detail":"x","raised_by":"fleet-runtime","idempotency_key":"e-v1"}`)
	rec, _ := do(t, mux, "POST", fleetBase+"/reviews", `{"reviewed_by":"outsider","decision":"resume","approval_ref":"approval://test","idempotency_key":"r-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestFleetNonOperatorStartDenied(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", fleetBase+"/start", `{"started_by":"outsider","idempotency_key":"s-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}
