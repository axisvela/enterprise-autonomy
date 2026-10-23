package direct_test

import (
	"context"
	"strings"
	"testing"

	"github.com/axisvela/enterprise-autonomy/examples/a2a-agent-iam/internal/iamdemo"
)

func TestDirectGoogleADKAgentIAM(t *testing.T) {
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

	server := iamdemo.NewDirectServer(t, stack)
	defer server.Close()

	output, err := iamdemo.RunGoogleADK(ctx, server.URL, "Cancel order-1001", token, key)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(output, "approved: order-1001") {
		t.Fatalf("output = %q", output)
	}

	if _, err := iamdemo.RunGoogleADK(ctx, server.URL, "Cancel order-1002", token, key); err == nil {
		t.Fatal("expected AEGIVELA to deny order-1002")
	}
	if _, err := iamdemo.RunGoogleADK(ctx, server.URL, "Cancel order-1001", "wrong-token", key); err == nil {
		t.Fatal("expected EIDOVELA verification to reject an invalid token")
	}
}
