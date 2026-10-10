# Captured application frames

| ID | Producer | Scope | State |
| --- | --- | --- | --- |
| `diagnostics-idle-en-light-1264x681` | `d1b4cca6d1f843a559f4f47f0f01288e60b18773` | Actual painted Flutter frame, render-only | Diagnostic workspace, idle, English, light, 1264 × 681, scale 1 |

![Built blue-screen diagnostics workspace, idle, English and light theme](diagnostics-idle.png)

[Source and byte receipt](diagnostics-idle.json). The built native application ran on an isolated Lowlevel desktop with default preferences. The original PNG is retained unchanged. It is not a mock or reconstructed interface, but neither is it a native-compositor screenshot. Input handling, live event collection and the complete layout matrix remain unverified. The exact capture instant is unavailable; the receipt records a separately observed time.

`scripts/verify-render-frame.mjs` validates this narrow alternative route against the original owned run, producer receipt, current built bundle, PNG bytes, privacy declarations and teardown record. It does not pass the separate native-window evidence gate or change any capability to fully runtime-verified.
