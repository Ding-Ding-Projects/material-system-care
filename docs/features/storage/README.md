# Storage and recoverable cleanup

Storage analysis reads only a selected folder. Cleanup is a separate consent workflow limited to aged files in the current user's local temporary directory. It does not format disks or permanently delete files. No remote service receives file content or paths.

- [Storage analysis](analysis.md)
- [Read-only duplicate analysis](duplicates.md)
- [Cleanup and recovery](cleanup.md)
- [Verified disposable cleanup and recovery round trip](cleanup-verification.md)

The local named-pipe protocol is documented in `contracts/engine-protocol.md`. These methods are not HTTP endpoints, so a Postman collection is not applicable.
