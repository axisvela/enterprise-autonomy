package limenora_test

import (
	"context"
	"strings"
	"testing"

	"github.com/axisvela/enterprise-autonomy/examples/a2a-agent-iam/internal/iamdemo"
)

func TestLIMENORAFrontedGoogleADKAgentIAM(t *testing.T) {
	stack := iamdemo.NewStack()
	defer stack.Close()

	ctx := context.Background()
	agentID, workloadID, err := stack.RegisterGoogleADKAgent(ctx)
	if err != nil {
		t.Fatal(err)
	}
	token, key, err := stack.Enroll(ctx, agentID, workloadID)
	if err != nil {
		t.Fatal(err)
	}

	gateway, hits := iamdemo.NewGateway(t, stack, "gateway-secret")
	defer gateway.Close()

	output, err := iamdemo.RunGoogleADK(ctx, gateway.URL, "Cancel order-1001", token, key)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(output, "approved: order-1001") {
		t.Fatalf("output = %q", output)
	}
	if *hits != 1 {
		t.Fatalf("PRAXO hits = %d, want 1", *hits)
	}

	if _, err := iamdemo.RunGoogleADK(ctx, gateway.URL, "Cancel order-1002", token, key); err == nil {
		t.Fatal("expected the gateway to deny order-1002")
	}
	if *hits != 1 {
		t.Fatalf("denied request reached PRAXO: hits = %d", *hits)
	}
	if _, err := iamdemo.RunGoogleADK(ctx, gateway.URL, "Cancel order-1001", "wrong-token", key); err == nil {
		t.Fatal("expected the gateway to reject an invalid token")
	}
}
