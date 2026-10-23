# LIMENORA-Fronted A2A Agent IAM

The LIMENORA path puts a governed gateway in front of the PRAXO-CORE A2A server.

## Flow

1. The Google ADK checkout agent is registered in NOMIVELA and enrolled with
   EIDOVELA, exactly as in the direct example.
2. Google ADK calls the LIMENORA-shaped gateway with the EIDOVELA token and a
   DPoP proof.
3. The gateway verifies the proof and token, resolves the NOMIVELA Registry
   Context, and calls AEGIVELA.
4. A non-`allow` decision stops at the gateway; the PRAXO-CORE upstream is not
   called.
5. An allowed request is forwarded with a signed, short-lived verified context.
   The PRAXO-CORE upstream verifies the gateway signature and executes without
   re-reading the caller credential.

## Run

```powershell
$env:GOWORK = "off"
go test -count=1 ./limenora -v
```

The test covers:

- gateway-side EIDOVELA/NOMIVELA verification;
- AEGIVELA allowing `order-1001`;
- AEGIVELA denying `order-1002` before the upstream is called;
- an invalid token rejected by the gateway; and
- PRAXO-CORE hit counting for the denial path.

The gateway is a local reverse proxy that mirrors the LIMENORA trust split. It
is not a deployment of the current LIMENORA binary; see the
[parent README](../README.md) for the evidence boundary.
