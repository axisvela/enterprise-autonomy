package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"

	sdk "github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2aclient"
	adkagent "google.golang.org/adk/v2/agent"
	remoteagent "google.golang.org/adk/v2/agent/remoteagent/v2"
	"google.golang.org/adk/v2/auth"
	"google.golang.org/adk/v2/runner"
	"google.golang.org/genai"
)

func main() {
	cardURL := flag.String("card", "http://127.0.0.1:8091", "A2A agent card URL")
	prompt := flag.String("prompt", "Cancel order-1001", "user request")
	token := flag.String("token", os.Getenv("PRAXO_A2A_TOKEN"), "bearer token")
	agentCredential := flag.String("agent-credential", os.Getenv("LIMENORA_AGENT_CREDENTIAL"), "LIMENORA agent credential")
	flag.Parse()

	cfg := remoteagent.A2AConfig{
		Name:              "order_cancellation_peer",
		AgentCardProvider: remoteagent.NewAgentCardProvider(*cardURL),
	}
	if *agentCredential != "" {
		client := &http.Client{Transport: &gatewayTransport{credential: *agentCredential}}
		card, err := fetchCard(*cardURL+"/.well-known/agent-card.json", client)
		if err != nil {
			log.Fatal(err)
		}
		factory := a2aclient.NewFactory(a2aclient.WithJSONRPCTransport(client))
		cfg.AgentCard = card
		cfg.AgentCardProvider = nil
		cfg.ClientProvider = remoteagent.NewA2AClientProvider(factory)
	}
	if *token != "" && *agentCredential == "" {
		cfg.Auth = auth.StaticToken(*token)
	}
	remote, err := remoteagent.NewA2A(cfg)
	if err != nil {
		log.Fatal(err)
	}
	adkRunner, err := runner.NewInMemory("shopping_checkout", remote)
	if err != nil {
		log.Fatal(err)
	}
	var output strings.Builder
	for event, err := range adkRunner.Run(context.Background(), "buyer-42", "checkout-77", genai.NewContentFromText(*prompt, genai.RoleUser), adkagent.RunConfig{}) {
		if err != nil {
			log.Fatal(err)
		}
		if event.ErrorMessage != "" {
			log.Fatalf("remote agent: %s", event.ErrorMessage)
		}
		if event.Content == nil {
			continue
		}
		for _, part := range event.Content.Parts {
			output.WriteString(part.Text)
		}
	}
	fmt.Println(output.String())
}

type gatewayTransport struct{ credential string }

func (t *gatewayTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	clone := req.Clone(req.Context())
	clone.Header.Set("X-LIMENORA-Agent-Credential", t.credential)
	return http.DefaultTransport.RoundTrip(clone)
}

func fetchCard(url string, client *http.Client) (*sdk.AgentCard, error) {
	response, err := client.Get(url)
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("agent card: HTTP %d", response.StatusCode)
	}
	var card sdk.AgentCard
	if err := json.NewDecoder(response.Body).Decode(&card); err != nil {
		return nil, err
	}
	return &card, nil
}
