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

type fact struct {
	ID         string `json:"id"`
	Claim      string `json:"claim"`
	Source     string `json:"source"`
	Verified   bool   `json:"verified"`
	OccurredAt string `json:"occurred_at"`
}

type consent struct {
	ID            string `json:"id"`
	Customer      string `json:"customer"`
	Decision      string `json:"decision"`
	ConsentRef    string `json:"consent_ref"`
	IdempotencyKey string `json:"idempotency_key"`
	OccurredAt    string `json:"occurred_at"`
}

type resolution struct {
	ID             string `json:"id"`
	Type           string `json:"type"`
	Amount         int    `json:"amount"`
	ConsentRef     string `json:"consent_ref,omitempty"`
	ApprovalRef    string `json:"approval_ref,omitempty"`
	ApprovedBy     string `json:"approved_by,omitempty"`
	IdempotencyKey string `json:"idempotency_key"`
	OccurredAt     string `json:"occurred_at"`
	Status         string `json:"status"`
}

type action struct {
	ID        string `json:"id"`
	Type      string `json:"type"`
	By        string `json:"by"`
	Reference string `json:"reference,omitempty"`
	OccurredAt string `json:"occurred_at"`
}

type customerCase struct {
	ID          string       `json:"id"`
	Customer    string       `json:"customer"`
	Account     string       `json:"account"`
	Issue       string       `json:"issue"`
	Status      string       `json:"status"`
	Facts       []fact       `json:"facts"`
	Consent     *consent     `json:"consent,omitempty"`
	Resolutions []resolution `json:"resolutions"`
	Actions     []action     `json:"actions"`
}

type credit struct {
	ID         string `json:"id"`
	Amount     int    `json:"amount"`
	Reason     string `json:"reason"`
	ConsentRef string `json:"consent_ref"`
	ApprovalRef string `json:"approval_ref"`
	OccurredAt string `json:"occurred_at"`
}

type account struct {
	ID       string   `json:"id"`
	Customer string   `json:"customer"`
	Balance  int      `json:"balance"`
	Currency string   `json:"currency"`
	Status   string   `json:"status"`
	Credits  []credit `json:"credits"`
}

type store struct {
	sync.Mutex
	Cases   map[string]*customerCase `json:"cases"`
	Accounts map[string]*account     `json:"accounts"`
	file    string
}

func main() {
	addr := flag.String("addr", ":8093", "HTTP listen address")
	dataFile := flag.String("data-file", "customer-domain-data.json", "JSON persistence file")
	flag.Parse()
	s := load(*dataFile)
	log.Printf("customer-domain adapter listening on %s", *addr)
	log.Fatal(http.ListenAndServe(*addr, newMux(s)))
}

func newMux(s *store) *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { write(w, http.StatusOK, map[string]string{"status": "ok", "service": "customer-domain-adapter"}) })
	mux.HandleFunc("/v1/cases/", s.cases)
	mux.HandleFunc("/v1/accounts/", s.account)
	mux.HandleFunc("/v1/notifications/", s.notifications)
	return mux
}

func load(file string) *store {
	s := &store{file: file, Cases: map[string]*customerCase{"cs-0001": {ID: "cs-0001", Customer: "cust-1001", Account: "acct-2001", Issue: "billing overcharge", Status: "open"}}, Accounts: map[string]*account{"acct-2001": {ID: "acct-2001", Customer: "cust-1001", Balance: 120, Currency: "USD", Status: "active"}}}
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
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/v1/cases/"), "/")
	s.Lock()
	c, ok := s.Cases[parts[0]]
	s.Unlock()
	if !ok { write(w, http.StatusNotFound, map[string]string{"error": "case_not_found"}); return }
	switch {
	case len(parts) == 1 && r.Method == http.MethodGet:
		s.Lock(); defer s.Unlock()
		write(w, http.StatusOK, c)
	case len(parts) == 2 && parts[1] == "facts" && r.Method == http.MethodPost:
		s.addFact(w, r, c)
	case len(parts) == 2 && parts[1] == "consent" && r.Method == http.MethodPost:
		s.giveConsent(w, r, c)
	case len(parts) == 2 && parts[1] == "resolutions" && r.Method == http.MethodPost:
		s.applyResolution(w, r, c)
	case len(parts) == 2 && parts[1] == "close" && r.Method == http.MethodPost:
		s.close(w, r, c)
	default:
		write(w, http.StatusNotFound, map[string]string{"error": "not_found"})
	}
}

func (s *store) addFact(w http.ResponseWriter, r *http.Request, c *customerCase) {
	var input struct{ Claim string `json:"claim"`; Source string `json:"source"`; Verified bool `json:"verified"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.Claim == "" || input.Source == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "claim_source_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	for _, f := range c.Facts { if f.ID == "fact-"+input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"case": c, "fact": f, "replayed": true}); return } }
	if !input.Verified { write(w, http.StatusUnprocessableEntity, map[string]string{"error": "unverified_claim_requires_investigation"}); return }
	f := fact{ID: "fact-" + input.IdempotencyKey, Claim: input.Claim, Source: input.Source, Verified: input.Verified, OccurredAt: time.Now().UTC().Format(time.RFC3339)}
	c.Facts = append(c.Facts, f)
	c.Actions = append(c.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "fact", By: "service-agent", OccurredAt: f.OccurredAt})
	s.save(); write(w, http.StatusOK, map[string]any{"case": c, "fact": f, "replayed": false})
}

func (s *store) giveConsent(w http.ResponseWriter, r *http.Request, c *customerCase) {
	var input struct{ Customer string `json:"customer"`; Decision string `json:"decision"`; ConsentRef string `json:"consent_ref"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.Customer == "" || input.Decision == "" || input.ConsentRef == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "customer_decision_consent_ref_and_idempotency_key_are_required"}); return }
	if input.Decision != "approve" && input.Decision != "decline" { write(w, http.StatusBadRequest, map[string]string{"error": "decision_must_be_approve_or_decline"}); return }
	s.Lock(); defer s.Unlock()
	if input.Customer != c.Customer { write(w, http.StatusForbidden, map[string]string{"error": "customer_mismatch"}); return }
	if c.Consent != nil && c.Consent.IdempotencyKey == input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"case": c, "consent": c.Consent, "replayed": true}); return }
	con := &consent{ID: "consent-" + input.IdempotencyKey, Customer: input.Customer, Decision: input.Decision, ConsentRef: input.ConsentRef, IdempotencyKey: input.IdempotencyKey, OccurredAt: time.Now().UTC().Format(time.RFC3339)}
	c.Consent = con
	c.Actions = append(c.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "consent", By: input.Customer, Reference: input.ConsentRef, OccurredAt: con.OccurredAt})
	if input.Decision == "approve" && c.Status == "open" { c.Status = "consented" }
	s.save(); write(w, http.StatusOK, map[string]any{"case": c, "consent": con, "replayed": false})
}

func (s *store) applyResolution(w http.ResponseWriter, r *http.Request, c *customerCase) {
	var input struct{ Type string `json:"type"`; Amount int `json:"amount"`; ApprovedBy string `json:"approved_by"`; ApprovalRef string `json:"approval_ref"`; ConsentRef string `json:"consent_ref"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.Type == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "type_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	for _, res := range c.Resolutions { if res.IdempotencyKey == input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"case": c, "resolution": res, "replayed": true}); return } }
	switch input.Type {
	case "explanation", "correction":
		// no consent or approval required
	case "compensation", "refund", "credit":
		if c.Consent == nil || c.Consent.Decision != "approve" { write(w, http.StatusForbidden, map[string]string{"error": "consent_required"}); return }
		if input.ConsentRef != c.Consent.ConsentRef { write(w, http.StatusForbidden, map[string]string{"error": "consent_ref_mismatch"}); return }
		if input.ApprovedBy == "" || input.ApprovalRef == "" { write(w, http.StatusForbidden, map[string]string{"error": "approval_required_for_compensation"}); return }
		if input.Amount <= 0 { write(w, http.StatusBadRequest, map[string]string{"error": "amount_must_be_positive"}); return }
	case "escalation":
		// no consent, records escalation
	default:
		write(w, http.StatusBadRequest, map[string]string{"error": "unsupported_resolution_type"}); return
	}
	res := resolution{ID: "resolution-" + input.IdempotencyKey, Type: input.Type, Amount: input.Amount, ConsentRef: input.ConsentRef, ApprovalRef: input.ApprovalRef, ApprovedBy: input.ApprovedBy, IdempotencyKey: input.IdempotencyKey, OccurredAt: time.Now().UTC().Format(time.RFC3339), Status: "applied"}
	c.Resolutions = append(c.Resolutions, res)
	if input.Type == "credit" || input.Type == "compensation" || input.Type == "refund" {
		if acct, ok := s.Accounts[c.Account]; ok {
			acct.Credits = append(acct.Credits, credit{ID: "credit-" + input.IdempotencyKey, Amount: input.Amount, Reason: input.Type, ConsentRef: input.ConsentRef, ApprovalRef: input.ApprovalRef, OccurredAt: res.OccurredAt})
			acct.Balance -= input.Amount
		}
	}
	if input.Type == "escalation" { c.Status = "escalated" } else if c.Status == "open" || c.Status == "consented" { c.Status = "resolving" }
	c.Actions = append(c.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "resolution", By: input.ApprovedBy, Reference: input.ApprovalRef, OccurredAt: res.OccurredAt})
	s.save(); write(w, http.StatusOK, map[string]any{"case": c, "resolution": res, "replayed": false})
}

func (s *store) close(w http.ResponseWriter, r *http.Request, c *customerCase) {
	var input struct{ ClosedBy string `json:"closed_by"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.ClosedBy == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "closed_by_and_idempotency_key_are_required"}); return }
	s.Lock(); defer s.Unlock()
	for _, a := range c.Actions { if a.Type == "close" && a.ID == "action-"+input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"case": c, "replayed": true}); return } }
	if len(c.Resolutions) == 0 { write(w, http.StatusForbidden, map[string]string{"error": "no_resolution_applied"}); return }
	if c.Status == "escalated" { write(w, http.StatusConflict, map[string]string{"error": "escalated_case_requires_escalation_queue"}); return }
	c.Status = "resolved"
	c.Actions = append(c.Actions, action{ID: "action-" + input.IdempotencyKey, Type: "close", By: input.ClosedBy, OccurredAt: time.Now().UTC().Format(time.RFC3339)})
	s.save(); write(w, http.StatusOK, map[string]any{"case": c, "replayed": false})
}

func (s *store) account(w http.ResponseWriter, r *http.Request) { s.Lock(); defer s.Unlock(); id := strings.TrimPrefix(r.URL.Path, "/v1/accounts/"); a, ok := s.Accounts[id]; if !ok { write(w, http.StatusNotFound, map[string]string{"error": "account_not_found"}); return }; write(w, http.StatusOK, a) }

func (s *store) notifications(w http.ResponseWriter, r *http.Request) { s.Lock(); defer s.Unlock(); id := strings.TrimPrefix(r.URL.Path, "/v1/notifications/"); c, ok := s.Cases[id]; if !ok { write(w, http.StatusNotFound, map[string]string{"error": "case_not_found"}); return }; pending := []string{}; for _, res := range c.Resolutions { if res.Type != "explanation" { pending = append(pending, "customer-notification-pending:"+res.ID) } }; write(w, http.StatusOK, map[string]any{"case_id": id, "notifications": pending}) }

func write(w http.ResponseWriter, status int, v any) { w.Header().Set("Content-Type", "application/json"); w.WriteHeader(status); _ = json.NewEncoder(w).Encode(v) }
