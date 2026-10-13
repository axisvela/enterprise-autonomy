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

type route struct {
	Model      string `json:"model"`
	Endpoint   string `json:"endpoint"`
	PolicyRef  string `json:"policy_ref"`
	SelectedAt string `json:"selected_at"`
}

type grounding struct {
	ClaimRefs  []string `json:"claim_refs"`
	MemoryRef  string   `json:"memory_ref"`
	GroundedAt string   `json:"grounded_at"`
}

type review struct {
	ID         string `json:"id"`
	ReviewedBy string `json:"reviewed_by"`
	Decision   string `json:"decision"`
	ReviewRef  string `json:"review_ref"`
	ReviewedAt string `json:"reviewed_at"`
}

type answer struct {
	ID         string `json:"id"`
	AnswerRef  string `json:"answer_ref"`
	ProducedBy string `json:"produced_by"`
	OccurredAt string `json:"occurred_at"`
}

type audit struct {
	ID         string `json:"id"`
	AuditedBy  string `json:"audited_by"`
	AuditRef   string `json:"audit_ref"`
	OccurredAt string `json:"occurred_at"`
}

type inference struct {
	ID               string     `json:"id"`
	Use              string     `json:"use"`
	Impact           string     `json:"impact"`
	Status           string     `json:"status"`
	AuthorizedBy     string     `json:"authorized_by,omitempty"`
	AuthorizationRef string     `json:"authorization_ref,omitempty"`
	Route            *route     `json:"route,omitempty"`
	Grounding        *grounding `json:"grounding,omitempty"`
	Review           *review    `json:"review,omitempty"`
	Answer           *answer    `json:"answer,omitempty"`
	Audit            *audit     `json:"audit,omitempty"`
}

type store struct {
	sync.Mutex
	Inferences map[string]*inference `json:"inferences"`
	file       string
}

func main() {
	addr := flag.String("addr", ":8103", "HTTP listen address")
	dataFile := flag.String("data-file", "inference-domain-data.json", "JSON persistence file")
	flag.Parse()
	s := load(*dataFile)
	log.Printf("inference-domain adapter listening on %s", *addr)
	log.Fatal(http.ListenAndServe(*addr, newMux(s)))
}

func newMux(s *store) *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		write(w, http.StatusOK, map[string]string{"status": "ok", "service": "inference-domain-adapter"})
	})
	mux.HandleFunc("/v1/inferences/", s.inferences)
	mux.HandleFunc("/v1/notifications/", s.notifications)
	return mux
}

func load(file string) *store {
	s := &store{file: file, Inferences: map[string]*inference{
		"inf-0001": {
			ID: "inf-0001", Use: "customer-facing-summary", Impact: "high", Status: "submitted",
		},
	}}
	b, err := os.ReadFile(file)
	if err == nil {
		_ = json.Unmarshal(b, s)
	}
	return s
}

func (s *store) save() {
	_ = os.MkdirAll(filepath.Dir(s.file), 0755)
	b, _ := json.MarshalIndent(s, "", "  ")
	_ = os.WriteFile(s.file, b, 0600)
}

func (s *store) inferences(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/v1/inferences/"), "/")
	s.Lock()
	inf, ok := s.Inferences[parts[0]]
	s.Unlock()
	if !ok {
		write(w, http.StatusNotFound, map[string]string{"error": "inference_not_found"})
		return
	}
	switch {
	case len(parts) == 1 && r.Method == http.MethodGet:
		s.Lock()
		defer s.Unlock()
		write(w, http.StatusOK, inf)
	case len(parts) == 2 && parts[1] == "authorize" && r.Method == http.MethodPost:
		s.authorize(w, r, inf)
	case len(parts) == 2 && parts[1] == "route" && r.Method == http.MethodPost:
		s.route(w, r, inf)
	case len(parts) == 2 && parts[1] == "ground" && r.Method == http.MethodPost:
		s.ground(w, r, inf)
	case len(parts) == 2 && parts[1] == "reviews" && r.Method == http.MethodPost:
		s.reviews(w, r, inf)
	case len(parts) == 2 && parts[1] == "answers" && r.Method == http.MethodPost:
		s.answers(w, r, inf)
	case len(parts) == 2 && parts[1] == "audit" && r.Method == http.MethodPost:
		s.audit(w, r, inf)
	default:
		write(w, http.StatusNotFound, map[string]string{"error": "not_found"})
	}
}

func (s *store) immutableLocked(inf *inference) (bool, string) {
	if inf.Status == "audited" {
		return true, "inference_audited_immutable"
	}
	if inf.Status == "answered" {
		return true, "inference_answered_immutable"
	}
	return false, ""
}

func (s *store) authorize(w http.ResponseWriter, r *http.Request, inf *inference) {
	var input struct {
		AuthorizedBy     string `json:"authorized_by"`
		AuthorizationRef string `json:"authorization_ref"`
		IdempotencyKey   string `json:"idempotency_key"`
	}
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.AuthorizedBy == "" || input.AuthorizationRef == "" || input.IdempotencyKey == "" {
		write(w, http.StatusBadRequest, map[string]string{"error": "authorized_by_authorization_ref_and_idempotency_key_are_required"})
		return
	}
	s.Lock()
	defer s.Unlock()
	if imm, msg := s.immutableLocked(inf); imm {
		write(w, http.StatusConflict, map[string]string{"error": msg})
		return
	}
	if inf.AuthorizationRef != "" {
		write(w, http.StatusOK, map[string]any{"inference": inf, "replayed": true})
		return
	}
	inf.AuthorizedBy = input.AuthorizedBy
	inf.AuthorizationRef = input.AuthorizationRef
	inf.Status = "authorized"
	s.save()
	write(w, http.StatusOK, map[string]any{"inference": inf, "replayed": false})
}

var allowedModels = map[string]bool{"model-alpha": true, "model-beta": true}
var allowedEndpoints = map[string]bool{"endpoint-production": true}

func (s *store) route(w http.ResponseWriter, r *http.Request, inf *inference) {
	var input struct {
		Model          string `json:"model"`
		Endpoint       string `json:"endpoint"`
		PolicyRef      string `json:"policy_ref"`
		IdempotencyKey string `json:"idempotency_key"`
	}
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.Model == "" || input.Endpoint == "" || input.PolicyRef == "" || input.IdempotencyKey == "" {
		write(w, http.StatusBadRequest, map[string]string{"error": "model_endpoint_policy_ref_and_idempotency_key_are_required"})
		return
	}
	s.Lock()
	defer s.Unlock()
	if imm, msg := s.immutableLocked(inf); imm {
		write(w, http.StatusConflict, map[string]string{"error": msg})
		return
	}
	if inf.Route != nil {
		write(w, http.StatusOK, map[string]any{"inference": inf, "replayed": true})
		return
	}
	if inf.Status == "submitted" || inf.AuthorizationRef == "" {
		write(w, http.StatusForbidden, map[string]string{"error": "authorization_required_before_route"})
		return
	}
	if !allowedModels[input.Model] {
		write(w, http.StatusForbidden, map[string]string{"error": "model_out_of_policy_" + input.Model})
		return
	}
	if !allowedEndpoints[input.Endpoint] {
		write(w, http.StatusForbidden, map[string]string{"error": "endpoint_out_of_policy_" + input.Endpoint})
		return
	}
	inf.Route = &route{Model: input.Model, Endpoint: input.Endpoint, PolicyRef: input.PolicyRef, SelectedAt: time.Now().UTC().Format(time.RFC3339)}
	inf.Status = "routed"
	s.save()
	write(w, http.StatusOK, map[string]any{"inference": inf, "replayed": false})
}

func (s *store) ground(w http.ResponseWriter, r *http.Request, inf *inference) {
	var input struct {
		ClaimRefs      []string `json:"claim_refs"`
		MemoryRef      string   `json:"memory_ref"`
		IdempotencyKey string   `json:"idempotency_key"`
	}
	if json.NewDecoder(r.Body).Decode(&input) != nil || len(input.ClaimRefs) == 0 || input.MemoryRef == "" || input.IdempotencyKey == "" {
		write(w, http.StatusBadRequest, map[string]string{"error": "claim_refs_memory_ref_and_idempotency_key_are_required"})
		return
	}
	s.Lock()
	defer s.Unlock()
	if imm, msg := s.immutableLocked(inf); imm {
		write(w, http.StatusConflict, map[string]string{"error": msg})
		return
	}
	if inf.Grounding != nil {
		write(w, http.StatusOK, map[string]any{"inference": inf, "replayed": true})
		return
	}
	if inf.Route == nil {
		write(w, http.StatusForbidden, map[string]string{"error": "route_required_before_grounding"})
		return
	}
	inf.Grounding = &grounding{ClaimRefs: input.ClaimRefs, MemoryRef: input.MemoryRef, GroundedAt: time.Now().UTC().Format(time.RFC3339)}
	inf.Status = "grounded"
	s.save()
	write(w, http.StatusOK, map[string]any{"inference": inf, "replayed": false})
}

func (s *store) reviews(w http.ResponseWriter, r *http.Request, inf *inference) {
	var input struct {
		ReviewedBy     string `json:"reviewed_by"`
		Decision       string `json:"decision"`
		ReviewRef      string `json:"review_ref"`
		IdempotencyKey string `json:"idempotency_key"`
	}
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.ReviewedBy == "" || input.Decision == "" || input.ReviewRef == "" || input.IdempotencyKey == "" {
		write(w, http.StatusBadRequest, map[string]string{"error": "reviewed_by_decision_review_ref_and_idempotency_key_are_required"})
		return
	}
	s.Lock()
	defer s.Unlock()
	if imm, msg := s.immutableLocked(inf); imm {
		write(w, http.StatusConflict, map[string]string{"error": msg})
		return
	}
	if inf.Review != nil {
		write(w, http.StatusOK, map[string]any{"inference": inf, "replayed": true})
		return
	}
	if inf.Impact != "high" {
		write(w, http.StatusForbidden, map[string]string{"error": "review_not_required_for_low_impact"})
		return
	}
	if input.Decision != "approve" {
		write(w, http.StatusForbidden, map[string]string{"error": "review_decision_must_be_approve"})
		return
	}
	inf.Review = &review{ID: "review-" + input.IdempotencyKey, ReviewedBy: input.ReviewedBy, Decision: input.Decision, ReviewRef: input.ReviewRef, ReviewedAt: time.Now().UTC().Format(time.RFC3339)}
	inf.Status = "reviewed"
	s.save()
	write(w, http.StatusOK, map[string]any{"inference": inf, "replayed": false})
}

func (s *store) answers(w http.ResponseWriter, r *http.Request, inf *inference) {
	var input struct {
		AnswerRef      string `json:"answer_ref"`
		ProducedBy     string `json:"produced_by"`
		IdempotencyKey string `json:"idempotency_key"`
	}
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.AnswerRef == "" || input.ProducedBy == "" || input.IdempotencyKey == "" {
		write(w, http.StatusBadRequest, map[string]string{"error": "answer_ref_produced_by_and_idempotency_key_are_required"})
		return
	}
	s.Lock()
	defer s.Unlock()
	if imm, msg := s.immutableLocked(inf); imm {
		write(w, http.StatusConflict, map[string]string{"error": msg})
		return
	}
	if inf.Answer != nil {
		write(w, http.StatusOK, map[string]any{"inference": inf, "replayed": true})
		return
	}
	if inf.Route == nil || inf.Grounding == nil {
		write(w, http.StatusForbidden, map[string]string{"error": "route_and_grounding_required_before_answer"})
		return
	}
	if inf.Impact == "high" && inf.Review == nil {
		write(w, http.StatusForbidden, map[string]string{"error": "human_review_required_before_answer"})
		return
	}
	inf.Answer = &answer{ID: "answer-" + input.IdempotencyKey, AnswerRef: input.AnswerRef, ProducedBy: input.ProducedBy, OccurredAt: time.Now().UTC().Format(time.RFC3339)}
	inf.Status = "answered"
	s.save()
	write(w, http.StatusOK, map[string]any{"inference": inf, "replayed": false})
}

func (s *store) audit(w http.ResponseWriter, r *http.Request, inf *inference) {
	var input struct {
		AuditedBy      string `json:"audited_by"`
		AuditRef       string `json:"audit_ref"`
		IdempotencyKey string `json:"idempotency_key"`
	}
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.AuditedBy == "" || input.AuditRef == "" || input.IdempotencyKey == "" {
		write(w, http.StatusBadRequest, map[string]string{"error": "audited_by_audit_ref_and_idempotency_key_are_required"})
		return
	}
	s.Lock()
	defer s.Unlock()
	if inf.Audit != nil {
		write(w, http.StatusOK, map[string]any{"inference": inf, "replayed": true})
		return
	}
	if inf.Status != "answered" {
		write(w, http.StatusForbidden, map[string]string{"error": "answer_required_before_audit"})
		return
	}
	inf.Audit = &audit{ID: "audit-" + input.IdempotencyKey, AuditedBy: input.AuditedBy, AuditRef: input.AuditRef, OccurredAt: time.Now().UTC().Format(time.RFC3339)}
	inf.Status = "audited"
	s.save()
	write(w, http.StatusOK, map[string]any{"inference": inf, "replayed": false})
}

func (s *store) notifications(w http.ResponseWriter, r *http.Request) {
	s.Lock()
	defer s.Unlock()
	id := strings.TrimPrefix(r.URL.Path, "/v1/notifications/")
	inf, ok := s.Inferences[id]
	if !ok {
		write(w, http.StatusNotFound, map[string]string{"error": "inference_not_found"})
		return
	}
	pending := []string{}
	if inf.Status == "submitted" || inf.Status == "authorized" {
		pending = append(pending, "authorization-notification-pending:"+id)
	}
	if inf.Status == "routed" || inf.Status == "grounded" {
		if inf.Impact == "high" && inf.Review == nil {
			pending = append(pending, "review-required-notification-pending:"+id)
		}
	}
	if inf.Status == "answered" {
		pending = append(pending, "audit-notification-pending:"+id)
	}
	write(w, http.StatusOK, map[string]any{"inference_id": id, "notifications": pending})
}

func write(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
