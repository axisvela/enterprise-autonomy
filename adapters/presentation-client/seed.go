package main

import (
	"context"
	"fmt"

	nomivela "github.com/axisvela/nomivela-open/v3/sdk/go"
)

// seededIDs are the registry identifiers EIDOVELA enrollment needs.
type seededIDs struct {
	AgentID                string
	WorkloadRegistrationID string
}

// seedRegistry creates the NOMIVELA records EIDOVELA's registry-consumer path
// requires, in dependency order. It is idempotent-friendly: duplicate creations
// return an API error, so callers run it against a fresh database.
func seedRegistry(ctx context.Context, c *nomivela.Client, namespace, agentRef string) (seededIDs, error) {
	mut := nomivela.Mutation{}
	if _, err := c.CreateNamespace(ctx, namespace, "root:fp1", mut); err != nil {
		return seededIDs{}, fmt.Errorf("create namespace: %w", err)
	}
	if _, err := c.CreateAgent(ctx, nomivela.Agent{
		AgentRef: agentRef, Name: "FP-1 E2E Agent", Purpose: "Federated presentation E2E",
		SponsorRef: "org:fp1", OwnerRef: "user:fp1", RiskClass: "low", AgentClass: "service",
	}, mut); err != nil {
		return seededIDs{}, fmt.Errorf("create agent: %w", err)
	}
	for _, state := range []string{"registered", "approved", "active"} {
		if _, err := c.TransitionAgent(ctx, agentRef, state, mut); err != nil {
			return seededIDs{}, fmt.Errorf("transition agent %s: %w", state, err)
		}
	}
	identity, err := c.AllocateIdentityWithType(ctx, namespace, agentRef, "interactive", "user:fp1", mut)
	if err != nil {
		return seededIDs{}, fmt.Errorf("allocate identity: %w", err)
	}
	if _, err := c.BindIdentity(ctx, namespace, identity.AgentID, "root:fp1", "organization", mut); err != nil {
		return seededIDs{}, fmt.Errorf("bind identity: %w", err)
	}
	if _, err := c.TransitionIdentity(ctx, namespace, identity.AgentID, "active", mut); err != nil {
		return seededIDs{}, fmt.Errorf("activate identity: %w", err)
	}
	workload, err := c.CreateWorkloadRegistration(ctx, nomivela.WorkloadRegistration{
		Namespace: namespace, Platform: "kubernetes",
		Selector:            map[string]string{"namespace": "prod"},
		TrustDomain:         "fp1.test",
		AllowedProofMethods: []string{"private_key_jwt"},
	}, mut)
	if err != nil {
		return seededIDs{}, fmt.Errorf("create workload: %w", err)
	}
	return seededIDs{AgentID: identity.AgentID, WorkloadRegistrationID: workload.WorkloadRegistrationID}, nil
}
