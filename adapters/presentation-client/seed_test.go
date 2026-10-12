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
