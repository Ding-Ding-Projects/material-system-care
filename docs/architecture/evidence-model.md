# Evidence and completeness model

## Three independent claims

1. Catalogue integrity means the fixed declared capability list is complete and well formed.
2. Implementation means exact source implements the required operation with real data and enforced safety boundaries.
3. Verified delivery additionally means focused tests and actual built-surface interactions, localization, persistence and genuine captures are bound to that source and build.

The structural tests validate the first claim. They intentionally do not turn the other claims green. `--release` is the fail-closed delivery gate. The initial inventory is incomplete by design and must fail that gate until its applicable requirements are delivered. Excluded and unavailable rows stay visible, so the suite must not claim complete vendor parity.

## Fixed expectations

`tests/coverage/expected-capabilities.json` lists required capability IDs independently of the ledger. `tests/coverage/expected-universal.json` separately hand-enumerates all 104 canonical contract identifiers under public wording, with 69 surface contracts across 26 explicitly named planned surfaces. `surface-completeness.json` therefore holds 1,794 independent surface/contract rows plus 35 delivery requirements. A removed feature cannot disappear merely because runtime discovery no longer finds it. Update these reviewed baselines only for an explicit scope decision and preserve the decision in documentation.

Surface inventory entries are declared requirements, not evidence that all these routes already exist. Splitting a page or adding a dialog requires a new explicit surface entry and its complete contract rows. The public website cannot borrow desktop evidence, and settings cannot borrow evidence from Home.

## Proof references

A verified capability has real implementation paths, focused test paths, and evidence receipt paths. A verified surface additionally has exact localized-copy, persistence, interaction and capture references. Public receipts contain a 40-character source commit, a 64-character built-artifact SHA-256, the exact surface, viewport, scale, theme, language, a privacy verdict, method and measured file hashes. No private user data, private vocabulary payload, machine paths or credentials appear in public receipts.

The tests reject missing files, traversal, placeholder proof, fabricated verified statuses and malformed receipt metadata. They cannot inspect pixels or infer semantic correctness. A reviewer must inspect the genuine capture and real operation result, and confirm the receipt's hashes and source/build binding. Never promote a mock, source preview or static control as runtime evidence.

## Negative regression

The structural suites remove one required capability, family, contract and surface at a time, remove proof fields, create false verified states, and alter receipt boundaries. Each must fail validation before the unchanged baseline passes again. Release checks must remain red on the initial unimplemented baseline. Passing an intentionally weaker structural test cannot replace the release gate.
