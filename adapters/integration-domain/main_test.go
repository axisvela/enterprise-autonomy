package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sync"
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

func TestIntegrationIdempotencyPayloadMismatchRejected(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", intWork+"/preserve", `{"preserved_by":"integration-owner","preserved_ref":"process://one","idempotency_key":"p-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("initial preserve: %d", rec.Code) }
	rec, body := do(t, mux, "POST", intWork+"/preserve", `{"preserved_by":"integration-owner","preserved_ref":"process://two","idempotency_key":"p-v1"}`)
	if rec.Code != http.StatusConflict || body["error"] != "idempotency_key_conflict" { t.Fatalf("payload mismatch: code=%d body=%v", rec.Code, body) }
	rec, body = do(t, mux, "GET", intWork, "")
	if body["preserved_ref"] != "process://one" || len(list(body["actions"])) != 1 { t.Fatalf("conflict changed state: %v", body) }
	rec, body = do(t, mux, "POST", intWork+"/preserve", `{"preserved_by":"integration-owner","preserved_ref":"process://one","idempotency_key":"p-v1"}`)
	if rec.Code != http.StatusOK || body["replayed"] != true { t.Fatalf("identical replay: code=%d body=%v", rec.Code, body) }
}

func TestIntegrationCheckPayloadMismatchRejected(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", intCheck, `{"checked_by":"integration-owner","verified":true,"evidence_ref":"evidence://one","idempotency_key":"c-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("initial check: %d", rec.Code) }
	rec, body := do(t, mux, "POST", intCheck, `{"checked_by":"integration-owner","verified":false,"evidence_ref":"evidence://two","idempotency_key":"c-v1"}`)
	if rec.Code != http.StatusConflict || body["error"] != "idempotency_key_conflict" { t.Fatalf("payload mismatch: code=%d body=%v", rec.Code, body) }
	_, body = do(t, mux, "GET", "/v1/integrations/partner-shipping", "")
	if body["status"] != "checked" { t.Fatalf("conflict changed status: %v", body) }
}

func TestIntegrationCompletionIdempotencyAndSilentRerun(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", intWork+"/preserve", `{"preserved_by":"integration-owner","preserved_ref":"process://test","idempotency_key":"p-v1"}`)
	do(t, mux, "POST", intCheck, `{"checked_by":"integration-owner","verified":true,"evidence_ref":"evidence://test","idempotency_key":"c-v1"}`)
	do(t, mux, "POST", intWork+"/resume", `{"resumed_by":"integration-owner","idempotency_key":"r-v1"}`)
	rec, _ := do(t, mux, "POST", intWork+"/complete", `{"completed_by":"integration-owner","idempotency_key":"cm-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("initial complete: %d", rec.Code) }
	rec, body := do(t, mux, "POST", intWork+"/complete", `{"completed_by":"another-owner","idempotency_key":"cm-v1"}`)
	if rec.Code != http.StatusConflict || body["error"] != "idempotency_key_conflict" { t.Fatalf("completion payload mismatch: code=%d body=%v", rec.Code, body) }
	rec, body = do(t, mux, "POST", intWork+"/complete", `{"completed_by":"integration-owner","idempotency_key":"cm-v1"}`)
	if rec.Code != http.StatusOK || body["replayed"] != true { t.Fatalf("identical replay: code=%d body=%v", rec.Code, body) }
	rec, body = do(t, mux, "POST", intWork+"/complete", `{"completed_by":"integration-owner","idempotency_key":"cm-v2"}`)
	if rec.Code != http.StatusConflict || body["error"] != "action_already_completed_no_silent_rerun" { t.Fatalf("silent rerun: code=%d body=%v", rec.Code, body) }
}

func TestIntegrationPersistenceFailureDoesNotCommit(t *testing.T) {
	for _, operation := range []string{"preserve", "check", "resume", "complete"} {
		t.Run(operation, func(t *testing.T) {
			s, mux := newTestServer(t)
			if operation == "resume" || operation == "complete" {
				do(t, mux, "POST", intWork+"/preserve", `{"preserved_by":"integration-owner","preserved_ref":"process://test","idempotency_key":"p-v1"}`)
				do(t, mux, "POST", intCheck, `{"checked_by":"integration-owner","verified":true,"evidence_ref":"evidence://test","idempotency_key":"c-v1"}`)
			}
			if operation == "complete" {
				do(t, mux, "POST", intWork+"/resume", `{"resumed_by":"integration-owner","idempotency_key":"r-v1"}`)
			}
			blocked := filepath.Join(t.TempDir(), "blocked")
			if err := os.WriteFile(blocked, []byte("not a directory"), 0600); err != nil { t.Fatal(err) }
			s.file = filepath.Join(blocked, "data.json")
			var rec *httptest.ResponseRecorder
			var body map[string]any
			switch operation {
			case "preserve":
				rec, body = do(t, mux, "POST", intWork+"/preserve", `{"preserved_by":"integration-owner","preserved_ref":"process://fail","idempotency_key":"p-fail"}`)
			case "check":
				rec, body = do(t, mux, "POST", intCheck, `{"checked_by":"integration-owner","verified":true,"evidence_ref":"evidence://fail","idempotency_key":"c-fail"}`)
			case "resume":
				rec, body = do(t, mux, "POST", intWork+"/resume", `{"resumed_by":"integration-owner","idempotency_key":"r-fail"}`)
			case "complete":
				rec, body = do(t, mux, "POST", intWork+"/complete", `{"completed_by":"integration-owner","idempotency_key":"cm-fail"}`)
			}
			if rec.Code != http.StatusInternalServerError || body["error"] != "persistence_failed" { t.Fatalf("persistence failure was not surfaced: code=%d body=%v", rec.Code, body) }
			_, work := do(t, mux, "GET", intWork, "")
			_, integration := do(t, mux, "GET", "/v1/integrations/partner-shipping", "")
			wantStatus := map[string]string{"preserve": "inflight", "check": "down", "resume": "preserved", "complete": "resumed"}[operation]
			actual := work["status"]
			if operation == "check" { actual = integration["status"] }
			if actual != wantStatus { t.Fatalf("failed persistence changed state: want=%s got=%v", wantStatus, actual) }
			actions := list(work["actions"])
			if operation == "check" { actions = list(integration["actions"]) }
			for _, raw := range actions {
				if action := raw.(map[string]any); action["id"] == "action-"+map[string]string{"preserve":"p-fail","check":"c-fail","resume":"r-fail","complete":"cm-fail"}[operation] { t.Fatalf("failed action was retained: %v", action) }
			}
		})
	}
}

func TestIntegrationConcurrentIdempotency(t *testing.T) {
	_, mux := newTestServer(t)
	const workers = 8
	results := make(chan map[string]any, workers)
	var wg sync.WaitGroup
	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			req := httptest.NewRequest("POST", intWork+"/preserve", bytes.NewBufferString(`{"preserved_by":"integration-owner","preserved_ref":"process://concurrent","idempotency_key":"p-concurrent"}`))
			req.Header.Set("Content-Type", "application/json")
			rec := httptest.NewRecorder()
			mux.ServeHTTP(rec, req)
			var body map[string]any
			_ = json.Unmarshal(rec.Body.Bytes(), &body)
			body["_code"] = float64(rec.Code)
			results <- body
		}()
	}
	wg.Wait()
	close(results)
	replayed := 0
	for body := range results {
		if body["_code"] != float64(http.StatusOK) { t.Fatalf("concurrent request failed: %v", body) }
		if body["replayed"] == true { replayed++ }
	}
	if replayed != workers-1 { t.Fatalf("replayed=%d want=%d", replayed, workers-1) }
	_, work := do(t, mux, "GET", intWork, "")
	if work["status"] != "preserved" || len(list(work["actions"])) != 1 { t.Fatalf("concurrent duplicate effects: %v", work) }
}

func list(value any) []any {
	if value == nil {
		return nil
	}
	return value.([]any)
}


func TestIntegrationResponseLossRetryAfterRestart(t *testing.T) {
	s, mux := newTestServer(t)
	do(t, mux, "POST", intWork+"/preserve", `{"preserved_by":"integration-owner","preserved_ref":"process://test","idempotency_key":"p-v1"}`)
	do(t, mux, "POST", intCheck, `{"checked_by":"integration-owner","verified":true,"evidence_ref":"evidence://test","idempotency_key":"c-v1"}`)
	do(t, mux, "POST", intWork+"/resume", `{"resumed_by":"integration-owner","idempotency_key":"r-v1"}`)
	// Simulate a committed effect whose response was lost: discard the response,
	// then restart from the persisted file before retrying the same operation.
	rec, _ := do(t, mux, "POST", intWork+"/complete", `{"completed_by":"integration-owner","idempotency_key":"cm-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("initial complete: %d", rec.Code) }
	restarted := load(s.file)
	restartedMux := newMux(restarted)
	rec, body := do(t, restartedMux, "POST", intWork+"/complete", `{"completed_by":"integration-owner","idempotency_key":"cm-v1"}`)
	if rec.Code != http.StatusOK || body["replayed"] != true { t.Fatalf("restart did not replay committed effect: code=%d body=%v", rec.Code, body) }
	_, work := do(t, restartedMux, "GET", intWork, "")
	if work["status"] != "completed" || len(list(work["actions"])) != 3 { t.Fatalf("restart state: %v", work) }
}
