package iamdemo

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	sdk "github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2aclient"
	"github.com/a2aproject/a2a-go/v2/a2asrv"
	eidovela "github.com/axisvela/eidovela-open/v3/sdk/go/eidovela/v3"
	nomivela "github.com/axisvela/nomivela-open/v3/sdk/go"
	a2aadapter "github.com/axisvela/praxo-core/adapters/a2a"
	praxoagent "github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	adkagent "google.golang.org/adk/v2/agent"
	remoteagent "google.golang.org/adk/v2/agent/remoteagent/v2"
	"google.golang.org/adk/v2/runner"
	"google.golang.org/genai"
)

type Stack struct {
	Nomivela *fakeNOMIVELA
	Eidovela *fakeEIDOVELA
	Aegivela *fakeAEGIVELA
}

func NewStack() *Stack {
	return &Stack{
		Nomivela: newFakeNOMIVELA(),
		Eidovela: newFakeEIDOVELA(),
		Aegivela: newFakeAEGIVELA(),
	}
}

func (s *Stack) Close() {
	s.Nomivela.Close()
	s.Eidovela.Close()
	s.Aegivela.Close()
}

func (s *Stack) RegisterGoogleADKAgent(ctx context.Context) (string, string, error) {
	client := nomivela.New(s.Nomivela.URL(), nomivela.WithActor("google-adk-checkout"))
	mutation := nomivela.Mutation{Reason: "A2A Agent IAM demo"}
	if _, err := client.CreateNamespace(ctx, demoNamespace, demoRoot, mutation); err != nil {
		return "", "", err
	}
	if _, err := client.CreateAgent(ctx, nomivela.Agent{
		AgentRef: demoAgentRef, Name: "Google ADK checkout agent", Purpose: "Cancel eligible shopping orders",
		SponsorRef: "org:demo", OwnerRef: "user:demo", RiskClass: "low", AgentClass: "service",
	}, mutation); err != nil {
		return "", "", err
	}
	for _, state := range []string{"registered", "approved", "active"} {
		if _, err := client.TransitionAgent(ctx, demoAgentRef, state, mutation); err != nil {
			return "", "", err
		}
	}
	identity, err := client.AllocateIdentityWithType(ctx, demoNamespace, demoAgentRef, "autonomous", "", mutation)
	if err != nil {
		return "", "", err
	}
	if _, err := client.BindIdentity(ctx, demoNamespace, identity.AgentID, demoRoot, "organization", mutation); err != nil {
		return "", "", err
	}
	if _, err := client.TransitionIdentity(ctx, demoNamespace, identity.AgentID, "active", mutation); err != nil {
		return "", "", err
	}
	workload, err := client.CreateWorkloadRegistration(ctx, nomivela.WorkloadRegistration{
		Namespace: demoNamespace, Platform: "local", Selector: map[string]string{"app": "google-adk"},
		TrustDomain: "demo.test", AllowedProofMethods: []string{"private_key_jwt"},
	}, mutation)
	if err != nil {
		return "", "", err
	}
	return identity.AgentID, workload.WorkloadRegistrationID, nil
}

func (s *Stack) Enroll(ctx context.Context, agentID, workloadID string) (string, ed25519.PrivateKey, error) {
	_, key, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return "", nil, err
	}
	client := eidovela.NewClient(s.Eidovela.URL())
	challenge, err := client.CreateChallenge(ctx, agentID, workloadID)
	if err != nil {
		return "", nil, err
	}
	instance, err := client.CompleteEnrollment(ctx, challenge, key, "google-adk", "workload-instance-1", "sha256:demo", map[string]string{"app": "google-adk"})
	if err != nil {
		return "", nil, err
	}
	token, err := client.Token(ctx, agentID, instance.InstanceID, demoAudience, key)
	if err != nil {
		return "", nil, err
	}
	return token.Token, key, nil
}

func NewDirectServer(t *testing.T, stack *Stack) *httptest.Server {
	t.Helper()
	agent := mustOrderAgent(t)
	auth := func(r *http.Request) (int, error) {
		body := readAndRestore(r)
		id, err := verifyIdentity(r.Context(), r, body, stack.Eidovela.URL(), stack.Nomivela.URL())
		if err != nil {
			return http.StatusUnauthorized, err
		}
		if err := authorize(r.Context(), stack.Aegivela.URL(), id, orderRef(body)); err != nil {
			return http.StatusForbidden, err
		}
		return http.StatusOK, nil
	}
	var server *httptest.Server
	server = httptest.NewServer(newPraxoMux(agent, auth, func() *sdk.AgentCard {
		return NewCard(server.URL + "/invoke")
	}))
	return server
}

func NewGateway(t *testing.T, stack *Stack, secret string) (*httptest.Server, *int32) {
	t.Helper()
	agent := mustOrderAgent(t)
	var hits int32
	var gatewayURL string
	praxo := httptest.NewServer(newPraxoMux(agent, func(r *http.Request) (int, error) {
		if err := verifyGateway(r, secret); err != nil {
			return http.StatusUnauthorized, err
		}
		return http.StatusOK, nil
	}, func() *sdk.AgentCard {
		return NewCard(gatewayURL + "/invoke")
	}))
	gateway := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == a2asrv.WellKnownAgentCardPath {
			proxyTo(w, r, praxo.URL, nil)
			return
		}
		if r.URL.Path != "/invoke" {
			http.NotFound(w, r)
			return
		}
		body := readAndRestore(r)
		id, err := verifyIdentity(r.Context(), r, body, stack.Eidovela.URL(), stack.Nomivela.URL())
		if err != nil {
			http.Error(w, err.Error(), http.StatusUnauthorized)
			return
		}
		if err := authorize(r.Context(), stack.Aegivela.URL(), id, orderRef(body)); err != nil {
			http.Error(w, err.Error(), http.StatusForbidden)
			return
		}
		atomic.AddInt32(&hits, 1)
		now := time.Now().Unix()
		headers := map[string]string{
			"X-A2A-Agent-ID":          id.Registry.Identity.AgentID,
			"X-A2A-Namespace":         id.Registry.Namespace.Namespace,
			"X-A2A-Instance-ID":       id.Principal.InstanceID,
			"X-A2A-Gateway-Timestamp": fmt.Sprint(now),
			"X-A2A-Gateway-Signature": gatewaySignature(secret, id.Registry.Identity.AgentID, id.Registry.Namespace.Namespace, now),
		}
		proxyTo(w, r, praxo.URL, headers)
	}))
	gatewayURL = gateway.URL
	return gateway, &hits
}

func proxyTo(w http.ResponseWriter, r *http.Request, target string, extra map[string]string) {
	body := readAndRestore(r)
	req, err := http.NewRequestWithContext(r.Context(), r.Method, target+r.URL.Path, bytes.NewReader(body))
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	for key, values := range r.Header {
		if key == "Authorization" || key == "Dpop" || key == "X-Agent-Public-Key" {
			continue
		}
		for _, value := range values {
			req.Header.Add(key, value)
		}
	}
	for key, value := range extra {
		req.Header.Set(key, value)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()
	for key, values := range resp.Header {
		for _, value := range values {
			w.Header().Add(key, value)
		}
	}
	w.WriteHeader(resp.StatusCode)
	_, _ = io.Copy(w, resp.Body)
}

func newPraxoMux(runner a2aadapter.Runner, auth func(*http.Request) (int, error), card func() *sdk.AgentCard) http.Handler {
	handler := a2asrv.NewHandler(a2aadapter.Executor{Agent: runner})
	invoke := a2asrv.NewJSONRPCHandler(handler)
	mux := http.NewServeMux()
	mux.Handle("/invoke", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if status, err := auth(r); err != nil {
			http.Error(w, err.Error(), status)
			return
		}
		invoke.ServeHTTP(w, r)
	}))
	mux.Handle(a2asrv.WellKnownAgentCardPath, a2asrv.NewAgentCardHandler(a2asrv.AgentCardProducerFn(func(context.Context) (*sdk.AgentCard, error) {
		return card(), nil
	})))
	return mux
}

func readAndRestore(r *http.Request) []byte {
	body, _ := io.ReadAll(r.Body)
	r.Body = io.NopCloser(bytes.NewReader(body))
	return body
}

func RunGoogleADK(ctx context.Context, baseURL, prompt, token string, key ed25519.PrivateKey) (string, error) {
	card := NewCard(baseURL + "/invoke")
	httpClient := &http.Client{Transport: authTransport{token: token, key: key}}
	factory := a2aclient.NewFactory(a2aclient.WithJSONRPCTransport(httpClient))
	remote, err := remoteagent.NewA2A(remoteagent.A2AConfig{
		Name: "order_cancellation_peer", AgentCard: card,
		ClientProvider: remoteagent.NewA2AClientProvider(factory),
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
			return "", fmt.Errorf("%s", event.ErrorMessage)
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

type authTransport struct {
	token string
	key   ed25519.PrivateKey
}

func (t authTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	clone := req.Clone(req.Context())
	proof, err := eidovela.SignDPoP(t.key, req.Method, req.URL.String(), t.token, time.Now())
	if err != nil {
		return nil, err
	}
	clone.Header.Set("Authorization", "Bearer "+t.token)
	clone.Header.Set("DPoP", proof)
	clone.Header.Set("X-Agent-Public-Key", base64.RawURLEncoding.EncodeToString(t.key.Public().(ed25519.PublicKey)))
	return http.DefaultTransport.RoundTrip(clone)
}

func NewCard(invokeURL string) *sdk.AgentCard {
	return &sdk.AgentCard{
		Name:        "order-cancellation-eligibility",
		Description: "Checks whether a shopping order is eligible for automatic cancellation.",
		SupportedInterfaces: []*sdk.AgentInterface{
			sdk.NewAgentInterface(invokeURL, sdk.TransportProtocolJSONRPC),
		},
	}
}

func mustOrderAgent(t *testing.T) *praxoagent.Agent {
	t.Helper()
	agent, err := praxoagent.New(praxoagent.Options{Model: orderModel{}, MaxSteps: 1})
	if err != nil {
		t.Fatal(err)
	}
	return agent
}

type orderModel struct{}

func (orderModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	prompt := lastUser(req.Messages)
	content := "denied: order identifier is not eligible for automated cancellation"
	switch {
	case strings.Contains(prompt, "order-1001"):
		content = "approved: order-1001 can be cancelled before shipment"
	case strings.Contains(prompt, "order-1002"):
		content = "denied: order-1002 has shipped; route to a human returns specialist"
	}
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: content}}, nil
}

func lastUser(messages []model.Message) string {
	for i := len(messages) - 1; i >= 0; i-- {
		if messages[i].Role == model.RoleUser {
			return messages[i].Content
		}
	}
	return ""
}
