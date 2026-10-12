package main

import (
	"crypto/ed25519"
	"fmt"
	"time"

	"github.com/axisrobo/LIMENORA-open/sdk/go/network"
	eidovela "github.com/axisrobo/eidovela-open/sdk/go/eidovela/v3"
)

// proofCarrier implements network.ProofCarrier for FP-1: it signs a resource
// proof bound to (method, target) and an introspection proof bound to the
// EIDOVELA introspection endpoint, both over the exact presented token and with
// the same token-bound key. Header/scheme names mirror the gateway GATEWAY_*
// profile (defaults used here).
type proofCarrier struct {
	key              ed25519.PrivateKey
	introspectionHtu string
}

var _ network.ProofCarrier = (*proofCarrier)(nil)

func newProofCarrier(key ed25519.PrivateKey, introspectionHtu string) *proofCarrier {
	return &proofCarrier{key: key, introspectionHtu: introspectionHtu}
}

// ProofHeaders returns the resource and introspection proof headers. A signing
// failure is returned so the request fails closed. The private key never leaves
// the process.
func (c *proofCarrier) ProofHeaders(method, target, token string) (map[string]string, error) {
	resource, err := eidovela.SignDPoP(c.key, method, target, token, time.Now())
	if err != nil {
		return nil, fmt.Errorf("presentation: resource proof: %w", err)
	}
	introspection, err := eidovela.SignDPoP(c.key, "POST", c.introspectionHtu, token, time.Now())
	if err != nil {
		return nil, fmt.Errorf("presentation: introspection proof: %w", err)
	}
	return map[string]string{
		network.DefaultResourceProofHeader:      network.DefaultResourceProofScheme + " " + resource,
		network.DefaultIntrospectionProofHeader: network.DefaultIntrospectionProofScheme + " " + introspection,
	}, nil
}
