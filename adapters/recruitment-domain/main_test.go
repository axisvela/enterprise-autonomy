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

const recBase = "/v1/requisitions/req-0001"

func TestRecruitmentHealth(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "GET", "/healthz", "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
}

func TestRecruitmentSeed(t *testing.T) {
	_, mux := newTestServer(t)
	rec, body := do(t, mux, "GET", recBase, "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	if body["status"] != "draft" { t.Fatalf("expected draft, got %v", body["status"]) }
}

func TestRecruitmentValidateNonTaDenied(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", recBase+"/validate", `{"validated_by":"hiring-manager-1","criteria":["x"],"idempotency_key":"v-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestRecruitmentAutomationCannotDecide(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", recBase+"/validate", `{"validated_by":"ta-lead-1","criteria":["x"],"idempotency_key":"v-v1"}`)
	rec, _ := do(t, mux, "POST", recBase+"/decisions", `{"stage":"shortlist","decision":"advance","candidate":"cand-a","decided_by":"recruiter-assistant","actor_type":"automated","rationale":"keyword","decision_ref":"decision://test","idempotency_key":"a-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestRecruitmentLifecycle(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", recBase+"/validate", `{"validated_by":"ta-lead-1","criteria":["x"],"idempotency_key":"v-v1"}`)
	do(t, mux, "POST", recBase+"/decisions", `{"stage":"shortlist","decision":"advance","candidate":"cand-a","decided_by":"panel-1","actor_type":"human","rationale":"ok","decision_ref":"decision://test","idempotency_key":"sl-v1"}`)
	do(t, mux, "POST", recBase+"/decisions", `{"stage":"selection","decision":"select","candidate":"cand-a","decided_by":"hiring-manager-1","actor_type":"human","rationale":"best","decision_ref":"decision://test","idempotency_key":"sel-v1"}`)
	rec, body := do(t, mux, "POST", recBase+"/decisions", `{"stage":"offer","decision":"offer","candidate":"cand-a","decided_by":"hiring-manager-1","actor_type":"human","rationale":"approved","decision_ref":"decision://test","idempotency_key":"of-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	req := body["requisition"].(map[string]any)
	if req["status"] != "offer" { t.Fatalf("expected offer, got %v", req["status"]) }
	rec, body = do(t, mux, "POST", recBase+"/offers", `{"candidate":"cand-a","offered_by":"ta-lead-1","offer_ref":"offer://test","idempotency_key":"off-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	req = body["requisition"].(map[string]any)
	if req["status"] != "closed" { t.Fatalf("expected closed, got %v", req["status"]) }
}

func TestRecruitmentOutOfOrderSelectionDenied(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", recBase+"/validate", `{"validated_by":"ta-lead-1","criteria":["x"],"idempotency_key":"v-v1"}`)
	rec, _ := do(t, mux, "POST", recBase+"/decisions", `{"stage":"selection","decision":"select","candidate":"cand-a","decided_by":"hiring-manager-1","actor_type":"human","rationale":"x","decision_ref":"decision://test","idempotency_key":"sel-v1"}`)
	if rec.Code != http.StatusConflict { t.Fatalf("expected 409, got %d", rec.Code) }
}

func TestRecruitmentOfferWithoutDecisionDenied(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", recBase+"/validate", `{"validated_by":"ta-lead-1","criteria":["x"],"idempotency_key":"v-v1"}`)
	rec, _ := do(t, mux, "POST", recBase+"/offers", `{"candidate":"cand-a","offered_by":"ta-lead-1","offer_ref":"offer://test","idempotency_key":"off-v1"}`)
	if rec.Code != http.StatusConflict { t.Fatalf("expected 409, got %d", rec.Code) }
}
