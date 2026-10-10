# Startup action review

Startup record actions name the enable or disable effect, explain future sign-in behavior and block unavailable or conflicting records. Confirmation sends only the selected id, desired enabled state, server-issued `reviewRevision`, and explicit consent. The revision deterministically covers the name, raw command, registry value kind, and enabled or restoration state. Commands are not copied into the mutation request.

The engine saves the original current-user Run command before removal and restores only where no newer entry occupies the name. It rejects missing revisions and changed commands, kinds, journals, or missing records with `STARTUP_REVIEW_CHANGED` before the requested mutation. It rechecks live state before removal, and rechecks journal and absence before restoration. The desktop refreshes records on this error, shows a recoverable message, and requires a new review and confirmation; it never automatically retries a mutation. Successful changes also refresh the list.

This is optimistic stale-review protection, not an atomic registry compare-and-swap. Another process can still change registry state between a check and the operating-system write. Machine and startup-folder entries remain outside this workflow. Focused fixtures use an in-memory registry adapter and real isolated journals; real startup changes and built interaction require separate runtime evidence.


## Real engine registry verification

The built engine at `785a79c10d8c3318dc8b6a69aa17562fd7e0ae74` was exercised through its request-file interface against one uniquely named disposable current-user Run entry and isolated recovery records. A command changed after listing was rejected with `STARTUP_REVIEW_CHANGED`, preserving the changed value and creating no recovery journal. A fresh review then disabled the entry, preserving the exact raw command and `REG_EXPAND_SZ` kind in its journal. Restoration reproduced both exactly and removed that journal. The verified disposable entry was removed afterward; existing startup entries were not modified.

[The sanitized evidence summary](../../verification/startup-registry.json) binds the engine, source and private observations. This is real registry behavior, not a GUI interaction receipt and not atomic compare-and-swap proof. Desktop confirmation, refresh and keyboard behavior remain separate runtime work.

真正引擎已用一個獨有、即棄嘅目前使用者啟動項目驗證：覆核後改動嘅命令會被拒絕，重新覆核先可以停用，再復原完全相同嘅原始命令及登錄類型。測試項目已移除，既有項目冇改。呢份係真實登錄操作證據，唔代表介面操作或原子比較交換已驗證。
