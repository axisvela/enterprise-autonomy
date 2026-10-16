package main

// genkeys writes the Ed25519 PKCS#8 PEM signing keys aegivela-api requires at
// startup (and an audience registry) into a directory. Dev-only: the keys are
// generated locally and never leave the machine.
//
// usage: go run ./tools/genkeys <outDir>
//
// It is deliberately stdlib-only so it runs with GOWORK=off and no dependencies.

import (
	"crypto/ed25519"
	"crypto/rand"
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"os"
	"path/filepath"
)

var keys = []string{
	"policy-decision",
	"execution-grant",
	"workload-assertion",
	"attestation",
	"approval-artifact",
}

const audienceRegistry = `{
  "audiences": [
    { "audience": "rheovela", "description": "local bridge E2E", "max_ttl_seconds": 600 },
    { "audience": "praxovela", "description": "local acceptance", "max_ttl_seconds": 600 }
  ]
}
`

func main() {
	if len(os.Args) < 2 {
		fmt.Println("usage: genkeys <outDir>")
		os.Exit(2)
	}
	dir := os.Args[1]
	if err := os.MkdirAll(dir, 0o700); err != nil {
		fmt.Println("mkdir:", err)
		os.Exit(1)
	}
	for _, name := range keys {
		path := filepath.Join(dir, name+".pem")
		if _, err := os.Stat(path); err == nil {
			fmt.Println("keep", path)
			continue
		}
		_, priv, err := ed25519.GenerateKey(rand.Reader)
		if err != nil {
			fmt.Println("keygen:", err)
			os.Exit(1)
		}
		der, err := x509.MarshalPKCS8PrivateKey(priv)
		if err != nil {
			fmt.Println("marshal:", err)
			os.Exit(1)
		}
		if err := os.WriteFile(path, pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der}), 0o600); err != nil {
			fmt.Println("write:", err)
			os.Exit(1)
		}
		fmt.Println("wrote", path)
	}
	reg := filepath.Join(dir, "audiences.json")
	if _, err := os.Stat(reg); err != nil {
		if err := os.WriteFile(reg, []byte(audienceRegistry), 0o600); err != nil {
			fmt.Println("write registry:", err)
			os.Exit(1)
		}
		fmt.Println("wrote", reg)
	}
}
