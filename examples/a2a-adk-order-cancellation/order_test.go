package ordera2a

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	sdk "github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2asrv"
	a2aadapter "github.com/axisvela/praxo-core/adapters/a2a"
	praxoagent "github.com/axisvela/praxo-core/v2/pkg/agent"
	adkagent "google.golang.org/adk/v2/agent"
	remoteagent "google.golang.org/adk/v2/agent/remoteagent/v2"
	"google.golang.org/adk/v2/runner"
	"google.golang.org/genai"
)

func TestGoogleADKConsumesPraxoOrderAgent(t *testing.T) {
	server := newA2AServer(t, mustOrderAgent(t))
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
			output, err := runGoogleADK(t, context.Background(), server.URL, test.text)
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
	server := newA2AServer(t, failingRunner{})
	defer server.Close()

	_, err := runGoogleADK(t, context.Background(), server.URL, "Cancel order-1001")
	if err == nil || !strings.Contains(err.Error(), "order eligibility service is unavailable") {
		t.Fatalf("err = %v", err)
	}
}

func TestGoogleADKReportsPraxoTimeout(t *testing.T) {
	server := newA2AServer(t, blockingRunner{})
	defer server.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()
	_, err := runGoogleADK(t, ctx, server.URL, "Cancel order-1001")
	if err == nil || !strings.Contains(err.Error(), context.DeadlineExceeded.Error()) {
		t.Fatalf("err = %v", err)
	}
}

func mustOrderAgent(t *testing.T) *praxoagent.Agent {
	t.Helper()
	agent, err := newOrderAgent()
	if err != nil {
		t.Fatal(err)
	}
	return agent
}

func newA2AServer(t *testing.T, runner a2aadapter.Runner) *httptest.Server {
	t.Helper()
	handler := a2asrv.NewHandler(a2aadapter.Executor{Agent: runner})
	mux := http.NewServeMux()
	mux.Handle("/invoke", a2asrv.NewJSONRPCHandler(handler))

	var server *httptest.Server
	mux.Handle(a2asrv.WellKnownAgentCardPath, a2asrv.NewAgentCardHandler(a2asrv.AgentCardProducerFn(func(context.Context) (*sdk.AgentCard, error) {
		return &sdk.AgentCard{
			Name:        "order-cancellation-eligibility",
			Description: "Checks whether a shopping order is eligible for automatic cancellation.",
			SupportedInterfaces: []*sdk.AgentInterface{
				sdk.NewAgentInterface(server.URL+"/invoke", sdk.TransportProtocolJSONRPC),
			},
		}, nil
	})))
	server = httptest.NewServer(mux)
	return server
}

func runGoogleADK(t *testing.T, ctx context.Context, cardURL, prompt string) (string, error) {
	t.Helper()
	remote, err := remoteagent.NewA2A(remoteagent.A2AConfig{
		Name:              "order_cancellation_peer",
		AgentCardProvider: remoteagent.NewAgentCardProvider(cardURL),
	})
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
