package main

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"fmt"
	"log"
	"os"
	"time"

	eidovela "github.com/axisvela/eidovela-open/v3/sdk/go/eidovela/v3"
	nomivela "github.com/axisvela/nomivela-open/v3/sdk/go"
)

const (
	defaultNamespace = "https://registry.a2a-iam.test"
	defaultAudience  = "praxo-a2a"
	defaultAgentRef  = "agent_google_adk_checkout"
)

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	nomivelaURL := env("A2A_IAM_NOMIVELA_URL", "http://127.0.0.1:1956")
	eidovelaURL := env("A2A_IAM_EIDOVELA_URL", "http://127.0.0.1:1966")
	namespace := env("A2A_IAM_NAMESPACE", defaultNamespace)
	audience := env("A2A_IAM_AUDIENCE", defaultAudience)
	tokenValue := env("A2A_IAM_NOMIVELA_TOKEN", "dev-token")

	client := nomivela.New(nomivelaURL, nomivela.WithActor("google-adk-smoke"), nomivela.WithToken(tokenValue))
	mutation := nomivela.Mutation{Reason: "A2A Agent IAM local smoke"}
	if _, err := client.CreateNamespace(ctx, namespace, "root:demo", mutation); err != nil {
		log.Fatalf("create namespace: %v", err)
	}
	if _, err := client.CreateAgent(ctx, nomivela.Agent{
		AgentRef: defaultAgentRef, Name: "Google ADK checkout agent", Purpose: "Cancel eligible shopping orders",
		SponsorRef: "org:demo", OwnerRef: "user:demo", RiskClass: "low", AgentClass: "service",
	}, mutation); err != nil {
		log.Fatalf("create agent: %v", err)
	}
	for _, state := range []string{"registered", "approved", "active"} {
		if _, err := client.TransitionAgent(ctx, defaultAgentRef, state, mutation); err != nil {
			log.Fatalf("transition agent %s: %v", state, err)
		}
	}
	identity, err := client.AllocateIdentityWithType(ctx, namespace, defaultAgentRef, "autonomous", "", mutation)
	if err != nil {
		log.Fatalf("allocate identity: %v", err)
	}
	if _, err := client.BindIdentity(ctx, namespace, identity.AgentID, "root:demo", "organization", mutation); err != nil {
		log.Fatalf("bind identity: %v", err)
	}
	if _, err := client.TransitionIdentity(ctx, namespace, identity.AgentID, "active", mutation); err != nil {
		log.Fatalf("activate identity: %v", err)
	}
	workload, err := client.CreateWorkloadRegistration(ctx, nomivela.WorkloadRegistration{
		Namespace: namespace, Platform: "local", Selector: map[string]string{"app": "google-adk"},
		TrustDomain: "demo.test", AllowedProofMethods: []string{"private_key_jwt"},
	}, mutation)
	if err != nil {
		log.Fatalf("create workload: %v", err)
	}

	_, key, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		log.Fatal(err)
	}
	eidovelaClient := eidovela.NewClient(eidovelaURL)
	challenge, err := eidovelaClient.CreateChallenge(ctx, identity.AgentID, workload.WorkloadRegistrationID)
	if err != nil {
		log.Fatalf("create challenge: %v", err)
	}
	instance, err := eidovelaClient.CompleteEnrollment(ctx, challenge, key, "google-adk", "google-adk-1", "sha256:smoke", map[string]string{"app": "google-adk"})
	if err != nil {
		log.Fatalf("complete enrollment: %v", err)
	}
	token, err := eidovelaClient.Token(ctx, identity.AgentID, instance.InstanceID, audience, key)
	if err != nil {
		log.Fatalf("issue token: %v", err)
	}
	principal, err := eidovela.Verify(nil, token.Token, audience, key.Public().(ed25519.PublicKey))
	if err != nil {
		log.Fatalf("verify token: %v", err)
	}
	fmt.Printf("agent=%s instance=%s namespace=%s audience=%s expires=%s token_bytes=%d\n",
		principal.AgentID, principal.InstanceID, principal.Namespace, principal.Audience, token.ExpiresAt.UTC().Format(time.RFC3339), len(token.Token))
}

func env(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
