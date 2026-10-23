package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"

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
	flag.Parse()

	cfg := remoteagent.A2AConfig{
		Name:              "order_cancellation_peer",
		AgentCardProvider: remoteagent.NewAgentCardProvider(*cardURL),
	}
	if *token != "" {
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
