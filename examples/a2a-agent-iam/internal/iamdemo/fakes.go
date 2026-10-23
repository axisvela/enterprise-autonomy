package iamdemo

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"time"

	eidovela "github.com/axisvela/eidovela-open/v3/sdk/go/eidovela/v3"
)

const (
	demoNamespace = "https://registry.a2a-iam.test"
	demoAgentRef  = "agent_google_adk_checkout"
	demoAgentID   = "agent-id-adk-1"
	demoWorkload  = "workload-adk-1"
	demoRoot      = "root:demo"
	demoAudience  = "praxo-a2a"
)

type fakeNOMIVELA struct {
	mu             sync.Mutex
	server         *httptest.Server
	namespace      string
	agentRef       string
	agentState     string
	agentEpoch     int64
	agentID        string
	identityState  string
	identityEpoch  int64
	authorityRoot  string
	workloadID     string
	workloadStatus string
	workloadEpoch  int64
}

func newFakeNOMIVELA() *fakeNOMIVELA {
	f := &fakeNOMIVELA{
		namespace: demoNamespace, agentRef: demoAgentRef, agentState: "queued",
		agentEpoch: 1, agentID: demoAgentID, identityState: "queued", identityEpoch: 1,
		authorityRoot: demoRoot, workloadID: demoWorkload, workloadStatus: "queued", workloadEpoch: 1,
	}
	f.server = httptest.NewServer(http.HandlerFunc(f.handle))
	return f
}

func (f *fakeNOMIVELA) URL() string { return f.server.URL }

func (f *fakeNOMIVELA) Close() { f.server.Close() }

func (f *fakeNOMIVELA) handle(w http.ResponseWriter, r *http.Request) {
	f.mu.Lock()
	defer f.mu.Unlock()
	switch {
	case r.URL.Path == "/v1/namespaces" && r.Method == http.MethodPost:
		writeJSON(w, map[string]any{
			"namespace": demoNamespace, "authorityRootRef": demoRoot,
			"status": "active", "namespaceEpoch": 1,
		})
	case r.URL.Path == "/v1/agents" && r.Method == http.MethodPost:
		writeJSON(w, map[string]any{
			"agentRef": demoAgentRef, "name": "Google ADK checkout agent",
			"purpose": "Cancel eligible shopping orders", "sponsorRef": "org:demo",
			"ownerRef": "user:demo", "riskClass": "low", "agentClass": "service",
			"state": f.agentState, "agentEpoch": f.agentEpoch,
		})
	case strings.HasPrefix(r.URL.Path, "/v1/agents/") && strings.HasSuffix(r.URL.Path, "/lifecycle") && r.Method == http.MethodPost:
		var body struct {
			State string `json:"state"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		f.agentState = body.State
		f.agentEpoch++
		writeJSON(w, map[string]any{
			"agentRef": demoAgentRef, "name": "Google ADK checkout agent",
			"purpose": "Cancel eligible shopping orders", "sponsorRef": "org:demo",
			"ownerRef": "user:demo", "riskClass": "low", "agentClass": "service",
			"state": f.agentState, "agentEpoch": f.agentEpoch,
		})
	case r.URL.Path == "/v1/agent-identities" && r.Method == http.MethodPost:
		writeJSON(w, map[string]any{
			"namespace": demoNamespace, "agentId": demoAgentID, "agentRef": demoAgentRef,
			"identityType": "autonomous", "state": f.identityState, "identityEpoch": f.identityEpoch,
		})
	case strings.HasPrefix(r.URL.Path, "/v1/agent-identities/") && strings.HasSuffix(r.URL.Path, "/binding") && r.Method == http.MethodPost:
		f.authorityRoot = demoRoot
		writeJSON(w, map[string]any{
			"namespace": demoNamespace, "agentId": demoAgentID, "agentRef": demoAgentRef,
			"state": f.identityState, "identityEpoch": f.identityEpoch,
			"authorityRootRef": f.authorityRoot, "authorityRootType": "organization",
		})
	case strings.HasPrefix(r.URL.Path, "/v1/agent-identities/") && strings.HasSuffix(r.URL.Path, "/lifecycle") && r.Method == http.MethodPost:
		var body struct {
			State string `json:"state"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		f.identityState = body.State
		f.identityEpoch++
		writeJSON(w, map[string]any{
			"namespace": demoNamespace, "agentId": demoAgentID, "agentRef": demoAgentRef,
			"state": f.identityState, "identityEpoch": f.identityEpoch,
			"authorityRootRef": f.authorityRoot, "authorityRootType": "organization",
		})
	case r.URL.Path == "/v1/workload-registrations" && r.Method == http.MethodPost:
		writeJSON(w, map[string]any{
			"workloadRegistrationId": demoWorkload, "namespace": demoNamespace,
			"platform": "local", "selector": map[string]string{"app": "google-adk"}, "trustDomain": "demo.test",
			"allowedProofMethods": []string{"private_key_jwt"}, "status": f.workloadStatus, "workloadEpoch": f.workloadEpoch,
		})
	case r.URL.Path == "/v1/registry-context" && r.Method == http.MethodGet:
		writeJSON(w, map[string]any{
			"namespace": map[string]any{
				"namespace": demoNamespace, "authorityRootRef": demoRoot, "status": "active", "namespaceEpoch": 1,
			},
			"agent": map[string]any{
				"agentRef": demoAgentRef, "name": "Google ADK checkout agent",
				"purpose": "Cancel eligible shopping orders", "sponsorRef": "org:demo",
				"ownerRef": "user:demo", "riskClass": "low", "agentClass": "service",
				"state": f.agentState, "agentEpoch": f.agentEpoch,
			},
			"identity": map[string]any{
				"namespace": demoNamespace, "agentId": demoAgentID, "agentRef": demoAgentRef,
				"identityType": "autonomous", "state": f.identityState, "identityEpoch": f.identityEpoch,
				"authorityRootRef": f.authorityRoot, "authorityRootType": "organization",
			},
			"workloadRegistration": map[string]any{
				"workloadRegistrationId": demoWorkload, "namespace": demoNamespace,
				"platform": "local", "selector": map[string]string{"app": "google-adk"}, "trustDomain": "demo.test",
				"allowedProofMethods": []string{"private_key_jwt"}, "status": f.workloadStatus, "workloadEpoch": f.workloadEpoch,
			},
		})
	default:
		http.NotFound(w, r)
	}
}

type fakeEIDOVELA struct {
	server     *httptest.Server
	key        ed25519.PrivateKey
	kid        string
	instanceID string
}

func newFakeEIDOVELA() *fakeEIDOVELA {
	_, key, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		panic(err)
	}
	f := &fakeEIDOVELA{key: key, kid: "demo-key", instanceID: "instance-adk-1"}
	f.server = httptest.NewServer(http.HandlerFunc(f.handle))
	return f
}

func (f *fakeEIDOVELA) URL() string { return f.server.URL }

func (f *fakeEIDOVELA) Close() { f.server.Close() }

func (f *fakeEIDOVELA) handle(w http.ResponseWriter, r *http.Request) {
	switch r.URL.Path {
	case "/v1/enrollments":
		var body struct {
			AgentID                string `json:"agentId"`
			WorkloadRegistrationID string `json:"workloadRegistrationId"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		writeJSON(w, map[string]any{
			"enrollmentId": "enrollment-1", "agentId": body.AgentID, "nonce": "nonce-1",
			"expiresAt": time.Now().Add(5 * time.Minute).UTC().Format(time.RFC3339),
		})
	case "/v1/enrollments/complete":
		var body struct {
			AgentID string `json:"agentId"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		writeJSON(w, map[string]any{
			"instanceId": f.instanceID, "agentId": body.AgentID, "workloadId": "workload-instance-1",
			"status": "active",
		})
	case "/oauth2/token":
		var body struct {
			AgentID   string `json:"agentId"`
			Audience  string `json:"audience"`
			PublicKey struct {
				X string `json:"x"`
			} `json:"publicKey"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		pub, err := base64.RawURLEncoding.DecodeString(body.PublicKey.X)
		if err != nil || len(pub) != ed25519.PublicKeySize {
			http.Error(w, "invalid public key", http.StatusBadRequest)
			return
		}
		token, expires := f.issueToken(body.AgentID, body.Audience, ed25519.PublicKey(pub))
		writeJSON(w, map[string]any{"token": token, "expiresAt": expires.Format(time.RFC3339)})
	case "/jwks.json":
		pub := f.key.Public().(ed25519.PublicKey)
		writeJSON(w, map[string]any{"keys": []any{map[string]any{
			"kty": "OKP", "crv": "Ed25519", "x": base64.RawURLEncoding.EncodeToString(pub),
			"kid": f.kid, "alg": "EdDSA", "use": "sig",
		}}})
	default:
		http.NotFound(w, r)
	}
}

func (f *fakeEIDOVELA) issueToken(agentID, audience string, pub ed25519.PublicKey) (string, time.Time) {
	now := time.Now()
	expires := now.Add(5 * time.Minute)
	header := map[string]any{"alg": "EdDSA", "kid": f.kid, "typ": "JWT"}
	claims := map[string]any{
		"iss": f.server.URL + "/t/demo", "aud": audience, "sub": agentID,
		"iat": now.Unix(), "exp": expires.Unix(), "jti": "token-1",
		"cnf":      map[string]any{"jkt": eidovela.Thumbprint(pub)},
		"registry": demoNamespace, "agentClass": "service",
		"instanceId": f.instanceID, "workloadId": "workload-instance-1",
		"authorityRootRef": demoRoot, "agentEpoch": 2, "identityEpoch": 2,
	}
	encode := func(value any) string {
		raw, _ := json.Marshal(value)
		return base64.RawURLEncoding.EncodeToString(raw)
	}
	input := encode(header) + "." + encode(claims)
	return input + "." + base64.RawURLEncoding.EncodeToString(ed25519.Sign(f.key, []byte(input))), expires
}

type fakeAEGIVELA struct {
	server *httptest.Server
}

func newFakeAEGIVELA() *fakeAEGIVELA {
	f := &fakeAEGIVELA{}
	f.server = httptest.NewServer(http.HandlerFunc(f.handle))
	return f
}

func (f *fakeAEGIVELA) URL() string { return f.server.URL }

func (f *fakeAEGIVELA) Close() { f.server.Close() }

func (f *fakeAEGIVELA) handle(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/v1/policy/decisions/evaluate" {
		http.NotFound(w, r)
		return
	}
	var body struct {
		Action   string `json:"action"`
		Resource struct {
			Reference string `json:"reference"`
		} `json:"resource"`
	}
	_ = json.NewDecoder(r.Body).Decode(&body)
	outcome := "deny"
	if body.Resource.Reference == "order-1001" {
		outcome = "allow"
	}
	writeJSON(w, map[string]any{
		"api_version":    "aegivela.io/v1alpha1",
		"decision_id":    "decision-1",
		"outcome":        outcome,
		"policy_version": "demo-order-policy-v1",
		"evidence_refs":  []string{"evidence://demo/decision-1"},
	})
}

func writeJSON(w http.ResponseWriter, value any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(value)
}
