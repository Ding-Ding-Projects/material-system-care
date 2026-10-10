# Read-only duplicate analysis

Open **Find exact duplicates** from Storage, choose or enter an absolute folder path, and review the normalized selected root before starting. The dedicated workspace reads up to 10,000 directory entries and hashes up to 512 MiB. These fixed limits keep the request bounded. It does not delete, move, select files for removal, or execute commands.

The engine groups candidate files by length, computes SHA-256 and verifies matches byte for byte. The displayed verification label means both checks were performed. It is a point-in-time result, not a guarantee that files remain identical after the read. Writers, deletion, reparse points, symbolic links and hard-linked files are excluded by the existing storage reader.

The summary shows reported groups, hashed bytes, potential duplicate bytes, changed or unavailable checks, inaccessible entries, skipped reparse points and depth-limit exclusions. A depth exclusion, traversal limit, hash or group limit, or any unavailable comparison marks the view incomplete. Changed or unavailable counts describe checks, not necessarily unique files. An empty result says no exact groups were reported within the limits; it does not claim that no duplicates exist.

Potential duplicate space is `size × (total matching files − 1)` for each reported group. It is an estimate, not recovered bytes. No space is reclaimed by this workflow. At most 100 groups and 20 paths per group are shown. Expanded groups disclose the full reported matching count and whether paths were omitted, with selectable full paths. No paths are inferred from display labels.

The desktop requires the response root to match the requested root using the shared Windows lexical normalization. It validates the read-only marker, all required boolean and count fields, group and path bounds, globally unique in-root paths, complete path-truncation relationships, the exact verification label, hashed-byte consistency and potential-space arithmetic. Any malformed row rejects the whole response. Lexical normalization is not filesystem identity proof; existence, permissions and reparse checks remain engine responsibilities.

Changing the root clears prior results and invalidates pending responses. A new failed request clears the old groups. Cancel addresses the exact pending request and keeps the busy indication until it settles. A successful result may win the cancellation race. Stopped waiting does not mean that all engine reads have already stopped. Leaving the page requests cancellation and ignores late completion.

Page Up and Page Down keep a persistent page focus without replacing text-editing shortcuts. Paging uses a short animation normally and no animation in reduced-motion mode. Expanded groups explicitly use zero forward and reverse durations in reduced-motion mode. Controls and labels support English, Cantonese and bilingual preferences.

`--duplicate-analysis` selects this page for isolated captures with the existing `--capture-*` preferences. It remains mutually exclusive with the other capture destinations, loads no synthetic records and does not read saved personal preferences in capture mode.

Focused parser and widget tests cover malformed responses, arithmetic and scope, review, root changes, cancellation and completion races, disposal, empty and incomplete states, long paths and bilingual 800 × 600 layout at text scale 2. Separate engine fixtures verify zero and nonzero depth exclusions. These source checks do not constitute built-runtime, physical-display or file-deletion evidence.

The integrated build at `baa4fca7483265b53d1c7fe472571c0c0584e90c` was driven at 1280 × 1000 in bilingual dark mode with reduced motion. An owned seven-file fixture returned two groups, five matching files, 128 hashed bytes and 64 potential duplicate bytes. Both groups were expanded, including the zero-byte pair; cancelling the initial review performed no collection, and editing the root cleared the prior result. All fixture contents, identities and modification times remained unchanged. The 800 × 600 doubled-text run exposed the path field but did not establish retained hidden input or collection. That sequence remains unresolved, not a full minimum-size acceptance. See [bounded runtime observations](../../verification/duplicate-analysis-observations.json).

中文：重複檔案分析先檢閱所選資料夾，再按固定上限讀取及驗證。配對會經 SHA-256 同逐位元組比較，可能節省空間只係估算，唔係已回收空間。頁面會交代未完成、略過、無法比較及路徑省略情況，唔提供刪除或搬移。取消只表示停止等候，唔會聲稱引擎已即時停止所有讀取。
