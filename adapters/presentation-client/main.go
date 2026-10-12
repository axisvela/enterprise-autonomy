package main

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/http/httptest"
	"os"
	"sync/atomic"
	"time"

	"github.com/axisrobo/LIMENORA-open/sdk/go/network"
	eidovela "github.com/axisrobo/eidovela-open/sdk/go/eidovela/v3"
	nomivela "github.com/axisrobo/nomivela-open/v2/sdk/go"
)

type config struct {
	AdminDSN       string
	NomivelaURL    string
	EidovelaURL    string
	EidovelaIssuer string
	LimenoraURL    string
	Namespace      string
	AgentRef       string
	Audience       string
	Token          string
	ReportPath     string
}

type report struct {
	Scenarios []scenarioResult `json:"scenarios"`
	Passed    bool             `json:"passed"`
}

type scenarioResult struct {
	ID       string `json:"id"`
	Desc     string `json:"description"`
	Expected string `json:"expected"`
	Actual   string `json:"actual"`
	Passed   bool   `json:"passed"`
}

func loadConfig() config {
	return config{
		AdminDSN:       env("FP1_ADMIN_DSN", "postgres://postgres:postgres@localhost:5433/postgres?sslmode=disable"),
		NomivelaURL:    env("FP1_NOMIVELA_URL", "http://127.0.0.1:1956"),
		EidovelaURL:    env("FP1_EIDOVELA_URL", "http://127.0.0.1:1966"),
		EidovelaIssuer: env("FP1_EIDOVELA_ISSUER", "http://127.0.0.1:1966"),
		LimenoraURL:    env("FP1_LIMENORA_URL", "http://127.0.0.1:1897"),
		Namespace:      env("FP1_NAMESPACE", "https://registry.fp1.test"),
		AgentRef:       env("FP1_AGENT_REF", "agent_fp1_e2e"),
		Audience:       env("FP1_AUDIENCE", "limenora"),
		Token:          env("FP1_NOMIVELA_TOKEN", "dev-token"),
		ReportPath:     env("FP1_REPORT", "fp1-value-report.json"),
	}
}

func main() {
	if os.Getenv("FP1_INIT_DB") != "" {
		admin := env("FP1_ADMIN_DSN", "postgres://postgres:postgres@localhost:5433/postgres?sslmode=disable")
		if err := resetDatabases(context.Background(), admin, []string{"fp1_nomivela", "fp1_eidovela", "fp1_limenora"}); err != nil {
			log.Fatalf("init-db: %v", err)
		}
		if err := ensureDatabaseSearchPath(context.Background(), admin, "fp1_eidovela", "eidovela, public"); err != nil {
			log.Fatalf("init-db: %v", err)
		}
		fmt.Println("fp1 databases ready")
		return
	}
	cfg := loadConfig()
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()

	rep, err := run(ctx, cfg)
	if err != nil {
		log.Fatalf("fp1 e2e: %v", err)
	}
	if err := writeReport(cfg.ReportPath, rep); err != nil {
		log.Fatalf("fp1 e2e: write report: %v", err)
	}
	if !rep.Passed {
		log.Fatalf("fp1 e2e: FAILED (%d scenarios)", len(rep.Scenarios))
	}
	fmt.Printf("fp1 e2e: PASSED (%d scenarios)\n", len(rep.Scenarios))
}

func run(ctx context.Context, cfg config) (report, error) {
	// 1. Seed the registry.
	nClient := nomivela.New(cfg.NomivelaURL, nomivela.WithToken(cfg.Token))
	ids, err := seedRegistry(ctx, nClient, cfg.Namespace, cfg.AgentRef)
	if err != nil {
		return report{}, err
	}

	// 2. Enroll with EIDOVELA and obtain a PoP token bound to a fresh key.
	_, key, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return report{}, err
	}
	eClient := eidovela.NewClient(cfg.EidovelaURL)
	challenge, err := eClient.CreateChallenge(ctx, ids.AgentID, ids.WorkloadRegistrationID)
	if err != nil {
		return report{}, fmt.Errorf("create challenge: %w", err)
	}
	instance, err := eClient.CompleteEnrollment(ctx, challenge, key, "praxovela", "wl-e2e", "sha256:e2e",
		map[string]string{"namespace": "prod"})
	if err != nil {
		return report{}, fmt.Errorf("complete enrollment: %w", err)
	}

	// 3. Build the egress: EIDOVELA token as the agent credential + both proofs.
	tokenSource := newEidovelaTokenSource(eClient, ids.AgentID, instance.InstanceID, cfg.Audience, key)
	carrier := newProofCarrier(key, cfg.EidovelaIssuer+"/v1/introspect")
	egress, err := network.NewProxyEgress(cfg.LimenoraURL, tokenSource,
		network.WithProofCarrier(carrier), network.WithCarriage(network.CarriageRequestHeader))
	if err != nil {
		return report{}, err
	}

	// 4. Upstream: an in-process server the gateway forwards to.
	var seenProofHeaders bool
	var upstreamHits int32
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&upstreamHits, 1)
		if r.Header.Get(network.DefaultResourceProofHeader) != "" ||
			r.Header.Get(network.DefaultIntrospectionProofHeader) != "" ||
			r.Header.Get("Proxy-Authorization") != "" {
			seenProofHeaders = true
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("upstream-ok"))
	}))
	defer upstream.Close()

	// 5. Run scenarios.
	var results []scenarioResult
	results = append(results, runHappyPath(ctx, egress, upstream.URL, &seenProofHeaders))
	results = append(results, runMissingProofDenied(ctx, cfg, tokenSource, upstream.URL))
	results = append(results, runReplayDenied(ctx, tokenSource, upstream.URL, key, cfg))
	results = append(results, runProviderDenied(ctx, cfg, tokenSource, eClient, ids.AgentID, key, upstream.URL, &upstreamHits))

	rep := report{Scenarios: results, Passed: true}
	for _, s := range results {
		if !s.Passed {
			rep.Passed = false
		}
	}
	return rep, nil
}

func runHappyPath(ctx context.Context, egress network.NetworkGateway, upstreamURL string, seenProofHeaders *bool) scenarioResult {
	res := scenarioResult{ID: "FP-01", Desc: "valid token + both proofs reach upstream", Expected: "200"}
	got, err := egress.Do(ctx, network.GatewayRequest{URL: upstreamURL + "/resource", Method: http.MethodGet})
	switch {
	case err != nil:
		res.Actual = "error: " + err.Error()
	case got.Status != http.StatusOK:
		res.Actual = fmt.Sprintf("status %d", got.Status)
	case *seenProofHeaders:
		res.Actual = "proof headers leaked upstream"
	case string(got.Body) != "upstream-ok":
		res.Actual = "unexpected body"
	default:
		res.Actual = "200, proofs stripped"
		res.Passed = true
	}
	return res
}

func runMissingProofDenied(ctx context.Context, cfg config, ts *eidovelaTokenSource, upstreamURL string) scenarioResult {
	res := scenarioResult{ID: "FP-02", Desc: "missing resource proof denied", Expected: "407"}
	raw, err := network.NewProxyEgress(cfg.LimenoraURL, ts, network.WithCarriage(network.CarriageRequestHeader))
	if err != nil {
		res.Actual = "build error: " + err.Error()
		return res
	}
	got, err := raw.Do(ctx, network.GatewayRequest{URL: upstreamURL + "/resource", Method: http.MethodGet})
	switch {
	case err != nil:
		res.Actual = "error: " + err.Error()
	case got.Status == http.StatusProxyAuthRequired || got.Status == http.StatusForbidden:
		res.Actual = fmt.Sprintf("status %d", got.Status)
		res.Passed = true
	default:
		res.Actual = fmt.Sprintf("status %d, want 407", got.Status)
	}
	return res
}

// runReplayDenied presents the same resource-proof jti twice; the gateway's
// replay ledger must reject the second presentation.
func runReplayDenied(ctx context.Context, ts network.AgentTokenSource, upstreamURL string, key ed25519.PrivateKey, cfg config) scenarioResult {
	res := scenarioResult{ID: "FP-05", Desc: "replayed resource-proof jti denied", Expected: "407"}
	replay := newFixedReplayCarrier(key, cfg.EidovelaIssuer+"/v1/introspect")
	egress, err := network.NewProxyEgress(cfg.LimenoraURL, ts,
		network.WithProofCarrier(replay), network.WithCarriage(network.CarriageRequestHeader))
	if err != nil {
		res.Actual = "build error: " + err.Error()
		return res
	}
	first, err := egress.Do(ctx, network.GatewayRequest{URL: upstreamURL + "/resource", Method: http.MethodGet})
	if err != nil {
		res.Actual = "first use error: " + err.Error()
		return res
	}
	if first.Status != http.StatusOK {
		res.Actual = fmt.Sprintf("first use status %d, want 200", first.Status)
		return res
	}
	second, err := egress.Do(ctx, network.GatewayRequest{URL: upstreamURL + "/resource", Method: http.MethodGet})
	if err != nil {
		res.Actual = "second use error: " + err.Error()
		return res
	}
	if second.Status == http.StatusProxyAuthRequired || second.Status == http.StatusForbidden {
		res.Actual = fmt.Sprintf("second use denied %d", second.Status)
		res.Passed = true
	} else {
		res.Actual = fmt.Sprintf("second status %d, want 407", second.Status)
	}
	return res
}

// runProviderDenied disables the agent at EIDOVELA and proves a selected agent
// route is denied with no downgrade and no upstream contact when the provider
// reports the identity inactive.
func runProviderDenied(ctx context.Context, cfg config, ts network.AgentTokenSource, eClient *eidovela.Client, agentID string, key ed25519.PrivateKey, upstreamURL string, hits *int32) scenarioResult {
	res := scenarioResult{ID: "FP-07", Desc: "provider denies a disabled agent; no downgrade, upstream untouched", Expected: "deny, 0 upstream hits"}
	before := atomic.LoadInt32(hits)
	if _, err := eClient.SetAuthenticationState(ctx, agentID, "disable", "fp1-e2e"); err != nil {
		res.Actual = "disable error: " + err.Error()
		return res
	}
	carrier := newProofCarrier(key, cfg.EidovelaIssuer+"/v1/introspect")
	egress, err := network.NewProxyEgress(cfg.LimenoraURL, ts, network.WithProofCarrier(carrier), network.WithCarriage(network.CarriageRequestHeader))
	if err != nil {
		res.Actual = "build error: " + err.Error()
		return res
	}
	got, err := egress.Do(ctx, network.GatewayRequest{URL: upstreamURL + "/denied", Method: http.MethodGet})
	if err != nil {
		res.Actual = "error: " + err.Error()
		return res
	}
	denied := got.Status == http.StatusProxyAuthRequired || got.Status == http.StatusForbidden
	after := atomic.LoadInt32(hits)
	if denied && after == before {
		res.Actual = fmt.Sprintf("denied %d, upstream hits unchanged", got.Status)
		res.Passed = true
	} else {
		res.Actual = fmt.Sprintf("status %d, upstream hits %d->%d", got.Status, before, after)
	}
	return res
}

func writeReport(path string, rep report) error {
	raw, err := json.MarshalIndent(rep, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, raw, 0o600)
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
