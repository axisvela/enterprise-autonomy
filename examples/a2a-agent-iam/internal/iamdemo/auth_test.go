package iamdemo

import (
	"crypto/ed25519"
	"crypto/rand"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	eidovela "github.com/axisvela/eidovela-open/v3/sdk/go/eidovela/v3"
)

func TestDPoPTimeAndRequestBinding(t *testing.T) {
	pub, key, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"current", "skew-past", "skew-future", "expired", "future", "method", "path", "token", "key"} {
		t.Run(name, func(t *testing.T) {
			issued := time.Now()
			if name == "expired" {
				issued = issued.Add(-2 * time.Minute)
			}
			if name == "future" {
				issued = issued.Add(2 * time.Minute)
			}
			if name == "skew-past" {
				issued = issued.Add(-30 * time.Second)
			}
			if name == "skew-future" {
				issued = issued.Add(30 * time.Second)
			}
			proof, err := eidovela.SignDPoP(key, http.MethodPost, "http://example.test/invoke", "synthetic-token", issued)
			if err != nil {
				t.Fatal(err)
			}
			req := httptest.NewRequest(http.MethodPost, "http://example.test/invoke", nil)
			token := "synthetic-token"
			verifyKey := pub
			switch name {
			case "method":
				req.Method = http.MethodGet
			case "path":
				req.URL.Path = "/different"
			case "token":
				token = "other-synthetic-token"
			case "key":
				verifyKey, _, err = ed25519.GenerateKey(rand.Reader)
				if err != nil {
					t.Fatal(err)
				}
			}
			err = verifyDPoP(req, proof, token, verifyKey)
			if (err == nil) != (name == "current" || name == "skew-past" || name == "skew-future") {
				t.Fatalf("proof validation mismatch: case=%s err=%v", name, err)
			}
		})
	}
}

func TestGatewayTimeAndRequiredKey(t *testing.T) {
	for _, name := range []string{"current", "skew-past", "skew-future", "expired", "future", "missing-key", "blank-key", "signature", "agent", "namespace", "timestamp"} {
		t.Run(name, func(t *testing.T) {
			issued := time.Now()
			if name == "expired" {
				issued = issued.Add(-2 * time.Minute)
			}
			if name == "future" {
				issued = issued.Add(2 * time.Minute)
			}
			if name == "skew-past" {
				issued = issued.Add(-30 * time.Second)
			}
			if name == "skew-future" {
				issued = issued.Add(30 * time.Second)
			}
			secret := "synthetic-gateway-key"
			if name == "missing-key" {
				secret = ""
			}
			if name == "blank-key" {
				secret = " \t "
			}
			agentID, namespace := "synthetic-agent", "https://registry.example.test"
			if name == "agent" {
				agentID = ""
			}
			if name == "namespace" {
				namespace = ""
			}
			req := httptest.NewRequest(http.MethodPost, "http://example.test/invoke", nil)
			req.Header.Set("X-A2A-Agent-ID", agentID)
			req.Header.Set("X-A2A-Namespace", namespace)
			req.Header.Set("X-A2A-Gateway-Timestamp", fmt.Sprint(issued.Unix()))
			req.Header.Set("X-A2A-Gateway-Signature", gatewaySignature(secret, agentID, namespace, issued.Unix()))
			if name == "signature" {
				req.Header.Set("X-A2A-Gateway-Signature", "invalid-signature")
			}
			if name == "timestamp" {
				req.Header.Set("X-A2A-Gateway-Timestamp", "invalid-time")
			}
			err := verifyGateway(req, secret)
			if (err == nil) != (name == "current" || name == "skew-past" || name == "skew-future") {
				t.Fatalf("gateway validation mismatch: case=%s err=%v", name, err)
			}
		})
	}
}
