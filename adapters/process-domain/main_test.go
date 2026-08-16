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

const procBase = "/v1/processes/proc-0001"

func TestProcessHealth(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "GET", "/healthz", "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
}

func TestProcessSeed(t *testing.T) {
	_, mux := newTestServer(t)
	rec, body := do(t, mux, "GET", procBase, "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	if body["current_stage"] != "request" { t.Fatalf("expected request, got %v", body["current_stage"]) }
}

func TestProcessOutOfOrderAdvanceDenied(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", procBase+"/advance", `{"from_stage":"request","to_stage":"approve","decided_by":"ops-lead","rationale":"skip","decision_ref":"decision://test","idempotency_key":"a-v1"}`)
	if rec.Code != http.StatusConflict { t.Fatalf("expected 409, got %d", rec.Code) }
}

func TestProcessCompleteBeforeTerminalDenied(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", procBase+"/complete", `{"completed_by":"ops-lead","idempotency_key":"c-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestProcessFullFlow(t *testing.T) {
	_, mux := newTestServer(t)
	for _, pair := range [][2]string{{"request", "review"}, {"review", "approve"}, {"approve", "complete"}} {
		body := `{"from_stage":"` + pair[0] + `","to_stage":"` + pair[1] + `","decided_by":"ops-lead","rationale":"ok","decision_ref":"decision://test","idempotency_key":"` + pair[0] + `"}`
		rec, _ := do(t, mux, "POST", procBase+"/advance", body)
		if rec.Code != http.StatusOK { t.Fatalf("expected 200 for %s, got %d", pair[0], rec.Code) }
	}
	rec, body := do(t, mux, "GET", procBase, "")
	p := body
	if p["current_stage"] != "complete" || p["status"] != "awaiting-outcome" { t.Fatalf("unexpected terminal state: %v", p) }
	rec, body = do(t, mux, "POST", procBase+"/complete", `{"completed_by":"ops-lead","idempotency_key":"c-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	p = body["process"].(map[string]any)
	if p["status"] != "completed" { t.Fatalf("expected completed, got %v", p["status"]) }
}

func TestProcessReopenDenied(t *testing.T) {
	_, mux := newTestServer(t)
	for _, pair := range [][2]string{{"request", "review"}, {"review", "approve"}, {"approve", "complete"}} {
		body := `{"from_stage":"` + pair[0] + `","to_stage":"` + pair[1] + `","decided_by":"ops-lead","rationale":"ok","decision_ref":"decision://test","idempotency_key":"` + pair[0] + `"}`
		do(t, mux, "POST", procBase+"/advance", body)
	}
	do(t, mux, "POST", procBase+"/complete", `{"completed_by":"ops-lead","idempotency_key":"c-v1"}`)
	rec, _ := do(t, mux, "POST", procBase+"/advance", `{"from_stage":"complete","to_stage":"request","decided_by":"ops-lead","rationale":"reopen","decision_ref":"decision://test","idempotency_key":"reopen"}`)
	if rec.Code != http.StatusConflict { t.Fatalf("expected 409, got %d", rec.Code) }
}

func TestProcessNoAdvancesCannotComplete(t *testing.T) {
	s, mux := newTestServer(t)
	s.Lock()
	p := s.Processes["proc-0001"]
	p.CurrentStage = "complete"
	p.Status = "awaiting-outcome"
	s.Unlock()
	rec, _ := do(t, mux, "POST", procBase+"/complete", `{"completed_by":"ops-lead","idempotency_key":"c-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}
