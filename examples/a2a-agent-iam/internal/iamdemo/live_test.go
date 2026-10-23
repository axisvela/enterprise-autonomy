package iamdemo

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	sdk "github.com/a2aproject/a2a-go/v2/a2a"
)

func TestLiveMuxRejectsMissingToken(t *testing.T) {
	mux := NewLiveMux(mustOrderAgent(t), "http://127.0.0.1:1", "http://127.0.0.1:1", "http://127.0.0.1:1", "assertion", func() *sdk.AgentCard {
		return NewCard("http://example.test/invoke")
	})
	request := httptest.NewRequest(http.MethodPost, "/invoke", strings.NewReader(`{}`))
	response := httptest.NewRecorder()

	mux.ServeHTTP(response, request)

	if response.Code != http.StatusUnauthorized {
		t.Fatalf("status=%d body=%s", response.Code, response.Body.String())
	}
}
