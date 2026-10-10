# Blue-screen investigation

## Explicit interaction-frame export

When launched with `--diagnostics --capture-frame=<absolute-new-png> --capture-on-input`, the real diagnostic workspace exports its initial painted frame and subsequent frames following pointer release or key release. Captures are debounced for 800 ms, limited to twenty attempts, and use numbered siblings without overwriting existing files. Continuous input can delay a capture, and an asynchronous operation may still be running when a frame is produced. The option injects no results and changes no control behavior. Capture mode uses isolated default preferences. Inspect every resulting frame for private content before sharing it. Painted frames remain distinct from native compositor evidence; a post-input frame establishes behavior only when its visible state proves the intended action and the input receipt binds to the same live process.

The native writer uses one exclusively created, unshared file handle for creation and writing, with a 32 MiB PNG bound. Failed writes can leave incomplete files, which must not be accepted as evidence. The caller chooses the destination; a drive-letter path can resolve to redirected or network storage, so the lexical path check is not proof of local-only storage. Verification runs use a reviewed local, ignored directory.

Open **Tools → Blue-screen diagnostics**. Choose a lookback period, then select **Read crash evidence**. Collection is explicit and read-only. The separate stop-code field accepts hexadecimal (`0x0000009F`) or unsigned decimal (`159`) without collecting host events.

## Evidence and interpretation

The engine queries the Windows System event log through the supported `wevtutil.exe` utility. It selects only provider-qualified event 1001 (`Microsoft-Windows-WER-SystemErrorReporting`) and event 41 (`Microsoft-Windows-Kernel-Power`). A nonzero event 41 BugcheckCode is decimal. WER report codes are parsed as bounded leading hexadecimal values.

An unexpected restart alone does not establish that a blue screen occurred. Zero or unreadable codes remain explicitly uncertain. Matching timestamps are not deduplicated: separate event record identifiers remain available. Recorded event times may follow a crash or restart and are not presented as exact crash times.

Nine common stop codes have curated names and broad categories. Other values remain uncatalogued. Neither the code nor its category establishes a root cause or identifies a culprit driver. Next checks describe comparing recent changes, preserving evidence, and using Microsoft WinDbg with matching symbols when deeper analysis is appropriate.

## Limits and privacy

Collection accepts `days` from 1 through 365 and `limit` from 1 through 100; the interface requests at most 50 events. The query has a 15-second deadline and a 2 MiB output bound. A maximum of 100 dump-file metadata records are returned from the standard Windows dump locations. Reparse-point dump directories and files are excluded.

The engine reads dump names, lengths and modification times, never dump contents, stacks or symbols. It excludes raw event messages, computer names, SIDs, bugcheck address parameters and full file paths. Responses are transient, are not automatically recorded in operation history, and are not uploaded. No debugger, driver, privilege, event-log configuration, restart, repair or crash-trigger action is performed. Fixture contexts cannot inspect actual host events.

An inaccessible event query returns `EVENT_LOG_UNAVAILABLE`, not an empty successful report. Invalid limits or codes return `INVALID_PARAMETERS`. Malformed XML and entity declarations are rejected. Metadata access limitations are warnings. A failed refresh clears the previous report so old evidence cannot masquerade as a new result.

## Verification

The standalone fixture project checks decimal/hex parsing, provider qualification, unknown codes, zero-code semantics, timestamp and record retention, malformed and entity XML, output bounds, cancellation, privacy projection and fixture isolation. The widget fixtures check explicit collection, request parameters, stale-result removal and disposal during a pending request. Run the engine fixtures with the root `build.bat /s --target=engine --verify-engine`; focused Flutter fixtures are in `desktop/test/crash_diagnostics_test.dart`.

Built manual stop-code interaction passed at source cfa86ebb78312984a90ccd26b814f4a4d00a58e9: actual hidden-desktop input entered 0x9F, selected the explanation control and produced DRIVER_POWER_STATE_FAILURE. The [reviewed painted result](../../captures/diagnostics-explained.png) and [source-bound receipt](../../captures/diagnostics-explained.json) preserve that narrow evidence. The image was rechecked against public delivery byte for byte. This does not verify native compositor capture, the complete input/appearance/accessibility matrix or dump-content analysis. Fixture success alone establishes none of those results.

For isolated visual verification, the built executable accepts `--diagnostics --capture-frame=<absolute-new-png-path>`. This opens the same production diagnostic widget without loading persisted personal preferences and exports one actual painted Flutter frame. It never injects diagnostic results or automatically collects host events. The output must not already exist. Bind the file to the executable hash and hidden-desktop launch receipt, inspect its pixels, and label the route as Flutter frame export rather than native-window capture. The export alone proves neither input handling nor native compositor behavior.

## Built collection evidence

A fresh hidden run of producer cfa86ebb78312984a90ccd26b814f4a4d00a58e9 completed the actual Read crash evidence control at the default 30-day lookback and expanded one returned record. Three painted frames were inspected privately; the completed view and expanded provider/event/uncatalogued-code explanation were visible. No root cause was inferred. Host-specific timestamps, record identifiers and code observations are withheld from publication. docs/verification/diagnostic-collection.json retains sanitized source/hash declarations; scripts/verify-diagnostic-collection.mjs checked 210 producer files, two background clicks, private frame hashes and teardown receipts. An altered input hash was rejected, then restored evidence passed. A scroll call was rejected before execution, so the dump-metadata section was not inspected. Exact desktop/engine paths were absent and the named hidden desktop was closed. Other periods, failure/refresh paths, native compositor and full appearance/accessibility coverage remain pending.

## Sources

- [Microsoft: troubleshoot unexpected reboots using event logs](https://learn.microsoft.com/en-us/troubleshoot/windows-server/performance/troubleshoot-unexpected-reboots-system-event-logs)
- [Microsoft: interpret Kernel-Power event 41](https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/event-id-41-restart)
- [Microsoft: bug-check code reference](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/bug-check-code-reference2)
