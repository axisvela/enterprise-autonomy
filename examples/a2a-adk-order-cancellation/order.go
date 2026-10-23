package ordera2a

import (
	"context"
	"fmt"
	"strings"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

const (
	approvedOrder = "order-1001"
	deniedOrder   = "order-1002"
)

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

func newOrderAgent() (*agent.Agent, error) {
	return agent.New(agent.Options{Model: eligibilityModel{}, MaxSteps: 1})
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
