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
| `asc-toolbox.06` | System Information | unverified | Logical processor count, operating-system description, physical-memory state and drive capacities only; no complete motherboard, GPU, sensor or device inventory. |
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
| `asc-toolbox.18` | Disk Cleaner | unverified | Only aged current-user temporary files in a server-issued recoverable plan; no browser privacy sweep, system-wide disk cleaner or all-user cleanup. |
| `asc-toolbox.19` | File Shredder | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-toolbox.20` | Empty Folder Scanner | unverified | Reports selected-root empty directories; does not delete them. |
| `asc-toolbox.21` | Shortcut Fixer | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-toolbox.22` | Cloned File Scanner | unverified | Bounded selected-folder SHA-256 plus byte-comparison groups; read-only, no automatic duplicate deletion. |
| `asc-toolbox.23` | Large File Finder | unverified | Largest 100 files within a bounded selected-root scan; no deletion or complete all-drive inventory. |
| `asc-toolbox.24` | Process Manager | unverified | Process working-set and cumulative CPU records plus same-user interactive graceful-close request. No forced termination, RAM recycling, service mutation or boost guarantee. |

## Configuration and safety

No scan grants permission to mutate the device. Mutations need the selected stable target, an explicit confirmation, cancellation where feasible, and a durable outcome record. Permissions, unsupported APIs, missing licensed engines and unavailable hardware telemetry must produce their actual reason. No advertisement, partner installation, unknown driver package or remote data upload may be silently introduced.

## Verification

Coverage structure is checked by `node tests/coverage/catalogue.test.mjs`. Passing that test proves inventory integrity only. The release completeness check is `node tests/coverage/catalogue.test.mjs --release`; it intentionally fails until every in-scope capability has linked code, focused tests and reviewed built-artifact evidence. Unit fixtures alone do not prove a visible workflow.

## Process Manager evidence update

`asc-toolbox.24` now links the dedicated Tools > Processes workspace, focused Flutter fixtures, inspected idle frame, measured read-only inventory and owned-fixture close-request/absence evidence. Its status remains unverified because this bounded evidence does not complete the appearance, input, rejection or arbitrary-application matrix. See [process workflow](../features/management/processes.md).
