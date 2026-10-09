# Advanced SystemCare Free / Pro

Official reference: [Advanced SystemCare Free / Pro](https://www.iobit.com/product-manuals/asc-help/). Reviewed inventory baseline: 2026-10-08. This article records independent implementation requirements, not a claim of shipped parity.

Intended workspace: **Security**. Configuration is local and operations follow the [engine protocol](../../contracts/engine-protocol.md). Each row in the [machine-readable ledger](../../contracts/capabilities.json) records API requirements, safety boundaries, implementation paths, tests and evidence. Empty proof lists mean unverified work.

| ID | Required capability | Current status | Limit or next requirement |
| --- | --- | --- | --- |
| `asc-protect.01` | Protected file vault | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-protect.02` | Sensitive-data access review | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-protect.03` | Browser fingerprint controls | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-protect.04` | Tracking-data cleanup | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-protect.05` | Email risk warnings | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-protect.06` | Advertisement filtering | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-protect.07` | URL reputation | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-protect.08` | Homepage change alerts | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-protect.09` | Security settings handoff | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |

## Configuration and safety

No scan grants permission to mutate the device. Mutations need the selected stable target, an explicit confirmation, cancellation where feasible, and a durable outcome record. Permissions, unsupported APIs, missing licensed engines and unavailable hardware telemetry must produce their actual reason. No advertisement, partner installation, unknown driver package or remote data upload may be silently introduced.

## Verification

Coverage structure is checked by `node tests/coverage/catalogue.test.mjs`. Passing that test proves inventory integrity only. The release completeness check is `node tests/coverage/catalogue.test.mjs --release`; it intentionally fails until every in-scope capability has linked code, focused tests and reviewed built-artifact evidence. Unit fixtures alone do not prove a visible workflow.
