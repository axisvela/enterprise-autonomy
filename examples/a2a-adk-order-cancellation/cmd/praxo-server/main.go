package main

import (
	"flag"
	"log"
	"net"
	"net/http"
	"os"

	sdk "github.com/a2aproject/a2a-go/v2/a2a"
	ordera2a "github.com/axisvela/enterprise-autonomy/examples/a2a-adk-order-cancellation"
)

func main() {
	addr := flag.String("addr", "127.0.0.1:8091", "listen address")
	flag.Parse()

	agent, err := ordera2a.NewOrderAgent()
	if err != nil {
		log.Fatal(err)
	}
	listener, err := net.Listen("tcp", *addr)
	if err != nil {
		log.Fatal(err)
	}
	baseURL := "http://" + listener.Addr().String()
	token := os.Getenv("PRAXO_A2A_TOKEN")
	mux := ordera2a.NewMux(agent, token, func() *sdk.AgentCard {
		return ordera2a.NewCard(baseURL+"/invoke", token)
	})
	log.Printf("PRAXO A2A order service listening on %s", baseURL)
	log.Fatal(http.Serve(listener, mux))
}
