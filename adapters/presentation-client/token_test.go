package main

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	eidovela "github.com/axisvela/eidovela-open/v3/sdk/go/eidovela/v3"
)

func TestEIDOVELATokenSourceReturnsIssuedTokenAndCaches(t *testing.T) {
	var calls int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&calls, 1)
		_ = json.NewEncoder(w).Encode(map[string]any{
			"token":     "eid-token-1",
			"expiresAt": time.Now().Add(time.Hour).UTC().Format(time.RFC3339),
		})
	}))
	defer srv.Close()

	_, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	src := newEidovelaTokenSource(eidovela.NewClient(srv.URL), "agent-1", "inst-1", "limenora", priv)

	got, err := src.Token(context.Background())
	if err != nil {
		t.Fatalf("Token: %v", err)
	}
	if got != "eid-token-1" {
		t.Fatalf("token = %q, want eid-token-1", got)
	}
	if _, err := src.Token(context.Background()); err != nil {
		t.Fatalf("second Token: %v", err)
	}
	if n := atomic.LoadInt32(&calls); n != 1 {
		t.Fatalf("issuer called %d times, want 1 (cached)", n)
	}
}
