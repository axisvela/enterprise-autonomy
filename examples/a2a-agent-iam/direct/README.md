# Direct A2A Agent IAM

The direct path has no gateway. Google ADK calls the PRAXO-CORE A2A JSON-RPC
server directly.

## Flow

1. The Google ADK checkout agent is registered in NOMIVELA as a service Agent,
   Agent Identity, and Workload Registration, then activated.
2. EIDOVELA enrolls the workload key and issues a short-lived token bound to the
   key's `cnf.jkt`.
3. Google ADK signs a DPoP proof for the A2A request and sends the EIDOVELA
   token, proof, and public key.
4. The PRAXO-CORE add-in verifies the DPoP proof and token through EIDOVELA
   JWKS, resolves the NOMIVELA Registry Context, and rejects inactive records.
5. AEGIVELA evaluates `order:cancel` for the requested order using the verified
   Agent IAM context.
6. Only an `allow` decision reaches the PRAXO-CORE executor.

## Run

```powershell
$env:GOWORK = "off"
go test -count=1 ./direct -v
```

The test covers:

- EIDOVELA token and DPoP proof accepted;
- NOMIVELA active Agent/Identity context accepted;
- AEGIVELA allows `order-1001`;
- AEGIVELA denies `order-1002`; and
- an invalid token is rejected before AEGIVELA or the executor.

The IAM services are local contract fakes driven through their real Go SDKs.
See the [parent README](../README.md) for the evidence boundary.
