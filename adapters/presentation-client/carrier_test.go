package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"strings"
	"testing"
)

func decodeClaims(t *testing.T, jws string) map[string]any {
	t.Helper()
	parts := strings.Split(jws, ".")
	if len(parts) != 3 {
		t.Fatalf("jws has %d parts, want 3", len(parts))
	}
	raw, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		t.Fatalf("decode claims: %v", err)
	}
	var claims map[string]any
	if err := json.Unmarshal(raw, &claims); err != nil {
		t.Fatalf("unmarshal claims: %v", err)
	}
	return claims
}

func TestProofCarrierBindsBothTargetsToTheToken(t *testing.T) {
	_, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	carrier := newProofCarrier(priv, "http://localhost:1966/v1/introspect")
	token := "the-exact-token"

	hdr, err := carrier.ProofHeaders("GET", "http://127.0.0.1:9000/resource", token)
	if err != nil {
		t.Fatalf("ProofHeaders: %v", err)
	}
	resource := strings.TrimPrefix(hdr["DPoP"], "DPoP ")
	intro := strings.TrimPrefix(hdr["DPoP-Introspection"], "DPoP ")

	rc := decodeClaims(t, resource)
	ic := decodeClaims(t, intro)
	wantAth := base64.RawURLEncoding.EncodeToString(func() []byte { s := sha256.Sum256([]byte(token)); return s[:] }())

	if rc["htm"] != "GET" || rc["htu"] != "http://127.0.0.1:9000/resource" {
		t.Fatalf("resource proof htm/htu = %v/%v", rc["htm"], rc["htu"])
	}
	if ic["htm"] != "POST" || ic["htu"] != "http://localhost:1966/v1/introspect" {
		t.Fatalf("introspection proof htm/htu = %v/%v", ic["htm"], ic["htu"])
	}
	if rc["ath"] != wantAth || ic["ath"] != wantAth {
		t.Fatalf("ath mismatch: resource=%v intro=%v want=%v", rc["ath"], ic["ath"], wantAth)
	}
	if rc["jti"] == ic["jti"] {
		t.Fatal("resource and introspection proofs must use distinct jti")
	}
}
