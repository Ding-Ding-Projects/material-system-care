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

## Capture-scoped Flutter diagnostics

New capture-mode entrypoints install `FlutterError.onError` and
`PlatformDispatcher.onError` before `runApp`, after binding initialization, in
the existing zone. Both handlers forward to the original handlers and retain
their return behavior. Normal startup does not install these hooks. Disposal
restores only hooks still owned by that capture session.

An observed receipt adds `diagnosticStatus: "observed"` and a typed `diagnostics`
object: `schemaVersion: 1`, fixed `coverage: "flutter-framework,platform-dispatcher"`,
`startedUtc`, `completedUtc`, `sequence`, `frameworkErrorCount`,
`platformErrorCount`, `droppedCount`, and `healthy`. Counts are cumulative from
hook installation through the instant after the frame render completes, before
PNG encoding. The completed timestamp and sequence must exactly match the frame;
the start cannot follow frame start, and the interval cannot exceed 24 hours.

Only errors delivered to those hooks are counted. This is not console, browser
page, zone, native stderr, engine, process-crash, or complete application-health
coverage. No error messages or stacks are retained. A zero is an observation from
registered hooks, never a value assigned to missing coverage. Hook health checks
ownership at snapshot time; they cannot detect an external replacement that was
restored between observations.

At most 1000 delivered errors are counted, combined across the two sources.
Further errors increase `droppedCount` up to 1000 (a saturated lower bound), and
make health false. Missing/replaced/disposed hooks also make health false. Native
validation rejects unhealthy snapshots, dropped observations, malformed types,
counts, timestamps, coverage, or sequence mismatches before creating a PNG.
Nonzero error counts remain valid evidence and never mean an error-free frame.
Native persistence failure remains a failed capture, not a zero native count.

Requests without a snapshot retain compatibility but write
`diagnosticStatus: "legacy-unverified"` and `diagnostics: null`. Existing receipts
and images are never changed; an absent historical field remains unverified.

The [narrow observed-frame verifier](observed-flutter-frame.md) checks the
source/bundle/frame byte chain and zero-error observed-hook snapshot. Its
verdict is separate from global UI-evidence promotion and visual acceptance.
