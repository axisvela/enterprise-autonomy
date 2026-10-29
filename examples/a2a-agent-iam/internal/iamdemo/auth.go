package iamdemo

import (
	"context"
	"crypto/ed25519"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/axisvela/aegivela-open/sdk/go/v3/pepsdk"
	eidovela "github.com/axisvela/eidovela-open/v3/sdk/go/eidovela/v3"
	nomivela "github.com/axisvela/nomivela-open/v3/sdk/go"
)

var errUnauthorized = errors.New("unauthorized")

type identity struct {
	Token     string
	Principal eidovela.Principal
	Registry  *nomivela.RegistryContext
}

func verifyIdentity(ctx context.Context, r *http.Request, body []byte, eidovelaURL, nomivelaURL string) (*identity, error) {
	token := bearerToken(r)
	if token == "" {
		return nil, errUnauthorized
	}
	proof := r.Header.Get("DPoP")
	pub, err := publicKey(r.Header.Get("X-Agent-Public-Key"))
	if err != nil {
		return nil, errUnauthorized
	}
	if err := verifyDPoP(r, proof, token, pub); err != nil {
		return nil, errUnauthorized
	}
	principal, err := eidovela.Verify(http.DefaultClient, token, demoAudience, pub)
	if err != nil {
		return nil, errUnauthorized
	}
	client := nomivela.New(nomivelaURL, nomivela.WithToken("dev-token"))
	registry, err := client.GetRegistryContext(ctx, principal.Namespace, principal.AgentID, principal.InstanceID, "")
	if err != nil {
		return nil, err
	}
	if registry.Agent.State != "active" || registry.Identity.State != "active" {
		return nil, errors.New("agent or identity is not active")
	}
	_ = body
	return &identity{Token: token, Principal: principal, Registry: registry}, nil
}

func authorize(ctx context.Context, aegivelaURL string, id *identity, orderRef string) error {
	assertion := fmt.Sprintf(`{"agentId":%q,"namespace":%q,"instanceId":%q,"agentEpoch":%d,"identityEpoch":%d}`,
		id.Registry.Identity.AgentID, id.Registry.Namespace.Namespace, id.Principal.InstanceID,
		id.Registry.Agent.AgentEpoch, id.Registry.Identity.IdentityEpoch)
	return authorizeWithAssertion(ctx, aegivelaURL, assertion, orderRef)
}

func authorizeWithAssertion(ctx context.Context, aegivelaURL, assertion, orderRef string) error {
	options := []pepsdk.Option{}
	if token := os.Getenv("A2A_IAM_AEGIVELA_TOKEN"); token != "" {
		options = append(options, pepsdk.WithHeaders(map[string]string{
			"X-Aegivela-Internal-Token": token,
			"X-Aegivela-Tenant-ID":      envOr("A2A_IAM_TENANT", "demo"),
			"X-Aegivela-Actor-ID":       envOr("A2A_IAM_AEGIVELA_ACTOR", "agent_google_adk_checkout"),
			"X-Aegivela-Authority-Root": envOr("A2A_IAM_AEGIVELA_AUTHORITY_ROOT", "root:demo"),
		}))
	}
	client := pepsdk.NewClient(aegivelaURL, http.DefaultClient, options...)
	result, err := client.Evaluate(ctx, pepsdk.Route{
		Audience:  envOr("A2A_IAM_AUDIENCE", "praxo-a2a"),
		Action:    "order:cancel",
		Scope:     []string{"order:cancel"},
		Kind:      "order",
		Reference: orderRef,
	}, pepsdk.AuthorizationInput{
		Mode:              pepsdk.ModeSystemAPI,
		WorkloadAssertion: assertion,
	})
	if err != nil {
		return err
	}
	if result.Outcome != "allow" {
		return pepsdk.ErrDenied
	}
	return nil
}

func envOr(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func bearerToken(r *http.Request) string {
	value := r.Header.Get("Authorization")
	if !strings.HasPrefix(value, "Bearer ") {
		return ""
	}
	return strings.TrimSpace(strings.TrimPrefix(value, "Bearer "))
}

func publicKey(value string) (ed25519.PublicKey, error) {
	raw, err := base64.RawURLEncoding.DecodeString(value)
	if err != nil || len(raw) != ed25519.PublicKeySize {
		return nil, errUnauthorized
	}
	return ed25519.PublicKey(raw), nil
}

func verifyDPoP(r *http.Request, proof, token string, pub ed25519.PublicKey) error {
	parts := strings.Split(proof, ".")
	if len(parts) != 3 {
		return errUnauthorized
	}
	decode := func(segment string, value any) error {
		raw, err := base64.RawURLEncoding.DecodeString(segment)
		if err != nil {
			return errUnauthorized
		}
		return json.Unmarshal(raw, value)
	}
	var header struct {
		Typ string `json:"typ"`
		Alg string `json:"alg"`
	}
	var claims struct {
		HTM string `json:"htm"`
		HTU string `json:"htu"`
		ATH string `json:"ath"`
		IAT int64  `json:"iat"`
		JTI string `json:"jti"`
	}
	if err := decode(parts[0], &header); err != nil {
		return err
	}
	if header.Typ != "dpop+jwt" || header.Alg != "EdDSA" {
		return errUnauthorized
	}
	if err := decode(parts[1], &claims); err != nil {
		return err
	}
	signature, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil || !ed25519.Verify(pub, []byte(parts[0]+"."+parts[1]), signature) {
		return errUnauthorized
	}
	sum := sha256.Sum256([]byte(token))
	age := time.Since(time.Unix(claims.IAT, 0))
	if claims.HTM != r.Method || claims.ATH != base64.RawURLEncoding.EncodeToString(sum[:]) ||
		claims.JTI == "" || age > time.Minute || age < -time.Minute {
		return errUnauthorized
	}
	target := "http://" + r.Host + r.URL.EscapedPath()
	if claims.HTU != target {
		return errUnauthorized
	}
	return nil
}

func orderRef(body []byte) string {
	text := string(body)
	switch {
	case strings.Contains(text, "order-1001"):
		return "order-1001"
	case strings.Contains(text, "order-1002"):
		return "order-1002"
	default:
		return "order-unknown"
	}
}

func gatewaySignature(secret, agentID, namespace string, timestamp int64) string {
	mac := hmac.New(sha256.New, []byte(secret))
	_, _ = fmt.Fprintf(mac, "%s|%s|%d", agentID, namespace, timestamp)
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}

func verifyGateway(r *http.Request, secret string) error {
	if strings.TrimSpace(secret) == "" {
		return errUnauthorized
	}
	timestamp, err := strconv.ParseInt(r.Header.Get("X-A2A-Gateway-Timestamp"), 10, 64)
	age := time.Since(time.Unix(timestamp, 0))
	if err != nil || age > time.Minute || age < -time.Minute {
		return errUnauthorized
	}
	agentID := r.Header.Get("X-A2A-Agent-ID")
	namespace := r.Header.Get("X-A2A-Namespace")
	expected := gatewaySignature(secret, agentID, namespace, timestamp)
	if !subtleCompare(expected, r.Header.Get("X-A2A-Gateway-Signature")) {
		return errUnauthorized
	}
	if agentID == "" || namespace == "" {
		return errUnauthorized
	}
	return nil
}

func subtleCompare(a, b string) bool {
	return hmac.Equal([]byte(a), []byte(b))
}
