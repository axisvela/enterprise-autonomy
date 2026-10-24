package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/axisvela/aegivela-open/sdk/go/v3/pepsdk"
)

func main() {
	assertion := flag.String("assertion", os.Getenv("AEGIVELA_WORKLOAD_ASSERTION"), "AEGIVELA workload assertion")
	agentID := flag.String("agent", "", "NOMIVELA Agent ID")
	instanceID := flag.String("instance", "", "EIDOVELA instance ID")
	agentRef := flag.String("agent-ref", "agent_google_adk_checkout", "Agent reference")
	workloadRef := flag.String("workload", "workload-adk-1", "AEGIVELA workload reference")
	namespace := flag.String("namespace", "https://registry.a2a-iam.test", "NOMIVELA namespace")
	audience := flag.String("audience", "praxo-a2a", "A2A audience")
	tenant := flag.String("tenant", "demo", "tenant")
	token := flag.String("internal-token", "dev-aegivela-token", "AEGIVELA internal token")
	baseURL := flag.String("aegivela", "http://127.0.0.1:1886", "AEGIVELA base URL")
	mode := flag.String("mode", "service", "service or system")
	flag.Parse()
	if *assertion == "" || *agentID == "" || *instanceID == "" {
		log.Fatal("assertion, agent, and instance are required")
	}

	client := pepsdk.NewClient(*baseURL, http.DefaultClient, pepsdk.WithHeaders(map[string]string{
		"X-Aegivela-Internal-Token": *token,
		"X-Aegivela-Tenant-ID":      *tenant,
		"X-Aegivela-Actor-ID":       *agentRef,
		"X-Aegivela-Authority-Root": "root:demo",
	}))
	agentEpoch := int64(4)
	identityEpoch := int64(3)
	task := "task-order-1001"
	parent := &pepsdk.ParentAuthority{
		AuthorityRef: "root:demo",
		Scope:        []string{"order:cancel"},
		Audience:     []string{*audience},
		ExpiresAt:    time.Now().Add(5 * time.Minute),
		TaskBinding:  task,
	}
	route := pepsdk.Route{
		Audience: *audience, Action: "order:cancel", Scope: []string{"order:cancel"},
		Kind: "order", Reference: "order-1001",
	}
	if *mode == "system" {
		result, err := client.Evaluate(context.Background(), route, pepsdk.AuthorizationInput{
			Mode: pepsdk.ModeSystemAPI, WorkloadAssertion: *assertion,
		})
		if err != nil {
			fmt.Printf("error: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("outcome=%s decision=%s policy=%s\n", result.Outcome, result.DecisionID, result.PolicyVersion)
		return
	}
	result, err := client.Evaluate(context.Background(), route, pepsdk.AuthorizationInput{
		APIVersion:        pepsdk.APIVersionV2,
		Mode:              pepsdk.ModeServiceAgentAPI,
		WorkloadAssertion: *assertion,
		TaskBinding:       task,
		ParentAuthority:   parent,
		Principal: &pepsdk.PolicyPrincipalV2{
			Namespace: *namespace, ActorRef: *agentID, WorkloadRef: *workloadRef,
			AgentID: *agentID, AgentClass: "service",
			OrganizationAuthorityRoot: "root:demo", AuthorityBinding: "organizationRoot",
			AgentEpoch: &agentEpoch, IdentityEpoch: &identityEpoch, InstanceID: *instanceID,
		},
	})
	if err != nil {
		fmt.Printf("error: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("outcome=%s decision=%s policy=%s\n", result.Outcome, result.DecisionID, result.PolicyVersion)
}
