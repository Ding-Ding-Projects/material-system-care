# Managed package discovery

In **Apps**, choose **WinGet matches** in the inventory-source selector, select **Discover WinGet packages** and review the network disclosure. **Installed applications** is a separate read-only registry and AppX inventory. Each source uses dedicated cards with name, installed version and source; changing source clears prior records and actions. The engine uses the installed WinGet client to export installed package matches from its standard `winget` source. Display names and formatted console tables are never guessed into package identifiers.

Each managed card contains the exact package identifier and optional installed version. Select **Review upgrade** or **Review uninstall** and review the exact target before proceeding. Discovery changes no installed package, accepts no new source agreement, and does not imply consent to a later operation. Existing source agreements and a working WinGet installation are required; a missing client or unsuccessful discovery has an explicit unavailable result and its bounded cause. Invalid data is distinguished from a valid unavailable response and a successful empty inventory.

Confirmation sends only the exact package identifier and consent. A result must match that identifier, contain a consistent completion/exit-code pair and explicitly state that no restart was initiated before success is reported. Every attempted mutation refreshes discovery without automatically repeating the mutation. A failed refresh removes prior actions. The engine does not compare the installed version to its reviewed value, so concurrent changes remain possible. Removal creates no rollback copy. These limits are repeated in the review dialog.

中文：應用程式工作區分開一般唯讀清單及 WinGet 配對。探索、升級同移除各自要覆核；只有確實配對識別碼可以發送操作。來源不可用會保留實際原因，唔會同空清單或無效資料混埋。移除不會建立復原副本，覆核後版本亦可能被其他程序改變。

The export does not establish available update versions. Rows say `updateAvailability: "not-checked"`; WinGet checks applicability when a separately confirmed upgrade is requested. Packages that WinGet cannot match are omitted by its export and remain visible in the general installed inventory. This is not a complete inventory or evidence that removal is safe.

## Protocol and bounds

`apps.managed` takes an empty parameter object and returns `{available, records, completeInstalledInventory:false, updateAvailability, limitation}` on success. Unavailable results include a reason and, where available, the command exit code. The method is registered in `engine.ping.capabilities` and belongs to the management module.

Discovery has a ninety-second deadline, bounded output streams, a 2 MiB JSON limit, a depth limit and at most 10,000 package records. While WinGet runs, the output length is checked every 100 ms and an oversized export cancels discovery. This polling bound is not a filesystem quota: the producer can write beyond the threshold between observations. Malformed records, duplicate IDs and unsupported source identities fail closed. Fixture contexts cannot run host discovery. The command uses a fixed executable and argument list, with no shell or user-supplied switches.

The request owns a unique local scratch directory. Cleanup targets only its exact export file and empty directory. If either cannot be removed, `DISCOVERY_CLEANUP_INCOMPLETE` explicitly reports that a local inventory copy may remain; the request does not report success. Console output is drained but not returned; exported custom arguments, source endpoints and extra metadata are excluded from the projection. Results are not automatically uploaded or added to general operation history. WinGet may contact its configured source as disclosed before discovery.

Cancellation requests termination of the owned discovery process tree and observes the direct process exit with a separate five-second deadline. An unconfirmed direct-process exit returns `DISCOVERY_TEARDOWN_INCOMPLETE`; parent exit alone does not establish descendant exit. If cleanup also fails, its retained-inventory warning takes precedence in the single-code response.

## Verification

The installed client rejected an export path under the application's LocalAppData directory with `0x80070003`. Identical arguments succeeded in the account's temporary directory. Requests therefore use uniquely named temporary directories rather than the maintenance data directory; only their exact output and empty directory are cleanup targets.

Integrated fixtures verify exact-ID projection, unknown update status, omitted custom switches, malformed/duplicate/oversized export rejection, fixture isolation and mutation consent. The Flutter fixture proves that discovery waits for explicit review, cancelling the selected upgrade review makes no mutation request, and an unavailable refresh removes stale actionable rows. A built read-only query returned 45 matches with explicit incomplete-inventory and unchecked-update states, followed by zero remaining request-owned export directories. No installed package was changed during these checks. Source bindings and pending visual interaction are separately tracked in the handoff.

Sources: [Microsoft's export command](https://learn.microsoft.com/en-us/windows/package-manager/winget/export) and [the official package-export schema](https://github.com/microsoft/winget-cli/blob/master/schemas/JSON/packages/packages.schema.2.0.json).
