# Cleanup and recovery verification

The actual Windows desktop completed a disposable-file round trip at source `2ed02f132083d75d281ce1ab4859583f7d5e3c88`. The root desktop build produced bundle SHA-256 `150c91b25589153e740a62d0a32d919b498b7eb783b11c270ff66f62e5144d2a`. The run used a named hidden desktop, a unique engine pipe and the explicitly enabled [isolated verification mode](../../architecture/cleanup-fixture.md).

## Observed behavior

1. Scan found two aged disposable temporary files. Only the first file was selected.
2. Cancelled confirmation left both original hashes and file identities unchanged and created no recovery receipt.
3. Confirmed cleanup moved only the selected file. Its recovery copy retained its exact bytes and file identity; the unselected file remained unchanged. The receipt recorded the single original selection index.
4. A deliberately created disposable file occupied the original destination. Restore preserved that occupant and the recovery copy, recording `RESTORE_CONFLICT`.
5. After removing only that verified disposable conflict, a new explicit restore succeeded. Both original files had their original hashes, identities and modification times. The moved recovery source was absent.
6. The application and engine stopped, their bundle executable paths had no remaining processes, and the empty hidden desktop was closed.

The run used bilingual dark presentation, a 1280 × 1000 client area, text scale 1 and reduced-motion capture settings. These are painted Flutter observations with independent filesystem checks. They do not prove native compositor output, physical DPI, arbitrary user-file safety, complete keyboard order or the full appearance/accessibility matrix.

## Evidence and privacy

[The evidence inventory](../../captures/cleanup-workflow.json) binds the source, build, ten inspected frames and private action/file observations by SHA-256. Run `node scripts/verify-cleanup-workflow.mjs <repository> <private-run-root>` where those private records are available. The verifier checks the original selection, cancellation, conflict, restoration, frame dimensions and teardown assertions against the bound observations. It does not infer pixel contents from a passing hash.

Populated frames show local paths and remain private. No edited, cropped or reconstructed image substitutes for them. Exact frame timestamps were not emitted and remain unavailable. The current record-shaped result presentation also needs dedicated bilingual cleanup summaries; successful recovery does not mark that interface work complete.

## 廣東話

真正 Windows 介面已用兩個即棄檔案完成選取、取消確認、移到復原區、目的地衝突保護，以及再次確認復原。取消後兩個檔案都冇改；只處理已選檔案。衝突時現有檔案同復原內容都保留，移走指定測試衝突檔案後，原本內容、檔案識別及修改時間全部吻合。

呢次只驗證隔離測試範圍。含本機路徑嘅畫面保留喺私人證據，公開記錄只列來源、雜湊同實際結果。完整外觀、鍵盤、輔助使用及實體 DPI 驗證仍未完成。
