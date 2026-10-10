# Folder analysis and duplicate files

`storage.analyze` accepts `{ "path": "C:\\SelectedFolder", "maxEntries": 20000 }`. Select an existing folder. It returns `root`, `fileCount`, `totalBytes`, `largeFiles` (the largest 100 files), `emptyFolders` (up to 1,000), `emptyFolderCount`, `inaccessible`, `reparseSkipped`, `tooDeep`, `truncated`, and `mutationPerformed: false`. Empty means no entries were observed, including hidden files. Inaccessible folders are never reported as empty. `maxEntries` may be 1 through 100,000; depth is capped at 64. Paths longer than 1,024 characters are excluded and counted as inaccessible.

`storage.duplicates` accepts `{ "path": "C:\\SelectedFolder", "maxEntries": 10000, "maxHashMiB": 512 }`. Files are grouped by length, hashed with SHA-256, then compared byte for byte. A hash match alone never proves duplication. Results contain `groups`, `hashedBytes`, `budgetReached`, `changedOrUnavailable`, and traversal counters. Each group gives `size`, up to 20 `paths`, `totalMatchingFiles`, `pathsTruncated`, `reclaimableBytes`, and `verification`. At most 100 groups are returned. The maximum enumeration is 50,000 entries and the maximum hashing budget is 4,096 MiB. `budgetReached` also indicates the group-result limit. Comparison reads are additional to hashing bytes. Cancellation is checked throughout enumeration, hashing, and comparison.

Files are opened with writers and deletion excluded. Reparse points, symbolic links and hard-linked files are excluded from duplicate hashing. Metadata changes or inaccessible files do not silently become matches. Analysis remains a point-in-time view, and a path may change after results are returned. No duplicate deletion operation is provided.

`INVALID_ARGUMENT`, `PATH_NOT_FOUND`, `ACCESS_DENIED`, `REPARSE_NOT_ALLOWED` and `STORAGE_IO` are narrow operation errors. Individual unreadable files increment counters while the rest of the selected folder can still be analyzed.

Fixture checks live in `tests/storage`. They create their own isolated directory and never operate on user documents.

## Desktop cancellation

Read-only folder analysis, duplicate discovery and temporary-file scans now expose a request-specific Cancel scan control. The spinner remains until the original desktop request finishes; a result that wins the race remains successful. Cancellation ends the desktop wait and asks the engine to stop, but is not an acknowledgement that all engine reads have already stopped. Leaving the workspace also requests cancellation of its active read. Mutation workflows do not receive this control. Three focused Flutter checks passed, including cancellation and completion races, selected cleanup and recovery review. The root desktop build passed at 7fccbd4a8354a09ee3c32ca98aa88b64b362c4b7. Built cancellation interaction remains pending.
