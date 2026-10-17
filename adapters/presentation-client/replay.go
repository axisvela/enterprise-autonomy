package main

import (
	"crypto/ed25519"

	"github.com/axisvela/LIMENORA-open/sdk/go/network"
)

// fixedReplayCarrier reuses one resource-proof payload across calls so the
// gateway's replay ledger must reject the second presentation.
type fixedReplayCarrier struct {
	inner *proofCarrier
	once  string
}

var _ network.ProofCarrier = (*fixedReplayCarrier)(nil)

func newFixedReplayCarrier(key ed25519.PrivateKey, introspectionHtu string) *fixedReplayCarrier {
	return &fixedReplayCarrier{inner: newProofCarrier(key, introspectionHtu)}
}

func (c *fixedReplayCarrier) ProofHeaders(method, target, token string) (map[string]string, error) {
	hdr, err := c.inner.ProofHeaders(method, target, token)
	if err != nil {
		return nil, err
	}
	if c.once != "" {
		hdr[network.DefaultResourceProofHeader] = c.once
	} else {
		c.once = hdr[network.DefaultResourceProofHeader]
	}
	return hdr, nil
}
