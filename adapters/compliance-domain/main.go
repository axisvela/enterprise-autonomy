package main

import (
	"encoding/json"
	"flag"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

type evidenceItem struct {
	ID          string `json:"id"`
	Source      string `json:"source"`
	Timestamp   string `json:"timestamp"`
	EvidenceRef string `json:"evidence_ref"`
	CollectedBy string `json:"collected_by"`
	OccurredAt  string `json:"occurred_at"`
}

type attestation struct {
	ID             string `json:"id"`
	AttestedBy     string `json:"attested_by"`
	Decision       string `json:"decision"`
	AttestationRef string `json:"attestation_ref"`
	IdempotencyKey string `json:"idempotency_key"`
	OccurredAt     string `json:"occurred_at"`
}

type action struct {
	ID        string `json:"id"`
	Type      string `json:"type"`
	By        string `json:"by"`
	Reference string `json:"reference,omitempty"`
	OccurredAt string `json:"occurred_at"`
}

type complianceCase struct {
	ID            string                 `json:"id"`
	Requirement   string                 `json:"requirement"`
	Status        string                 `json:"status"`
	Attestor      string                 `json:"attestor"`
	RequiredItems []string               `json:"required_items"`
	Evidence      map[string]evidenceItem `json:"evidence"`
	Attestation   *attestation           `json:"attestation,omitempty"`
	PackageID     string                 `json:"package_id,omitempty"`
	Actions       []action               `json:"actions"`
}

type store struct {
	sync.Mutex
	Cases map[string]*complianceCase `json:"cases"`
	file  string
}

func main() {
	addr := flag.String("addr", ":8098", "HTTP listen address")
	dataFile := flag.String("data-file", "compliance-domain-data.json", "JSON persistence file")
	flag.Parse()
	s := load(*dataFile)
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { write(w, http.StatusOK, map[string]string{"status": "ok", "service": "compliance-domain-adapter"}) })
	mux.HandleFunc("/v1/compliance/", s.cases)
	mux.HandleFunc("/v1/notifications/", s.notifications)
	log.Printf("compliance-domain adapter listening on %s", *addr)
	log.Fatal(http.ListenAndServe(*addr, mux))
}

func load(file string) *store {
	s := &store{file: file, Cases: map[string]*complianceCase{"compliance-0001": {ID: "compliance-0001", Requirement: "SOC2-1", Status: "open", Attestor: "compliance-lead", RequiredItems: []string{"evidence-item-1", "evidence-item-2", "evidence-item-3", "evidence-item-4"}, Evidence: map[string]evidenceItem{}}}}
	b, err := os.ReadFile(file)
	if err == nil { _ = json.Unmarshal(b, s) }
	return s
}

func (s *store) save() {
	_ = os.MkdirAll(filepath.Dir(s.file), 0755)
	b, _ := json.MarshalIndent(s, "", "  ")
	_ = os.WriteFile(s.file, b, 0600)
}

func (s *store) cases(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/v1/compliance/"), "/")
	s.Lock()
	c, ok := s.Cases[parts[0]]
	s.Unlock()
	if !ok { write(w, http.StatusNotFound, map[string]string{"error": "compliance_case_not_found"}); return }
	switch {
	case len(parts) == 1 && r.Method == http.MethodGet:
		s.Lock(); defer s.Unlock()
		write(w, http.StatusOK, c)
	case len(parts) == 2 && parts[1] == "evidence" && r.Method == http.MethodPost:
		s.collect(w, r, c)
	case len(parts) == 2 && parts[1] == "attestations" && r.Method == http.MethodPost:
		s.attest(w, r, c)
	case len(parts) == 2 && parts[1] == "packages" && r.Method == http.MethodPost:
		s.release(w, r, c)
	default:
		write(w, http.StatusNotFound, map[string]string{"error": "not_found"})
	}
}

func (s *store) collect(w http.ResponseWriter, r *http.Request, c *complianceCase) {
	var input struct{ ItemID string `json:"item_id"`; Source string `json:"source"`; Timestamp string `json:"timestamp"`; EvidenceRef string `json:"evidence_ref"`; CollectedBy string `json:"collected_by"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.ItemID == "" || input.Source == "" || input.Timestamp == "" || input.EvidenceRef == "" || input.CollectedBy == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "item_id_source_timestamp_evidence_ref_collected_by_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	if _, exists := c.Evidence[input.ItemID]; exists {
		if existing, idem := c.Evidence[input.ItemID]; idem && existing.ID == "evidence-"+input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"case": c, "evidence": existing, "replayed": true}); return }
	}
	if !contains(c.RequiredItems, input.ItemID) { write(w, http.StatusBadRequest, map[string]string{"error": "unknown_evidence_item"}); return }
	if _, exists := c.Evidence[input.ItemID]; exists { write(w, http.StatusConflict, map[string]string{"error": "evidence_item_already_collected"}); return }
	it := evidenceItem{ID: "evidence-" + input.IdempotencyKey, Source: input.Source, Timestamp: input.Timestamp, EvidenceRef: input.EvidenceRef, CollectedBy: input.CollectedBy, OccurredAt: time.Now().UTC().Format(time.RFC3339)}
	c.Evidence[input.ItemID] = it
	c.Actions = append(c.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "evidence", By: input.CollectedBy, Reference: input.EvidenceRef, OccurredAt: it.OccurredAt})
	if len(c.Evidence) == len(c.RequiredItems) && c.Status == "open" { c.Status = "evidence" }
	s.save(); write(w, http.StatusOK, map[string]any{"case": c, "evidence": it, "replayed": false})
}

func (s *store) attest(w http.ResponseWriter, r *http.Request, c *complianceCase) {
	var input struct{ AttestedBy string `json:"attested_by"`; Decision string `json:"decision"`; AttestationRef string `json:"attestation_ref"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.AttestedBy == "" || input.Decision == "" || input.AttestationRef == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "attested_by_decision_attestation_ref_and_idempotency_key_are_required"}); return }
	if input.Decision != "attest" && input.Decision != "defer" { write(w, http.StatusBadRequest, map[string]string{"error": "decision_must_be_attest_or_defer"}); return }
	s.Lock(); defer s.Unlock()
	if c.Attestation != nil && c.Attestation.IdempotencyKey == input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"case": c, "attestation": c.Attestation, "replayed": true}); return }
	if len(c.Evidence) != len(c.RequiredItems) { write(w, http.StatusForbidden, map[string]string{"error": "evidence_incomplete_attestation_requires_all_items"}); return }
	if input.AttestedBy != c.Attestor { write(w, http.StatusForbidden, map[string]string{"error": "not_designated_attestor"}); return }
	a := &attestation{ID: "attestation-" + input.IdempotencyKey, AttestedBy: input.AttestedBy, Decision: input.Decision, AttestationRef: input.AttestationRef, IdempotencyKey: input.IdempotencyKey, OccurredAt: time.Now().UTC().Format(time.RFC3339)}
	c.Attestation = a
	if input.Decision == "attest" { c.Status = "attested" }
	c.Actions = append(c.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "attestation", By: input.AttestedBy, Reference: input.AttestationRef, OccurredAt: a.OccurredAt})
	s.save(); write(w, http.StatusOK, map[string]any{"case": c, "attestation": a, "replayed": false})
}

func (s *store) release(w http.ResponseWriter, r *http.Request, c *complianceCase) {
	var input struct{ ReleasedBy string `json:"released_by"`; AttestationRef string `json:"attestation_ref"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.ReleasedBy == "" || input.AttestationRef == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "released_by_attestation_ref_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	if c.PackageID != "" && c.PackageID == "package-"+input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"case": c, "replayed": true}); return }
	if c.PackageID != "" { write(w, http.StatusConflict, map[string]string{"error": "package_already_released_immutable"}); return }
	if c.Attestation == nil || c.Attestation.Decision != "attest" { write(w, http.StatusForbidden, map[string]string{"error": "attestation_required_before_package"}); return }
	if input.AttestationRef != c.Attestation.AttestationRef { write(w, http.StatusForbidden, map[string]string{"error": "attestation_ref_mismatch"}); return }
	c.PackageID = "package-" + input.IdempotencyKey
	c.Status = "released"
	c.Actions = append(c.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "package-release", By: input.ReleasedBy, Reference: input.AttestationRef, OccurredAt: time.Now().UTC().Format(time.RFC3339)})
	s.save(); write(w, http.StatusOK, map[string]any{"case": c, "package_id": c.PackageID, "replayed": false})
}

func contains(list []string, v string) bool {
	for _, x := range list { if x == v { return true } }
	return false
}

func (s *store) notifications(w http.ResponseWriter, r *http.Request) { s.Lock(); defer s.Unlock(); id := strings.TrimPrefix(r.URL.Path, "/v1/notifications/"); c, ok := s.Cases[id]; if !ok { write(w, http.StatusNotFound, map[string]string{"error": "compliance_case_not_found"}); return }; pending := []string{}; if c.PackageID != "" { pending = append(pending, "audit-package-notification-pending:"+c.PackageID) }; write(w, http.StatusOK, map[string]any{"case_id": id, "notifications": pending}) }

func write(w http.ResponseWriter, status int, v any) { w.Header().Set("Content-Type", "application/json"); w.WriteHeader(status); _ = json.NewEncoder(w).Encode(v) }
