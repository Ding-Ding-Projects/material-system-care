# Hardware and operating-system inventory

`system.inventory` captures an immutable local report and returns its first page. The fixed PowerShell CIM adapter queries only selected fields from `Win32_Processor`, `Win32_OperatingSystem`, `Win32_ComputerSystem`, `Win32_BaseBoard`, `Win32_BIOS`, `Win32_PhysicalMemory`, `Win32_VideoController`, `Win32_DiskDrive` and `Win32_PnPEntity`. It never accepts a class, script, hostname or remote connection from a request.

CPU records contain provider-reported model, manufacturer, cores, logical processors, maximum clock and architecture. OS records contain caption, version, build and architecture. Other categories contain computer/board/firmware descriptions, physical-memory module capacities and configured speeds, video-controller names and driver versions, physical-disk models and capacities, and device category/status/error codes. Nullable fields remain null. Maximum clock is not a real-time frequency. Device status is not independent hardware-health proof.

Serial numbers, processor identifiers, device-instance identifiers, computer name, registered user, user profiles, network addresses and license keys are absent from the allowlist. Device friendly names can contain user-assigned labels; review any report before sharing it. No raw CIM object or provider error text is returned or logged.

Each category returns an explicit provider state with availability, safe code/reason, count and truncation. An available zero-record category means zero records were returned. Missing providers, access denial and timeout remain distinct unavailable states. The adapter limits each category to 256 rows, the complete output to 2 MiB, each CIM operation to two seconds and the complete child query to 25 seconds. Cancellation terminates only the owned query process and verifies exit within a further five seconds. Teardown uncertainty is an error, never successful inventory. A malformed projection fails with `INVALID_SYSTEM_INVENTORY`.

Requests accept integer `offset` (default 0) and `limit` (1..200, default 100). Results contain `reportId`, content `revision`, UTC created/observed/expiry times, exact total/page counts, `nextOffset`, records, provider states, unavailable sensors, privacy exclusions and an optional measured resource sample. `system.inventory.page` requires the original `reportId` and `revision`, accepts the same pagination and optional registered `category`. IDs such as `cpu:0` are slots within that immutable report, never global hardware identities. Later pages read the same observations without recollecting. Invalid offsets, stale revisions, unknown reports and expired reports fail explicitly.

Reports are retained locally for 24 hours with at most 30 unexpired reports, each bounded to 2 MiB. New captures transactionally reclaim expired report-cache rows before admission. A full unexpired cache rejects new admission and preserves existing rows. No snapshot is written to general history or uploaded.

Temperature, GPU utilization and SMART-health entries are explicitly unavailable. ACPI thermal-zone readings are not silently relabelled as CPU or GPU temperature. Video-controller descriptions and disk capacity never imply GPU load or SMART health. Video-controller provider values may be inaccurate on hardware incompatible with WDDM, so no GPU memory amount is inferred from `AdapterRAM`.

Fixture contexts never fall through to real host inventory. Integrated fixtures inject synthetic allowlisted providers and measurements, then verify counts, pagination, malformed output, sensitive-field rejection, missing/denied/timed-out providers, report expiry and capacity. Built workspace interaction and live provider verification remain separate evidence.

The published engine's `--system-inventory-diagnostic` route performs the same bounded live read but prints only provider states/counts, unavailable sensor declarations and privacy exclusions. It does not construct an engine context, retain observations or print hardware values. It returns 0 when at least one provider is available, 2 when every provider is unavailable and 1 on an invalid query result. This route supports privacy-preserving live adapter verification independently of disposable fixtures.

## Official references

- [Get-CimInstance](https://learn.microsoft.com/en-us/powershell/module/cimcmdlets/get-ciminstance)
- [Win32_Processor](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-processor)
- [Win32_OperatingSystem](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-operatingsystem)
- [Win32_VideoController and its WDDM limitation](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-videocontroller)
- [Win32_DiskDrive](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-diskdrive)
- [Win32_PnPEntity](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-pnpentity)
