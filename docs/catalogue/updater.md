# IObit Software Updater

Official reference: [IObit Software Updater](https://www.iobit.com/product-manuals/isu-help/). Reviewed inventory baseline: 2026-10-08. This article records independent implementation requirements, not a claim of shipped parity.

Intended workspace: **Applications**. Configuration is local and operations follow the [engine protocol](../../contracts/engine-protocol.md). Each row in the [machine-readable ledger](../../contracts/capabilities.json) records API requirements, safety boundaries, implementation paths, tests and evidence. Empty proof lists mean unverified work.

| ID | Required capability | Current status | Limit or next requirement |
| --- | --- | --- | --- |
| `updater.01` | Installed version scan | unverified | Structured WinGet matches expose installed versions. Available update versions remain unchecked; no vendor database or complete update inventory is claimed. |
| `updater.02` | Selected application update | unverified | Discovered exact package IDs reach separately reviewed upgrade actions. Consent and cancellation fixtures pass; actual installation and built interaction evidence remain unverified. |
| `updater.03` | Batch application updates | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `updater.04` | Resumable downloads | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `updater.05` | Pre-update restore point | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `updater.06` | Per-application automatic updates | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `updater.07` | Ignored updates | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `updater.08` | Application recommendations | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `updater.09` | Selected application installation | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `updater.10` | System restore handoff | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |

## Configuration and safety

No scan grants permission to mutate the device. Mutations need the selected stable target, an explicit confirmation, cancellation where feasible, and a durable outcome record. Permissions, unsupported APIs, missing licensed engines and unavailable hardware telemetry must produce their actual reason. No advertisement, partner installation, unknown driver package or remote data upload may be silently introduced.

## Verification

Coverage structure is checked by `node tests/coverage/catalogue.test.mjs`. Passing that test proves inventory integrity only. The release completeness check is `node tests/coverage/catalogue.test.mjs --release`; it intentionally fails until every in-scope capability has linked code, focused tests and reviewed built-artifact evidence. Unit fixtures alone do not prove a visible workflow.
