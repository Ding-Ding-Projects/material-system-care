# Implementation handoff

## Read-only scan cancellation

Read-only folder analysis, duplicate discovery and temporary-file scans now expose a request-specific Cancel scan control. The spinner remains until the original desktop request finishes; a result that wins the race remains successful. Cancellation ends the desktop wait and asks the engine to stop, but is not an acknowledgement that all engine reads have already stopped. Leaving the workspace also requests cancellation of its active read. Mutation workflows do not receive this control. Three focused Flutter checks passed, including cancellation and completion races, selected cleanup and recovery review. The root desktop build passed at 7fccbd4a8354a09ee3c32ca98aa88b64b362c4b7. Built cancellation interaction remains pending.

## Recovery file review

The engine now exposes read-only cleanup.details for a validated receipt ID. It returns recorded path, size, state and reason without internal hashes or quarantine locations. The desktop reads matching details before restore confirmation, shows the recorded files, blocks unavailable or empty details, and sends only the reviewed receipt ID with explicit confirmation. Stored state is a snapshot; current availability and destination conflicts remain governed by actual restore-time validation. Skipped/already-restored items can appear in review without being moved again.

Thirty-three storage checks and the focused recovery-review Flutter check passed. Tests cover metadata-only behavior, omitted internal fields, traversal rejection, unavailable-detail blocking, cancellation without restoration and receipt-specific confirmation. Independent bounded review found no concrete correctness/privacy/scope regression. Root engine verification and desktop builds passed at ca91247ef313ff0592c5d45d70d819049e9de92f. Genuine built recovery interaction remains pending. No real user files were restored.

## Selected maintenance targets

The cleanup workflow now requires checked targets, snapshots their original plan indices and exact paths for review, and sends only that subset. The engine validates nonempty unique in-range integers against its stored plan before creating a recovery receipt, persists the canonical selection, and rejects replay with a changed selection. Unchecked eligible files remain untouched. Legacy receipts represent the previous whole-plan selection; older clients omitting selection must be updated. Replay does not resume omitted work or preserve historical cancellation provenance.

Thirty storage fixture checks passed, including invalid types/bounds/duplicates, no mutation before valid selection, unselected eligible files, replay expansion refusal, order-independent replay and existing recovery checks. The focused Flutter fixture passed with an active filter, proving original row index 1 reaches the engine after explicit review, while cancellation sends nothing. One existing symbolic-link fixture remains skipped for unavailable privilege. Independent bounded review found no concrete selection/recovery regression. Root engine verification and desktop builds passed at 488aaf78bf8f2bc993dfd4c88cc4bab7f1c7cbbe. Genuine built selection interaction remains pending. No real user temporary files were moved.

Diagnostic documentation deployment 38010171599 succeeded at 661e763198a28fd6eae8597e26edbebf70460ff8. Live home, script and result PNG returned 200; script/image bytes matched local output, and the public About homepage readback remained exact.

## Diagnostic interaction evidence

Desktop source cfa86ebb78312984a90ccd26b814f4a4d00a58e9 passed the root desktop build and a real isolated Lowlevel background-input sequence. The operator entered public code 0x9F in the actual field and clicked the explanation control. The inspected painted output shows 0x0000009F, DRIVER_POWER_STATE_FAILURE and the completed local-engine response. Both idle and result PNGs, source/build/hash receipts, input/child receipts and owned teardown are retained. The narrow validator checked 210 bundle files and rejected a deliberately altered input-receipt hash before passing restored evidence. No real crash-history collection or dump read occurred in this sequence.

Opt-in capture-on-input uses an 800 ms debounce and at most twenty attempts. The native writer uses CREATE_NEW and one unshared handle, with I/O on an owned worker and completion on the platform thread. Review found no new blocking worker regression. Network destination and bounded network teardown are not established; shutdown cancellation is best effort and joining can still wait on unresponsive storage. Capture existence alone never proves success. Native compositor, complete input/motion/layout/accessibility coverage and full suite completion remain unverified.

Hosted build 38009212969 succeeded for the preceding main revision 6c7ebaa333c84968cabe6692d5e2fb402ffd6e64. The newly saved diagnostic guide and result image require their own deployment readback.

## Managed package discovery candidate

The Apps workflow now exposes explicit WinGet discovery after a network disclosure. `apps.managed` reads structured export records, validates exact package identifiers and source identity, and returns unknown update availability honestly. A selected row uses the existing separately reviewed upgrade/uninstall operation. Discovery never accepts a new source agreement or changes installed packages. Bounds include a ninety-second collection deadline, monitored export growth, final 2 MiB JSON validation, and separately bounded process teardown. Cleanup failures disclose possible retained local inventory.

The integrated engine fixture suite passed 28 assertion groups after these changes. The focused Flutter fixture passed, including review-before-discovery, exact upgrade target, cancellation without mutation, and removal of stale actionable rows after an unavailable refresh. Independent source review prompted producer-size monitoring and exit observation before cleanup. The root desktop build passed at 7cf40d1c9f8ed94eabefa4b0a4b6a1349abd32df. The root engine build and complete focused engine checks passed at 15bda1d3c5ffad297f98ff5969c1e942e75e85b9; one existing symbolic-link fixture remains skipped for missing host privilege.

An actual read-only discovery at the latter engine revision returned 45 matched records, completeInstalledInventory=false and updateAvailability=not-checked. No request-owned temporary export directories remained. An earlier attempt under the maintenance LocalAppData directory returned 0x80070003; controlled identical-argument probes isolated the output location, and the account temporary directory succeeded. Installed-package identities and raw control-probe exports remain private. No package mutation was performed. Native visual interaction evidence for the new Apps control remains pending, and all affected catalogue rows remain unverified.

Hosted Windows build 38008237408 completed successfully for fc4f57f2016c48773d2e4476989e39877a0721a8. This does not verify this newer candidate or establish a published release.

The selected target is Windows 11 x64. Source is public at `Ding-Ding-Projects/material-system-care`. The suite remains in development, not a completed replacement for the whole reference catalogue.

## Verified milestones

| Source revision | Scope | Result |
| --- | --- | --- |
| `7e2a8c88d59d2cf5f6e5ba53615aa8fcaafd0653` | Root engine build and focused actual-engine fixtures | Exit 0: 15 integrated groups, 7 utility groups, 14 storage assertions, 19 protection assertions, 8 core process/pipe groups |
| `54891b514feeda75f2fb001304d8e8c3c096d3e5` | Root native desktop build | Exit 0; separate Flutter analyzer and 3 component/workspace tests passed at its UI source |
| `02883f9f6e7058b897412695144460f2fe107dc1` | Root website build | Exit 0, official Material Web components and locally bundled fonts |
| `3de6d908c184a4a92dcd53d9444daeaf54d9fb5a` | Coverage structure | 295 capabilities; 104 canonical contracts; 331 catalogue, 211 surface and 21 receipt negative mutations rejected |

Engine executable SHA-256 for the first row: `282a9a22b3641328b52a27985f74ad562208ff70b5a4dd8d7ef975c176c31cda`.

One symbolic-link fixture explicitly skipped `ERROR_PRIVILEGE_NOT_HELD (1314)`. Host privileges were unchanged. Storage mutations occurred only inside owned fixture directories. Active security scans, driver installation and real-host maintenance were not performed.

These are source-bound intermediate results. They do not transfer automatically to a later integrated revision. Final candidate rebuilds remain required.

## Current review and gaps

Independent review accepted and repaired an oversized aggregate-response defect, long-operation transport deadlines, incomplete capability discovery, inefficient line framing, interrupted-restore accounting, missing native installer awareness metadata, unbound pipe server identity, unsafe settings retry, delayed startup state, private-cache replacement, factual scalar rendering and platform text scaling. Their focused regressions and targeted independent re-reviews passed. A same-user local-record tampering claim was not accepted as a demonstrated security boundary crossing. A journal path-swap hypothesis needs deterministic proof.

Engine candidate `a700cb31bf81bcfcdd459570b70b02ebdd6cded7` passed 28 integrated checks, 7 utility groups, 18 storage assertions, 19 protection assertions and 8 core groups. Native candidate `06e6716219ed2261c67c2430027a7394a63f16f4` passed five transport checks, including a 31-second reply, cancellation, timeout and wrong-server identity. Resource candidate `cecdf4b` verified the actual compiled English Unicode awareness resource. Desktop candidate `23a60f6` passed 16 widget tests; `e244020` passed two additional delayed-response regressions. These remain distinct from real GUI interaction proof.

Complete catalogue workflows, universal per-surface controls, full language coverage, native optional audio/narration, complete update handling and fresh-environment bootstrap remain unfinished. Release readiness stays unverified.

The maintainer subsequently authorized bounded repair of supported Lowlevel transports. A task-owned persistent loopback compatibility HTTP/native backend now supports isolated desktop launch, exact process/window discovery and capture. Earlier Flutter captures were blank and are rejected as UI evidence. Desktop scaling/motion/accessibility interaction and installer lifecycle proof remain pending.

The earlier website was hosted at the historical external deployment. Deployment `appgdep_6ac84608e6e4819190c8a83fc5589588` succeeded from source snapshot `e890ea1078c595af87ba3738840500ce71200a34`. Anonymous HTTP returned 200 for the home page and linked script/style assets; coverage contained 295 entries. The release manifest remains development with no installer URL. Repository homepage readback matches the live URL exactly.

The first integrated installer attempt passed engine fixtures and bundle negative checks, then failed in Flutter assembly with MSB8066. The subsequent verbose root desktop build passed with zero compiler warnings/errors. The earlier hosted build failed its unchanged-source check after generated line endings changed; exact LF attributes now prevent that false source drift.

Earlier local candidate `fca93588af594290c97612253861d0db05b5c565` passed `build-installer.bat /s`, including engine, desktop, website, compiled Squirrel awareness resource, bundle manifests and packaging. The package's 209 payload files were independently read from the full nupkg and checked against their recorded lengths and SHA-256 values. Both embedded producer receipts matched that candidate. The Squirrel completion race was repaired by waiting for its actual exit code before checking outputs.

| Local output | Bytes | SHA-256 |
| --- | ---: | --- |
| Setup.exe | 48,533,504 | `85049f61b08c5ed847feb102b8b0843a167d722483d80134a33a2ff8244d9ca3` |
| MaterialSystemCare-0.1.0-full.nupkg | 47,821,303 | `37946378ac4ae367b1a570260498166200981e505c24b0e884c3bc4f5e77c4ed` |
| RELEASES | 88 | `dce6f670b624d1a1f39bed578074208afb2b68564f6e966083f5232fb0fc892f` |

Installer creation and payload integrity are verified locally. Installation, uninstall, update lifecycle and fresh-machine behavior are not verified. No production release has been published. Later documentation-only commits retain this exact producer identity rather than relabelling the build.

Hosted run `37871588366` compiled all targets but Squirrel rejected its four-part `0.1.8.1` version. An exact local root-entrypoint reproduction established the same strict-SemVer exception. The workflow now selects `0.<run_number>.<run_attempt>`, with early full-string, ASCII, leading-zero and 16-bit component validation. Eleven focused version checks passed. Producer receipts now contain the selected version, the desktop prefers that value, and four focused provenance checks passed. The corrected hosted run is pending; its terminal result belongs in issue #1 and discussion #2 without changing this source-bound record.

Version bounds now match between packaging and desktop provenance, with ten focused desktop cases and independent re-review. Packaging attempts have isolated input, release and diagnostic directories. Exclusive promotion locking, non-nesting directory renames, comparison against the attempt's own bytes, and rollback preserve previous outputs. Eleven synthetic isolation/contention/rollback checks passed and targeted independent re-review found no residual issue in that scope.

Candidate `77f6815a8c4490eae7f18f959fa4423ff8e657e3` completed the exact root installer entrypoint with version `0.8.1`, but independent package verification rejected its full package. Of 218 ZIP entries, `lib/net45/flutter_windows.dll` has CRC metadata `976c718e` while its actual CRC is `83160968`. Its decompressed SHA-256 matches both the raw NuGet input and built file. The corruption is in ZIP metadata produced during releasification. The failed full package has SHA-256 `5b0c017fa21861460b8c3269979c7e4afecbfeb08704252b58df40ce1d2f30e5` and is retained for diagnosis. Entry-point exit zero therefore does not establish installer integrity. The producer correction and successful replacement evidence follow.

Current local producer `b80d9938c1a90cea17eb6a69faa18fb2a257dbf0` passed `build-installer.bat /s` with version `0.8.1`. Each attempt preserves the original Squirrel.Windows 2.0.1 tools and uses a separate copy with the unchanged Squirrel assembly plus a hash-pinned official 7-Zip 26.04 helper. This project-owned helper composition does not modify a finished archive or setup executable. Its independent ZIP validator rejects the exact earlier invalid package and checks CRC, length, all bundle-manifest payload hashes, and both embedded source/version receipts before canonical promotion. Four focused negative/positive cases and independent source review passed.

The final full package passed a second implementation's complete ZIP check: 230 archive entries, 209 recorded payload files, both embedded receipts, and the RELEASES package SHA-1 and byte count. The previous canonical package remains preserved in the packaging history. Installation, update, uninstall and fresh-host behavior remain unverified.

| Current local output | Bytes | SHA-256 |
| --- | ---: | --- |
| Setup.exe | 48,532,992 | `a83e99003bf7a68426a4f7d1244c970bca648c6016a4084e4210329bfe402a84` |
| MaterialSystemCare-0.8.1-full.nupkg | 47,821,020 | `acefef1afb201bf9c76227a34a972d16a0e8da04e9446388cac6c579f26365ef` |
| RELEASES | 88 | `d6eb08a58d6028816b35a01bab9026074fb983b7b6f4079e594b06d62f9b44bf` |

Hosted verification is separate from this local producer. Read the run tied to the final public main revision and the subsequent terminal-result comments in issue #1 and discussion #2; historical failed runs are not relabelled as successful.

The wiki clone endpoint returned `Repository not found`, despite wiki being enabled. GitHub Projects discovery lacks `read:project` scope and is skipped. Documentation, issue #1 and discussion #2 retain the factual handoff. Runtime status enrollment is unavailable without its configured ingest credential. No external status delivery is claimed.

## Next actions

1. Read the final default-branch hosted build result and its exact source binding.
2. Continue remaining implementation requirements without marking absent runtime evidence complete.
3. When the permitted capture route is available, run the full built interaction matrix and installer/update verification before release publication.

## GitHub Pages migration

Source and deployment configuration prepared. Live deployment, repository homepage readback, and runtime captures remain pending. The local Lowlevel compatibility HTTP endpoint was restored on loopback. Flutter window captures were blank; Edge rejected the previous host with ERR_SSL_VERSION_OR_CIPHER_MISMATCH. Neither capture is accepted product evidence.

## Current diagnostics and hosting checkpoint

GitHub Pages is live at https://ding-ding-projects.github.io/material-system-care/. Deployment run 38005854415 succeeded at source `66880b5904726afb5f2444950964e8b147d5d929`. Anonymous homepage, JavaScript, CSS and logo returned HTTP 200; the repository About homepage exactly matched. The Windows build run 38005854482 also completed successfully at that source. Isolated Edge produced genuine desktop and mobile captures; the mobile header needs layout correction before acceptance as completed visual evidence.

The new blue-screen workflow adds two explicit engine methods and a dedicated Tools workspace. Thirty-five synthetic diagnostic assertions, 28 integrated engine groups and eight focused Flutter tests passed on the changed source. This is not yet a compiled candidate or a runtime screenshot verdict. No actual host crash was triggered, no dump contents were read and no driver or power action occurred. The broader suite remains incomplete.

Candidate `2714879de8acf64c3da6aae6320ef8cae5724abd` subsequently passed both root engine verification and the root desktop build. Desktop executable SHA-256: `63efc3ae2683250617457a7375803a181fb2de7fb417388219216dedf5b354de`. Five diagnostic widget checks now cover explicit collection, stale results, disposal, partial inventory and distinct failure reasons. Its hidden-window capture still returned blank pixels and was rejected. An explicit built Flutter frame-export route is being added; its output and runtime validity remain unverified until a new build is inspected.

Candidate `d1b4cca6d1f843a559f4f47f0f01288e60b18773` passed the root desktop build and produced an actual 1264 × 681 painted Flutter frame on an isolated Lowlevel desktop. Its SHA-256 is `ae81d30b57c848cd944b13c604155cb906ee61a8f239ce1b56df01914a0f2ee9`. The frame was visually inspected, retained byte-for-byte, and checked against all 210 files in its built bundle. The render-only validator rejected an intentionally changed capture hash, then passed the restored receipt. This alternative evidence does not satisfy native-compositor, input or live event-collection verification. No host events were collected for the image. The owning window and process were closed and the hidden desktop was released.

The website now includes bilingual diagnostic guidance and this qualified frame. The narrow-screen header gives the brand its own row. This website revision still requires its root build, deployment and same-viewport browser readback.

Runtime browser verification found that native class fields shadowed Lit reactive accessors. The URL could change without rendering the requested surface. Initial tab change events also removed a documentation topic fragment. Explicit TypeScript assignment semantics and ignoring same-page tab changes repair these causes; built click verification follows separately. Official reference: https://lit.dev/docs/components/properties/#avoiding-issues-with-class-fields-when-declaring-properties.

The built website at `2b570f47f88f236b5cf730527dbe015fd79a6138` passed isolated browser checks for a retained diagnostic deep link, unshadowed reactive page accessor, actual home navigation and opening preferences. The guide image decoded at its original 1264-pixel width. Captures are retained with the source-specific private run receipt; the preferences capture was taken during its transition and is not a settled visual baseline. Deployment of this repair is pending.

A separate focused regression reproduced loss of language and reduced-motion preferences when entering diagnostics from Tools. The route now carries CopyScope explicitly. The same regression passed after repair, and all 12 focused diagnostic/workspace/localization widget tests passed. Native compilation of this final route adjustment remains pending.

## Latest verification result

The diagnostic route at `fb128bc4acf89d9fe149150bd571c2351b91229e` passed the exact root desktop build. Its current painted frame is byte-identical to the earlier inspected image and is now bound to this source in `docs/captures/diagnostics-idle.json`. The full producing bundle and original output are retained privately, and the narrow validator verified all 210 bundle files and owned teardown. A real bounded engine collection also returned successfully with an explicit truncated-inventory flag; only counts and outcome flags were summarized, while returned local event records remain private. No dump contents were read or uploaded.

Documentation deployment [38007816620](https://github.com/Ding-Ding-Projects/material-system-care/actions/runs/38007816620) succeeded at `2b570f47f88f236b5cf730527dbe015fd79a6138`. Live isolated browser verification confirmed the diagnostic deep link, actual navigation and settled preferences. Anonymous homepage, script, stylesheet, logo and PNG returned 200 and matched the built bytes. About homepage readback remains exact. The desktop build/release workflows for later source revisions were still running at this record; no release outcome is inferred.

The completeness inventory now retains 104 canonical contracts across 28 surfaces and 1,932 requirement rows, including the diagnostic workspace. Its 213 negative mutations passed. No incomplete universal contract was marked verified. All task-owned browser/application windows in these runs were closed with identity-checked background messages and absent-process readback; the loopback capture service remains task-owned for continuing verification. The overall suite goal remains active.
