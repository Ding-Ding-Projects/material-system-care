# Smart Defrag

Official reference: [Smart Defrag](https://www.iobit.com/product-manuals/sd-help/). Reviewed inventory baseline: 2026-10-08. This article records independent implementation requirements, not a claim of shipped parity.

Intended workspace: **Storage**. Configuration is local and operations follow the [engine protocol](../../contracts/engine-protocol.md). Each row in the [machine-readable ledger](../../contracts/capabilities.json) records API requirements, safety boundaries, implementation paths, tests and evidence. Empty proof lists mean unverified work.

| ID | Required capability | Current status | Limit or next requirement |
| --- | --- | --- | --- |
| `defrag.01` | Volume analysis | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `defrag.02` | Automatic method selection | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `defrag.03` | Fast HDD optimization | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `defrag.04` | HDD data optimization | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `defrag.05` | Large file optimization | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `defrag.06` | Free-space consolidation | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `defrag.07` | File prioritization | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `defrag.08` | Idle optimization | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `defrag.09` | Scheduled optimization | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `defrag.10` | SSD trim | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `defrag.11` | Mixed-media optimization | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `defrag.12` | Volume type detection | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `defrag.13` | Packaged application optimization | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `defrag.14` | Selected file optimization | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `defrag.15` | Pause and resume | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `defrag.16` | Operation report | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `defrag.17` | Drive health | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `defrag.18` | Game file optimization | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `defrag.19` | Boot-time pagefile optimization | excluded | Outside the Windows 11 user-mode, no-driver, no-remote-device release boundary or the no-power-action boundary. |
| `defrag.20` | Boot-time MFT optimization | excluded | Outside the Windows 11 user-mode, no-driver, no-remote-device release boundary or the no-power-action boundary. |
| `defrag.21` | Boot-time system file optimization | excluded | Outside the Windows 11 user-mode, no-driver, no-remote-device release boundary or the no-power-action boundary. |
| `defrag.22` | Boot-time registry optimization | excluded | Outside the Windows 11 user-mode, no-driver, no-remote-device release boundary or the no-power-action boundary. |
| `defrag.23` | Boot-time selected file optimization | excluded | Outside the Windows 11 user-mode, no-driver, no-remote-device release boundary or the no-power-action boundary. |

## Configuration and safety

No scan grants permission to mutate the device. Mutations need the selected stable target, an explicit confirmation, cancellation where feasible, and a durable outcome record. Permissions, unsupported APIs, missing licensed engines and unavailable hardware telemetry must produce their actual reason. No advertisement, partner installation, unknown driver package or remote data upload may be silently introduced.

## Verification

Coverage structure is checked by `node tests/coverage/catalogue.test.mjs`. Passing that test proves inventory integrity only. The release completeness check is `node tests/coverage/catalogue.test.mjs --release`; it intentionally fails until every in-scope capability has linked code, focused tests and reviewed built-artifact evidence. Unit fixtures alone do not prove a visible workflow.
