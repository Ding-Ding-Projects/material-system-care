# Folder analysis and duplicate files

`storage.analyze` accepts `{ "path": "C:\\SelectedFolder", "maxEntries": 20000 }`. Select an existing folder. It returns `root`, `fileCount`, `totalBytes`, `largeFiles` (the largest 100 files), `emptyFolders` (up to 1,000), `emptyFolderCount`, `inaccessible`, `reparseSkipped`, `tooDeep`, `truncated`, and `mutationPerformed: false`. Empty means no entries were observed, including hidden files. Inaccessible folders are never reported as empty. `maxEntries` may be 1 through 100,000; depth is capped at 64. Paths longer than 1,024 characters are excluded and counted as inaccessible.

`storage.duplicates` accepts `{ "path": "C:\\SelectedFolder", "maxEntries": 10000, "maxHashMiB": 512 }`. Files are grouped by length, hashed with SHA-256, then compared byte for byte. A hash match alone never proves duplication. Results contain `groups`, `hashedBytes`, `budgetReached`, `changedOrUnavailable`, and traversal counters. Each group gives `size`, up to 20 `paths`, `totalMatchingFiles`, `pathsTruncated`, `reclaimableBytes`, and `verification`. At most 100 groups are returned. The maximum enumeration is 50,000 entries and the maximum hashing budget is 4,096 MiB. `budgetReached` also indicates the group-result limit. Comparison reads are additional to hashing bytes. Cancellation is checked throughout enumeration, hashing, and comparison.

Files are opened with writers and deletion excluded. Reparse points, symbolic links and hard-linked files are excluded from duplicate hashing. Metadata changes or inaccessible files do not silently become matches. Analysis remains a point-in-time view, and a path may change after results are returned. No duplicate deletion operation is provided.

`INVALID_ARGUMENT`, `PATH_NOT_FOUND`, `ACCESS_DENIED`, `REPARSE_NOT_ALLOWED` and `STORAGE_IO` are narrow operation errors. Individual unreadable files increment counters while the rest of the selected folder can still be analyzed.

Fixture checks live in `tests/storage`. They create their own isolated directory and never operate on user documents.

## Desktop cancellation

Read-only folder analysis, duplicate discovery and temporary-file scans expose a request-specific Cancel scan control. The spinner remains until the original desktop request finishes; a result that wins the race remains successful. Cancellation ends the desktop wait and asks the engine to stop, but is not an acknowledgement that all engine reads have already stopped. Leaving the workspace also requests cancellation of its active read. Mutation workflows do not receive this control. Three focused Flutter checks passed, including cancellation and completion races, selected cleanup and recovery review.

A real isolated `cleanup.scan` at source `1c6b7049f04979de209c87d02c1d787923c4e58d` verified a visible pending scan, one Cancel input, the truthful stopped-waiting state and a completed fresh scan. The final fixture contained 9,000 eligible files holding 500 MiB plus its marker. Independent verification matched length, modification time, file identity and SHA-256 for all 9,001 files. The subsequent plan disclosed its 1,000-target limit and selected no files. No cleanup mutation was requested.

Three attempts are retained separately. The first reached stopped-waiting but its native busy images were blank and rejected. Completion won the second, whose late click initiated another read. The third has the matching painted busy/cancelled sequence. Existing plan files mean that immediate engine termination cannot be inferred. The generic lifecycle helper remained incomplete; a separately revalidated identity-bound close, process absence and empty-desktop proof completed disposal. See [frame manifest](../../verification/scan-cancellation-frames.json) and [bounded observations](../../verification/scan-cancellation-observations.json).

中文：真正隔離掃描已驗證等待中、一次取消輸入、如實顯示停止等待，以及其後重新掃描成功。九千零一個即棄檔案嘅內容、時間及識別全部不變。第二次嘗試由完成先到，不能當取消證據；第三次保留配對畫面。停止等待不代表引擎立即停止，亦沒有要求搬移任何檔案。其他掃描類型及完整外觀、無障礙仍需分開驗證。
