package main

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"time"

	sdk "github.com/a2aproject/a2a-go/v2/a2a"
	eidovela "github.com/axisvela/eidovela-open/v3/sdk/go/eidovela/v3"
	"github.com/axisvela/enterprise-autonomy/examples/a2a-agent-iam/internal/iamdemo"
)

const (
	defaultNamespace = "https://registry.a2a-iam.test"
	defaultAudience  = "praxo-a2a"
)

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	addr := flag.String("addr", "127.0.0.1:18086", "PRAXO A2A listen address")
	prompt := flag.String("prompt", "Can order-1001 be cancelled automatically?", "Google ADK prompt")
	agentID := flag.String("agent-id", os.Getenv("A2A_IAM_AGENT_ID"), "NOMIVELA agent ID")
	workloadID := flag.String("workload-id", os.Getenv("A2A_IAM_WORKLOAD_ID"), "NOMIVELA workload registration ID")
	assertion := flag.String("assertion", os.Getenv("A2A_IAM_WORKLOAD_ASSERTION"), "AEGIVELA workload assertion")
	flag.Parse()

	if *agentID == "" || *workloadID == "" || *assertion == "" {
		log.Fatal("agent-id, workload-id, and assertion are required")
	}

	nomivelaURL := env("A2A_IAM_NOMIVELA_URL", "http://127.0.0.1:1956")
	eidovelaURL := env("A2A_IAM_EIDOVELA_URL", "http://127.0.0.1:1966")
	aegivelaURL := env("A2A_IAM_AEGIVELA_URL", "http://127.0.0.1:1886")
	audience := env("A2A_IAM_AUDIENCE", defaultAudience)

	_, key, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		log.Fatal(err)
	}
	eidovelaClient := eidovela.NewClient(eidovelaURL)
	challenge, err := eidovelaClient.CreateChallenge(ctx, *agentID, *workloadID)
	if err != nil {
		log.Fatalf("create challenge: %v", err)
	}
	instance, err := eidovelaClient.CompleteEnrollment(ctx, challenge, key, "google-adk", "google-adk-live", "sha256:live", map[string]string{"app": "google-adk"})
	if err != nil {
		log.Fatalf("complete enrollment: %v", err)
	}
	token, err := eidovelaClient.Token(ctx, *agentID, instance.InstanceID, audience, key)
	if err != nil {
		log.Fatalf("issue token: %v", err)
	}
	principal, err := eidovela.Verify(nil, token.Token, audience, key.Public().(ed25519.PublicKey))
	if err != nil {
		log.Fatalf("verify token: %v", err)
	}
	if principal.AgentID != *agentID {
		log.Fatalf("token agent mismatch: %s", principal.AgentID)
	}
	fmt.Printf("enrolled agent=%s instance=%s token_bytes=%d\n", principal.AgentID, principal.InstanceID, len(token.Token))

	agent, err := iamdemo.NewOrderAgent()
	if err != nil {
		log.Fatal(err)
	}
	listener, err := net.Listen("tcp", *addr)
	if err != nil {
		log.Fatal(err)
	}
	baseURL := "http://" + listener.Addr().String()
	mux := iamdemo.NewLiveMux(agent, eidovelaURL, nomivelaURL, aegivelaURL, *assertion, func() *sdk.AgentCard {
		return iamdemo.NewCard(baseURL + "/invoke")
	})
	server := &http.Server{Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	go func() {
		if err := server.Serve(listener); err != nil && err != http.ErrServerClosed {
			log.Printf("a2a server: %v", err)
		}
	}()
	defer func() {
		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer shutdownCancel()
		_ = server.Shutdown(shutdownCtx)
	}()

	output, err := iamdemo.RunGoogleADK(ctx, baseURL, *prompt, token.Token, key)
	if err != nil {
		log.Fatalf("google adk run: %v", err)
	}
	if strings.TrimSpace(output) == "" {
		log.Fatal("google adk returned empty output")
	}
	fmt.Printf("google_adk=%s\n", strings.TrimSpace(output))
}

func env(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
