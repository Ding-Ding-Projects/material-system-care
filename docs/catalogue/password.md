# Random Password Generator

Official reference: [Random Password Generator](https://www.iobit.com/en/passwordgenerator.php). Reviewed inventory baseline: 2026-10-08. This article records independent implementation requirements, not a claim of shipped parity.

Intended workspace: **Privacy**. Configuration is local and operations follow the [engine protocol](../../contracts/engine-protocol.md). Each row in the [machine-readable ledger](../../contracts/capabilities.json) records API requirements, safety boundaries, implementation paths, tests and evidence. Empty proof lists mean unverified work.

| ID | Required capability | Current status | Limit or next requirement |
| --- | --- | --- | --- |
| `password.01` | Cryptographic password generation | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `password.02` | Password character policy | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `password.03` | Password strength explanation | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `password.04` | Local generated-secret storage | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |

## Configuration and safety

No scan grants permission to mutate the device. Mutations need the selected stable target, an explicit confirmation, cancellation where feasible, and a durable outcome record. Permissions, unsupported APIs, missing licensed engines and unavailable hardware telemetry must produce their actual reason. No advertisement, partner installation, unknown driver package or remote data upload may be silently introduced.

## Verification

Coverage structure is checked by `node tests/coverage/catalogue.test.mjs`. Passing that test proves inventory integrity only. The release completeness check is `node tests/coverage/catalogue.test.mjs --release`; it intentionally fails until every in-scope capability has linked code, focused tests and reviewed built-artifact evidence. Unit fixtures alone do not prove a visible workflow.
