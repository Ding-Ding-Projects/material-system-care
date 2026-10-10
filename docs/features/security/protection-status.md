# Read-only protection status

Open **Protection status** from the Protection workspace, then choose **Refresh protection status**. The page calls only `security.status`; it never starts a scan, changes firewall or Defender settings, or requests a restart. The separately confirmed Quick scan action remains in the Protection workspace. Entering either the workspace or the status page does not automatically read status.

The result presents Microsoft Defender service and feature booleans, the antivirus signature version, provider timestamps, and the Domain, Private and Public firewall profiles. Null Defender fields remain **Not reported**, not false. Defender and firewall unavailability are reported independently using their source-specific reasons. These observations do not establish that the machine is healthy, secure or threat-free.

The engine uses its existing constant Windows PowerShell script. In that route, Defender booleans serialize as JSON booleans, while firewall enums serialize as integers. The status page validates the installed NetSecurity definitions: enabled values are 0 (False), 1 (True), and 2 (NotConfigured); default actions are 0 (NotConfigured), 2 (Allow), and 4 (Block). All three distinct profiles must be present when the firewall source is available. Profile settings alone do not prove effective traffic filtering.

Windows PowerShell 5.1 serializes provider dates using `/Date(milliseconds)/`, optionally with an original local offset suffix. The milliseconds identify a UTC instant. The page validates the representation and range, converts that instant to selectable UTC text, and does not apply the suffix twice. Null dates remain **Not reported**. The separately labelled receipt time records when the desktop accepted the response; it is not a provider measurement time. Provider dates may reflect cached state.

Required fields, booleans, enums, profile uniqueness, bounded signature strings, dates and source/reason consistency are checked before rendering. A malformed response is rejected as a whole. An unsuccessful refresh clears previous status, displays a bounded local message, and exposes no raw exception. Refresh cannot be reentered while pending, and a disposed page ignores late replies. There is no automatic polling.

The page uses official Material controls, selectable details and persistent Page Up/Page Down focus. Firewall expansion and collapse use explicit zero duration in reduced-motion mode; normal mode retains the framework animation. The status page has no mutation controls. `--protection-status` adds an isolated capture destination with the existing exclusive destination and private-preference boundaries; it injects no status records.

Focused tests cover numeric enum and PowerShell date semantics, malformed responses, source-specific unavailability, explicit refresh, stale status, disposal, scan separation, capture isolation, and bilingual 800 × 600 layout at text scale 2 with normal and reduced motion. Synthetic PowerShell serialization confirmed the transport representation without reading or changing protection settings. These checks do not claim live protection-status verification.

中文：防護狀態頁面只會喺按重新整理之後讀取資料，唔會開始掃描、更改設定或要求重新啟動。Defender 同防火牆各自顯示無法使用原因，未回報欄位唔會當成「否」。日期會按 PowerShell 格式轉成 UTC，接收時間同提供者時間分開處理。呢啲資料唔能夠證明本機健康或冇威脅。
