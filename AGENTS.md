# Material System Care

## Product contract

This repository implements an independent Windows 11 x64 maintenance suite. The desktop uses Flutter/Dart, the local engine uses C#/.NET 10, and narrowly scoped native integration uses C++20. The public website uses TypeScript, Lit, and official Material Web components. SQLite holds local settings and operation records.

The desktop is a productive workspace with real records and contextual actions. Marketing, downloads, and feature promotion belong on the separate public website. All product-owned visible controls must use registered Material Design 3 components or specification-backed compositions. Every element and action has an explicit motion/state contract, with reduced-motion alternatives. Optional action sounds are muted by default.

The engine implements supported user-mode Windows APIs. Kernel drivers, other operating systems, proprietary vendor engines, and remote-device administration are outside this release. Files and credentials remain local unless the user explicitly enables a disclosed provider. A disabled capability must give its actual reason and must never count as implemented parity.

Root build entrypoints are `build.bat` and `build-installer.bat`. Shared IPC contracts are in `contracts/engine-protocol.md`. Capability coverage is recorded separately from verified implementation status.

## Agent conversation vocabulary

Agents working in this repository use the shared private conversation vocabulary defined in
the maintainer's canonical agent instructions for every reply, including chat prose, visible
reasoning, status lines, and task or session titles. Read those instructions and apply them
in full. They are deliberately not restated here, because this file is part of this
repository's public record.

That vocabulary never appears in anything published. Keep it out of commit messages, branch
names, code, code comments, test names, documentation, this file, issues, pull requests,
discussions, release notes, published sites, logs, and every other file in this repository.
Published writing uses ordinary professional English, and exact technical identifiers always
keep their literal spelling. The single documented public-safe exception is named in those
canonical instructions; do not infer any other.

Scan any text bound for a public surface against that vocabulary before publishing it. A
reviewer cannot tell a correct release note from a leaking one by reading it, so the scan is
a step, not a habit.
