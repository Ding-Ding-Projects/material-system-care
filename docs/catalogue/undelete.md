# IObit Undelete

Official reference: [IObit Undelete](https://www.iobit.com/en/iobitundelete.php). Reviewed inventory baseline: 2026-10-08. This article records independent implementation requirements, not a claim of shipped parity.

Intended workspace: **Recovery**. Configuration is local and operations follow the [engine protocol](../../contracts/engine-protocol.md). Each row in the [machine-readable ledger](../../contracts/capabilities.json) records API requirements, safety boundaries, implementation paths, tests and evidence. Empty proof lists mean unverified work.

| ID | Required capability | Current status | Limit or next requirement |
| --- | --- | --- | --- |
| `undelete.01` | Deleted file discovery | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `undelete.02` | Targeted recovery scan | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `undelete.03` | Deep recovery scan | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `undelete.04` | Recoverability estimate | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `undelete.05` | Selected file recovery | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `undelete.06` | External drive recovery | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |

## Configuration and safety

No scan grants permission to mutate the device. Mutations need the selected stable target, an explicit confirmation, cancellation where feasible, and a durable outcome record. Permissions, unsupported APIs, missing licensed engines and unavailable hardware telemetry must produce their actual reason. No advertisement, partner installation, unknown driver package or remote data upload may be silently introduced.

## Verification

Coverage structure is checked by `node tests/coverage/catalogue.test.mjs`. Passing that test proves inventory integrity only. The release completeness check is `node tests/coverage/catalogue.test.mjs --release`; it intentionally fails until every in-scope capability has linked code, focused tests and reviewed built-artifact evidence. Unit fixtures alone do not prove a visible workflow.
