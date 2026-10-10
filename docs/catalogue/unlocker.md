# IObit Unlocker

Official reference: [IObit Unlocker](https://www.iobit.com/product-manuals/unlocker-help/). Reviewed inventory baseline: 2026-10-08. This article records independent implementation requirements, not a claim of shipped parity.

Intended workspace: **Files**. Configuration is local and operations follow the [engine protocol](../../contracts/engine-protocol.md). Each row in the [machine-readable ledger](../../contracts/capabilities.json) records API requirements, safety boundaries, implementation paths, tests and evidence. Empty proof lists mean unverified work.

| ID | Required capability | Current status | Limit or next requirement |
| --- | --- | --- | --- |
| `unlocker.01` | Lock owner diagnostics | unverified | Restart Manager diagnostic reports affected processes; no handle closure, complete handle inventory or unlock mutation. No desktop action is currently linked. |
| `unlocker.02` | Cooperative file release | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `unlocker.03` | Unlock and delete | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `unlocker.04` | Unlock and rename | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `unlocker.05` | Unlock and move | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `unlocker.06` | Unlock and copy | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `unlocker.07` | Forced process termination | excluded | Outside the Windows 11 user-mode, no-driver, no-remote-device release boundary or the no-power-action boundary. |

## Configuration and safety

No scan grants permission to mutate the device. Mutations need the selected stable target, an explicit confirmation, cancellation where feasible, and a durable outcome record. Permissions, unsupported APIs, missing licensed engines and unavailable hardware telemetry must produce their actual reason. No advertisement, partner installation, unknown driver package or remote data upload may be silently introduced.

## Verification

Coverage structure is checked by `node tests/coverage/catalogue.test.mjs`. Passing that test proves inventory integrity only. The release completeness check is `node tests/coverage/catalogue.test.mjs --release`; it intentionally fails until every in-scope capability has linked code, focused tests and reviewed built-artifact evidence. Unit fixtures alone do not prove a visible workflow.

## Read-only workspace progress

Tools > File use now exposes the existing Restart Manager query through explicit file selection, correlated results and advisory empty state. Focused widget checks, root builds and one owned-fixture empty-result interaction are recorded. Native picker, populated owner records, full surface contracts, handle closure and unlock mutations are not established. See [workflow documentation](../features/protection/file-use.md).
