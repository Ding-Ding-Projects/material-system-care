# IObit online tools

Official reference: [IObit online tools](https://www.iobit.com/en/products.php). Reviewed inventory baseline: 2026-10-08. This article records independent implementation requirements, not a claim of shipped parity.

Intended workspace: **Tools**. Configuration is local and operations follow the [engine protocol](../../contracts/engine-protocol.md). Each row in the [machine-readable ledger](../../contracts/capabilities.json) records API requirements, safety boundaries, implementation paths, tests and evidence. Empty proof lists mean unverified work.

| ID | Required capability | Current status | Limit or next requirement |
| --- | --- | --- | --- |
| `online.01` | Can I Run It | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `online.02` | Bottleneck Calculator | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `online.03` | Power Supply Calculator | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `online.04` | FPS Calculator | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `online.05` | Rate My PC | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `online.06` | Reaction Time Test | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `online.07` | Email Leak Checker | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `online.08` | Gamepad Tester | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `online.09` | Battery Test | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `online.10` | Sens Converter | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `online.11` | eDPI Calculator | unverified | Validated DPI × sensitivity arithmetic exists in engine; current desktop Tools does not expose this calculator. |
| `online.12` | Keyboard Latency Test | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `online.13` | Unlock PDF | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `online.14` | Metadata Remover | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `online.15` | PC Stress Test | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `online.16` | AI Photo Editor | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `online.17` | AI Math Solver | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `online.18` | AI Photo Enhancer | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `online.19` | AI Video Enhancer | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `online.20` | Background Remover | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `online.21` | Sound Test | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `online.22` | Keyboard Test | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `online.23` | Online Mic Test | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `online.24` | Online Webcam Test | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `online.25` | Online Password Generator | unverified | Cryptographic local generation only; no stored-password reading, password manager or cloud service. UI generation remains uncaptured. |
| `online.26` | Internet Speed Test | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |

## Configuration and safety

No scan grants permission to mutate the device. Mutations need the selected stable target, an explicit confirmation, cancellation where feasible, and a durable outcome record. Permissions, unsupported APIs, missing licensed engines and unavailable hardware telemetry must produce their actual reason. No advertisement, partner installation, unknown driver package or remote data upload may be silently introduced.

## Verification

Coverage structure is checked by `node tests/coverage/catalogue.test.mjs`. Passing that test proves inventory integrity only. The release completeness check is `node tests/coverage/catalogue.test.mjs --release`; it intentionally fails until every in-scope capability has linked code, focused tests and reviewed built-artifact evidence. Unit fixtures alone do not prove a visible workflow.
