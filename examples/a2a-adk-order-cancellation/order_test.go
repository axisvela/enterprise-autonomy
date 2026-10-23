package ordera2a

import (
	"context"
	"fmt"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	sdk "github.com/a2aproject/a2a-go/v2/a2a"
	a2aadapter "github.com/axisvela/praxo-core/adapters/a2a"
	praxoagent "github.com/axisvela/praxo-core/v2/pkg/agent"
	adkagent "google.golang.org/adk/v2/agent"
	remoteagent "google.golang.org/adk/v2/agent/remoteagent/v2"
	"google.golang.org/adk/v2/auth"
	"google.golang.org/adk/v2/runner"
	"google.golang.org/genai"
)

func TestGoogleADKConsumesPraxoOrderAgent(t *testing.T) {
	server := newA2AServer(t, mustOrderAgent(t), "")
	defer server.Close()

	tests := []struct {
		name string
		text string
		want string
	}{
		{name: "approved cancellation", text: "Cancel order-1001", want: "approved: order-1001"},
		{name: "human escalation", text: "Cancel order-1002", want: "denied: order-1002 has shipped"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			output, err := runGoogleADK(t, context.Background(), server.URL, test.text, "")
			if err != nil {
				t.Fatal(err)
			}
			if !strings.Contains(output, test.want) {
				t.Fatalf("output = %q, want substring %q", output, test.want)
			}
		})
	}
}

func TestGoogleADKReportsPraxoFailure(t *testing.T) {
	server := newA2AServer(t, failingRunner{}, "")
	defer server.Close()

	_, err := runGoogleADK(t, context.Background(), server.URL, "Cancel order-1001", "")
	if err == nil || !strings.Contains(err.Error(), "order eligibility service is unavailable") {
		t.Fatalf("err = %v", err)
	}
}

func TestGoogleADKReportsPraxoTimeout(t *testing.T) {
	server := newA2AServer(t, blockingRunner{}, "")
	defer server.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()
	_, err := runGoogleADK(t, ctx, server.URL, "Cancel order-1001", "")
	if err == nil || !strings.Contains(err.Error(), context.DeadlineExceeded.Error()) {
		t.Fatalf("err = %v", err)
	}
}

func TestGoogleADKAuthenticatesPraxoPeer(t *testing.T) {
	const token = "test-order-token"
	server := newA2AServer(t, mustOrderAgent(t), token)
	defer server.Close()

	output, err := runGoogleADK(t, context.Background(), server.URL, "Cancel order-1001", token)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(output, "approved: order-1001") {
		t.Fatalf("output = %q", output)
	}
	for _, badToken := range []string{"", "wrong-token"} {
		_, err := runGoogleADK(t, context.Background(), server.URL, "Cancel order-1001", badToken)
		if err == nil || !isUnauthorized(err) {
			t.Fatalf("token %q err = %v", badToken, err)
		}
	}
}

func isUnauthorized(err error) bool {
	text := strings.ToLower(err.Error())
	return strings.Contains(text, "401") || strings.Contains(text, "unauthorized")
}

func mustOrderAgent(t *testing.T) *praxoagent.Agent {
	t.Helper()
	agent, err := NewOrderAgent()
	if err != nil {
		t.Fatal(err)
	}
	return agent
}

func newA2AServer(t *testing.T, runner a2aadapter.Runner, token string) *httptest.Server {
	t.Helper()
	var server *httptest.Server
	server = httptest.NewServer(NewMux(runner, token, func() *sdk.AgentCard {
		return NewCard(server.URL+"/invoke", token)
	}))
	return server
}

func runGoogleADK(t *testing.T, ctx context.Context, cardURL, prompt, token string) (string, error) {
	t.Helper()
	cfg := remoteagent.A2AConfig{
		Name:              "order_cancellation_peer",
		AgentCardProvider: remoteagent.NewAgentCardProvider(cardURL),
	}
	if token != "" {
		cfg.Auth = auth.StaticToken(token)
	}
	remote, err := remoteagent.NewA2A(cfg)
	if err != nil {
		return "", err
	}
	adkRunner, err := runner.NewInMemory("shopping_checkout", remote)
	if err != nil {
		return "", err
	}
	var output strings.Builder
	for event, err := range adkRunner.Run(ctx, "buyer-42", "checkout-77", genai.NewContentFromText(prompt, genai.RoleUser), adkagent.RunConfig{}) {
		if err != nil {
			return "", err
		}
		if event.ErrorMessage != "" {
			return "", fmt.Errorf("google adk remote agent: %s", event.ErrorMessage)
		}
		if event.Content == nil {
			continue
		}
		for _, part := range event.Content.Parts {
			output.WriteString(part.Text)
		}
	}
	return output.String(), nil
}
