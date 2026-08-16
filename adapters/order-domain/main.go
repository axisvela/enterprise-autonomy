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

type order struct {
	ID                string   `json:"id"`
	SKU               string   `json:"sku"`
	Quantity          int      `json:"quantity"`
	Warehouse         string   `json:"warehouse"`
	FulfillmentStatus string   `json:"fulfillment_status"`
	PaymentStatus     string   `json:"payment_status"`
	CarrierStatus     string   `json:"carrier_status"`
	Notifications     []string `json:"notifications"`
	Actions           []action `json:"actions"`
}

type action struct {
	ID             string `json:"id"`
	Action         string `json:"action"`
	ApprovedBy     string `json:"approved_by"`
	ApprovalRef    string `json:"approval_ref"`
	IdempotencyKey string `json:"idempotency_key"`
	OccurredAt     string `json:"occurred_at"`
}

type store struct {
	sync.Mutex
	Orders map[string]*order `json:"orders"`
	file   string
}

func main() {
	addr := flag.String("addr", ":8090", "HTTP listen address")
	dataFile := flag.String("data-file", "order-domain-data.json", "JSON persistence file")
	flag.Parse()
	s := load(*dataFile)
	log.Printf("order-domain adapter listening on %s", *addr)
	log.Fatal(http.ListenAndServe(*addr, newMux(s)))
}

func newMux(s *store) *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { write(w, http.StatusOK, map[string]string{"status": "ok", "service": "order-domain-adapter"}) })
	mux.HandleFunc("/v1/orders/", s.orders)
	mux.HandleFunc("/v1/inventory/", s.inventory)
	mux.HandleFunc("/v1/payments/", s.payment)
	mux.HandleFunc("/v1/shipments/", s.shipment)
	mux.HandleFunc("/v1/notifications/", s.notifications)
	return mux
}

func load(file string) *store {
	s := &store{file: file, Orders: map[string]*order{"order-123": {ID: "order-123", SKU: "sku-inspection-kit", Quantity: 1, Warehouse: "warehouse-a", FulfillmentStatus: "stockout", PaymentStatus: "authorized", CarrierStatus: "not_dispatched"}}}
	b, err := os.ReadFile(file)
	if err == nil { _ = json.Unmarshal(b, s) }
	return s
}

func (s *store) save() {
	_ = os.MkdirAll(filepath.Dir(s.file), 0755)
	b, _ := json.MarshalIndent(s, "", "  ")
	_ = os.WriteFile(s.file, b, 0600)
}

func (s *store) orders(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/v1/orders/"), "/")
	if len(parts) == 1 && r.Method == http.MethodGet { s.getOrder(w, parts[0]); return }
	if len(parts) == 2 && parts[1] == "fulfillment-actions" && r.Method == http.MethodPost { s.fulfillmentAction(w, r, parts[0]); return }
	write(w, http.StatusNotFound, map[string]string{"error": "not_found"})
}

func (s *store) getOrder(w http.ResponseWriter, id string) {
	s.Lock(); defer s.Unlock()
	o, ok := s.Orders[id]; if !ok { write(w, http.StatusNotFound, map[string]string{"error": "order_not_found"}); return }
	write(w, http.StatusOK, o)
}

func (s *store) fulfillmentAction(w http.ResponseWriter, r *http.Request, id string) {
	var input struct { Action string `json:"action"`; ApprovedBy string `json:"approved_by"`; ApprovalRef string `json:"approval_ref"`; IdempotencyKey string `json:"idempotency_key"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil || input.Action == "" || input.ApprovedBy == "" || input.ApprovalRef == "" || input.IdempotencyKey == "" { write(w, http.StatusBadRequest, map[string]string{"error": "action_approved_by_approval_ref_and_idempotency_key_are_required"}); return }
	if input.Action != "alternate_location" && input.Action != "split_shipment" && input.Action != "approved_substitute" && input.Action != "cancel" { write(w, http.StatusBadRequest, map[string]string{"error": "unsupported_action"}); return }
	s.Lock(); defer s.Unlock()
	o, ok := s.Orders[id]; if !ok { write(w, http.StatusNotFound, map[string]string{"error": "order_not_found"}); return }
	for _, a := range o.Actions { if a.IdempotencyKey == input.IdempotencyKey { write(w, http.StatusOK, map[string]any{"order": o, "action": a, "replayed": true}); return } }
	a := action{ID: "action-" + input.IdempotencyKey, Action: input.Action, ApprovedBy: input.ApprovedBy, ApprovalRef: input.ApprovalRef, IdempotencyKey: input.IdempotencyKey, OccurredAt: time.Now().UTC().Format(time.RFC3339)}
	o.Actions = append(o.Actions, a)
	if input.Action == "alternate_location" { o.Warehouse = "warehouse-b"; o.FulfillmentStatus = "replanned"; o.CarrierStatus = "awaiting_dispatch" } else if input.Action == "cancel" { o.FulfillmentStatus = "cancelled"; o.CarrierStatus = "not_dispatched" } else { o.FulfillmentStatus = "replanned"; o.CarrierStatus = "awaiting_dispatch" }
	o.Notifications = append(o.Notifications, "customer-notification-pending:"+a.ID)
	s.save(); write(w, http.StatusOK, map[string]any{"order": o, "action": a, "replayed": false})
}

func (s *store) inventory(w http.ResponseWriter, r *http.Request) { s.Lock(); defer s.Unlock(); write(w, http.StatusOK, map[string]any{"sku": strings.TrimPrefix(r.URL.Path, "/v1/inventory/"), "warehouse-a_available": 0, "warehouse-b_available": 10}) }
func (s *store) payment(w http.ResponseWriter, r *http.Request) { s.getView(w, r, "payment_status") }
func (s *store) shipment(w http.ResponseWriter, r *http.Request) { s.getView(w, r, "carrier_status") }
func (s *store) notifications(w http.ResponseWriter, r *http.Request) { s.Lock(); defer s.Unlock(); id := strings.TrimPrefix(r.URL.Path, "/v1/notifications/"); o, ok := s.Orders[id]; if !ok { write(w, http.StatusNotFound, map[string]string{"error": "order_not_found"}); return }; write(w, http.StatusOK, map[string]any{"order_id": id, "notifications": o.Notifications}) }
func (s *store) getView(w http.ResponseWriter, r *http.Request, field string) { s.Lock(); defer s.Unlock(); id := strings.TrimPrefix(strings.TrimPrefix(r.URL.Path, "/v1/payments/"), "/v1/shipments/"); o, ok := s.Orders[id]; if !ok { write(w, http.StatusNotFound, map[string]string{"error": "order_not_found"}); return }; value := o.PaymentStatus; if field == "carrier_status" { value = o.CarrierStatus }; write(w, http.StatusOK, map[string]string{"order_id": id, field: value}) }
func write(w http.ResponseWriter, status int, v any) { w.Header().Set("Content-Type", "application/json"); w.WriteHeader(status); _ = json.NewEncoder(w).Encode(v) }
