# Folder analysis and duplicate files

## Read-only folder-analysis workspace

### Built-runtime observations

Source `c2fd97ed4406e3a06af64a53c362d64c61c13da7` passed the root desktop build and real selected-folder analysis at 800×600 with doubled bilingual text and 1280×1000 with standard bilingual text. An owned disposable folder returned four files, 5,169 bytes and two empty folders. The displayed descending file sizes were 4,096, 1,024, 32 and 17 bytes. Normal-view file details showed the complete path and modification time; both empty-folder paths were expanded and inspected. Independent snapshots showed file bytes, identities and modification times unchanged. Both owned process sets and hidden desktops closed.

Eleven minimum-size and nine normal-size frames passed the narrow source/bundle/two-hook verifier. Raw path-containing images stay private. See [observations](../../verification/storage-analysis-observations.json). Pending-read cancellation, stale-result clearing, invalid-path feedback and the remaining appearance/accessibility matrix still need runtime verification. A root-edit attempt exhausted the 20-frame limit and is not claimed as successful freshness evidence.

中文：真正隔離資料夾分析回傳四個檔案、5,169 位元組及兩個空資料夾；排序、完整路徑及修改時間已核對。兩次畫面分別為最小雙倍文字及正常大小，檔案內容、識別及時間保持不變。程序及隱藏桌面已關閉；路徑畫面不公開，取消及資料更新失效等其他流程仍待實際驗證。

The Storage workspace's **Analyze folder** action opens a dedicated folder-analysis page. Choose a folder with the native folder picker or enter an absolute local or UNC folder path. Review the normalized selected root before starting. Nothing is collected automatically, and this page does not provide deletion, move, duplicate removal, or arbitrary command actions.

The result summarizes observed file count, bytes and empty-folder count. It separately reports inaccessible entries, skipped reparse points, depth-limit exclusions and the traversal limit. Any of those conditions marks the view incomplete. The largest-file section lists at most 100 files; the empty-folder section lists at most 1,000 folders. Their displayed counts distinguish listed rows from observed totals. Expand a row to select its complete path, and for files inspect the UTC modification timestamp. These are point-in-time metadata, not proof that a path has remained unchanged.

The desktop sends a 20,000-entry limit and validates the returned root against the normalized requested root, using Windows case-insensitive lexical comparison. It rejects device paths, invalid or overlong paths, out-of-scope rows, invalid UTC timestamps, negative or excessive counts, non-boolean traversal flags, non-read-only responses, inconsistent totals, duplicate rows, wrong list lengths and incorrect largest-file ordering. One malformed row rejects the entire result. Normalization is not a filesystem identity check; existence, permissions and reparse validation remain engine responsibilities.

Editing the root clears the previous result and invalidates an outstanding response. A new failed analysis clears previous data. Cancel targets the exact pending desktop request, remains disabled after one request, and retains the busy state until that read settles. Successful completion may win the cancellation race. A stopped-waiting message does not claim that every engine read has stopped. Leaving the page requests cancellation without allowing a late response to update a disposed page.

Page Up and Page Down retain a persistent page focus when records scroll out of view. Text editing keeps its own keyboard behavior. Normal paging animates for 200 ms; reduced motion jumps directly. The page uses the official Material controls, expandable cards, a nonblocking status message and selectable path details.

`--storage-analysis` selects this page for an isolated capture run with the existing `--capture-*` options. Exactly one workspace destination is required to enable frame capture. Capture preferences remain separate from saved personal settings. No records are injected by this option.

Focused widget and parser checks cover rejected response shapes, root editing and stale completions, review cancellation, pending-read cancellation and completion races, disposal, the real Storage navigation entry, exclusive capture selection, and bilingual 800 × 600 layout with text scale 2 and both motion modes. These checks are not built-runtime or physical-display evidence; that acceptance is separate.

中文：資料夾分析而家有獨立唯讀頁面。先揀資料夾或輸入完整路徑，再檢閱所選根目錄先開始。結果分開顯示檔案、位元組、空資料夾及各種未完成原因；完整路徑可展開選取。改路徑會清除舊結果，取消只表示停止等候，唔會聲稱引擎已即時停止所有讀取。呢個頁面唔提供刪除或搬移操作。

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
