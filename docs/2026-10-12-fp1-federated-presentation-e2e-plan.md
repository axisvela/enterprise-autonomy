# FP-1 Federated Presentation E2E Implementation Plan

> **Status (2026-10-13):** Parts A/B implemented and exercised against real
> NOMIVELA/EIDOVELA/LIMENORA binaries (round 1 — see
> `PRAXOVELA-EE/docs/assessments/2026-10-13-ecosystem-integration-e2e-report.md`).
> Part C (PRAXOVELA production token source) is wired
> (`AXON_LIMENORA_TOKEN_SOURCE=eidovela`). The remaining negatives (lifecycle
> denial, outage, confinement, multi-replica replay, process-level federated
> CONNECT) are tracked as LIMENORA Wave 12
> (`LIMENORA/docs/superpowers/plans/2026-10-13-e2e-round2-exit-gates.md`).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement the plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a public, reproducible FP-1 federated-presentation end-to-end example (`enterprise-autonomy`) plus the production PRAXOVELA `AgentTokenSource` that presents the EIDOVELA-issued token as the LIMENORA agent credential.

**Architecture:** An SDK-only Go client adapter (`adapters/presentation-client`) drives three real core binaries (`nomivela`, `eidovelad`, `limenora` server-gateway) against PostgreSQL. The client enrolls with EIDOVELA, presents the EIDOVELA token as the LIMENORA agent credential, and attaches two DPoP proofs (resource + introspection). A separate PRAXOVELA change adds the same token source to the production egress.

**Tech Stack:** Go 1.25, `nomivela-open/v2/sdk/go`, `eidovela-open/sdk/go/eidovela/v3`, `LIMENORA-open/sdk/go/network`, PowerShell 5.1, PostgreSQL.

**Spec:** `docs/2026-10-12-fp1-federated-presentation-e2e-design.md`.

**Ports:** PostgreSQL `5433` · NOMIVELA `1956` · EIDOVELA `1966` · LIMENORA `1897`.

---

## File Structure

Enterprise-autonomy (this repo):

- `adapters/presentation-client/go.mod` — module + SDK `replace` directives.
- `adapters/presentation-client/token.go` — EIDOVELA-token `AgentTokenSource`.
- `adapters/presentation-client/carrier.go` — `network.ProofCarrier` (two proofs).
- `adapters/presentation-client/seed.go` — NOMIVELA registry seeding.
- `adapters/presentation-client/dbinit.go` — create the three databases.
- `adapters/presentation-client/main.go` — scenario driver + assertions.
- `adapters/presentation-client/main_test.go` — SDK-only unit tests (httptest).
- `examples/agent-federated-presentation-local/local.env.ps1.example`
- `examples/agent-federated-presentation-local/start-services.ps1`
- `examples/agent-federated-presentation-local/run-all.ps1`
- `examples/agent-federated-presentation-local/verify.ps1`
- `examples/agent-federated-presentation-local/evidence-schema.md`
- `examples/agent-federated-presentation-local/README.md`

PRAXOVELA (sibling checkout):

- `packages/adapters/eidovela/token_source.go` — production `AgentTokenSource`.
- `packages/adapters/eidovela/token_source_test.go`
- `packages/axon-core/internal/runtime/limenora.go` — accept a token source.
- `packages/axon-core/pkg/daemon/limenora.go` — select the EIDOVELA token source.
- `packages/axon-core/internal/config/config.go` — `AXON_LIMENORA_TOKEN_SOURCE`.

---

# Part A — SDK-only `presentation-client` adapter

## Task A1: Module skeleton + SDK replacements

**Files:**
- Create: `adapters/presentation-client/go.mod`

- [ ] **Step 1: Write the module file**

```go.mod
module github.com/axisrobo/enterprise-autonomy/adapters/presentation-client

go 1.25.0

require (
	github.com/axisrobo/LIMENORA-open/sdk/go v0.0.0
	github.com/axisrobo/eidovela-open v0.0.0
	github.com/axisrobo/nomivela-open/v2 v2.0.0
)

replace github.com/axisrobo/LIMENORA-open/sdk/go => ../../../LIMENORA-open/backend/sdk/go

replace github.com/axisrobo/eidovela-open => ../../../EIDOVELA-open

replace github.com/axisrobo/nomivela-open/v2 => ../../../NOMIVELA-open
```

- [ ] **Step 2: Verify the module resolves**

Run: `go mod tidy` (from `adapters/presentation-client`)
Expected: no error; `go.sum` may be created empty (SDKs are stdlib-only).

- [ ] **Step 3: Add a minimal entrypoint and confirm it builds**

Create `adapters/presentation-client/main.go`:

```go
// Command presentation-client is the SDK-only FP-1 federated-presentation E2E
// client. It depends only on the public NOMIVELA/EIDOVELA/LIMENORA SDKs and the
// product core binaries; it never imports product source.
package main

func main() {}
```

Run: `go build ./...`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add adapters/presentation-client/go.mod adapters/presentation-client/go.sum adapters/presentation-client/main.go
git commit -m "feat(presentation-client): SDK-only module skeleton"
```

---

## Task A2: EIDOVELA-token `AgentTokenSource`

**Files:**
- Create: `adapters/presentation-client/token.go`
- Test: `adapters/presentation-client/token_test.go`

- [ ] **Step 1: Write the failing test**

```go
package main

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	eidovela "github.com/axisrobo/eidovela-open/sdk/go/eidovela/v3"
)

func TestEIDOVELATokenSourceReturnsIssuedTokenAndCaches(t *testing.T) {
	var calls int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&calls, 1)
		_ = json.NewEncoder(w).Encode(map[string]any{
			"token":     "eid-token-1",
			"expiresAt": time.Now().Add(time.Hour).UTC().Format(time.RFC3339),
		})
	}))
	defer srv.Close()

	_, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	src := newEidovelaTokenSource(eidovela.NewClient(srv.URL), "agent-1", "inst-1", "limenora", priv)

	got, err := src.Token(context.Background())
	if err != nil {
		t.Fatalf("Token: %v", err)
	}
	if got != "eid-token-1" {
		t.Fatalf("token = %q, want eid-token-1", got)
	}
	if _, err := src.Token(context.Background()); err != nil {
		t.Fatalf("second Token: %v", err)
	}
	if n := atomic.LoadInt32(&calls); n != 1 {
		t.Fatalf("issuer called %d times, want 1 (cached)", n)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./... -run TestEIDOVELATokenSource`
Expected: FAIL — `undefined: newEidovelaTokenSource`.

- [ ] **Step 3: Write minimal implementation**

Create `adapters/presentation-client/token.go`:

```go
package main

import (
	"context"
	"crypto/ed25519"
	"sync"
	"time"

	"github.com/axisrobo/LIMENORA-open/sdk/go/network"
	eidovela "github.com/axisrobo/eidovela-open/sdk/go/eidovela/v3"
)

// refreshSkew is how long before expiry the token is reissued.
const refreshSkew = 30 * time.Second

// eidovelaTokenSource yields the EIDOVELA-issued PoP token as the LIMENORA agent
// credential. This is the FP-1 alignment: the token presented to LIMENORA is the
// same token whose cnf.jkt binds the proof key and whose hash is the proofs' ath.
type eidovelaTokenSource struct {
	client   *eidovela.Client
	agentID  string
	instance string
	audience string
	key      ed25519.PrivateKey

	mu     sync.Mutex
	value  string
	expiry time.Time
}

var _ network.AgentTokenSource = (*eidovelaTokenSource)(nil)

func newEidovelaTokenSource(client *eidovela.Client, agentID, instance, audience string, key ed25519.PrivateKey) *eidovelaTokenSource {
	return &eidovelaTokenSource{client: client, agentID: agentID, instance: instance, audience: audience, key: key}
}

// Token returns a cached token, reissuing shortly before expiry. A failure is
// returned so the egress fails closed; there is no plaintext fallback.
func (s *eidovelaTokenSource) Token(ctx context.Context) (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.value != "" && time.Until(s.expiry) > refreshSkew {
		return s.value, nil
	}
	resp, err := s.client.Token(ctx, s.agentID, s.instance, s.audience, s.key)
	if err != nil {
		return "", err
	}
	if resp.Token == "" {
		return "", network.ErrNoAgentToken
	}
	s.value, s.expiry = resp.Token, resp.ExpiresAt
	return s.value, nil
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `go test ./... -run TestEIDOVELATokenSource`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add adapters/presentation-client/token.go adapters/presentation-client/token_test.go
git commit -m "feat(presentation-client): EIDOVELA-token agent credential source"
```

---

## Task A3: Two-proof `ProofCarrier`

**Files:**
- Create: `adapters/presentation-client/carrier.go`
- Test: `adapters/presentation-client/carrier_test.go`

- [ ] **Step 1: Write the failing test**

```go
package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"strings"
	"testing"
)

func decodeClaims(t *testing.T, jws string) map[string]any {
	t.Helper()
	parts := strings.Split(jws, ".")
	if len(parts) != 3 {
		t.Fatalf("jws has %d parts, want 3", len(parts))
	}
	raw, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		t.Fatalf("decode claims: %v", err)
	}
	var claims map[string]any
	if err := json.Unmarshal(raw, &claims); err != nil {
		t.Fatalf("unmarshal claims: %v", err)
	}
	return claims
}

func TestProofCarrierBindsBothTargetsToTheToken(t *testing.T) {
	_, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	carrier := newProofCarrier(priv, "http://localhost:1966/v1/introspect")
	token := "the-exact-token"

	hdr, err := carrier.ProofHeaders("GET", "http://127.0.0.1:9000/resource", token)
	if err != nil {
		t.Fatalf("ProofHeaders: %v", err)
	}
	resource := strings.TrimPrefix(hdr["DPoP"], "DPoP ")
	intro := strings.TrimPrefix(hdr["DPoP-Introspection"], "DPoP ")

	rc := decodeClaims(t, resource)
	ic := decodeClaims(t, intro)
	wantAth := base64.RawURLEncoding.EncodeToString(func() []byte { s := sha256.Sum256([]byte(token)); return s[:] }())

	if rc["htm"] != "GET" || rc["htu"] != "http://127.0.0.1:9000/resource" {
		t.Fatalf("resource proof htm/htu = %v/%v", rc["htm"], rc["htu"])
	}
	if ic["htm"] != "POST" || ic["htu"] != "http://localhost:1966/v1/introspect" {
		t.Fatalf("introspection proof htm/htu = %v/%v", ic["htm"], ic["htu"])
	}
	if rc["ath"] != wantAth || ic["ath"] != wantAth {
		t.Fatalf("ath mismatch: resource=%v intro=%v want=%v", rc["ath"], ic["ath"], wantAth)
	}
	if rc["jti"] == ic["jti"] {
		t.Fatal("resource and introspection proofs must use distinct jti")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./... -run TestProofCarrier`
Expected: FAIL — `undefined: newProofCarrier`.

- [ ] **Step 3: Write minimal implementation**

Create `adapters/presentation-client/carrier.go`:

```go
package main

import (
	"crypto/ed25519"
	"fmt"
	"time"

	"github.com/axisrobo/LIMENORA-open/sdk/go/network"
	eidovela "github.com/axisrobo/eidovela-open/sdk/go/eidovela/v3"
)

// proofCarrier implements network.ProofCarrier for FP-1: it signs a resource
// proof bound to (method, target) and an introspection proof bound to the
// EIDOVELA introspection endpoint, both over the exact presented token and with
// the same token-bound key. Header/scheme names mirror the gateway GATEWAY_*
// profile (defaults used here).
type proofCarrier struct {
	key              ed25519.PrivateKey
	introspectionHtu string
}

var _ network.ProofCarrier = (*proofCarrier)(nil)

func newProofCarrier(key ed25519.PrivateKey, introspectionHtu string) *proofCarrier {
	return &proofCarrier{key: key, introspectionHtu: introspectionHtu}
}

// ProofHeaders returns the resource and introspection proof headers. A signing
// failure is returned so the request fails closed. The private key never leaves
// the process.
func (c *proofCarrier) ProofHeaders(method, target, token string) (map[string]string, error) {
	resource, err := eidovela.SignDPoP(c.key, method, target, token, time.Now())
	if err != nil {
		return nil, fmt.Errorf("presentation: resource proof: %w", err)
	}
	introspection, err := eidovela.SignDPoP(c.key, "POST", c.introspectionHtu, token, time.Now())
	if err != nil {
		return nil, fmt.Errorf("presentation: introspection proof: %w", err)
	}
	return map[string]string{
		network.DefaultResourceProofHeader:      network.DefaultResourceProofScheme + " " + resource,
		network.DefaultIntrospectionProofHeader: network.DefaultIntrospectionProofScheme + " " + introspection,
	}, nil
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `go test ./... -run TestProofCarrier`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add adapters/presentation-client/carrier.go adapters/presentation-client/carrier_test.go
git commit -m "feat(presentation-client): two-proof FP-1 carrier"
```

---

## Task A4: NOMIVELA registry seeding

**Files:**
- Create: `adapters/presentation-client/seed.go`
- Test: `adapters/presentation-client/seed_test.go`

- [ ] **Step 1: Write the failing test**

```go
package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	nomivela "github.com/axisrobo/nomivela-open/v2/sdk/go"
)

func TestSeedRegistryCreatesRecordsInDependencyOrder(t *testing.T) {
	var paths []string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		paths = append(paths, r.Method+" "+r.URL.Path)
		w.Header().Set("Content-Type", "application/json")
		switch {
		case r.URL.Path == "/v1/agent-identities" && r.Method == http.MethodPost:
			_ = json.NewEncoder(w).Encode(map[string]any{"agentId": "aid-1", "agentRef": "agent_fp1"})
		case strings.HasPrefix(r.URL.Path, "/v1/workload-registrations") && r.Method == http.MethodPost:
			_ = json.NewEncoder(w).Encode(map[string]any{"workloadRegistrationId": "wl-1"})
		default:
			_ = json.NewEncoder(w).Encode(map[string]any{})
		}
	}))
	defer srv.Close()

	client := nomivela.New(srv.URL, nomivela.WithToken("dev-token"))
	ids, err := seedRegistry(context.Background(), client, "https://registry.fp1.test", "agent_fp1")
	if err != nil {
		t.Fatalf("seedRegistry: %v", err)
	}
	if ids.AgentID != "aid-1" || ids.WorkloadRegistrationID != "wl-1" {
		t.Fatalf("ids = %+v", ids)
	}
	joined := strings.Join(paths, ",")
	for _, want := range []string{
		"POST /v1/namespaces", "POST /v1/agents", "POST /v1/agent-identities",
		"POST /v1/agent-identities/aid-1/binding", "POST /v1/workload-registrations",
	} {
		if !strings.Contains(joined, want) {
			t.Fatalf("missing %q in %s", want, joined)
		}
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./... -run TestSeedRegistry`
Expected: FAIL — `undefined: seedRegistry`.

- [ ] **Step 3: Write minimal implementation**

Create `adapters/presentation-client/seed.go`:

```go
package main

import (
	"context"
	"fmt"

	nomivela "github.com/axisrobo/nomivela-open/v2/sdk/go"
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `go test ./... -run TestSeedRegistry`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add adapters/presentation-client/seed.go adapters/presentation-client/seed_test.go
git commit -m "feat(presentation-client): NOMIVELA registry seeding"
```

---

## Task A5: Database bootstrap helper

**Files:**
- Create: `adapters/presentation-client/dbinit.go`

- [ ] **Step 1: Implement**

Create `adapters/presentation-client/dbinit.go`:

```go
package main

import (
	"context"
	"database/sql"
	"fmt"
	"net/url"
	"strings"

	_ "github.com/jackc/pgx/v5/stdlib"
)

// ensureDatabases connects to the admin database of adminURL and creates each
// named database if absent. It lets the example run without psql/Docker.
func ensureDatabases(ctx context.Context, adminURL string, names []string) error {
	db, err := sql.Open("pgx", adminURL)
	if err != nil {
		return err
	}
	defer db.Close()
	for _, name := range names {
		if !validDBName(name) {
			return fmt.Errorf("invalid database name %q", name)
		}
		var exists bool
		if err := db.QueryRowContext(ctx, `SELECT EXISTS(SELECT 1 FROM pg_database WHERE datname=$1)`, name).Scan(&exists); err != nil {
			return err
		}
		if exists {
			continue
		}
		if _, err := db.ExecContext(ctx, `CREATE DATABASE `+quoteIdent(name)); err != nil {
			return fmt.Errorf("create database %s: %w", name, err)
		}
	}
	return nil
}

func validDBName(name string) bool {
	if name == "" {
		return false
	}
	for _, r := range name {
		if !(r == '_' || (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9')) {
			return false
		}
	}
	return true
}

func quoteIdent(name string) string { return `"` + strings.ReplaceAll(name, `"`, `""`) + `"` }

// withDatabase returns a copy of dsn with its path replaced by the named
// database, preserving the rest of the URL.
func withDatabase(dsn, name string) (string, error) {
	u, err := url.Parse(dsn)
	if err != nil {
		return "", err
	}
	u.Path = "/" + name
	return u.String(), nil
}
```

- [ ] **Step 2: Add the pgx dependency and build**

Run: `go get github.com/jackc/pgx/v5/stdlib && go build ./...`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add adapters/presentation-client/dbinit.go go.mod go.sum
git commit -m "feat(presentation-client): idempotent database bootstrap"
```

---

## Task A6: Scenario driver + assertions

**Files:**
- Create: `adapters/presentation-client/main.go`

- [ ] **Step 1: Implement the driver**

Overwrite `adapters/presentation-client/main.go` with the driver:

```go
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
	AdminDSN        string
	NomivelaURL     string
	EidovelaURL     string
	EidovelaIssuer  string
	LimenoraURL     string
	Namespace       string
	AgentRef        string
	Audience        string
	Token           string
	ReportPath      string
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
		EidovelaURL:    env("FP1_EIDOVELA_URL", "http://localhost:1966"),
		EidovelaIssuer: env("FP1_EIDOVELA_ISSUER", "http://localhost:1966"),
		LimenoraURL:    env("FP1_LIMENORA_URL", "http://127.0.0.1:1897"),
		Namespace:      env("FP1_NAMESPACE", "https://registry.fp1.test"),
		AgentRef:       env("FP1_AGENT_REF", "agent_fp1_e2e"),
		Audience:       env("FP1_AUDIENCE", "limenora"),
		Token:          env("FP1_NOMIVELA_TOKEN", "dev-token"),
		ReportPath:     env("FP1_REPORT", "fp1-value-report.json"),
	}
}

func main() {
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

// runReplayDenied is completed in Task B4 (it exercises the replay ledger).
func runReplayDenied(_ context.Context, _ network.AgentTokenSource, _ string, _ ed25519.PrivateKey, _ config) scenarioResult {
	return scenarioResult{ID: "FP-05", Desc: "replayed resource-proof jti denied", Expected: "407", Actual: "pending (Task B4)"}
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
```

- [ ] **Step 2: Build and run the unit tests**

Run: `go build ./... && go test ./...`
Expected: PASS (the driver compiles; unit tests pass; the replay/outage helpers are stubbed here and completed in Task B4).

- [ ] **Step 3: Commit**

```bash
git add adapters/presentation-client/main.go
git commit -m "feat(presentation-client): FP-1 scenario driver"
```

> **Note:** `fixedReplayCarrier`, `egressToken`, and the outage scenario are completed in Task B4 once the example scripts exist. Keep the driver compiling at every commit.

---

# Part B — `agent-federated-presentation-local` example

## Task B1: Environment template + README

**Files:**
- Create: `examples/agent-federated-presentation-local/local.env.ps1.example`
- Create: `examples/agent-federated-presentation-local/README.md`

- [ ] **Step 1: Write `local.env.ps1.example`**

```powershell
# Copy to local.env.ps1 and adjust. Do not commit local.env.ps1.
$AxisRoboHome = "D:\profile\paper-code\axis-vela"

# Admin DSN: the harness creates fp1_nomivela / fp1_eidovela / fp1_limenora.
$env:FP1_ADMIN_DSN = "postgres://postgres:postgres@localhost:5433/postgres?sslmode=disable"

$env:FP1_NOMIVELA_URL = "http://127.0.0.1:1956"
$env:FP1_EIDOVELA_URL = "http://localhost:1966"
$env:FP1_EIDOVELA_ISSUER = "http://localhost:1966"
$env:FP1_LIMENORA_URL = "http://127.0.0.1:1897"
$env:FP1_NAMESPACE = "https://registry.fp1.test"
$env:FP1_AGENT_REF = "agent_fp1_e2e"
$env:FP1_AUDIENCE = "limenora"
$env:FP1_NOMIVELA_TOKEN = "dev-token"
```

- [ ] **Step 2: Write `README.md`**

```markdown
# Agent Federated Presentation (local)

End-to-end FP-1 federated-presentation demo: an SDK-only client presents an
EIDOVELA-issued PoP token as the LIMENORA agent credential together with a
resource proof and an introspection proof. LIMENORA verifies the resource proof,
consumes the replay ledger, relays the introspection proof to EIDOVELA, maps the
verified context to a binding, and forwards to the upstream — fail-closed.

## Prerequisites
- Windows PowerShell 5.1, `curl.exe`, Go 1.25
- A reachable PostgreSQL (default `localhost:5433`, user `postgres`)
- Sibling checkouts of NOMIVELA, EIDOVELA, LIMENORA (+ their open SDKs)

## Run
```powershell
Copy-Item local.env.ps1.example local.env.ps1
. .\local.env.ps1
.\run-all.ps1
```
`run-all.ps1` builds the binaries, creates the databases, starts the services,
runs the scenarios, verifies the value report, and stops the stack.

## Ports
PostgreSQL `5433` · NOMIVELA `1956` · EIDOVELA `1966` · LIMENORA `1897`.
```

- [ ] **Step 3: Commit**

```bash
git add examples/agent-federated-presentation-local/local.env.ps1.example examples/agent-federated-presentation-local/README.md
git commit -m "docs(fp1-demo): env template and README"
```

---

## Task B2: `start-services.ps1`

**Files:**
- Create: `examples/agent-federated-presentation-local/start-services.ps1`

- [ ] **Step 1: Implement**

```powershell
param()

$ErrorActionPreference = "Stop"
if (-not $AxisRoboHome -or -not $env:FP1_ADMIN_DSN) { throw "Load local.env.ps1 before running this script." }

$logDir = Join-Path $PSScriptRoot ".local-logs"
$dataDir = Join-Path $PSScriptRoot ".local-data"
New-Item -ItemType Directory -Force -Path $logDir, $dataDir | Out-Null

function Build-Go($dir, $out, $pkg) {
  $env:GOWORK = "off"
  Push-Location $dir
  try { go build -o $out $pkg } finally { Pop-Location; $env:GOWORK = $null }
}

# Build the three core binaries (plus EIDOVELA migrate).
$nomivelaBin = Join-Path $dataDir "nomivela.exe"
$eidovelaBin = Join-Path $dataDir "eidovelad.exe"
$eidovelaMig = Join-Path $dataDir "eidovela-migrate.exe"
$limenoraBin = Join-Path $dataDir "limenora-server.exe"
Build-Go (Join-Path $AxisRoboHome "NOMIVELA\backend") $nomivelaBin "./cmd/nomivela"
Build-Go (Join-Path $AxisRoboHome "EIDOVELA\backend") $eidovelaBin "./cmd/eidovelad"
Build-Go (Join-Path $AxisRoboHome "EIDOVELA\backend") $eidovelaMig "./cmd/eidovela-migrate"
Build-Go (Join-Path $AxisRoboHome "LIMENORA\backend\go") $limenoraBin "./cmd/server-gateway"

# Create databases via the adapter's init-db, if the helper exists.
$adapter = Join-Path $PSScriptRoot "..\..\adapters\presentation-client"
$previousAdmin = $env:FP1_INIT_DB
$env:FP1_INIT_DB = "1"
Push-Location $adapter
try { go run . -init-db } finally { Pop-Location; $env:FP1_INIT_DB = $previousAdmin }

$nomivelaDSN = "postgres://postgres:postgres@localhost:5433/fp1_nomivela?sslmode=disable"
$eidovelaDSN = "postgres://postgres:postgres@localhost:5433/fp1_eidovela?sslmode=disable"
$limenoraDSN = "postgres://postgres:postgres@localhost:5433/fp1_limenora?sslmode=disable"

# NOMIVELA (migrate on boot).
$env:NOMIVELA_DATABASE_URL = $nomivelaDSN
$env:NOMIVELA_HTTP_PORT = "1956"
$env:NOMIVELA_MIGRATE = "true"
$env:NOMIVELA_API_TOKENS = $env:FP1_NOMIVELA_TOKEN
Start-Process -FilePath $nomivelaBin -RedirectStandardOutput "$logDir\nomivela.out.log" -RedirectStandardError "$logDir\nomivela.err.log" -WindowStyle Hidden

# EIDOVELA migrate, then daemon (consumer mode against NOMIVELA).
$env:EIDOVELA_DATABASE_URL = $eidovelaDSN
& $eidovelaMig
$env:EIDOVELA_LISTEN_ADDR = "127.0.0.1:1966"
$env:EIDOVELA_ISSUER = $env:FP1_EIDOVELA_ISSUER
$env:EIDOVELA_NOMIVELA_URL = $env:FP1_NOMIVELA_URL
$env:EIDOVELA_NOMIVELA_NAMESPACE = $env:FP1_NAMESPACE
$env:EIDOVELA_NOMIVELA_TOKEN = $env:FP1_NOMIVELA_TOKEN
$env:EIDOVELA_NOMIVELA_CACHE_TTL = "0s"
$env:EIDOVELA_REQUIRE_DPOP = "1"
Start-Process -FilePath $eidovelaBin -RedirectStandardOutput "$logDir\eidovela.out.log" -RedirectStandardError "$logDir\eidovela.err.log" -WindowStyle Hidden

# LIMENORA server-gateway: agent-egress scenario + federated presentation.
$env:DATABASE_URL = $limenoraDSN
$env:GATEWAY_AGENT_EGRESS_REQUIRED = "true"
$env:GATEWAY_EIDOVELA_URL = $env:FP1_EIDOVELA_URL
$env:GATEWAY_EIDOVELA_AUDIENCE = $env:FP1_AUDIENCE
$env:GATEWAY_RESOURCE_PROOF_CARRIAGE = "request_header"
$env:GATEWAY_AGENT_TUNNEL_POLICY = "deny"
Start-Process -FilePath $limenoraBin -RedirectStandardOutput "$logDir\limenora.out.log" -RedirectStandardError "$logDir\limenora.err.log" -WindowStyle Hidden

# Health checks.
$checks = @("$($env:FP1_NOMIVELA_URL)/healthz", "$($env:FP1_EIDOVELA_URL)/healthz", "$($env:FP1_LIMENORA_URL)/healthz")
foreach ($c in $checks) {
  $ready = $false
  for ($i = 0; $i -lt 30 -and -not $ready; $i++) {
    try { Invoke-WebRequest -UseBasicParsing $c | Out-Null; $ready = $true } catch { Start-Sleep -Seconds 1 }
  }
  if (-not $ready) { throw "Service not ready: $c" }
}
Write-Host "FP-1 services ready."
```

- [ ] **Step 2: Add `-init-db` to the adapter driver**

In `adapters/presentation-client/main.go`, at the top of `main()`:

```go
	if os.Getenv("FP1_INIT_DB") != "" {
		admin := env("FP1_ADMIN_DSN", "postgres://postgres:postgres@localhost:5433/postgres?sslmode=disable")
		if err := ensureDatabases(context.Background(), admin, []string{"fp1_nomivela", "fp1_eidovela", "fp1_limenora"}); err != nil {
			log.Fatalf("init-db: %v", err)
		}
		fmt.Println("fp1 databases ready")
		return
	}
```

- [ ] **Step 3: Build the driver**

Run: `go build ./...` (from `adapters/presentation-client`)
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add examples/agent-federated-presentation-local/start-services.ps1 adapters/presentation-client/main.go
git commit -m "feat(fp1-demo): service launcher + db init"
```

---

## Task B3: `run-all.ps1`, `verify.ps1`, evidence schema

**Files:**
- Create: `examples/agent-federated-presentation-local/run-all.ps1`
- Create: `examples/agent-federated-presentation-local/verify.ps1`
- Create: `examples/agent-federated-presentation-local/evidence-schema.md`

- [ ] **Step 1: Write `run-all.ps1`**

```powershell
param([switch]$CheckOnly)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\local.env.ps1"

if ($CheckOnly) { Write-Host "structure OK"; exit 0 }

& "$PSScriptRoot\start-services.ps1"
try {
  $adapter = Join-Path $PSScriptRoot "..\..\adapters\presentation-client"
  Push-Location $adapter
  try {
    go run . -report (Join-Path $PSScriptRoot ".local-data\fp1-value-report.json")
  } finally { Pop-Location }
  & "$PSScriptRoot\verify.ps1"
} finally {
  Get-Process nomivela, eidovelad, limenora-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
```

- [ ] **Step 2: Write `verify.ps1`**

```powershell
param()
$ErrorActionPreference = "Stop"
$report = Join-Path $PSScriptRoot ".local-data\fp1-value-report.json"
if (-not (Test-Path $report)) { throw "value report missing: $report" }
$data = Get-Content $report -Raw | ConvertFrom-Json
if (-not $data.passed) { throw "FP-1 scenarios failed" }
foreach ($s in $data.scenarios) {
  if (-not $s.passed) { throw "scenario $($s.id) failed: $($s.actual)" }
}
Write-Host "FP-1 value report verified: $($data.scenarios.Count) scenarios passed."
```

- [ ] **Step 3: Write `evidence-schema.md`**

```markdown
# FP-1 Value Report Schema

`fp1-value-report.json`:

| Field | Type | Meaning |
| --- | --- | --- |
| `passed` | bool | every scenario passed |
| `scenarios[]` | array | one entry per assertion |
| `scenarios[].id` | string | `FP-01`..`FP-09` |
| `scenarios[].expected` | string | expected outcome |
| `scenarios[].actual` | string | observed outcome |
| `scenarios[].passed` | bool | assertion result |
```

- [ ] **Step 4: Commit**

```bash
git add examples/agent-federated-presentation-local/run-all.ps1 examples/agent-federated-presentation-local/verify.ps1 examples/agent-federated-presentation-local/evidence-schema.md
git commit -m "feat(fp1-demo): run/verify scripts and evidence schema"
```

---

## Task B4: Complete the denial + no-leak scenarios

**Files:**
- Modify: `adapters/presentation-client/main.go`
- Create: `adapters/presentation-client/replay.go`

- [ ] **Step 1: Add the replay carrier + token helper**

Create `adapters/presentation-client/replay.go`:

```go
package main

import (
	"context"
	"crypto/ed25519"
	"time"

	"github.com/axisrobo/LIMENORA-open/sdk/go/network"
	eidovela "github.com/axisrobo/eidovela-open/sdk/go/eidovela/v3"
)

// fixedReplayCarrier reuses one resource-proof jti across calls so the gateway's
// replay ledger must reject the second presentation.
type fixedReplayCarrier struct {
	inner *proofCarrier
	once  map[string]string
}

func newFixedReplayCarrier(key ed25519.PrivateKey, introspectionHtu string) *fixedReplayCarrier {
	return &fixedReplayCarrier{inner: newProofCarrier(key, introspectionHtu), once: map[string]string{}}
}

func (c *fixedReplayCarrier) ProofHeaders(method, target, token string) (map[string]string, error) {
	hdr, err := c.inner.ProofHeaders(method, target, token)
	if err != nil {
		return nil, err
	}
	// Freeze the resource proof after the first production so every later call
	// replays the same bytes (and thus the same jti).
	if prev, ok := c.once["resource"]; ok {
		hdr[network.DefaultResourceProofHeader] = prev
	} else {
		c.once["resource"] = hdr[network.DefaultResourceProofHeader]
	}
	return hdr, nil
}

// egressToken extracts the current credential from a token source for a direct
// proof build.
func egressToken(ctx context.Context, ts network.AgentTokenSource) (string, error) {
	return ts.Token(ctx)
}

var _ = time.Now
var _ = eidovela.SignDPoP
```

- [ ] **Step 2: Wire the real replay + no-leak scenarios in `main.go`**

Replace `runReplayDenied` with:

```go
func runReplayDenied(ctx context.Context, ts network.AgentTokenSource, upstreamURL string, key ed25519.PrivateKey, cfg config) scenarioResult {
	res := scenarioResult{ID: "FP-05", Desc: "replayed resource-proof jti denied", Expected: "407"}
	replay := newFixedReplayCarrier(key, cfg.EidovelaIssuer+"/v1/introspect")
	egress, err := network.NewProxyEgress(cfg.LimenoraURL, ts,
		network.WithProofCarrier(replay), network.WithCarriage(network.CarriageRequestHeader))
	if err != nil {
		res.Actual = "build error: " + err.Error()
		return res
	}
	_, err = egress.Do(ctx, network.GatewayRequest{URL: upstreamURL + "/resource", Method: http.MethodGet})
	if err == nil {
		res.Actual = "first use unexpectedly failed"
		return res
	}
	got, err := egress.Do(ctx, network.GatewayRequest{URL: upstreamURL + "/resource", Method: http.MethodGet})
	if err != nil {
		res.Actual = "error: " + err.Error()
		return res
	}
	if got.Status == http.StatusProxyAuthRequired || got.Status == http.StatusForbidden {
		res.Actual = "second use denied"
		res.Passed = true
	} else {
		res.Actual = fmt.Sprintf("status %d, want 407", got.Status)
	}
	return res
}
```

- [ ] **Step 3: Add the no-downgrade / no-leak scenario**

Append to `main.go` and include it in `run()`:

```go
// runNoDowngradeDenied proves an agent-selected route with a valid token but no
// resource proof is denied and the upstream is never contacted (no downgrade,
// no leak).
func runNoDowngradeDenied(ctx context.Context, cfg config, ts network.AgentTokenSource, upstreamURL string, hits *int32) scenarioResult {
	res := scenarioResult{ID: "FP-07", Desc: "proof-less agent route denied; upstream untouched", Expected: "deny, 0 upstream hits"}
	before := atomic.LoadInt32(hits)
	raw, err := network.NewProxyEgress(cfg.LimenoraURL, ts, network.WithCarriage(network.CarriageRequestHeader))
	if err != nil {
		res.Actual = "build error: " + err.Error()
		return res
	}
	got, err := raw.Do(ctx, network.GatewayRequest{URL: upstreamURL + "/downgrade", Method: http.MethodGet})
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
```

Add to `run()` after the replay scenario:

```go
	results = append(results, runNoDowngradeDenied(ctx, cfg, tokenSource, upstream.URL, &upstreamHits))
```

- [ ] **Step 4: Run unit tests**

Run: `go build ./... && go test ./...`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add adapters/presentation-client/replay.go adapters/presentation-client/main.go
git commit -m "feat(presentation-client): replay + no-downgrade scenarios"
```

---

## Task B5: Wire the example into the demo suite

**Files:**
- Modify: `examples/run-all-demos.ps1`
- Modify: `scripts/validate-demos.ps1`
- Modify: `scripts/check-examples.ps1`

- [ ] **Step 1: Read the existing structure**

Run: `Get-Content examples/run-all-demos.ps1` and `Get-Content scripts/validate-demos.ps1`
Confirm how demos are enumerated (list/array of demo directory names).

- [ ] **Step 2: Add `agent-federated-presentation-local` to the demo list**

Add the demo name to the enumeration used by `run-all-demos.ps1` and
`validate-demos.ps1`, and add any required `-CheckOnly` structure assertions in
`check-examples.ps1` (files: `README.md`, `local.env.ps1.example`,
`start-services.ps1`, `run-all.ps1`, `verify.ps1`).

- [ ] **Step 3: Run the structural check**

Run: `.\examples\run-all-demos.ps1 -CheckOnly`
Expected: PASS with the new demo listed.

- [ ] **Step 4: Commit**

```bash
git add examples/run-all-demos.ps1 scripts/validate-demos.ps1 scripts/check-examples.ps1
git commit -m "feat(fp1-demo): register the demo in the suite"
```

---

# Part C — PRAXOVELA production `AgentTokenSource`

> **Independent subsystem.** This part is out of the example repository and may
> be executed as its own plan; it produces working, testable software on its own.

## Task C1: EIDOVELA ticket source in the adapter

**Files:**
- Create: `packages/adapters/eidovela/token_source.go`
- Test: `packages/adapters/eidovela/token_source_test.go`

- [ ] **Step 1: Write the failing test**

```go
package eidovela

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestClientTokenSourceYieldsEIDOVELAToken(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"token": "eid-tok", "expiresAt": time.Now().Add(time.Hour).UTC().Format(time.RFC3339),
		})
	}))
	defer srv.Close()

	_, key, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	client := NewClient(srv.URL, WithSigner(NewSigner(key)), WithIdentity("agent-1", "inst-1"), WithAudience("limenora"))
	src := NewTokenSource(client)
	got, err := src.Token(context.Background())
	if err != nil {
		t.Fatalf("Token: %v", err)
	}
	if got != "eid-tok" {
		t.Fatalf("token = %q, want eid-tok", got)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./eidovela/ -run TestClientTokenSource`
Expected: FAIL — `undefined: NewSigner`, `NewTokenSource`, `WithIdentity` (verify the exact existing constructors; adjust names to the current adapter surface).

- [ ] **Step 3: Implement**

Create `packages/adapters/eidovela/token_source.go`:

```go
package eidovela

import (
	"context"
	"sync"
	"time"
)

// TokenSource yields the EIDOVELA-issued PoP token as the egress agent
// credential. It implements the LIMENORA-open client AgentTokenSource contract so
// the same token that binds cnf.jkt and the proofs' ath is presented to the
// gateway.
type TokenSource struct {
	client *HTTPClient

	mu     sync.Mutex
	value  string
	expiry time.Time
}

// NewTokenSource wraps an enrolled client as a refresh-on-expiry token source.
func NewTokenSource(client *HTTPClient) *TokenSource { return &TokenSource{client: client} }

// Token returns a cached token, reissuing shortly before expiry.
func (s *TokenSource) Token(ctx context.Context) (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.value != "" && time.Until(s.expiry) > time.Minute {
		return s.value, nil
	}
	tok, err := s.client.Token(ctx)
	if err != nil {
		return "", err
	}
	s.value, s.expiry = tok.Value, tok.ExpiresAt
	return s.value, nil
}
```

- [ ] **Step 4: Run tests**

Run: `go test ./eidovela/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/adapters/eidovela/token_source.go packages/adapters/eidovela/token_source_test.go
git commit -m "feat(eidovela): token source presents the PoP token as the agent credential"
```

---

## Task C2: Accept a token source in the LIMENORA egress

**Files:**
- Modify: `packages/axon-core/internal/runtime/limenora.go`
- Test: `packages/axon-core/internal/runtime/limenora_test.go`

- [ ] **Step 1: Write the failing test**

Add to `limenora_test.go`:

```go
type fakeTokenSource struct{ token string }

func (f fakeTokenSource) Token(context.Context) (string, error) { return f.token, nil }

func TestNewLimenoraEgressUsesProvidedTokenSource(t *testing.T) {
	gw, err := NewLimenoraEgress(NetworkEgressConfig{
		ProxyURL:   "http://proxy.local:3128",
		TokenSrc:   fakeTokenSource{token: "eid-tok"},
	})
	if err != nil {
		t.Fatalf("NewLimenoraEgress: %v", err)
	}
	if gw == nil {
		t.Fatal("expected a gateway")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/runtime/ -run TestNewLimenoraEgressUsesProvidedTokenSource`
Expected: FAIL — `TokenSrc` undefined.

- [ ] **Step 3: Implement**

In `NetworkEgressConfig`, add:

```go
	// TokenSrc, when set, supplies the presented agent credential (for example
	// the EIDOVELA-issued PoP token). It takes precedence over AgentToken.
	TokenSrc network.AgentTokenSource
```

In `NewLimenoraEgress`, replace the static source construction:

```go
	var tokens network.AgentTokenSource
	if cfg.TokenSrc != nil {
		tokens = cfg.TokenSrc
	} else {
		tokens = network.NewStaticTokenSource(cfg.AgentToken)
	}
	gw, err := network.NewProxyEgress(cfg.ProxyURL, tokens, opts...)
```

- [ ] **Step 4: Run tests**

Run: `go test ./internal/runtime/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/axon-core/internal/runtime/limenora.go packages/axon-core/internal/runtime/limenora_test.go
git commit -m "feat(runtime): accept an agent token source on the LIMENORA egress"
```

---

## Task C3: Wire the EIDOVELA token source in the daemon + config

**Files:**
- Modify: `packages/axon-core/pkg/daemon/limenora.go`
- Modify: `packages/axon-core/internal/config/config.go`
- Test: `packages/axon-core/pkg/daemon/limenora_test.go`

- [ ] **Step 1: Write the failing test**

Add to `pkg/daemon/limenora_test.go`:

```go
func TestSelectLimenoraEgressEidovelaTokenSourceRequiresConfig(t *testing.T) {
	_, err := SelectLimenoraEgress(LimenoraEgressConfig{
		ProxyURL:     "http://proxy.local:3128",
		TokenSource:  "eidovela",
		EidovelaURL:  "",
	})
	if err == nil {
		t.Fatal("expected an error when token source is eidovela without EIDOVELA config")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./pkg/daemon/ -run TestSelectLimenoraEgressEidovela`
Expected: FAIL — `TokenSource` field undefined.

- [ ] **Step 3: Implement**

In `LimenoraEgressConfig` add `TokenSource string` (values `static` default | `eidovela`).
In `SelectLimenoraEgress`, when `TokenSource == "eidovela"`, build the signer+client
(already done in `limenoraProofCarrier`) and set `egress.TokenSrc = eidovelaadapter.NewTokenSource(client)`;
when `EidovelaURL`/`EidovelaKeyFile` are missing, return a fail-closed error.
Refactor `limenoraProofCarrier` to return the built `*eidovelaadapter.HTTPClient`
so both the carrier and the token source share one enrolled client.

- [ ] **Step 4: Add config + env**

In `internal/config/config.go` add `LimenoraTokenSource string` reading
`AXON_LIMENORA_TOKEN_SOURCE` (default `static`). In `cmd/axond/main.go`
`selectLimenoraEgress`, pass `TokenSource: cfg.LimenoraTokenSource`.

- [ ] **Step 5: Run tests + build**

Run: `go test ./... -run Limenora && go build ./...`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add packages/axon-core/pkg/daemon/limenora.go packages/axon-core/pkg/daemon/limenora_test.go packages/axon-core/internal/config/config.go packages/axon-core/cmd/axond/main.go
git commit -m "feat(axond): select the EIDOVELA token source for LIMENORA egress"
```

---

## Task C4: Docs

**Files:**
- Modify: `README.md` (PRAXOVELA) or `PRAXOVELA-EE/docs/` per project convention.

- [ ] **Step 1:** Document `AXON_LIMENORA_TOKEN_SOURCE=eidovela` and the alignment requirement (`cnf.jkt == proof key == presenterJkt`, both `ath` over one token).

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: AXON_LIMENORA_TOKEN_SOURCE and the FP-1 token alignment"
```

---

## Self-Review

**Spec coverage:** §4 dependency rule → Tasks A1/A6; §6 data flow → A5/A6/B2; §7 alignment → A2/A3/C1; §9 fail-closed matrix → A6/B4; §10 layout → Part A/B; §11 PRAXOVELA → Part C; §8 ports → B2/local.env; §12 verification → B3/B5.
**Placeholder scan:** none; every code step has content. The `main.go` comments note the B4 completion explicitly.
**Type consistency:** `eidovelaTokenSource`/`proofCarrier`/`seededIDs`/`report`/`scenarioResult` are used consistently across tasks; SDK signatures (`SignDPoP`, `CreateChallenge`, `CompleteEnrollment`, `Token`, `NewProxyEgress`, `WithProofCarrier`, `WithCarriage`) match the SDK surfaces read during planning.

## Open items / follow-ups
- AEGIVELA decision plane (deferred).
- Cross-replica replay.
- Confirm the exact `NewSigner`/`WithIdentity` names in Task C1 against the current PRAXOVELA adapter surface before implementing.
