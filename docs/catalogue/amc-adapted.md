# AMC Security capability adaptations

Official reference: [AMC Security capability adaptations](https://www.iobit.com/product-manuals/amc-help/). Reviewed inventory baseline: 2026-10-08. This article records independent implementation requirements, not a claim of shipped parity.

Intended workspace: **Security**. Configuration is local and operations follow the [engine protocol](../../contracts/engine-protocol.md). Each row in the [machine-readable ledger](../../contracts/capabilities.json) records API requirements, safety boundaries, implementation paths, tests and evidence. Empty proof lists mean unverified work.

| ID | Required capability | Current status | Limit or next requirement |
| --- | --- | --- | --- |
| `amc-adapted.01` | Combined maintenance plan | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |
| `amc-adapted.02` | Resource pressure review | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |
| `amc-adapted.03` | Antivirus handoff | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |
| `amc-adapted.04` | Payment risk guidance | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |
| `amc-adapted.05` | Phishing warnings | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |
| `amc-adapted.06` | Browsing risk review | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |
| `amc-adapted.07` | Local security configuration | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |
| `amc-adapted.08` | Application management | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |
| `amc-adapted.09` | Battery report | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |
| `amc-adapted.10` | Private file vault | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |
| `amc-adapted.11` | Application permission advisor | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |
| `amc-adapted.12` | Game launch profile | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |
| `amc-adapted.13` | Desktop widgets | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |
| `amc-adapted.14` | Remote anti-theft | excluded | Outside the Windows 11 user-mode, no-driver, no-remote-device release boundary or the no-power-action boundary. |
| `amc-adapted.15` | Call and SMS blocking | excluded | Outside the Windows 11 user-mode, no-driver, no-remote-device release boundary or the no-power-action boundary. |
| `amc-adapted.16` | Android package management | excluded | Outside the Windows 11 user-mode, no-driver, no-remote-device release boundary or the no-power-action boundary. |

## Configuration and safety

No scan grants permission to mutate the device. Mutations need the selected stable target, an explicit confirmation, cancellation where feasible, and a durable outcome record. Permissions, unsupported APIs, missing licensed engines and unavailable hardware telemetry must produce their actual reason. No advertisement, partner installation, unknown driver package or remote data upload may be silently introduced.

## Verification

Coverage structure is checked by `node tests/coverage/catalogue.test.mjs`. Passing that test proves inventory integrity only. The release completeness check is `node tests/coverage/catalogue.test.mjs --release`; it intentionally fails until every in-scope capability has linked code, focused tests and reviewed built-artifact evidence. Unit fixtures alone do not prove a visible workflow.
