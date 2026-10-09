# Driver Booster Free / Pro

Official reference: [Driver Booster Free / Pro](https://www.iobit.com/product-manuals/db-help/). Reviewed inventory baseline: 2026-10-08. This article records independent implementation requirements, not a claim of shipped parity.

Intended workspace: **Drivers**. Configuration is local and operations follow the [engine protocol](../../contracts/engine-protocol.md). Each row in the [machine-readable ledger](../../contracts/capabilities.json) records API requirements, safety boundaries, implementation paths, tests and evidence. Empty proof lists mean unverified work.

| ID | Required capability | Current status | Limit or next requirement |
| --- | --- | --- | --- |
| `drivers.01` | Outdated driver discovery | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.02` | Missing device drivers | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.03` | Faulty device diagnostics | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.04` | Game component inventory | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.05` | Selected driver updates | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.06` | Batch driver updates | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.07` | Resumable package download | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.08` | Restore point creation | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.09` | Driver backup | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.10` | Driver restore | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.11` | Driver rollback | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.12` | Driver removal | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.13` | Offline driver packages | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.14` | Idle update scheduling | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.15` | Audio troubleshooting | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.16` | Device problem codes | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.17` | Disconnected device review | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.18` | Network troubleshooting | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.19` | Display troubleshooting | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.20` | Missing game components | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.21` | Incompatible drivers | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.22` | Hardware information | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.23` | Boost profile handoff | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.24` | Scan priority | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `drivers.25` | Update exclusions | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |

## Configuration and safety

No scan grants permission to mutate the device. Mutations need the selected stable target, an explicit confirmation, cancellation where feasible, and a durable outcome record. Permissions, unsupported APIs, missing licensed engines and unavailable hardware telemetry must produce their actual reason. No advertisement, partner installation, unknown driver package or remote data upload may be silently introduced.

## Verification

Coverage structure is checked by `node tests/coverage/catalogue.test.mjs`. Passing that test proves inventory integrity only. The release completeness check is `node tests/coverage/catalogue.test.mjs --release`; it intentionally fails until every in-scope capability has linked code, focused tests and reviewed built-artifact evidence. Unit fixtures alone do not prove a visible workflow.
