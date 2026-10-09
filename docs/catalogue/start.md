# Start Menu 8

Official reference: [Start Menu 8](https://www.iobit.com/product-manuals/sm8-help/). Reviewed inventory baseline: 2026-10-08. This article records independent implementation requirements, not a claim of shipped parity.

Intended workspace: **Launcher**. Configuration is local and operations follow the [engine protocol](../../contracts/engine-protocol.md). Each row in the [machine-readable ledger](../../contracts/capabilities.json) records API requirements, safety boundaries, implementation paths, tests and evidence. Empty proof lists mean unverified work.

| ID | Required capability | Current status | Limit or next requirement |
| --- | --- | --- | --- |
| `start.01` | Application launcher | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `start.02` | File and application search | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `start.03` | Pinned applications | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `start.04` | Launcher groups | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `start.05` | Custom launcher icon | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `start.06` | Launcher style | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `start.07` | Contextual application actions | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `start.08` | Taskbar customization | unimplemented | The reference targets older Windows shells. Only supported Windows 11 settings handoff is intended, with no shell injection. |
| `start.09` | Legacy shell replacement | excluded | Outside the Windows 11 user-mode, no-driver, no-remote-device release boundary or the no-power-action boundary. |
| `start.10` | Power menu handoff | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |

## Configuration and safety

No scan grants permission to mutate the device. Mutations need the selected stable target, an explicit confirmation, cancellation where feasible, and a durable outcome record. Permissions, unsupported APIs, missing licensed engines and unavailable hardware telemetry must produce their actual reason. No advertisement, partner installation, unknown driver package or remote data upload may be silently introduced.

## Verification

Coverage structure is checked by `node tests/coverage/catalogue.test.mjs`. Passing that test proves inventory integrity only. The release completeness check is `node tests/coverage/catalogue.test.mjs --release`; it intentionally fails until every in-scope capability has linked code, focused tests and reviewed built-artifact evidence. Unit fixtures alone do not prove a visible workflow.
