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

**Copy Microsoft reference** writes only the fixed public Microsoft URL shown beside the explanation. A completed write shows a nonblocking confirmation. If the clipboard rejects the write, the page retains its result and selectable URL and explains that copying did not complete. The message does not expose the underlying exception. Three focused platform-channel tests cover success, rejection and disposal during a pending rejected write. Those mocks do not establish an actual system-clipboard interaction; that remains pending separate isolation and runtime verification.

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

## Enlarged bilingual result

A second real run at producer eeaf858395cf171291faa31d0d85c3de206fdb4b verified manual 0x9F entry and a completed DRIVER_POWER_STATE_FAILURE explanation in bilingual mode, dark theme and text scale 2. The complete result was inspected at 1264×961 after resizing the same owned hidden window. It did not collect crash history or read dump contents. A background wheel message was accepted without visible scrolling, so no scroll verification is claimed. The exact bundle processes were absent and the owned desktop closed. The original rejected reuse attempt changed only an unreferenced launch-result log; all previously published evidence hashes still passed. The new run uses independent saved state.

[Inspected result](../../captures/diagnostics-bilingual-explained.png) and [receipt](../../verification/diagnostics-bilingual-explained.json). The background wheel limitation remains open; the larger viewport is not evidence of minimum-size scrolling.

## Response integrity and evidence meaning

The desktop validates complete bounded diagnostic responses before accepting them. Malformed event or dump lists, invalid entries, mismatched requested periods, contradictory stop codes, unsupported references and invalid UTC timestamps reject the whole response with a safe message. Unknown fields are not retained. A successful response now exposes the code category, confidence limitation, next checks and an explicitly copied Microsoft reference. Reports show collection time and label dump modification times as file metadata rather than crash times. Fourteen focused checks passed, including 240 title combinations. Removing response validation made the malformed-response widget regression fail; restoring validation passed. New built runtime verification is pending.

## Rebuilt response validation evidence

Root engine and desktop builds passed at 5dbf2884901cbbad61a3c763c120b19d997928e8. A real English/light run verified manual 0x9F lookup, visible code category, confidence limit, four next checks and the fixed Microsoft reference at 1264×961. A subsequent live collection passed the new response validator and displayed collection time and timestamp meaning. Populated frames remain private. The guidance-only frame and 210 bundle files passed the shared evidence verifier; altered input evidence was rejected before restoration passed. Owned processes were absent and the hidden desktop closed. Copy-reference, individual dump rows and the full display/input matrix remain unverified.

[Current guidance frame](../../captures/diagnostics-guidance.png) and [receipt](../../verification/diagnostics-guidance.json). The previous frames retain their historical producer identities.

## Seven-day collection and metadata availability

Source `6d3695e738b0902390e473f6aaf1fb153c30f106` completed a real seven-day collection in the bilingual dark workspace at 1280×1000. The actual period popup, selected seven-day value, collection timestamp and metadata-time explanation were inspected. Keyboard traversal reached the dump section. It showed no accessible dump files and explicitly disclosed that this account could not read the metadata; no elevation was requested. This verifies the unavailable state, not a populated dump row. The [frame manifest](../../verification/diagnostic-period-frames.json) and [observations](../../verification/diagnostic-period-observations.json) retain the bounded result. Event pixels remain private.

The same run found repeated Page Down stopped after the focused selector scrolled out of view. Tab restored a visible target. The persistent paging-focus repair passed fifteen focused checks, independent source review and the integrated root desktop build at `f310e7684c9ebdf621bc656f2f98bfa3a47c12bc`. A fresh real 800×600 run with doubled bilingual text accepted fifteen consecutive Page Down inputs without refocusing, moving from the original selector through the final event rows. Six representative frames were inspected and all twenty originals retained privately. The capture limit prevents a further minimum-size dump-section or reverse-paging frame from this run. See [paging observations](../../verification/diagnostic-paging-observations.json).

Reference copying, populated dump metadata, remaining periods, failure/refresh states, full accessibility and physical-DPI coverage remain separate requirements.

中文：真正七日收集已驗證，週期選單、收集時間及時間含義可見。鍵盤可到傾印資料區，本帳戶不能讀取資料嘅限制亦清楚列明，沒有要求提升權限。這只證明不可用狀態，並非已有傾印資料列。重複翻頁焦點修正已通過指定測試，重新建置後嘅實際驗證仍待完成。

New explicit painted-capture sessions allow at most 64 attempts (sequences 0 through 63), so longer review workflows can retain their later states. The debounce and one-writer rule remain unchanged. Historical evidence produced under the earlier 20-attempt limit is unchanged and does not acquire additional frames or coverage.
