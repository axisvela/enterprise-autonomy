package ordera2a

import (
	"context"
	"crypto/subtle"
	"fmt"
	"net/http"
	"strings"

	sdk "github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2asrv"
	a2aadapter "github.com/axisvela/praxo-core/adapters/a2a"
	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

const (
	approvedOrder = "order-1001"
	deniedOrder   = "order-1002"
)

// NewOrderAgent returns the deterministic PRAXO-CORE eligibility agent.
func NewOrderAgent() (*agent.Agent, error) {
	return agent.New(agent.Options{Model: eligibilityModel{}, MaxSteps: 1})
}

// NewCard describes the A2A service and its optional bearer requirement.
func NewCard(invokeURL, token string) *sdk.AgentCard {
	card := &sdk.AgentCard{
		Name:        "order-cancellation-eligibility",
		Description: "Checks whether a shopping order is eligible for automatic cancellation.",
		SupportedInterfaces: []*sdk.AgentInterface{
			sdk.NewAgentInterface(invokeURL, sdk.TransportProtocolJSONRPC),
		},
	}
	if token != "" {
		card.SecuritySchemes = sdk.NamedSecuritySchemes{
			"bearer": sdk.HTTPAuthSecurityScheme{Scheme: "Bearer"},
		}
		card.SecurityRequirements = sdk.SecurityRequirementsOptions{
			{sdk.SecuritySchemeName("bearer"): sdk.SecuritySchemeScopes{}},
		}
	}
	return card
}

// NewMux exposes the executor over JSON-RPC and publishes its agent card.
func NewMux(runner a2aadapter.Runner, token string, card func() *sdk.AgentCard) http.Handler {
	handler := a2asrv.NewHandler(a2aadapter.Executor{Agent: runner})
	mux := http.NewServeMux()
	invoke := a2asrv.NewJSONRPCHandler(handler)
	if token == "" {
		mux.Handle("/invoke", invoke)
	} else {
		mux.Handle("/invoke", bearerAuth(token, invoke))
	}
	mux.Handle(a2asrv.WellKnownAgentCardPath, a2asrv.NewAgentCardHandler(a2asrv.AgentCardProducerFn(func(context.Context) (*sdk.AgentCard, error) {
		return card(), nil
	})))
	return mux
}

func bearerAuth(token string, next http.Handler) http.Handler {
	expected := "Bearer " + token
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if subtle.ConstantTimeCompare([]byte(r.Header.Get("Authorization")), []byte(expected)) != 1 {
			w.Header().Set("WWW-Authenticate", "Bearer")
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		next.ServeHTTP(w, r)
	})
}

type eligibilityModel struct{}

func (eligibilityModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	prompt := lastUserMessage(req.Messages)
	switch {
	case strings.Contains(prompt, approvedOrder):
		return response("approved: order-1001 can be cancelled before shipment"), nil
	case strings.Contains(prompt, deniedOrder):
		return response("denied: order-1002 has shipped; route to a human returns specialist"), nil
	default:
		return response("denied: order identifier is not eligible for automated cancellation"), nil
	}
}

func response(content string) model.Response {
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: content}}
}

func lastUserMessage(messages []model.Message) string {
	for i := len(messages) - 1; i >= 0; i-- {
		if messages[i].Role == model.RoleUser {
			return messages[i].Content
		}
	}
	return ""
}

type failingRunner struct{}

func (failingRunner) Run(context.Context, agent.Session, string) (*agent.Result, error) {
	return nil, fmt.Errorf("order eligibility service is unavailable")
}

type blockingRunner struct{}

func (blockingRunner) Run(ctx context.Context, _ agent.Session, _ string) (*agent.Result, error) {
	<-ctx.Done()
	return nil, ctx.Err()
}
