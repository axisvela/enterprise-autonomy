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

const simBase = "/v1/proposals/proposal-sim-0001"

func TestSimulationHealth(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "GET", "/healthz", "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
}

func TestSimulationSeed(t *testing.T) {
	_, mux := newTestServer(t)
	rec, body := do(t, mux, "GET", simBase, "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	if body["status"] != "proposed" { t.Fatalf("expected proposed, got %v", body["status"]) }
}

func TestSimulationDecisionWithoutEvidenceDenied(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", simBase+"/decisions", `{"decision":"approve","decided_by":"reviewer-a","rationale":"x","decision_ref":"decision://test","idempotency_key":"d-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestSimulationImmutableEvidence(t *testing.T) {
	_, mux := newTestServer(t)
	rec, body := do(t, mux, "POST", simBase+"/runs", `{"run_id":"run-001","outcome":"pass","evidence_ref":"evidence://test","recorded_by":"simulation-engineer","idempotency_key":"r-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	run := body["run"].(map[string]any)
	if run["immutable"] != true { t.Fatalf("expected immutable=true, got %v", run["immutable"]) }
	rec, _ = do(t, mux, "POST", simBase+"/runs", `{"run_id":"run-002","outcome":"fail","evidence_ref":"evidence://test2","recorded_by":"simulation-engineer","idempotency_key":"r2-v1"}`)
	if rec.Code != http.StatusConflict { t.Fatalf("expected 409, got %d", rec.Code) }
}

func TestSimulationNonMemberDecisionDenied(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", simBase+"/runs", `{"run_id":"run-001","outcome":"pass","evidence_ref":"evidence://test","recorded_by":"simulation-engineer","idempotency_key":"r-v1"}`)
	rec, _ := do(t, mux, "POST", simBase+"/decisions", `{"decision":"approve","decided_by":"outsider","rationale":"x","decision_ref":"decision://test","idempotency_key":"d-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestSimulationFullFlow(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", simBase+"/scenarios", `{"scenario_id":"scn-collision","description":"collision","idempotency_key":"s-v1"}`)
	do(t, mux, "POST", simBase+"/runs", `{"run_id":"run-001","outcome":"pass","evidence_ref":"evidence://test","recorded_by":"simulation-engineer","idempotency_key":"r-v1"}`)
	rec, body := do(t, mux, "POST", simBase+"/decisions", `{"decision":"approve","decided_by":"reviewer-a","rationale":"evidence passes","decision_ref":"decision://test","idempotency_key":"d-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	p := body["proposal"].(map[string]any)
	if p["status"] != "decided" { t.Fatalf("expected decided, got %v", p["status"]) }
	rec, body = do(t, mux, "POST", simBase+"/release", `{"released_by":"reviewer-a","decision_ref":"decision://test","idempotency_key":"rel-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	p = body["proposal"].(map[string]any)
	if p["status"] != "released" { t.Fatalf("expected released, got %v", p["status"]) }
}

func TestSimulationReleaseWrongRefDenied(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", simBase+"/runs", `{"run_id":"run-001","outcome":"pass","evidence_ref":"evidence://test","recorded_by":"simulation-engineer","idempotency_key":"r-v1"}`)
	do(t, mux, "POST", simBase+"/decisions", `{"decision":"approve","decided_by":"reviewer-a","rationale":"x","decision_ref":"decision://test","idempotency_key":"d-v1"}`)
	rec, _ := do(t, mux, "POST", simBase+"/release", `{"released_by":"reviewer-a","decision_ref":"decision://wrong","idempotency_key":"rel-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}
