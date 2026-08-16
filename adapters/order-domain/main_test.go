package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func do(t *testing.T, mux http.Handler, method, path, body string) (*httptest.ResponseRecorder, map[string]any) {
	t.Helper()
	var rdr *bytes.Reader
	if body == "" {
		rdr = bytes.NewReader(nil)
	} else {
		rdr = bytes.NewReader([]byte(body))
	}
	req := httptest.NewRequest(method, path, rdr)
	if body != "" {
		req.Header.Set("Content-Type", "application/json")
	}
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	var out map[string]any
	if rec.Body.Len() > 0 {
		_ = json.Unmarshal(rec.Body.Bytes(), &out)
	}
	return rec, out
}

func newTestServer(t *testing.T) (*store, http.Handler) {
	t.Helper()
	s := load(t.TempDir() + "/data.json")
	return s, newMux(s)
}

func TestOrderHealth(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "GET", "/healthz", "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
}

func TestOrderStartsInStockout(t *testing.T) {
	_, mux := newTestServer(t)
	rec, body := do(t, mux, "GET", "/v1/orders/order-123", "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	if body["fulfillment_status"] != "stockout" { t.Fatalf("expected stockout, got %v", body["fulfillment_status"]) }
}

func TestOrderUnapprovedActionRejected(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", "/v1/orders/order-123/fulfillment-actions", `{"action":"alternate_location","approved_by":"","approval_ref":"","idempotency_key":"unapproved"}`)
	if rec.Code != http.StatusBadRequest { t.Fatalf("expected 400, got %d", rec.Code) }
}

func TestOrderApprovedAction(t *testing.T) {
	_, mux := newTestServer(t)
	rec, body := do(t, mux, "POST", "/v1/orders/order-123/fulfillment-actions", `{"action":"alternate_location","approved_by":"ops-lead","approval_ref":"approval://test","idempotency_key":"a-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	order := body["order"].(map[string]any)
	if order["fulfillment_status"] != "replanned" { t.Fatalf("expected replanned, got %v", order["fulfillment_status"]) }
	if order["warehouse"] != "warehouse-b" { t.Fatalf("expected warehouse-b, got %v", order["warehouse"]) }
}

func TestOrderActionIdempotent(t *testing.T) {
	_, mux := newTestServer(t)
	payload := `{"action":"alternate_location","approved_by":"ops-lead","approval_ref":"approval://test","idempotency_key":"a-v1"}`
	rec1, _ := do(t, mux, "POST", "/v1/orders/order-123/fulfillment-actions", payload)
	rec2, body2 := do(t, mux, "POST", "/v1/orders/order-123/fulfillment-actions", payload)
	if rec1.Code != http.StatusOK || rec2.Code != http.StatusOK { t.Fatalf("expected 200s, got %d/%d", rec1.Code, rec2.Code) }
	if body2["replayed"] != true { t.Fatalf("expected replayed=true, got %v", body2["replayed"]) }
}

func TestOrderCancel(t *testing.T) {
	_, mux := newTestServer(t)
	rec, body := do(t, mux, "POST", "/v1/orders/order-123/fulfillment-actions", `{"action":"cancel","approved_by":"ops-lead","approval_ref":"approval://test","idempotency_key":"c-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	order := body["order"].(map[string]any)
	if order["fulfillment_status"] != "cancelled" { t.Fatalf("expected cancelled, got %v", order["fulfillment_status"]) }
}

func TestOrderViews(t *testing.T) {
	_, mux := newTestServer(t)
	for _, p := range []string{"/v1/inventory/sku-inspection-kit", "/v1/payments/order-123", "/v1/shipments/order-123", "/v1/notifications/order-123"} {
		rec, _ := do(t, mux, "GET", p, "")
		if rec.Code != http.StatusOK { t.Fatalf("expected 200 for %s, got %d", p, rec.Code) }
	}
}

func TestOrderUnknownOrder(t *testing.T) {
	_, mux := newTestServer(t)
	rec, body := do(t, mux, "GET", "/v1/orders/nope", "")
	if rec.Code != http.StatusNotFound { t.Fatalf("expected 404, got %d", rec.Code) }
	if !strings.Contains(rec.Body.String(), "order_not_found") { t.Fatalf("unexpected body: %v", body) }
}
