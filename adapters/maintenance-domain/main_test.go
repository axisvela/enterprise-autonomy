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

const maintBase = "/v1/signals/signal-pm-0001"

func TestMaintenanceHealth(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "GET", "/healthz", "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
}

func TestMaintenanceSeed(t *testing.T) {
	_, mux := newTestServer(t)
	rec, body := do(t, mux, "GET", maintBase, "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	if body["status"] != "pending" { t.Fatalf("expected pending, got %v", body["status"]) }
	if body["confirmed"] != false { t.Fatalf("expected confirmed=false, got %v", body["confirmed"]) }
}

func TestMaintenanceUnvalidatedWorkOrderDenied(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", maintBase+"/work-orders", `{"scope":"replace","approved_by":"maintenance-manager","approval_ref":"approval://test","idempotency_key":"w-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestMaintenanceUnconfirmedStopDenied(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", maintBase+"/validate", `{"validated_by":"maintenance-manager","confirmed":false,"note":"prediction","idempotency_key":"v-v1"}`)
	rec, _ := do(t, mux, "POST", maintBase+"/decisions", `{"decision":"stop","decided_by":"maintenance-manager","decision_ref":"decision://test","idempotency_key":"st-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestMaintenanceWorkOrderWithoutSafetyDenied(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", maintBase+"/validate", `{"validated_by":"maintenance-manager","confirmed":false,"note":"prediction","idempotency_key":"v-v1"}`)
	do(t, mux, "POST", maintBase+"/decisions", `{"decision":"repair","decided_by":"maintenance-manager","decision_ref":"decision://test","idempotency_key":"d-v1"}`)
	rec, _ := do(t, mux, "POST", maintBase+"/work-orders", `{"scope":"replace","approved_by":"maintenance-manager","approval_ref":"approval://test","idempotency_key":"w-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestMaintenanceFullFlow(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", maintBase+"/validate", `{"validated_by":"maintenance-manager","confirmed":false,"note":"prediction","idempotency_key":"v-v1"}`)
	do(t, mux, "POST", maintBase+"/decisions", `{"decision":"repair","decided_by":"maintenance-manager","decision_ref":"decision://test","idempotency_key":"d-v1"}`)
	do(t, mux, "POST", maintBase+"/safety-reviews", `{"reviewed_by":"safety-authority","outcome":"approve","safety_ref":"safety://test","idempotency_key":"s-v1"}`)
	rec, body := do(t, mux, "POST", maintBase+"/work-orders", `{"scope":"replace","approved_by":"maintenance-manager","approval_ref":"approval://test","idempotency_key":"w-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	wo := body["work_order"].(map[string]any)
	if wo["status"] != "scheduled" { t.Fatalf("expected scheduled, got %v", wo["status"]) }
}

func TestMaintenanceMonitorDoesNotProduceWorkOrder(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", maintBase+"/validate", `{"validated_by":"maintenance-manager","confirmed":false,"note":"prediction","idempotency_key":"v-v1"}`)
	do(t, mux, "POST", maintBase+"/decisions", `{"decision":"monitor","decided_by":"maintenance-manager","decision_ref":"decision://test","idempotency_key":"d-v1"}`)
	rec, _ := do(t, mux, "POST", maintBase+"/work-orders", `{"scope":"watch","approved_by":"maintenance-manager","approval_ref":"approval://test","idempotency_key":"w-v1"}`)
	if rec.Code != http.StatusBadRequest { t.Fatalf("expected 400, got %d", rec.Code) }
}

func TestMaintenanceNonManagerValidateDenied(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", maintBase+"/validate", `{"validated_by":"outsider","confirmed":false,"note":"x","idempotency_key":"v-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}
