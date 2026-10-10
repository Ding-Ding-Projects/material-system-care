# Managed package discovery

In **Apps**, choose **WinGet matches** in the inventory-source selector, select **Discover WinGet packages** and review the network disclosure. **Installed applications** is a separate read-only registry and AppX inventory. Each source uses dedicated cards with name, installed version and source; changing source clears prior records and actions. The engine uses the installed WinGet client to export installed package matches from its standard `winget` source. Display names and formatted console tables are never guessed into package identifiers.

Each managed card contains the exact package identifier and optional installed version. Select **Review upgrade** or **Review uninstall** and review the exact target before proceeding. Discovery changes no installed package, accepts no new source agreement, and does not imply consent to a later operation. Existing source agreements and a working WinGet installation are required; a missing client or unsuccessful discovery has an explicit unavailable result and its bounded cause. Invalid data is distinguished from a valid unavailable response and a successful empty inventory.

General installed-inventory display metadata has separate quality states. An invalid name, version or publisher is discarded and rendered with a fixed localized unavailable label; it is not truncated, repaired or used in search. Stable identifiers, source, scope and read-only capability checks remain strict. The workspace counts affected records separately from inaccessible inventory sources. Managed-package records retain their original strict validation and never become actionable through display fallbacks.

中文：一般已安裝清單會分開處理顯示資料品質。名稱、版本或發行者無效時，原值會捨棄，改用固定本地化提示，不會截短或猜測內容。識別碼、來源、範圍及唯讀限制仍嚴格驗證；受影響記錄數與來源不可讀警告分開顯示。WinGet 操作資料仍維持原本嚴格規則。

Confirmation sends only the exact package identifier and consent. A result must match that identifier, contain a consistent completion/exit-code pair and explicitly state that no restart was initiated before success is reported. Every attempted mutation refreshes discovery without automatically repeating the mutation. A failed refresh removes prior actions. The engine does not compare the installed version to its reviewed value, so concurrent changes remain possible. Removal creates no rollback copy. These limits are repeated in the review dialog.

中文：應用程式工作區分開一般唯讀清單及 WinGet 配對。探索、升級同移除各自要覆核；只有確實配對識別碼可以發送操作。來源不可用會保留實際原因，唔會同空清單或無效資料混埋。移除不會建立復原副本，覆核後版本亦可能被其他程序改變。

The export does not establish available update versions. Rows say `updateAvailability: "not-checked"`; WinGet checks applicability when a separately confirmed upgrade is requested. Packages that WinGet cannot match are omitted by its export and remain visible in the general installed inventory. This is not a complete inventory or evidence that removal is safe.

## Protocol and bounds

`apps.managed` takes an empty parameter object and returns `{available, records, completeInstalledInventory:false, updateAvailability, limitation}` on success. Unavailable results include a reason and, where available, the command exit code. The method is registered in `engine.ping.capabilities` and belongs to the management module.

Discovery has a ninety-second deadline, bounded output streams, a 2 MiB JSON limit, a depth limit and at most 10,000 package records. While WinGet runs, the output length is checked every 100 ms and an oversized export cancels discovery. This polling bound is not a filesystem quota: the producer can write beyond the threshold between observations. Malformed records, duplicate IDs and unsupported source identities fail closed. Fixture contexts cannot run host discovery. The command uses a fixed executable and argument list, with no shell or user-supplied switches.

The request owns a unique local scratch directory. Cleanup targets only its exact export file and empty directory. If either cannot be removed, `DISCOVERY_CLEANUP_INCOMPLETE` explicitly reports that a local inventory copy may remain; the request does not report success. Console output is drained but not returned; exported custom arguments, source endpoints and extra metadata are excluded from the projection. Results are not automatically uploaded or added to general operation history. WinGet may contact its configured source as disclosed before discovery.

Cancellation requests termination of the owned discovery process tree and observes the direct process exit with a separate five-second deadline. An unconfirmed direct-process exit returns `DISCOVERY_TEARDOWN_INCOMPLETE`; parent exit alone does not establish descendant exit. If cleanup also fails, its retained-inventory warning takes precedence in the single-code response.

## Verification

The display-quality repair passed the integrated root desktop build at `6ec050099d6239b5b230b9d703a28b55b732ddfc`. Real general inventory then displayed 741 records with four explicit degraded-display warnings. Searching the localized fallback returned exactly four records; a nonmatching query returned zero; the actual Select all context-menu action and Backspace restored all 741. No package mutation was requested. Six representative private frames passed the narrow source/bundle/two-hook verifier. See [bounded observations](../../verification/package-display-quality-observations.json). The text-selection menu itself remained English-only in bilingual mode, so complete menu localization is still unfinished. Synthetic Ctrl+A did not select all and is not counted as shortcut proof.

中文：顯示品質修正嘅實際清單有七百四十一項，四項清楚標示顯示資料不可用。搜尋提示字得到四項，不符合查詢得到零項，透過實際選單全選及退格清除後恢復全部記錄。沒有要求更改任何套件。文字選取選單仍只有英文，完整選單本地化尚未完成。

The combined desktop at `bc8274a0bdf0ec984ee6cadbf3c01cda52facfc7` completed explicit real discovery with 45 matched packages at the time of the run. A selected package's upgrade review displayed its exact identifier and installed version, and the review was cancelled. No upgrade or uninstall was confirmed. The owned process and hidden desktop were closed. New frame receipts contain observed framework/platform diagnostic intervals; this is not universal native-error coverage.

That run exposed an English-only popup and an untranslated discovery title in bilingual mode. The navigator now inherits the same language preferences and the title has a Cantonese translation. The regression opens the actual popup in bilingual and Cantonese-only modes; the old source failed and the corrected source passed. A subsequent real minimum-size run verified both corrected surfaces.

The integrated source `6d3695e738b0902390e473f6aaf1fb153c30f106` passed the root desktop build. Its real 800×600 bilingual dark run with doubled text verified discovery, Page Down into later cards, visible Tab focus, Enter opening the selected removal review, explicit cancellation, and continued Page Down/Page Up navigation. No package mutation was confirmed. Escape did not dismiss the review; use the visible Cancel action. Fifteen inspected frames and eighteen supporting hashes are recorded in [the frame manifest](../../verification/packages-keyboard-frames.json) and [bounded observations](../../verification/packages-keyboard-observations.json). Local inventory pixels remain private.

Normal keyboard paging animates for 200 ms; reduced-motion paging moves immediately. After discovery the results target receives focus only if the user has not moved focus elsewhere. Text editing retains its key behavior. The focused tests include a 45-record minimum-size case and newer editing-focus preservation. Real normal-motion, all themes/scales, general installed-inventory interaction and complete accessibility verification remain separate work.

中文：合併版本嘅真正最小視窗已驗證探索、下翻至較後卡片、Tab 操作焦點、Enter 開啟指定覆核，以及明確取消後繼續上下翻頁。沒有確認任何套件變更。一般翻頁用二百毫秒動畫，減少動態即時移動；使用者已移去輸入欄嘅焦點會保留。完整外觀及無障礙驗證仍待完成。

The installed client rejected an export path under the application's LocalAppData directory with `0x80070003`. Identical arguments succeeded in the account's temporary directory. Requests therefore use uniquely named temporary directories rather than the maintenance data directory; only their exact output and empty directory are cleanup targets.

Integrated fixtures verify exact-ID projection, unknown update status, omitted custom switches, malformed/duplicate/oversized export rejection, fixture isolation and mutation consent. The Flutter fixture proves that discovery waits for explicit review, cancelling the selected upgrade review makes no mutation request, and an unavailable refresh removes stale actionable rows. A built read-only query returned 45 matches with explicit incomplete-inventory and unchecked-update states, followed by zero remaining request-owned export directories. No installed package was changed during these checks. Source bindings and pending visual interaction are separately tracked in the handoff.

Sources: [Microsoft's export command](https://learn.microsoft.com/en-us/windows/package-manager/winget/export) and [the official package-export schema](https://github.com/microsoft/winget-cli/blob/master/schemas/JSON/packages/packages.schema.2.0.json).

## Keyboard review dialogs

Package discovery and selected-package review dialogs own a separate scroll controller and keyboard paging target. Page Down and Page Up from dialog actions or non-editing content scroll only the dialog, and repeated paging retains that target. Editable text keeps its standard selection and editing keys. Normal paging animates for 200 milliseconds with ease-out cubic easing; reduced motion scrolls immediately.

Cancel and confirmation keep their existing result semantics. Cancelling a review makes no package-change request. Both dialog outcomes restore the prior usable focus target, or the package-results target when the original control is no longer available, before continuing the existing workflow. The dialog disposes its own scrolling and focus resources when closed. This behavior does not add any package operation or change the exact-ID consent boundary.

Focused widget checks use the actual isolated application at 800 by 600, bilingual dark preferences and 200% text size. They exercise repeated and reverse paging, both motion modes, editing exclusion, cancel without mutation and dialog disposal. These checks are not new live runtime evidence.
