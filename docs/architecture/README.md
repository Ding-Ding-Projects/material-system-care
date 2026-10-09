# Architecture documentation

- [Capability and platform boundaries](capability-boundaries.md)
- [Evidence and completeness model](evidence-model.md)
- [Source mapping and fixture evidence](fixture-evidence.md)
- [Navigation mapping](navigation-mapping.md)
- [Per-surface inventory](surface-completeness.json)

The engine is a local Windows 11 x64 user-mode service behind a current-user named pipe. Flutter/Dart owns desktop interaction, C#/.NET 10 owns validated operations, C++20 supplies narrowly scoped native integration, and SQLite stores settings and operation records. Public website components use TypeScript, Lit and Material Web. No HTTP engine endpoint exists, so Postman collections are not applicable to the local protocol.
