package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestGatewayTransportAddsCredential(t *testing.T) {
	var got string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		got = r.Header.Get("X-LIMENORA-Agent-Credential")
		w.WriteHeader(http.StatusOK)
	}))
	defer srv.Close()

	client := &http.Client{Transport: &gatewayTransport{credential: "demo-credential"}}
	if _, err := client.Get(srv.URL); err != nil {
		t.Fatal(err)
	}
	if got != "demo-credential" {
		t.Fatalf("credential = %q", got)
	}
}

func TestFetchCard(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"name":"order-cancellation-eligibility","supportedInterfaces":[{"url":"http://example.test/invoke","protocolBinding":"JSONRPC"}]}`))
	}))
	defer srv.Close()

	card, err := fetchCard(srv.URL, srv.Client())
	if err != nil {
		t.Fatal(err)
	}
	if card.Name != "order-cancellation-eligibility" || len(card.SupportedInterfaces) != 1 ||
		card.SupportedInterfaces[0].URL != "http://example.test/invoke" {
		t.Fatalf("card = %+v", card)
	}
}

func TestFetchCardRejectsNon200(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		http.Error(w, "forbidden", http.StatusForbidden)
	}))
	defer srv.Close()

	if _, err := fetchCard(srv.URL, srv.Client()); err == nil {
		t.Fatal("expected a non-200 error")
	}
}
