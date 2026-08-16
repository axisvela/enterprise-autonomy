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

func TestInventoryHealth(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "GET", "/healthz", "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
}

func TestInventorySeed(t *testing.T) {
	_, mux := newTestServer(t)
	rec, body := do(t, mux, "GET", "/v1/inventory/sku-inspection-kit", "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	levels := body["levels"].([]any)
	if len(levels) != 2 { t.Fatalf("expected 2 levels, got %d", len(levels)) }
}

func TestInventoryReservation(t *testing.T) {
	_, mux := newTestServer(t)
	rec, body := do(t, mux, "POST", "/v1/inventory/sku-inspection-kit", `{"warehouse":"warehouse-b","delta":-1,"reason":"reserve","approved_by":"ops-lead","approval_ref":"approval://test","idempotency_key":"r-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	adj := body["adjustment"].(map[string]any)
	if adj["delta"].(float64) != -1 { t.Fatalf("expected delta -1, got %v", adj["delta"]) }
}

func TestInventoryReservationIdempotent(t *testing.T) {
	_, mux := newTestServer(t)
	payload := `{"warehouse":"warehouse-b","delta":-1,"reason":"reserve","approved_by":"ops-lead","approval_ref":"approval://test","idempotency_key":"r-v1"}`
	do(t, mux, "POST", "/v1/inventory/sku-inspection-kit", payload)
	rec2, body2 := do(t, mux, "POST", "/v1/inventory/sku-inspection-kit", payload)
	if rec2.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec2.Code) }
	if body2["replayed"] != true { t.Fatalf("expected replayed=true, got %v", body2["replayed"]) }
}

func TestInventoryInsufficientStock(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", "/v1/inventory/sku-inspection-kit", `{"warehouse":"warehouse-a","delta":-5,"reason":"overdraw","approved_by":"ops-lead","approval_ref":"approval://test","idempotency_key":"o-v1"}`)
	if rec.Code != http.StatusUnprocessableEntity { t.Fatalf("expected 422, got %d", rec.Code) }
}

func TestInventoryMissingFields(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", "/v1/inventory/sku-inspection-kit", `{"warehouse":"warehouse-b","delta":-1}`)
	if rec.Code != http.StatusBadRequest { t.Fatalf("expected 400, got %d", rec.Code) }
}

func TestInventoryUnknownSku(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "GET", "/v1/inventory/nope", "")
	if rec.Code != http.StatusNotFound { t.Fatalf("expected 404, got %d", rec.Code) }
}
