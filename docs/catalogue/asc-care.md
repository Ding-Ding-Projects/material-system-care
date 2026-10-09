# Advanced SystemCare Free / Pro

Official reference: [Advanced SystemCare Free / Pro](https://www.iobit.com/product-manuals/asc-help/). Reviewed inventory baseline: 2026-10-08. This article records independent implementation requirements, not a claim of shipped parity.

Intended workspace: **Care**. Configuration is local and operations follow the [engine protocol](../../contracts/engine-protocol.md). Each row in the [machine-readable ledger](../../contracts/capabilities.json) records API requirements, safety boundaries, implementation paths, tests and evidence. Empty proof lists mean unverified work.

| ID | Required capability | Current status | Limit or next requirement |
| --- | --- | --- | --- |
| `asc-care.01` | Privacy traces | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-care.02` | Temporary files | unverified | Only aged current-user temporary files in a server-issued recoverable plan; no browser privacy sweep, system-wide disk cleaner or all-user cleanup. |
| `asc-care.03` | Broken shortcuts | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-care.04` | Registry review | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-care.05` | System settings review | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-care.06` | Network diagnostics | unverified | Bounded interface, DNS and one ICMP check; no speed measurement or TCP optimization. |
| `asc-care.07` | Registry compaction | excluded | Outside the Windows 11 user-mode, no-driver, no-remote-device release boundary or the no-power-action boundary. |
| `asc-care.08` | Disk optimization | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-care.09` | Antivirus status | unverified | Reads actual Defender status through supported Windows tooling; no independent antivirus protection engine. |
| `asc-care.10` | Firewall status | unverified | Reads firewall profiles; does not enable, disable or edit firewall rules. |
| `asc-care.11` | Device health | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-care.12` | Application health | unverified | Returns WinGet text output without guessed package records; no normalized per-application update model or vendor database. |
| `asc-care.13` | Spyware scan | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-care.14` | Security configuration | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-care.15` | Windows patches | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-care.16` | Disk integrity | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-care.17` | Manual scan selection | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-care.18` | Adaptive scan recommendations | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-care.19` | Scan exclusions | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `asc-care.20` | Recovery history | unverified | Cleanup receipts only; no registry, driver or arbitrary settings rescue center. |

## Configuration and safety

No scan grants permission to mutate the device. Mutations need the selected stable target, an explicit confirmation, cancellation where feasible, and a durable outcome record. Permissions, unsupported APIs, missing licensed engines and unavailable hardware telemetry must produce their actual reason. No advertisement, partner installation, unknown driver package or remote data upload may be silently introduced.

## Verification

Coverage structure is checked by `node tests/coverage/catalogue.test.mjs`. Passing that test proves inventory integrity only. The release completeness check is `node tests/coverage/catalogue.test.mjs --release`; it intentionally fails until every in-scope capability has linked code, focused tests and reviewed built-artifact evidence. Unit fixtures alone do not prove a visible workflow.
