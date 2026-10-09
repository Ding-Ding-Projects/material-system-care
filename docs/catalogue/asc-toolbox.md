# Advanced SystemCare toolbox

Official reference: [Advanced SystemCare toolbox](https://www.iobit.com/product-manuals/asc-help/). Reviewed inventory baseline: 2026-10-08. This article records independent implementation requirements, not a claim of shipped parity.

Intended workspace: **Toolbox**. Configuration is local and operations follow the [engine protocol](../../contracts/engine-protocol.md). Each row in the [machine-readable ledger](../../contracts/capabilities.json) records API requirements, safety boundaries, implementation paths, tests and evidence. Empty proof lists mean unverified work.

| ID | Required capability | Current status | Limit or next requirement |
| --- | --- | --- | --- |
| `asc-toolbox.01` | Smart RAM | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-toolbox.02` | Internet Booster | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-toolbox.03` | Program Deactivator | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-toolbox.04` | MyWin10 | unimplemented | The reference targets older Windows shells. Only supported Windows 11 settings handoff is intended, with no shell injection. |
| `asc-toolbox.05` | Registry Defrag | excluded | Outside the Windows 11 user-mode, no-driver, no-remote-device release boundary or the no-power-action boundary. |
| `asc-toolbox.06` | System Information | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-toolbox.07` | Auto Shutdown | excluded | Outside the Windows 11 user-mode, no-driver, no-remote-device release boundary or the no-power-action boundary. |
| `asc-toolbox.08` | Portable Version | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-toolbox.09` | Win Fix | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-toolbox.10` | FaceID | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-toolbox.11` | Context Menu Manager | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-toolbox.12` | Disk Doctor | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-toolbox.13` | System Control | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-toolbox.14` | Undelete | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-toolbox.15` | DNS Protector | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-toolbox.16` | Default Program | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-toolbox.17` | Registry Cleaner | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-toolbox.18` | Disk Cleaner | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-toolbox.19` | File Shredder | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-toolbox.20` | Empty Folder Scanner | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-toolbox.21` | Shortcut Fixer | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-toolbox.22` | Cloned File Scanner | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-toolbox.23` | Large File Finder | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-toolbox.24` | Process Manager | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |

## Configuration and safety

No scan grants permission to mutate the device. Mutations need the selected stable target, an explicit confirmation, cancellation where feasible, and a durable outcome record. Permissions, unsupported APIs, missing licensed engines and unavailable hardware telemetry must produce their actual reason. No advertisement, partner installation, unknown driver package or remote data upload may be silently introduced.

## Verification

Coverage structure is checked by `node tests/coverage/catalogue.test.mjs`. Passing that test proves inventory integrity only. The release completeness check is `node tests/coverage/catalogue.test.mjs --release`; it intentionally fails until every in-scope capability has linked code, focused tests and reviewed built-artifact evidence. Unit fixtures alone do not prove a visible workflow.
