import 'package:flutter/material.dart';

class CopyScope extends InheritedWidget {
  const CopyScope({super.key, required this.preferences, required super.child});
  final Map<String, dynamic> preferences;
  static Map<String, dynamic> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CopyScope>()?.preferences ??
      {};
  @override
  bool updateShouldNotify(CopyScope oldWidget) =>
      oldWidget.preferences != preferences;
}

const translations = <String, String>{
  "File use": "檔案使用情況",
  "Inspect a file in use": "檢視檔案使用情況",
  "Restart Manager reports affected applications and services, not every possible file handle. Results can change after inspection.":
      "重新啟動管理員會列出受影響的應用程式及服務，並非所有檔案控制代碼。檢查後結果可能改變。",
  "Local file path": "本機檔案路徑",
  "Choose file": "選擇檔案",
  "Inspect file use": "檢查檔案使用情況",
  "Choose a file, then inspect. Nothing is collected automatically.":
      "請選擇檔案後再檢查，不會自動收集資料。",
  "Inspected file": "已檢查的檔案",
  "Service": "服務",
  "No affected applications were reported. This does not prove that the file is unlocked.":
      "沒有回報受影響的應用程式，但這不代表檔案沒有被鎖定。",
  "Restart Manager marks this record as restartable. No restart is requested.":
      "重新啟動管理員將此記錄標示為可重新啟動；此處沒有發出重新啟動要求。",
  "Restart Manager does not mark this record as restartable.":
      "重新啟動管理員沒有將此記錄標示為可重新啟動。",
  "This inspection does not close processes or handles, unlock files, or change file contents.":
      "此檢查不會關閉程序或控制代碼、解除檔案鎖定，亦不會更改檔案內容。",
  "The file picker is unavailable. Enter a full local file path.":
      "檔案選擇器無法使用，請輸入完整本機檔案路徑。",
  "Choose an existing file using its full local path.": "請使用完整本機路徑選擇現有檔案。",
  "File use changed during inspection. Try again.": "檢查期間檔案使用情況已改變，請再試一次。",
  "Too many affected records were reported. No partial result is shown.":
      "回報的受影響記錄太多，不會顯示不完整結果。",
  "File-use inspection requires Windows.": "檔案使用情況檢查需要 Windows。",
  "Windows Restart Manager could not inspect this file.":
      "Windows 重新啟動管理員無法檢查此檔案。",
  "File-use inspection is unavailable. No process or handle was closed.":
      "無法檢查檔案使用情況，沒有關閉任何程序或控制代碼。",
  "Processes": "程序",
  "Inspect running processes": "檢視運行中程序",
  "Memory is a point-in-time working set. CPU time is cumulative, not current utilization. Records can change after collection.":
      "記憶體係當時嘅工作集。CPU 時間係累計值，唔係即時使用率。收集後記錄可能改變。",
  "Refresh processes": "更新程序",
  "Filter by process name or PID": "按程序名稱或 PID 篩選",
  "Request graceful close?": "要求正常關閉？",
  "Save work first. The selected application may ask about unsaved work, decline, or remain open. This never forces termination.":
      "請先儲存工作。所選應用程式可能詢問未儲存內容、拒絕或繼續開啟。此操作絕不強制終止。",
  "Request close": "要求關閉",
  "Close requested. Process exit is not confirmed. Refresh to observe current records.":
      "已要求關閉，未確認程序已退出。請更新查看目前記錄。",
  "No close request was accepted. The process may still be running.":
      "關閉要求未被接受，程序可能仍在運行。",
  "Close outcome is unavailable. Do not assume the process stopped. Refresh before another request.":
      "未能取得關閉結果，請勿假設程序已停止。再次要求前請先更新。",
  "Process records are unavailable. Refresh to try again.": "未能取得程序記錄，請更新重試。",
  "Working set bytes": "工作集位元組",
  "Cumulative CPU milliseconds": "累計 CPU 毫秒",
  "Started at UTC": "開始時間 UTC",
  "Graceful close is unavailable for this record.": "此記錄未能使用正常關閉。",
  'Cancel scan': '取消掃描',
  'Cancellation requested…': '已要求取消…',
  'Stopped waiting for scan.': '已停止等候掃描。',
  'The engine was asked to cancel and may still be finishing.':
      '已要求引擎取消，佢可能仍然完成緊手上步驟。',
  'Cancellation was not accepted. The scan may still be running.':
      '取消要求未獲接受，掃描可能仍然進行中。',
  'Review recovery files': '覆核復原檔案',
  'Recorded state': '已記錄狀態',
  'Recovery details are unavailable.': '未能讀取復原詳情。',
  'This recovery record contains no files.': '此復原記錄冇任何檔案。',
  'Review recorded files before restoration. Existing files will not be overwritten; availability is checked during restoration.':
      '復原前請覆核已記錄檔案。現有檔案唔會被覆蓋；復原時會重新檢查可用狀態。',
  'Only selected temporary files will move to recovery.': '只有已選取嘅暫存檔會移到復原儲存區。',
  'Move selected temporary files to recovery?': '將已選取暫存檔移到復原儲存區？',
  'Apply selected cleanup targets': '處理已選取清理項目',
  'Select visible targets': '選取目前顯示項目',
  'Clear selection': '清除選取',
  "Discover managed packages?": "探索可管理套件？",
  "Discover WinGet packages": "探索 WinGet 套件",
  "WinGet may contact its configured source to match installed packages. No packages will be changed, and new source agreements will not be accepted.":
      "WinGet 可能連接已設定來源以比對已安裝套件。不會更改套件，亦不會接受新的來源協議。",
  "Only installed packages matched by WinGet are listed. Unmatched applications remain in the general inventory. Available update versions are not inferred from an export.":
      "只列出 WinGet 成功比對的已安裝套件。未能比對的程式仍在一般清單中；匯出資料不會被當作可用更新版本。",
  "WinGet discovery is unavailable.": "無法探索 WinGet 套件。",
  "The local engine connection is unavailable.": "本機引擎連線無法使用。",
  "Crash collection exceeded fifteen seconds. Try a shorter period.":
      "當機資料收集超過十五秒，請選擇較短期間。",
  "Crash evidence exceeded the output limit. Choose a shorter period.":
      "當機證據超過輸出上限，請選擇較短期間。",
  "Crash event collection requires Windows.": "收集當機事件需要 Windows。",
  "The local diagnostic request could not complete. Reconnect the engine and try again.":
      "本機診斷要求未能完成，請重新連接引擎後再試。",
  "Only the newest 50 matching events are shown. Choose a shorter period to narrow the result.":
      "只顯示最近 50 項符合條件的事件，請選擇較短期間以縮窄結果。",
  "A redirected dump directory was not inspected.": "未檢查重新導向的傾印目錄。",
  "Dump inventory is limited to 100 records.": "傾印清單上限為 100 項記錄。",
  "Dump metadata is unavailable for this account. No elevation was requested.":
      "此帳戶無法讀取傾印檔案資料，並未要求提升權限。",
  "A dump record changed or could not be read. Refresh to try again.":
      "傾印記錄已更改或無法讀取，請重新整理後再試。",
  "Blue-screen diagnostics": "藍畫面診斷",
  "Investigate a crash": "調查當機",
  "Read local crash events and dump metadata. Dump contents stay untouched. Nothing is uploaded or repaired.":
      "讀取本機當機事件及傾印檔案資料。不會讀取傾印內容、上傳或進行修復。",
  "Event lookback": "事件查閱期間",
  "7 days": "7 日",
  "30 days": "30 日",
  "90 days": "90 日",
  "365 days": "365 日",
  "Read crash evidence": "讀取當機證據",
  "Stop code": "停止代碼",
  "Explain stop code": "解釋停止代碼",
  "A stop code describes a condition, not a confirmed cause.":
      "停止代碼描述當時狀況，並不代表已確認原因。",
  "Crash evidence could not be read. No permissions were changed. Try again or check Event Viewer.":
      "未能讀取當機證據，權限並無更改。請重試或查看事件檢視器。",
  "Enter a valid hexadecimal stop code or unsigned decimal number.":
      "請輸入有效十六進制停止代碼或無符號十進制數字。",
  "Recorded events": "已記錄事件",
  "Event times can follow the crash or restart. An unexpected restart alone does not prove a blue screen.":
      "事件時間可能在當機或重新啟動之後。單憑意外重新啟動不能證明出現過藍畫面。",
  "No matching events in this period.": "這段期間沒有符合條件的事件。",
  "This does not rule out a crash. Event records may be unavailable or cleared.":
      "這不能排除曾經當機，事件記錄可能無法讀取或已被清除。",
  "Stop code recorded": "已記錄停止代碼",
  "Crash report without a readable code": "當機報告沒有可讀取代碼",
  "Unexpected restart": "意外重新啟動",
  "Time unavailable": "時間不詳",
  "Event": "事件",
  "Available dump metadata": "可讀取的傾印檔案資料",
  "No accessible dump files found.": "找不到可讀取的傾印檔案。",
  "bytes": "位元組",
  "Metadata only": "只限檔案資料",
  "Some dump metadata was unavailable or the inventory reached its limit.":
      "部分傾印檔案資料無法讀取，或清單已達數量上限。",
  "Next checks": "下一步檢查",
  "Compare recent driver, firmware, hardware, and Windows updates. Preserve dump files before changing anything. Use Microsoft WinDbg with matching symbols for deeper analysis.":
      "核對近期驅動程式、韌體、硬件及 Windows 更新。更改前請保留傾印檔案，並使用 Microsoft WinDbg 及相符符號作深入分析。",
  "This workspace does not analyze stacks or symbols, identify a culprit driver, change drivers, or restart Windows.":
      "此工作區不會分析堆疊或符號、判定肇因驅動程式、更改驅動程式或重新啟動 Windows。",
  'Material System Care': 'Material System Care',
  'Overview': '總覽',
  'Storage': '儲存空間',
  'Apps': '應用程式',
  'Startup': '開機項目',
  'Protection': '保護',
  'Drivers': '驅動程式',
  'Tools': '工具',
  'Activity': '操作記錄',
  'Settings': '設定',
  'Help': '說明',
  'Refresh workspace': '重新整理工作區',
  'Workspace': '工作區',
  'Refresh records': '重新讀取記錄',
  'Analyze folder': '分析資料夾',
  'Scan recoverable cleanup': '掃描可還原清理項目',
  'Find exact duplicates': '尋找完全相同檔案',
  'Check available updates': '檢查可用更新',
  'Quick scan': '快速掃描',
  'Recovery history': '還原記錄',
  'Choose folder': '選擇資料夾',
  'Apply reviewed cleanup plan': '套用已檢閱清理方案',
  'Folder to analyze': '要分析的資料夾',
  'Enter a local folder. Analysis does not remove files.': '輸入本機資料夾。分析不會移除檔案。',
  'Filter these records': '篩選這些記錄',
  'Regular expression builder': '正則表達式建立工具',
  'Use regular expression': '使用正則表達式',
  'Contains text': '包含文字',
  'Starts with': '開頭是',
  'Ends with': '結尾是',
  'Digits': '數字',
  'One of': '其中一項',
  'Invalid regular expression': '正則表達式無效',
  'Waiting for measured engine result': '正在等待引擎實際結果',
  'Operation unavailable': '操作暫時無法使用',
  'Retry': '重試',
  'Reading local records…': '正在讀取本機記錄…',
  'No measured result yet. Start an operation above.': '尚未有實際結果，請先在上方開始操作。',
  'No matching records.': '沒有符合的記錄。',
  'Record actions': '記錄操作',
  'Uninstall selected app': '解除安裝所選程式',
  'Upgrade selected app': '更新所選程式',
  'Change selected startup entry': '變更所選開機項目',
  'Export selected driver': '匯出所選驅動程式',
  'Restore selected cleanup': '還原所選清理項目',
  'Actions use the selected record only': '操作只處理所選記錄',
  'Review selected action': '檢閱所選操作',
  'Cancel': '取消',
  'Confirm selected action': '確認所選操作',
  'Start quick security scan?': '開始快速安全掃描？',
  'Windows security will scan the local computer. Security settings remain enabled.':
      'Windows 安全性會掃描本機。安全設定會保持啟用。',
  'Move approved temporary files to recovery?': '將核准的暫存檔案移到還原儲存區？',
  'The engine will revalidate this cleanup plan and move eligible aged temporary files into recoverable storage. Documents are excluded.':
      '引擎會重新驗證清理方案，將合資格舊暫存檔案移到可還原儲存區，不包括文件。',
  'File hash': '檔案雜湊',
  'Convert file': '轉換檔案',
  'Password': '密碼',
  'Network': '網絡',
  'Source file path': '來源檔案路徑',
  'Destination file path': '輸出檔案路徑',
  'Existing files are never silently overwritten.': '不會在未提示下覆寫現有檔案。',
  'Conversion': '轉換格式',
  'Format JSON': '格式化 JSON',
  'Compact JSON': '壓縮 JSON',
  'Convert text to UTF-8': '將文字轉為 UTF-8',
  'Generated locally. Passwords are not added to history or copied automatically.':
      '於本機產生。密碼不會加入記錄或自動複製。',
  'Calculate SHA-256': '計算 SHA-256',
  'Convert to new file': '轉換為新檔案',
  'Generate password': '產生密碼',
  'Run network checks': '執行網絡檢查',
  'Local maintenance guide': '本機維護指南',
  'Safe cleanup and recovery': '安全清理與還原',
  'Analyze first, review selected files, and apply only a server-issued cleanup plan. Recovery history restores eligible moved files. No automatic document deletion is offered.':
      '先分析及檢閱所選檔案，只套用引擎發出的清理方案。還原記錄可還原合資格已移動檔案。不提供自動刪除文件。',
  'Apps, startup and drivers': '程式、開機項目與驅動程式',
  'Select real records before changing them. Operations requiring administrator access report that requirement. Unsupported vendor capabilities remain unavailable.':
      '變更前先選擇實際記錄。需要管理員權限的操作會清楚說明。不支援的供應商功能會保持不可用。',
  'Privacy and operation history': '私隱與操作記錄',
  'Settings and operation receipts stay in local application data. Credentials and personal vocabulary are excluded from diagnostic exports and general history.':
      '設定及操作收據留在本機應用程式資料。憑證及個人用詞不會加入診斷匯出或一般記錄。',
  'Keyboard and appearance': '鍵盤與外觀',
  'Use Tab to move between controls, Space to select records, and Enter to activate focused actions. Settings provides language, theme and reduced-motion controls.':
      '使用 Tab 移動焦點、空白鍵選擇記錄，Enter 啟動目前操作。設定提供語言、主題及減少動態效果選項。',
  'Version': '版本',
  'Updated at': '更新時間',
  'build metadata unavailable': '無法取得建置資料',
  'provenance unavailable': '無法取得來源證明',
  'Measurements below come from the local engine. No scan has permission to change files.':
      '以下數據由本機引擎取得。掃描不會修改檔案。',
  'Operation completed': '操作已完成',
  'Operation could not complete': '操作未能完成',
  'Result received from local engine': '已收到本機引擎結果',
  'Inspect the exact engine details below.': '請檢閱下方引擎的實際詳細資料。',
  'Operation': '操作',
  'Target': '目標',
  'Only this selected target will be sent to the local engine.':
      '只會將這個所選目標交給本機引擎。',
  'Selected record': '所選記錄',
  'Record': '記錄',
  'records': '項記錄',
  'selected': '已選取',
  'characters': '個字元',
  'completed': '已完成',
  'started': '已開始',
  'available': '可用',
  'enabled': '已啟用',
  'unavailableReason': '不可用原因',
  'reason': '原因',
  'message': '訊息',
  'exitCode': '結束代碼',
  'measurementSource': '量度來源',
  'measuredAt': '量度時間',
  'totalBytes': '總位元組',
  'freeBytes': '可用位元組',
  'fileCount': '檔案數量',
  'mutationPerformed': '已修改資料',
  'permanentDeletion': '永久刪除',
  'partial': '部分完成',
  'cancelled': '已取消',
  'restored': '已還原',
  'quarantined': '已移至還原區',
  'skipped': '已略過',
  'conflicts': '衝突',
  'name': '名稱',
  'version': '版本',
  'publisher': '發行者',
  'scope': '範圍',
  'source': '來源',
  'canUninstall': '可解除安裝',
  'canChange': '可變更',
  'provider': '提供者',
  'className': '類別',
  'originalName': '原始名稱',
  'signer': '簽署者',
  'ready': '準備就緒',
  'format': '格式',
  'memory': '記憶體',
  'cpu': '處理器',
  'os': '作業系統',
  'description': '描述',
  'architecture': '架構',
  'logicalProcessors': '邏輯處理器',
  'loadPercent': '負載百分比',
  'availableBytes': '可用位元組',
  'true': '是',
  'false': '否',
  'null': '未提供',
  'Notifications': '通知',
  'Close': '關閉',
  'No notifications yet.': '尚未有通知。',
  'The local engine is not connected. Start the installed application with its engine available, then retry.':
      '本機引擎未連接。請開啟已安裝的程式並確認引擎可用，然後重試。',
};

String localize(BuildContext context, String text) {
  final prefs = CopyScope.of(context);
  final language = prefs['language'] ?? 'en';
  String translated = translations[text] ?? text;
  var result = language == 'yue'
      ? translated
      : language == 'both' && translated != text
      ? '$text\n$translated'
      : text;
  final mappings = prefs['privateVocabulary'];
  if (mappings is Map && mappings.isNotEmpty) {
    final keys = mappings.keys.whereType<String>().toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    result = result.replaceAllMapped(
      RegExp(keys.map(RegExp.escape).join('|')),
      (m) => mappings[m[0]] as String,
    );
  }
  return result;
}

class UiText extends StatelessWidget {
  const UiText(this.data, {super.key, this.style, this.textAlign});
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  @override
  Widget build(BuildContext context) =>
      Text(localize(context, data), style: style, textAlign: textAlign);
}
