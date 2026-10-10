# Captured application frames

| ID | Producer | Scope | State |
| --- | --- | --- | --- |
| `diagnostics-idle-en-light-1264x681` | `cfa86ebb78312984a90ccd26b814f4a4d00a58e9` | Actual painted Flutter frame, render-only | Diagnostic workspace, idle, English, light, 1264 × 681, scale 1 |

![Built blue-screen diagnostics workspace, idle, English and light theme](diagnostics-idle.png)

[Source and byte receipt](diagnostics-idle.json). The built native application ran on an isolated Lowlevel desktop with default preferences. The original PNG is retained unchanged. It is not a mock or reconstructed interface, but neither is it a native-compositor screenshot. The separate stop-code interaction below passed. Live event collection and the complete layout matrix are not established by these frames. The exact capture instant is unavailable; the receipt records a separately observed time.

`scripts/verify-render-frame.mjs` validates this narrow alternative route against the original owned run, producer receipt, current built bundle, PNG bytes, privacy declarations and teardown record. It does not pass the separate native-window evidence gate or change any capability to fully runtime-verified.

## Observed stop-code interaction

![Completed local stop-code explanation](diagnostics-explained.png)

[Interaction receipt](diagnostics-explained.json): source `cfa86ebb78312984a90ccd26b814f4a4d00a58e9`, English, light, 1264 × 681, scale 1. Lowlevel background input entered `0x9F` and clicked the real explanation button. The inspected painted frame shows `0x0000009F · DRIVER_POWER_STATE_FAILURE` and a completed local-engine response. No crash-history collection or dump read ran. Source, bundle, raw PNG, input/child receipts and owned teardown are retained. Run the same validator with its optional fourth argument `explained`. It checks byte and receipt consistency; it cannot replace pixel inspection or prove a full input matrix.
