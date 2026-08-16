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

const sandBase = "/v1/proposals/proposal-sandbox-0001"

func TestSandboxHealth(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "GET", "/healthz", "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
}

func TestSandboxSeed(t *testing.T) {
	_, mux := newTestServer(t)
	rec, body := do(t, mux, "GET", sandBase, "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	if body["status"] != "proposed" { t.Fatalf("expected proposed, got %v", body["status"]) }
}

func TestSandboxBoundaryEnforced(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", sandBase+"/experiments", `{"experiment_id":"exp-001","scope":"outside-scope","outcome":"pass","evidence_ref":"e","recorded_by":"sandbox-engineer","idempotency_key":"x"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestSandboxDecisionWithoutEvidenceDenied(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", sandBase+"/decisions", `{"decision":"release","decided_by":"reviewer-a","rationale":"x","policy_ref":"policy://test","idempotency_key":"d"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestSandboxNonReviewerDenied(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", sandBase+"/experiments", `{"experiment_id":"exp-001","scope":"report-generation-scope","outcome":"pass","evidence_ref":"e","recorded_by":"sandbox-engineer","idempotency_key":"x"}`)
	rec, _ := do(t, mux, "POST", sandBase+"/decisions", `{"decision":"release","decided_by":"outsider","rationale":"x","policy_ref":"policy://test","idempotency_key":"d"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestSandboxFullFlow(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", sandBase+"/experiments", `{"experiment_id":"exp-001","scope":"report-generation-scope","outcome":"pass","evidence_ref":"e","recorded_by":"sandbox-engineer","idempotency_key":"x"}`)
	rec, body := do(t, mux, "POST", sandBase+"/decisions", `{"decision":"release","decided_by":"reviewer-a","rationale":"evidence passes","policy_ref":"policy://test","idempotency_key":"d"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	p := body["proposal"].(map[string]any)
	if p["status"] != "decided" { t.Fatalf("expected decided, got %v", p["status"]) }
	rec, body = do(t, mux, "POST", sandBase+"/apply", `{"applied_by":"reviewer-a","policy_ref":"policy://test","idempotency_key":"a"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	p = body["proposal"].(map[string]any)
	if p["status"] != "released" { t.Fatalf("expected released, got %v", p["status"]) }
}

func TestSandboxPolicyImmutable(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", sandBase+"/experiments", `{"experiment_id":"exp-001","scope":"report-generation-scope","outcome":"pass","evidence_ref":"e","recorded_by":"sandbox-engineer","idempotency_key":"x"}`)
	do(t, mux, "POST", sandBase+"/decisions", `{"decision":"release","decided_by":"reviewer-a","rationale":"x","policy_ref":"policy://test","idempotency_key":"d"}`)
	rec, _ := do(t, mux, "POST", sandBase+"/decisions", `{"decision":"restrict","decided_by":"reviewer-a","rationale":"change","policy_ref":"policy://test","idempotency_key":"d2"}`)
	if rec.Code != http.StatusConflict { t.Fatalf("expected 409, got %d", rec.Code) }
}

func TestSandboxRejectedCannotApply(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", sandBase+"/experiments", `{"experiment_id":"exp-001","scope":"report-generation-scope","outcome":"fail","evidence_ref":"e","recorded_by":"sandbox-engineer","idempotency_key":"x"}`)
	do(t, mux, "POST", sandBase+"/decisions", `{"decision":"reject","decided_by":"reviewer-a","rationale":"evidence fails","policy_ref":"policy://test","idempotency_key":"d"}`)
	rec, _ := do(t, mux, "POST", sandBase+"/apply", `{"applied_by":"reviewer-a","policy_ref":"policy://test","idempotency_key":"a"}`)
	if rec.Code != http.StatusConflict { t.Fatalf("expected 409, got %d", rec.Code) }
}
