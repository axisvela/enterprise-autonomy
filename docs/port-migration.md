# Port Migration Guide

Most products historically defaulted to `:8080`. New and future deployments use the planned allocation described in the [technical catalog](technical-catalog.md#port-allocation-from-1806).

## Allocation Model

Each product owns a block of ten consecutive ports starting at `1806 + productIndex × 10`, giving up to nine listener addresses per product for API, console, and auxiliary planes.

| Block | Product | Allocated |
| --- | --- | --- |
| 1806–1815 | Moduregis | `1806` API · `1807` console |
| 1816–1825 | Orchadyn | `1816` API |
| 1826–1835 | Noetivela | `1826` gateway · `1827` controller |
| 1836–1845 | Gnosivela | `1836` API |
| 1846–1855 | Mnemovela | `1846` HTTP · `1847` gRPC |
| 1856–1865 | Ontovela | `1856` API |
| 1866–1875 | Praxovela | `1866` AXON |
| 1876–1885 | Rheovela | `1876` serve · `1877` console |
| 1886–1895 | Aegivela | `1886` core · `1887` EE |
| 1896–1905 | Limenora | `1896` edge · `1897` enterprise · `1898` control |
| 1906–1915 | Peiravela | `1906` API |
| 1916–1925 | Tekmovela | `1916` reserved |
| 1926–1935 | Symbivela | `1926` API |
| 1936–1945 | Harmovela | `1936` WS · `1937` SSE · `1938` API |
| 1946–1955 | Kinetovela | `1946` API |
| 1956–1965 | Nomivela | `1956` API |
| 1966–1975 | Eidovela | `1966` API |

## Rules

- Use the next free port inside a product's block before extending into a later block.
- Do not reuse `8080`-style defaults in new deployments; the planned ports are authoritative going forward.
- Reserve the last slot of each block for future needs; document any occupation in the technical catalog table.

## Env-var Overrides

Current binaries keep their documented override variables (for example `LISTEN_ADDR`, `ORCHADYN_LISTEN_ADDR`, `NOETIVELA_ADDR`, `AXON_PORT`, `NOMIVELA_HTTP_PORT`, `AEPD_*_PORT`). Set these to the planned ports when standing up new deployments. Nomivela now defaults to `1956` (`NOMIVELA_HTTP_PORT`).

## Local Demos

The runnable local demos exercise the planned allocation where the product binaries support it: Moduregis (`1806`), Orchadyn (`1816`), Symbivela (`1926`), and Limenora edge (`1896`) ship those defaults, and the demo stack explicitly overrides Ontovela (`--addr :1856`), Rheovela (`--addr :1876`), and Praxovela (`AXON_PORT=1866`) onto their planned ports. The reference adapters use `8090`–`8103`. No demo service occupies `8080`. See the [local run handbook](../examples/local-run-handbook.md) and [release status](release-status.md#port-migration-status) for the per-product tracking.
