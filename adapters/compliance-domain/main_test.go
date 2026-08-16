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

const compBase = "/v1/compliance/compliance-0001"

func TestComplianceHealth(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "GET", "/healthz", "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
}

func TestComplianceSeed(t *testing.T) {
	_, mux := newTestServer(t)
	rec, body := do(t, mux, "GET", compBase, "")
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	if body["status"] != "open" { t.Fatalf("expected open, got %v", body["status"]) }
}

func TestComplianceUnknownEvidenceItemDenied(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", compBase+"/evidence", `{"item_id":"nope","source":"x","timestamp":"t","evidence_ref":"e","collected_by":"compliance-lead","idempotency_key":"e-v1"}`)
	if rec.Code != http.StatusBadRequest { t.Fatalf("expected 400, got %d", rec.Code) }
}

func TestComplianceAttestationBeforeEvidenceDenied(t *testing.T) {
	_, mux := newTestServer(t)
	rec, _ := do(t, mux, "POST", compBase+"/attestations", `{"attested_by":"compliance-lead","decision":"attest","attestation_ref":"attestation://test","idempotency_key":"a-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestComplianceNonAttestorDenied(t *testing.T) {
	_, mux := newTestServer(t)
	for i := 1; i <= 4; i++ {
		body := `{"item_id":"evidence-item-` + string(rune('0'+i)) + `","source":"s","timestamp":"t","evidence_ref":"e","collected_by":"compliance-lead","idempotency_key":"e` + string(rune('0'+i)) + `"}`
		do(t, mux, "POST", compBase+"/evidence", body)
	}
	rec, _ := do(t, mux, "POST", compBase+"/attestations", `{"attested_by":"outsider","decision":"attest","attestation_ref":"attestation://test","idempotency_key":"a-v1"}`)
	if rec.Code != http.StatusForbidden { t.Fatalf("expected 403, got %d", rec.Code) }
}

func TestComplianceFullFlow(t *testing.T) {
	_, mux := newTestServer(t)
	for i := 1; i <= 4; i++ {
		body := `{"item_id":"evidence-item-` + string(rune('0'+i)) + `","source":"s","timestamp":"t","evidence_ref":"e","collected_by":"compliance-lead","idempotency_key":"e` + string(rune('0'+i)) + `"}`
		do(t, mux, "POST", compBase+"/evidence", body)
	}
	rec, body := do(t, mux, "POST", compBase+"/attestations", `{"attested_by":"compliance-lead","decision":"attest","attestation_ref":"attestation://test","idempotency_key":"a-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	c := body["case"].(map[string]any)
	if c["status"] != "attested" { t.Fatalf("expected attested, got %v", c["status"]) }
	rec, body = do(t, mux, "POST", compBase+"/packages", `{"released_by":"compliance-lead","attestation_ref":"attestation://test","idempotency_key":"p-v1"}`)
	if rec.Code != http.StatusOK { t.Fatalf("expected 200, got %d", rec.Code) }
	c = body["case"].(map[string]any)
	if c["status"] != "released" { t.Fatalf("expected released, got %v", c["status"]) }
}

func TestCompliancePackageImmutable(t *testing.T) {
	_, mux := newTestServer(t)
	for i := 1; i <= 4; i++ {
		body := `{"item_id":"evidence-item-` + string(rune('0'+i)) + `","source":"s","timestamp":"t","evidence_ref":"e","collected_by":"compliance-lead","idempotency_key":"e` + string(rune('0'+i)) + `"}`
		do(t, mux, "POST", compBase+"/evidence", body)
	}
	do(t, mux, "POST", compBase+"/attestations", `{"attested_by":"compliance-lead","decision":"attest","attestation_ref":"attestation://test","idempotency_key":"a-v1"}`)
	do(t, mux, "POST", compBase+"/packages", `{"released_by":"compliance-lead","attestation_ref":"attestation://test","idempotency_key":"p-v1"}`)
	rec, _ := do(t, mux, "POST", compBase+"/packages", `{"released_by":"compliance-lead","attestation_ref":"attestation://test","idempotency_key":"p2-v1"}`)
	if rec.Code != http.StatusConflict { t.Fatalf("expected 409, got %d", rec.Code) }
}

func TestComplianceDuplicateEvidenceItemDenied(t *testing.T) {
	_, mux := newTestServer(t)
	body := `{"item_id":"evidence-item-1","source":"s","timestamp":"t","evidence_ref":"e","collected_by":"compliance-lead","idempotency_key":"e1"}`
	do(t, mux, "POST", compBase+"/evidence", body)
	rec, _ := do(t, mux, "POST", compBase+"/evidence", `{"item_id":"evidence-item-1","source":"s2","timestamp":"t2","evidence_ref":"e2","collected_by":"compliance-lead","idempotency_key":"e1b"}`)
	if rec.Code != http.StatusConflict { t.Fatalf("expected 409, got %d", rec.Code) }
}
