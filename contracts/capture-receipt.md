# Painted-frame receipt, version 1

Each successful explicit Flutter frame export creates `<png>.json` beside the PNG. Both files use exclusive creation and are flushed before the native method reports success. Existing files are never overwritten. The receipt contains no destination path.

| Field | Meaning |
| --- | --- |
| `schemaVersion` | `1` |
| `captureMethod` | `flutter-repaint-boundary` |
| `captureStartedUtc`, `captureCompletedUtc` | UTC immediately before and after `RenderRepaintBoundary.toImage(pixelRatio: 1)`, before PNG encoding |
| `captureElapsedMicroseconds` | Monotonic duration of that render call |
| `writeStartedUtc`, `writeCompletedUtc` | UTC around native exclusive PNG creation, write and flush; the sidecar is written afterward |
| `writeElapsedMicroseconds` | Monotonic duration of the PNG write interval |
| `sequence` | Integer 0–19; subsequent PNG names use `-001.png` through `-019.png` |
| `width`, `height` | Rendered image dimensions, independently matched to the PNG IHDR |
| `pixelRatio` | `1`; this is not physical display DPI |
| `pngBytes` | Number of exact PNG bytes written |
| `pngSha256` | Native SHA-256 of those exact bytes |

UTC values use `YYYY-MM-DDTHH:mm:ss.ffffffZ`. Invalid dates, reversed clocks, negative durations, render/write durations above ten minutes, frames older than ten minutes, future capture completion, mismatched dimensions, invalid sequence names, and non-unit pixel ratios are rejected. Dimensions are positive, at most 32768 per axis and at most 100 million pixels total. PNG input is at most 32 MiB; its signature and IHDR structure/dimensions are checked. This is not a full PNG decoder or an independent compositor capture.

`writeCapture` receives the PNG byte view using its exact buffer offset and length, plus render timing, sequence and dimensions. It returns success only after PNG and sidecar writes are flushed. If the PNG completes but sidecar creation, writing, cancellation, or clock validation prevents a receipt, the PNG is retained and the method returns `CAPTURE_RECEIPT_INCOMPLETE`. A partial PNG write remains an error with no verified receipt. The Flutter producer reports a path-free failure and never upgrades a missing receipt to success.

Wall-clock fields are direct observations, not file timestamps. Monotonic durations are separate measurements and need not equal wall-clock differences. Old frames without this sidecar retain unknown capture times. The sidecar binds bytes and timing; source/bundle provenance, visual inspection, privacy review, input evidence and owned teardown remain separate requirements.
