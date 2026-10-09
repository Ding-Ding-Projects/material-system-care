# Independent review results

The initial implementation received independent finder and refutation passes. Accepted fixes were reviewed again against immutable commits. This record does not replace runtime evidence.

| Area | Accepted correction | Verification |
| --- | --- | --- |
| IPC | 4 MiB UTF-8 output bound, bounded aggregate reads, explicit 35-method inventory, buffered retained line framing | Actual-engine regression fixtures and source-bound named pipe |
| Recovery | Recognize interrupted successful restoration only after matching original file identity, metadata and bytes | Four new positive and adversarial recovery fixtures |
| Native transport | Method-specific deadlines, cancellation, owned server PID and identification-level SQOS | Five native checks including a 31-second reply and wrong-PID rejection |
| Packaging | Compiled English Unicode Squirrel awareness, full AOT/assets/engine inventories, actual packager exit wait | Built resource check, four bundle negative cases, successful root installer build and 209 packaged-file hashes |
| Desktop | Read-before-write retry, startup cache restore, factual scalar boundaries, platform scaling, atomic cache replacement | Sixteen widget tests and two delayed-response regressions |
| Desktop async state | Newer preferences invalidate both stale startup continuations | Controlled startup and Settings completions through the actual root callback |
| Website | One-pass literal personal wording, bounded output and isolated regex workers | Eight focused validation/search/replacement tests |
| Version provenance | Strict three-part producer version and matching unsigned 16-bit component bounds in the desktop | Eleven producer-version checks, ten desktop cases and independent re-review |
| Package promotion | Isolated attempts, exclusive promotion lock, non-nesting renames, own-attempt byte comparison and rollback | Eleven focused synthetic isolation/contention/rollback checks and independent re-review |

A same-user local plan-editing candidate was rejected as an automatic security finding because no distinct privilege or integrity boundary crossing was demonstrated. A journal-directory replacement hypothesis remains unproven and requires a controlled native race fixture. These verdicts do not claim that all possible defects are absent.

Real UI interaction, every locale/theme/scale tuple, accessibility behavior, installer lifecycle and fresh-environment proof remain pending. The owner explicitly retained the strict approved hidden route when its endpoint was unavailable.

Independent archive verification rejected the `0.8.1` package from candidate `77f6815`: one ZIP entry has incorrect CRC metadata despite matching payload bytes. This remains a packaging defect under investigation, distinct from the resolved isolation and promotion findings.
