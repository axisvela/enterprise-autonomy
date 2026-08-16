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

const depBase = "/v1/deployments/dep-0001"

func TestDeploymentHealth(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "GET", "/healthz", "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
}

func TestDeploymentSeed(t *testing.T) {
	_, mux := newTestServer(t)
	rec, body := do(t, mux, "GET", depBase, "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	if body["status"] != "initiated" { t.Fatalf("expected initiated, got %v", body["status"]) }
}

func TestOutOfSequenceStepDenied(t *testing.T) {
	_, mux := newTestServer(t)
	rec, body := do(t, mux, "POST", depBase+"/steps", `{"step":"build","executed_by":"release-automation","evidence_ref":"evidence://test","idempotency_key":"d-v1"}`)
	if rec.Code != http.StatusConflict { t.Fatalf("expected 409, got %d", rec.Code) }
	if body["error"] != "step_out_of_sequence_next_is_checkout" { t.Fatalf("unexpected error: %v", body["error"]) }
}

func TestStepAlreadyExecutedImmutable(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", depBase+"/steps", `{"step":"checkout","executed_by":"release-automation","evidence_ref":"evidence://test","idempotency_key":"d-v1"}`)
	rec, _ := do(t, mux, "POST", depBase+"/steps", `{"step":"checkout","executed_by":"release-automation","evidence_ref":"evidence://test","idempotency_key":"d-v2"}`)
	if rec.Code != http.StatusConflict { t.Fatalf("expected 409, got %d", rec.Code) }
}

func TestDeviationRequiresHumanApproval(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", depBase+"/steps", `{"step":"checkout","executed_by":"release-automation","evidence_ref":"evidence://test","idempotency_key":"d-v1"}`)
	rec, body := do(t, mux, "POST", depBase+"/deviations", `{"action":"pause","idempotency_key":"d-pause"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
	if body["error"] != "deviation_requires_human_approval" { t.Fatalf("unexpected error: %v", body["error"]) }
}

func TestFullSequencedExecution(t *testing.T) {
	_, mux := newTestServer(t)
	for _, step := range []string{"checkout", "build", "test", "approve", "production"} {
		body := `{"step":"` + step + `","executed_by":"release-automation","evidence_ref":"evidence://test/` + step + `","idempotency_key":"` + step + `"}`
		rec, resp := do(t, mux, "POST", depBase+"/steps", body)
		if rec.Code != http.StatusOK { t.Fatalf("expected 200 for %s, got %d (%v)", step, rec.Code, resp) }
	}
	_, body := do(t, mux, "GET", depBase, "")
	d := body
	if d["status"] != "released" { t.Fatalf("expected released, got %v", d["status"]) }
}

func TestReleasedDeploymentImmutable(t *testing.T) {
	_, mux := newTestServer(t)
	for _, step := range []string{"checkout", "build", "test", "approve", "production"} {
		body := `{"step":"` + step + `","executed_by":"release-automation","evidence_ref":"evidence://test/` + step + `","idempotency_key":"` + step + `"}`
		do(t, mux, "POST", depBase+"/steps", body)
	}
	rec, _ := do(t, mux, "POST", depBase+"/steps", `{"step":"checkout","executed_by":"release-automation","evidence_ref":"evidence://test","idempotency_key":"re-run"}`)
	if rec.Code != http.StatusConflict { t.Fatalf("expected 409, got %d", rec.Code) }
	rec2, _ := do(t, mux, "POST", depBase+"/deviations", `{"action":"rollback","approved_by":"release-lead","approval_ref":"approval://test","idempotency_key":"rollback"}`)
	if rec2.Code != http.StatusConflict { t.Fatalf("expected 409, got %d", rec2.Code) }
}

func TestApprovedPauseAndResume(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", depBase+"/steps", `{"step":"checkout","executed_by":"release-automation","evidence_ref":"evidence://test","idempotency_key":"d-v1"}`)
	rec, body := do(t, mux, "POST", depBase+"/deviations", `{"action":"pause","approved_by":"release-lead","approval_ref":"approval://test","idempotency_key":"d-pause"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	if body["deployment"].(map[string]any)["status"] != "paused" { t.Fatalf("expected paused, got %v", body["deployment"].(map[string]any)["status"]) }
	rec2, _ := do(t, mux, "POST", depBase+"/steps", `{"step":"build","executed_by":"release-automation","evidence_ref":"evidence://test","idempotency_key":"d-v2"}`)
	if rec2.Code != http.StatusForbidden { t.Fatalf("expected 403 while paused, got %d", rec2.Code) }
}

func TestApprovedSkip(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", depBase+"/steps", `{"step":"checkout","executed_by":"release-automation","evidence_ref":"evidence://test","idempotency_key":"d-v1"}`)
	rec, body := do(t, mux, "POST", depBase+"/deviations", `{"action":"skip","to_step":"test","approved_by":"release-lead","approval_ref":"approval://test","idempotency_key":"d-skip"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	if body["deployment"].(map[string]any)["status"] != "in-flight" { t.Fatalf("expected in-flight, got %v", body["deployment"].(map[string]any)["status"]) }
}

func TestApprovedRollback(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", depBase+"/steps", `{"step":"checkout","executed_by":"release-automation","evidence_ref":"evidence://test","idempotency_key":"d-v1"}`)
	rec, body := do(t, mux, "POST", depBase+"/deviations", `{"action":"rollback","approved_by":"release-lead","approval_ref":"approval://test","idempotency_key":"d-roll"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	if body["deployment"].(map[string]any)["status"] != "rolled-back" { t.Fatalf("expected rolled-back, got %v", body["deployment"].(map[string]any)["status"]) }
}
