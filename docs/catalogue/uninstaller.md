# IObit Uninstaller Free / Pro

Official reference: [IObit Uninstaller Free / Pro](https://www.iobit.com/product-manuals/iu-help/). Reviewed inventory baseline: 2026-10-08. This article records independent implementation requirements, not a claim of shipped parity.

Intended workspace: **Applications**. Configuration is local and operations follow the [engine protocol](../../contracts/engine-protocol.md). Each row in the [machine-readable ledger](../../contracts/capabilities.json) records API requirements, safety boundaries, implementation paths, tests and evidence. Empty proof lists mean unverified work.

| ID | Required capability | Current status | Limit or next requirement |
| --- | --- | --- | --- |
| `uninstaller.01` | Installed application inventory | unverified | Registry and current-user AppX inventory plus explicit structured WinGet matches. Unmatched packages remain separate; AppX removal and complete built interaction evidence are unavailable. |
| `uninstaller.02` | Batch uninstall | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.03` | Bundle detection | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.04` | Installation change journal | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.05` | Large application filter | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.06` | Infrequent application filter | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.07` | Application repair | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.08` | Leftover review | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.09` | Uninstall history | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.10` | Application list export | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.11` | Outdated software review | unverified | Returns WinGet text output without guessed package records; no normalized per-application update model or vendor database. |
| `uninstaller.12` | Redundant application data | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.13` | Application hibernation | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.14` | Permission review | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.15` | Notification review | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.16` | Broken uninstall recovery | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.17` | Installer file review | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.18` | Malicious extension review | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.19` | Browser extension inventory | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.20` | Extension removal handoff | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.21` | Extension ratings | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.22` | Packaged application removal | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.23` | Packaged application ratings | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.24` | Automatic install monitoring | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.25` | Manual install monitoring | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.26` | Window-target uninstall | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.27` | Force uninstall review | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.28` | Stubborn program review | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.29` | File shredding | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.30` | Application relocation | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.31` | Bloatware review | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `uninstaller.32` | Windows update removal | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |

## Configuration and safety

No scan grants permission to mutate the device. Mutations need the selected stable target, an explicit confirmation, cancellation where feasible, and a durable outcome record. Permissions, unsupported APIs, missing licensed engines and unavailable hardware telemetry must produce their actual reason. No advertisement, partner installation, unknown driver package or remote data upload may be silently introduced.

## Verification

Coverage structure is checked by `node tests/coverage/catalogue.test.mjs`. Passing that test proves inventory integrity only. The release completeness check is `node tests/coverage/catalogue.test.mjs --release`; it intentionally fails until every in-scope capability has linked code, focused tests and reviewed built-artifact evidence. Unit fixtures alone do not prove a visible workflow.
