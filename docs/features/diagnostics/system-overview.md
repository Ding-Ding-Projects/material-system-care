# Machine overview

The Home workspace shows a dedicated machine overview. **Refresh measurements** requests one `system.snapshot` sample. There is no automatic measurement polling, benchmark, CPU-utilization estimate, health score or cleanup result on this page.

The top of the page retains the shared build-provenance component. Its version and updated-at values come from `engine.ping` and the build receipt. They are separate from the sample timestamp. Sample age is calculated when the view renders and is labelled accordingly; it does not imply continuous live updates. A future sample timestamp is reported as ahead of the display clock rather than converted into a negative age.

The overview shows the operating-system description and architecture, logical processor count, available physical-memory measurements, and reported drives. Memory load comes from the operating-system sample. Used memory is total minus available bytes. Drive usage is total minus available free bytes. Both are capacity measurements, not health or performance scores. Ready drive details expose the volume format and byte counts. Unready or inaccessible drives and unavailable memory remain explicit, while other valid measurements stay visible.

The typed boundary requires a UTC sample timestamp, `measurementSource: live-machine`, a boolean fixture-data flag, bounded processor count and descriptions, safe nonnegative byte integers and valid capacity relations. Memory availability, load percentages and drive readiness are validated before rendering. Contradictory or malformed rows reject the complete sample. A failed refresh clears the earlier measurements. Disposing the page prevents late responses from changing the interface.

An isolated data directory does not make these measurements synthetic: the engine still reads the current machine. That distinction is shown when `fixtureDataRoot` is true. No private data-directory path is displayed.

Controls use official Flutter Material components. Capacity indicators animate for 250 ms in normal mode and update immediately in reduced-motion mode. Drive details explicitly disable both expansion and collapse animation when reduced motion is selected. Persistent Page Up and Page Down navigation remains available through long drive lists. Full descriptions, drive identifiers and timestamps remain selectable.

`--system-overview` selects the overview for the existing isolated capture route. A valid capture request must select exactly one workspace, and capture preferences never fall back to saved personal settings. The option does not inject measurements or request a sample automatically.

Focused parser and widget tests cover malformed snapshots, partial availability, future timestamps, explicit refresh, stale-data removal, pending completion after disposal, build provenance, indicator and expansion motion, and bilingual 800 × 600 layout at text scale 2. These are source-level checks, not a claim of live machine or physical-display verification.

中文：本機總覽只會喺按「重新整理量度數據」之後取樣，唔會自動輪詢或估算 CPU 使用率、健康分數。記憶體同磁碟容量都係當時讀數，唔代表健康或可回收空間。部分資料無法提供會清楚顯示，無效新回應會清除舊資料。建置更新時間同取樣時間分開處理。
