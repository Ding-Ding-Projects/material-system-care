# Advanced SystemCare Ultimate

Official reference: [Advanced SystemCare Ultimate](https://www.iobit.com/product-manuals/asc-ultimate-help/). Reviewed inventory baseline: 2026-10-08. This article records independent implementation requirements, not a claim of shipped parity.

Intended workspace: **Security**. Configuration is local and operations follow the [engine protocol](../../contracts/engine-protocol.md). Each row in the [machine-readable ledger](../../contracts/capabilities.json) records API requirements, safety boundaries, implementation paths, tests and evidence. Empty proof lists mean unverified work.

| ID | Required capability | Current status | Limit or next requirement |
| --- | --- | --- | --- |
| `ultimate.01` | Quick antivirus scan | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `ultimate.02` | Full antivirus scan | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `ultimate.03` | Custom antivirus scan | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `ultimate.04` | Explorer scan handoff | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `ultimate.05` | Definition freshness | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `ultimate.06` | Real-time antivirus status | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `ultimate.07` | Quarantine review | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `ultimate.08` | Threat exclusions | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `ultimate.09` | Scan report export | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `ultimate.10` | Antivirus engine integration | unavailable | The proprietary vendor engine is not licensed or bundled. Windows Security integration is a different implementation and cannot prove engine parity. |

## Configuration and safety

No scan grants permission to mutate the device. Mutations need the selected stable target, an explicit confirmation, cancellation where feasible, and a durable outcome record. Permissions, unsupported APIs, missing licensed engines and unavailable hardware telemetry must produce their actual reason. No advertisement, partner installation, unknown driver package or remote data upload may be silently introduced.

## Verification

Coverage structure is checked by `node tests/coverage/catalogue.test.mjs`. Passing that test proves inventory integrity only. The release completeness check is `node tests/coverage/catalogue.test.mjs --release`; it intentionally fails until every in-scope capability has linked code, focused tests and reviewed built-artifact evidence. Unit fixtures alone do not prove a visible workflow.
