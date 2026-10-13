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

const infBase = "/v1/inferences/inf-0001"

func TestInferenceHealth(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "GET", "/healthz", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
}

func TestInferenceSeed(t *testing.T) {
	_, mux := newTestServer(t)
	rec, body := do(t, mux, "GET", infBase, "")
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if body["status"] != "submitted" {
		t.Fatalf("expected submitted, got %v", body["status"])
	}
}

func TestRouteRequiresAuthorization(t *testing.T) {
	_, mux := newTestServer(t)
	rec, body := do(t, mux, "POST", infBase+"/route", `{"model":"model-alpha","endpoint":"endpoint-production","policy_ref":"policy://test","idempotency_key":"i-v1"}`)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d", rec.Code)
	}
	if body["error"] != "authorization_required_before_route" {
		t.Fatalf("unexpected error: %v", body["error"])
	}
}

func TestOutOfPolicyModelDenied(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", infBase+"/authorize", `{"authorized_by":"inference-owner","authorization_ref":"authorization://test","idempotency_key":"i-auth"}`)
	rec, body := do(t, mux, "POST", infBase+"/route", `{"model":"model-forbidden","endpoint":"endpoint-production","policy_ref":"policy://test","idempotency_key":"i-v1"}`)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d", rec.Code)
	}
	if body["error"] != "model_out_of_policy_model-forbidden" {
		t.Fatalf("unexpected error: %v", body["error"])
	}
}

func TestAnswerRequiresGrounding(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", infBase+"/authorize", `{"authorized_by":"inference-owner","authorization_ref":"authorization://test","idempotency_key":"i-auth"}`)
	do(t, mux, "POST", infBase+"/route", `{"model":"model-alpha","endpoint":"endpoint-production","policy_ref":"policy://test","idempotency_key":"i-v1"}`)
	rec, body := do(t, mux, "POST", infBase+"/answers", `{"answer_ref":"answer://test","produced_by":"inference-runtime","idempotency_key":"i-ans"}`)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d", rec.Code)
	}
	if body["error"] != "route_and_grounding_required_before_answer" {
		t.Fatalf("unexpected error: %v", body["error"])
	}
}

func TestHighImpactAnswerRequiresHumanReview(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", infBase+"/authorize", `{"authorized_by":"inference-owner","authorization_ref":"authorization://test","idempotency_key":"i-auth"}`)
	do(t, mux, "POST", infBase+"/route", `{"model":"model-alpha","endpoint":"endpoint-production","policy_ref":"policy://test","idempotency_key":"i-v1"}`)
	do(t, mux, "POST", infBase+"/ground", `{"claim_refs":["claim://test/1"],"memory_ref":"memory://test","idempotency_key":"i-gnd"}`)
	rec, body := do(t, mux, "POST", infBase+"/answers", `{"answer_ref":"answer://test","produced_by":"inference-runtime","idempotency_key":"i-ans"}`)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d", rec.Code)
	}
	if body["error"] != "human_review_required_before_answer" {
		t.Fatalf("unexpected error: %v", body["error"])
	}
}

func TestFullGovernedFlow(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", infBase+"/authorize", `{"authorized_by":"inference-owner","authorization_ref":"authorization://test","idempotency_key":"i-auth"}`)
	do(t, mux, "POST", infBase+"/route", `{"model":"model-alpha","endpoint":"endpoint-production","policy_ref":"policy://test","idempotency_key":"i-v1"}`)
	do(t, mux, "POST", infBase+"/ground", `{"claim_refs":["claim://test/1"],"memory_ref":"memory://test","idempotency_key":"i-gnd"}`)
	rec, body := do(t, mux, "POST", infBase+"/reviews", `{"reviewed_by":"inference-owner","decision":"approve","review_ref":"review://test","idempotency_key":"i-rvw"}`)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 for review, got %d (%v)", rec.Code, body)
	}
	rec2, body2 := do(t, mux, "POST", infBase+"/answers", `{"answer_ref":"answer://test","produced_by":"inference-runtime","idempotency_key":"i-ans"}`)
	if rec2.Code != http.StatusOK {
		t.Fatalf("expected 200 for answer, got %d (%v)", rec2.Code, body2)
	}
	rec3, body3 := do(t, mux, "POST", infBase+"/audit", `{"audited_by":"inference-owner","audit_ref":"audit://test","idempotency_key":"i-aud"}`)
	if rec3.Code != http.StatusOK {
		t.Fatalf("expected 200 for audit, got %d (%v)", rec3.Code, body3)
	}
	_, final := do(t, mux, "GET", infBase, "")
	if final["status"] != "audited" {
		t.Fatalf("expected audited, got %v", final["status"])
	}
}

func TestAuditedInferenceImmutable(t *testing.T) {
	_, mux := newTestServer(t)
	do(t, mux, "POST", infBase+"/authorize", `{"authorized_by":"inference-owner","authorization_ref":"authorization://test","idempotency_key":"i-auth"}`)
	do(t, mux, "POST", infBase+"/route", `{"model":"model-alpha","endpoint":"endpoint-production","policy_ref":"policy://test","idempotency_key":"i-v1"}`)
	do(t, mux, "POST", infBase+"/ground", `{"claim_refs":["claim://test/1"],"memory_ref":"memory://test","idempotency_key":"i-gnd"}`)
	do(t, mux, "POST", infBase+"/reviews", `{"reviewed_by":"inference-owner","decision":"approve","review_ref":"review://test","idempotency_key":"i-rvw"}`)
	do(t, mux, "POST", infBase+"/answers", `{"answer_ref":"answer://test","produced_by":"inference-runtime","idempotency_key":"i-ans"}`)
	do(t, mux, "POST", infBase+"/audit", `{"audited_by":"inference-owner","audit_ref":"audit://test","idempotency_key":"i-aud"}`)
	rec, body := do(t, mux, "POST", infBase+"/answers", `{"answer_ref":"answer://test-2","produced_by":"inference-runtime","idempotency_key":"i-ans2"}`)
	if rec.Code != http.StatusConflict {
		t.Fatalf("expected 409, got %d", rec.Code)
	}
	if body["error"] != "inference_audited_immutable" {
		t.Fatalf("unexpected error: %v", body["error"])
	}
}

func TestNotifications(t *testing.T) {
	_, mux := newTestServer(t)
	rec, body := do(t, mux, "GET", "/v1/notifications/inf-0001", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if len(body["notifications"].([]any)) == 0 {
		t.Fatalf("expected a pending notification on a submitted request")
	}
}
