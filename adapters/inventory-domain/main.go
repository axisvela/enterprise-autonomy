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

type stockLevel struct {
	Warehouse string `json:"warehouse"`
	Available int    `json:"available"`
}

type skuRecord struct {
	SKU      string       `json:"sku"`
	Levels   []stockLevel `json:"levels"`
	Adjustments []adjustment `json:"adjustments"`
}

type adjustment struct {
	ID             string `json:"id"`
	Delta          int    `json:"delta"`
	Reason         string `json:"reason"`
	ApprovedBy     string `json:"approved_by"`
	ApprovalRef    string `json:"approval_ref"`
	IdempotencyKey string `json:"idempotency_key"`
	OccurredAt     string `json:"occurred_at"`
}

type store struct {
	sync.Mutex
	SKUs map[string]*skuRecord `json:"skus"`
	file string
}

func main() {
	addr := flag.String("addr", ":8091", "HTTP listen address")
	dataFile := flag.String("data-file", "inventory-domain-data.json", "JSON persistence file")
	flag.Parse()
	s := load(*dataFile)
	log.Printf("inventory-domain adapter listening on %s", *addr)
	log.Fatal(http.ListenAndServe(*addr, newMux(s)))
}

func newMux(s *store) *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { write(w, http.StatusOK, map[string]string{"status": "ok", "service": "inventory-domain-adapter"}) })
	mux.HandleFunc("/v1/inventory/", s.inventory)
	return mux
}

func load(file string) *store {
	s := &store{file: file, SKUs: map[string]*skuRecord{"sku-inspection-kit": {SKU: "sku-inspection-kit", Levels: []stockLevel{{Warehouse: "warehouse-a", Available: 0}, {Warehouse: "warehouse-b", Available: 10}}}}}
	b, err := os.ReadFile(file)
	if err == nil { _ = json.Unmarshal(b, s) }
	return s
}

func (s *store) save() {
	_ = os.MkdirAll(filepath.Dir(s.file), 0755)
	b, _ := json.MarshalIndent(s, "", "  ")
	_ = os.WriteFile(s.file, b, 0600)
}

func (s *store) inventory(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/v1/inventory/"), "/")
	if len(parts) != 1 { write(w, http.StatusNotFound, map[string]string{"error": "not_found"}); return }
	s.Lock()
	rec, ok := s.SKUs[parts[0]]
	s.Unlock()
	if !ok { write(w, http.StatusNotFound, map[string]string{"error": "sku_not_found"}); return }
	switch r.Method {
	case http.MethodGet:
		s.Lock(); defer s.Unlock()
		write(w, http.StatusOK, rec)
	case http.MethodPost:
		s.adjust(w, r, rec)
	default:
		write(w, http.StatusMethodNotAllowed, map[string]string{"error": "method_not_allowed"})
	}
}

func (s *store) adjust(w http.ResponseWriter, r *http.Request, rec *skuRecord) {
	var input struct { Warehouse string `json:"warehouse"`; Delta int `json:"delta"`; Reason string `json:"reason"`; ApprovedBy string `json:"approved_by"`; ApprovalRef string `json:"approval_ref"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.Warehouse == "" || input.ApprovedBy == "" || input.ApprovalRef == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "warehouse_approved_by_approval_ref_and_idempotency_key_are_required"}); return }
	if input.Delta == 0 { write(w, http.StatusBadRequest, map[string]string{"error": "delta_must_be_nonzero"}); return }
	s.Lock(); defer s.Unlock()
	for _, a := range rec.Adjustments { if a.IdempotencyKey == input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"sku": rec.SKU, "adjustment": a, "replayed": true}); return } }
	level := -1
	for i, l := range rec.Levels { if l.Warehouse == input.Warehouse { level = i; break } }
	if level == -1 { write(w, http.StatusBadRequest, map[string]string{"error": "warehouse_not_found"}); return }
	if rec.Levels[level].Available+input.Delta < 0 { write(w, http.StatusUnprocessableEntity, map[string]string{"error": "insufficient_stock"}); return }
	a := adjustment{ID: "adjustment-" + input.IdempotencyKey, Delta: input.Delta, Reason: input.Reason, ApprovedBy: input.ApprovedBy, ApprovalRef: input.ApprovalRef, IdempotencyKey: input.IdempotencyKey, OccurredAt: time.Now().UTC().Format(time.RFC3339)}
	rec.Levels[level].Available += input.Delta
	rec.Adjustments = append(rec.Adjustments, a)
	s.save()
	write(w, http.StatusOK, map[string]any{"sku": rec.SKU, "adjustment": a, "replayed": false})
}

func write(w http.ResponseWriter, status int, v any) { w.Header().Set("Content-Type", "application/json"); w.WriteHeader(status); _ = json.NewEncoder(w).Encode(v) }
