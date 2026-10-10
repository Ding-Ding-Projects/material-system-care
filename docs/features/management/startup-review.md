# Startup action review

## Dedicated desktop workspace

Startup has a dedicated Material 3 workspace with a labelled search control, state filter and individual entry cards. Reading starts only after Refresh records is selected. Enabled entries and saved restoration records have separate named actions; conflicts and read-only entries do not expose enabled mutation controls. Commands are selectable inside expandable details. Raw revision values and journal paths remain internal.

Each action reviews one named entry and its effect on future sign-in. Cancellation sends no mutation. A successful response must match the requested identifier and desired state before the desktop reports completion. The workspace refreshes after every attempted change and removes stale actions if that refresh fails. The `--startup` capture entry point opens the same workspace without loading personal settings; it does not inject startup records or perform mutations.

Focused component checks cover malformed data, cancellation, reviewed-state forwarding, stale-state refresh and unavailable refresh. The complete built interaction, appearance and accessibility matrix remains pending.

啟動項目有獨立工作區：可按狀態及名稱篩選，每個項目有清晰嘅覆核操作。取消不會發送變更；覆核資料過期會重新讀取，唔會自動重試修改。實際介面操作及完整外觀驗證仍待完成。

Startup record actions name the enable or disable effect, explain future sign-in behavior and block unavailable or conflicting records. Confirmation sends only the selected id, desired enabled state, server-issued `reviewRevision`, and explicit consent. The revision deterministically covers the name, raw command, registry value kind, and enabled or restoration state. Commands are not copied into the mutation request.

The engine saves the original current-user Run command before removal and restores only where no newer entry occupies the name. It rejects missing revisions and changed commands, kinds, journals, or missing records with `STARTUP_REVIEW_CHANGED` before the requested mutation. It rechecks live state before removal, and rechecks journal and absence before restoration. The desktop refreshes records on this error, shows a recoverable message, and requires a new review and confirmation; it never automatically retries a mutation. Successful changes also refresh the list.

This is optimistic stale-review protection, not an atomic registry compare-and-swap. Another process can still change registry state between a check and the operating-system write. Machine and startup-folder entries remain outside this workflow. Focused fixtures use an in-memory registry adapter and real isolated journals; real startup changes and built interaction require separate runtime evidence.


## Real engine registry verification

The built engine at `785a79c10d8c3318dc8b6a69aa17562fd7e0ae74` was exercised through its request-file interface against one uniquely named disposable current-user Run entry and isolated recovery records. A command changed after listing was rejected with `STARTUP_REVIEW_CHANGED`, preserving the changed value and creating no recovery journal. A fresh review then disabled the entry, preserving the exact raw command and `REG_EXPAND_SZ` kind in its journal. Restoration reproduced both exactly and removed that journal. The verified disposable entry was removed afterward; existing startup entries were not modified.

[The sanitized evidence summary](../../verification/startup-registry.json) binds the engine, source and private observations. This is real registry behavior, not a GUI interaction receipt and not atomic compare-and-swap proof. Desktop confirmation, refresh and keyboard behavior remain separate runtime work.

真正引擎已用一個獨有、即棄嘅目前使用者啟動項目驗證：覆核後改動嘅命令會被拒絕，重新覆核先可以停用，再復原完全相同嘅原始命令及登錄類型。測試項目已移除，既有項目冇改。呢份係真實登錄操作證據，唔代表介面操作或原子比較交換已驗證。

## Real desktop round trip

At `bab873cb655848ad8d4e13081ff8fd5ea46d50f8`, the actual 1280×1000 bilingual dark desktop completed cancelled review, stale-review rejection, a fresh disable review and exact command/type restoration for one uniquely named disposable current-user Run entry. Independent checks verified that stale review left the changed entry intact without a journal, disable preserved the reviewed raw command and `REG_EXPAND_SZ`, and restoration reproduced both. The owned entry and journal were removed afterward. All owned bundle processes and the hidden desktop were closed.

The stale-feedback frame exposed a missing Cantonese translation. A focused source correction and visible-feedback regression were added; the corrected minimum-size runtime is recorded below. Inspected painted frames and their timestamped sidecars remain private pending complete diagnostic provenance. See `docs/verification/startup-gui.json`.

## Verified startup minimum-size feedback

The exact root desktop build passed at `549ea20ebaccee35b7ee1334d8b27dd28807aa03`. A fresh hidden run at 800×600, bilingual dark theme, text scale 2 and reduced motion verified the real review dialog and corrected English/Cantonese stale feedback. Page Down reached the lower controls and Page Up brought the complete feedback into view. The stale review preserved the changed disposable Run value and created no journal. The fixture entry was removed afterward, all owned bundle processes were absent and the hidden desktop closed. See `docs/verification/startup-minimum.json` and `scripts/verify-startup-minimum.mjs`.

The earlier 1280×1000 run at `bab873cb655848ad8d4e13081ff8fd5ea46d50f8` independently verified cancellation, stale rejection, fresh disable and exact command/type restoration. Its historical missing-translation observation is retained, and this newer run verifies the correction. New frames remain private because native/framework diagnostic collection is not yet implemented. Full accessibility, motion, theme, scale and physical-DPI coverage remain incomplete.

中文：800×600、雙語深色及兩倍文字嘅實際覆核按鈕可見；資料過期時保留已變更項目，冇建立復原記錄。Page Up 可讀到完整中英文提示。即棄項目已移除，專用程序及隱藏桌面已關閉。新畫面仍未公開，完整外觀及無障礙驗證仍待完成。

