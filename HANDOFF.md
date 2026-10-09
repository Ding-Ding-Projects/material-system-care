# Implementation handoff

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

The maintainer explicitly retained the strict hidden capture route after its HTTP endpoint was unavailable. Therefore runtime screenshots, scaling/motion/accessibility interaction evidence and installer lifecycle proof remain pending. No alternate visual route is authorized. No fabricated or design-only screenshot is presented as runtime evidence.

The website is public at https://material-system-care.azureteal8.chatgpt.site. Deployment `appgdep_6ac84608e6e4819190c8a83fc5589588` succeeded from source snapshot `e890ea1078c595af87ba3738840500ce71200a34`. Anonymous HTTP returned 200 for the home page and linked script/style assets; coverage contained 295 entries. The release manifest remains development with no installer URL. Repository homepage readback matches the live URL exactly.

The first integrated installer attempt passed engine fixtures and bundle negative checks, then failed in Flutter assembly with MSB8066. The subsequent verbose root desktop build passed with zero compiler warnings/errors. The earlier hosted build failed its unchanged-source check after generated line endings changed; exact LF attributes now prevent that false source drift.

Final local candidate `fca93588af594290c97612253861d0db05b5c565` passed `build-installer.bat /s`, including engine, desktop, website, compiled Squirrel awareness resource, bundle manifests and packaging. The package's 209 payload files were independently read from the full nupkg and checked against their recorded lengths and SHA-256 values. Both embedded producer receipts matched that candidate. The Squirrel completion race was repaired by waiting for its actual exit code before checking outputs.

| Local output | Bytes | SHA-256 |
| --- | ---: | --- |
| Setup.exe | 48,533,504 | `85049f61b08c5ed847feb102b8b0843a167d722483d80134a33a2ff8244d9ca3` |
| MaterialSystemCare-0.1.0-full.nupkg | 47,821,303 | `37946378ac4ae367b1a570260498166200981e505c24b0e884c3bc4f5e77c4ed` |
| RELEASES | 88 | `dce6f670b624d1a1f39bed578074208afb2b68564f6e966083f5232fb0fc892f` |

Installer creation and payload integrity are verified locally. Installation, uninstall, update lifecycle and fresh-machine behavior are not verified. No production release has been published. Later documentation-only commits retain this exact producer identity rather than relabelling the build.

Hosted run `37871588366` compiled all targets but Squirrel rejected its four-part `0.1.8.1` version. An exact local root-entrypoint reproduction established the same strict-SemVer exception. The workflow now selects `0.<run_number>.<run_attempt>`, with early full-string, ASCII, leading-zero and 16-bit component validation. Eleven focused version checks passed. Producer receipts now contain the selected version, the desktop prefers that value, and four focused provenance checks passed. The corrected hosted run is pending; its terminal result belongs in issue #1 and discussion #2 without changing this source-bound record.

Version bounds now match between packaging and desktop provenance, with ten focused desktop cases and independent re-review. Packaging attempts have isolated input, release and diagnostic directories. Exclusive promotion locking, non-nesting directory renames, comparison against the attempt's own bytes, and rollback preserve previous outputs. Eleven synthetic isolation/contention/rollback checks passed and targeted independent re-review found no residual issue in that scope.

Candidate `77f6815a8c4490eae7f18f959fa4423ff8e657e3` completed the exact root installer entrypoint with version `0.8.1`, but independent package verification rejected its full package. Of 218 ZIP entries, `lib/net45/flutter_windows.dll` has CRC metadata `976c718e` while its actual CRC is `83160968`. Its decompressed SHA-256 matches both the raw NuGet input and built file. The corruption is in ZIP metadata produced during releasification. The failed full package has SHA-256 `5b0c017fa21861460b8c3269979c7e4afecbfeb08704252b58df40ce1d2f30e5` and is retained for diagnosis. Entry-point exit zero therefore does not establish installer integrity. Repair and a decisive archive-integrity check before output promotion are in progress.

The wiki clone endpoint returned `Repository not found`, despite wiki being enabled. GitHub Projects discovery lacks `read:project` scope and is skipped. Documentation, issue #1 and discussion #2 retain the factual handoff. Runtime status enrollment is unavailable without its configured ingest credential. No external status delivery is claimed.

## Next actions

1. Resolve the archive CRC metadata defect, verify the integrated package and preserve exact producer receipts.
2. Verify the default-branch hosted build after the packaging correction.
3. Continue remaining implementation requirements without marking absent runtime evidence complete.
4. When the permitted capture route is available, run the full built interaction matrix and installer/update verification before release publication.
