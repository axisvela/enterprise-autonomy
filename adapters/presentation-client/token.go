package main

import (
	"context"
	"crypto/ed25519"
	"sync"
	"time"

	"github.com/axisvela/LIMENORA-open/sdk/go/network"
	eidovela "github.com/axisrobo/eidovela-open/sdk/go/eidovela/v3"
)

// refreshSkew is how long before expiry the token is reissued.
const refreshSkew = 30 * time.Second

// eidovelaTokenSource yields the EIDOVELA-issued PoP token as the LIMENORA agent
// credential. This is the FP-1 alignment: the token presented to LIMENORA is the
// same token whose cnf.jkt binds the proof key and whose hash is the proofs' ath.
type eidovelaTokenSource struct {
	client   *eidovela.Client
	agentID  string
	instance string
	audience string
	key      ed25519.PrivateKey

	mu     sync.Mutex
	value  string
	expiry time.Time
}

var _ network.AgentTokenSource = (*eidovelaTokenSource)(nil)

func newEidovelaTokenSource(client *eidovela.Client, agentID, instance, audience string, key ed25519.PrivateKey) *eidovelaTokenSource {
	return &eidovelaTokenSource{client: client, agentID: agentID, instance: instance, audience: audience, key: key}
}

// Token returns a cached token, reissuing shortly before expiry. A failure is
// returned so the egress fails closed; there is no plaintext fallback.
func (s *eidovelaTokenSource) Token(ctx context.Context) (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.value != "" && time.Until(s.expiry) > refreshSkew {
		return s.value, nil
	}
	resp, err := s.client.Token(ctx, s.agentID, s.instance, s.audience, s.key)
	if err != nil {
		return "", err
	}
	if resp.Token == "" {
		return "", network.ErrNoAgentToken
	}
	s.value, s.expiry = resp.Token, resp.ExpiresAt
	return s.value, nil
}
