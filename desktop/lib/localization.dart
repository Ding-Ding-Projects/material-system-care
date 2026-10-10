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
  'Folder analysis': '資料夾分析',
  'Understand one folder': '了解一個資料夾',
  'Read-only analysis counts observed files and lists the largest files and empty folders. Nothing is collected until you review a folder.':
      '唯讀分析會統計觀察到嘅檔案，並列出最大檔案同空資料夾。檢閱資料夾之前唔會收集資料。',
  'Folder path': '資料夾路徑',
  'Review folder analysis': '檢閱資料夾分析',
  'Only this folder will be read. No files will be moved, changed or deleted.':
      '只會讀取呢個資料夾。唔會搬移、修改或刪除任何檔案。',
  'Analyze selected folder': '分析所選資料夾',
  'The folder picker is unavailable. Enter a full folder path.':
      '資料夾選擇器無法使用。請輸入完整資料夾路徑。',
  'Enter a full absolute folder path.': '請輸入完整嘅絕對資料夾路徑。',
  'Cancellation requested. Waiting for the current read to settle.':
      '已要求取消，正等候目前讀取結束。',
  'Cancellation could not be requested. The current read may still complete.':
      '未能要求取消。目前讀取仍然可能完成。',
  'Stopped waiting for analysis. This does not prove that all engine reads have stopped.':
      '已停止等候分析，但唔代表引擎已停止所有讀取。',
  'Folder analysis response is invalid. No result was accepted.':
      '資料夾分析回應無效，未有接納任何結果。',
  'The selected folder is unavailable or unsupported. Check the path and access, then retry.':
      '所選資料夾無法使用或不受支援。請檢查路徑同存取權限，然後重試。',
  'Folder analysis could not complete. No files were changed. Retry when the engine is available.':
      '未能完成資料夾分析，冇修改任何檔案。請喺引擎可用時重試。',
  'Analyzed folder': '已分析資料夾',
  'Incomplete view: some entries were not examined.': '檢視未完整：部分項目未經檢查。',
  'The selected folder traversal completed.': '已完成遍歷所選資料夾。',
  'Point-in-time metadata only. Files may change after analysis. No files were changed.':
      '只係當時嘅中繼資料。分析後檔案可能改變，呢次分析冇修改任何檔案。',
  'Observed files': '觀察到嘅檔案',
  'Observed bytes': '觀察到嘅位元組',
  'Observed empty folders': '觀察到嘅空資料夾',
  'Inaccessible entries': '無法存取嘅項目',
  'Reparse points skipped': '已略過嘅重新剖析點',
  'Folders beyond depth limit': '超過深度上限嘅資料夾',
  'The 20,000-entry traversal limit was reached. Totals describe only observed entries.':
      '已達到 20,000 個項目嘅遍歷上限。總數只包括觀察到嘅項目。',
  'Largest files': '最大檔案',
  'Shown files': '已列出檔案',
  'Only the largest 100 observed files are listed.': '只列出觀察到嘅最大 100 個檔案。',
  'No files were observed.': '未觀察到任何檔案。',
  'Full path': '完整路徑',
  'Empty folders': '空資料夾',
  'Shown folders': '已列出資料夾',
  'Only the first 1,000 observed empty folders are listed.':
      '只列出首 1,000 個觀察到嘅空資料夾。',
  'Empty means no entries were observed, including hidden entries. Inaccessible folders are not declared empty.':
      '空代表未觀察到任何項目，包括隱藏項目。無法存取嘅資料夾唔會當成空資料夾。',
  'No empty folders were observed.': '未觀察到任何空資料夾。',
  'Copy': '複製',
  'Cut': '剪下',
  'Paste': '貼上',
  'Select all': '全選',
  'Look Up': '查詢',
  'Search Web': '搜尋網頁',
  'Share': '分享',
  'Discover WinGet packages?': '探索 WinGet 套件？',
  'WinGet is not installed for the current user.': '目前使用者未安裝 WinGet。',
  'WinGet discovery did not complete. Check its installation, source availability and previously accepted source agreements. No source configuration was changed.':
      'WinGet 探索未完成。請檢查安裝、來源可用性及之前接受嘅來源協議，沒有更改來源設定。',
  'Unavailable': '無法提供',
  'Review installed applications': '檢視已安裝應用程式',
  'General inventory is read-only. Exact WinGet matches provide separately reviewed package actions.':
      '一般清單只供檢視。確實配對嘅 WinGet 套件先有獨立覆核操作。',
  'Inventory source': '清單來源',
  'Installed applications': '已安裝應用程式',
  'WinGet matches': 'WinGet 配對項目',
  'Filter application records': '篩選應用程式記錄',
  'Application records refreshed.': '已重新讀取應用程式記錄。',
  'Application records are unavailable or invalid. No package change was requested.':
      '無法取得應用程式記錄或資料無效，未要求變更任何套件。',
  'Select an inventory source and refresh to begin. No package changes occur during discovery.':
      '選擇清單來源並重新讀取。探索期間不會變更套件。',
  'Some inventory sources could not be read. Displayed records are incomplete.':
      '部分清單來源無法讀取，顯示嘅記錄並不完整。',
  'Only installed WinGet matches are listed. Available update versions have not been checked.':
      '只列出已安裝並經 WinGet 配對嘅項目，未檢查可用更新版本。',
  'No application records match the current filter.': '沒有應用程式記錄符合目前篩選條件。',
  'Installed version': '已安裝版本',
  'Display name unavailable': '顯示名稱無法提供',
  'Version unavailable': '版本無法提供',
  'Publisher unavailable': '發行者無法提供',
  'Records with unavailable display metadata': '部分顯示資料無法提供嘅記錄',
  'Publisher': '發行者',
  'Matched by WinGet': '由 WinGet 配對',
  'Current-user packaged application': '目前使用者嘅封裝應用程式',
  'Installed application registry': '已安裝應用程式登錄記錄',
  'Current user': '目前使用者',
  'All users': '所有使用者',
  'Read-only record. Use a verified WinGet match for package actions.':
      '此記錄只供檢視。套件操作需要已驗證嘅 WinGet 配對。',
  'Review upgrade': '覆核升級',
  'Review uninstall': '覆核移除',
  'Review package upgrade': '覆核套件升級',
  'Review package removal': '覆核套件移除',
  'WinGet will check whether this exact package can be upgraded. No newer version has been confirmed.':
      'WinGet 會檢查此確實套件能否升級，目前未確認有較新版本。',
  'WinGet will request removal of this exact package. This workspace does not create a rollback copy.':
      'WinGet 會要求移除此確實套件，此工作區不會建立復原副本。',
  'WinGet may contact its source and request system consent. The installed version can change after this review. No other package is selected.':
      'WinGet 可能連接來源並要求系統授權。已安裝版本可能在覆核後改變，沒有選取其他套件。',
  'Selected package operation completed and records refreshed.':
      '所選套件操作已完成，並已重新讀取記錄。',
  'The package operation completed, but refreshed records are unavailable.':
      '套件操作已完成，但無法取得更新後嘅記錄。',
  'Package completion was not confirmed. Review refreshed records before trying again.':
      '未能確認套件操作完成，重試前請檢視更新後嘅記錄。',
  'The startup record changed. Records were refreshed where available. Review the selected action again.':
      '啟動記錄已變更，已盡量重新讀取可用記錄。請再次覆核所選操作。',
  'Review sign-in entries': '檢視登入啟動項目',
  'Review current-user startup commands and saved restoration records. Machine and startup-folder entries are outside this workflow.':
      '檢視目前使用者嘅啟動命令及已儲存復原記錄。此流程不處理全機或啟動資料夾項目。',
  'Startup state': '啟動狀態',
  'All entries': '全部項目',
  'Enabled': '已啟用',
  'Disabled': '已停用',
  'Filter startup records': '篩選啟動記錄',
  'Startup records refreshed.': '已重新讀取啟動記錄。',
  'Startup records are unavailable or invalid. No change was requested.':
      '無法取得啟動記錄或資料無效，未要求任何變更。',
  'Startup change completed and records refreshed.': '啟動項目變更已完成，並已重新讀取記錄。',
  'The change completed, but refreshed records are unavailable.':
      '變更已完成，但無法取得更新後嘅記錄。',
  'The startup change was not confirmed. Review refreshed records before trying again.':
      '未能確認啟動項目變更，重試前請檢視更新後嘅記錄。',
  'Read startup records to begin. Nothing changes until you review and confirm an entry.':
      '先讀取啟動記錄；覆核並確認項目前不會作出變更。',
  'Matching entries': '符合項目',
  'No startup entries match the current filter.': '沒有啟動項目符合目前篩選條件。',
  'Enabled at sign-in': '登入時已啟用',
  'Disabled with saved restoration record': '已停用，並保留復原記錄',
  'A conflicting recovery record needs attention. This entry cannot be changed here.':
      '復原記錄有衝突需要處理，無法在此更改項目。',
  'This entry is read-only.': '此項目僅供讀取。',
  'Startup command': '啟動命令',
  'Review disable': '覆核停用',
  'Review enable': '覆核啟用',
  'Selected files': '已選取檔案',
  'Cleanup plan': '清理計劃',
  'Recorded cleanup result': '已記錄清理結果',
  'Only selected files will move to recovery. Nothing has moved yet.':
      '只有已選取檔案會移到復原區，目前尚未移動任何檔案。',
  'These are recorded outcomes. Current file availability is checked during restoration.':
      '以下係已記錄結果，復原時先會檢查檔案目前可用狀態。',
  'Operation stopped. Completed moves and recovery records were retained.':
      '操作已停止，已完成移動同復原記錄已保留。',
  'Some files did not complete. Review each recorded state before retrying.':
      '部分檔案未完成，重試前請逐項檢視已記錄狀態。',
  'The scan limit was reached. This plan contains only the reviewed subset.':
      '已達掃描上限，此計劃只包含已檢視部分。',
  'Excluded or unavailable entries': '已排除或無法取得的項目',
  'Recorded receipts': '已記錄復原單',
  'Recorded files': '已記錄檔案',
  'Selected files requested': '已要求處理的選取檔案',
  'Files without a completed result': '尚無完成結果的檔案',
  'Receipt identifier': '復原單識別碼',
  'Review restoration': '覆核復原',
  'No eligible temporary files were found.': '沒有符合條件的暫存檔。',
  'No recovery receipts were found.': '沒有復原單。',
  'This result contains no recorded files.': '此結果沒有已記錄檔案。',
  'No matching cleanup records.': '沒有符合的清理記錄。',
  'Bytes': '位元組',
  'File details': '檔案詳情',
  'Full original path': '完整原始路徑',
  'Engine reason code': '引擎原因代碼',
  'Recovery receipt': '復原單',
  'This recovery record is unavailable. No restoration is confirmed.':
      '此復原記錄無法取得，尚未確認任何復原。',
  'Ready for review': '等待覆核',
  'In recovery storage': '已存於復原區',
  'Restored': '已復原',
  'Skipped': '已略過',
  'Needs attention': '需要處理',
  'Move not confirmed': '尚未確認移動',
  'Restore not confirmed': '尚未確認復原',
  'Unresolved': '尚未解決',
  'State unavailable': '無法取得狀態',
  'The file changed after review. Scan again before cleanup.':
      '檔案喺覆核後有變，清理前請重新掃描。',
  'The original path is occupied. Recovery data was retained.':
      '原始路徑已被佔用，復原資料已保留。',
  'The recovery file changed. It was retained for inspection.':
      '復原檔案有變，已保留供檢查。',
  'The recovery file is missing. Restoration is not confirmed.':
      '復原檔案遺失，尚未確認復原。',
  'An interrupted restoration was verified against the original file.':
      '已按原始檔案核實中斷的復原操作。',
  'The operation stopped before this file completed.': '操作喺此檔案完成前已停止。',
  'A link or reparse point prevented this operation.': '連結或重新分析點阻止了此操作。',
  'A file with multiple links was excluded.': '有多個連結的檔案已排除。',
  'The file is outside the approved cleanup scope.': '檔案不在已核准清理範圍內。',
  'The file could not be accessed or moved. Recovery records were retained.':
      '無法存取或移動檔案，復原記錄已保留。',
  'The engine reported a condition that needs review.': '引擎回報需要覆核的狀況。',
  'Review recovery history': '檢視復原記錄',
  'Cleanup results are invalid. No result was accepted. Review recovery history before retrying.':
      '清理結果格式無效，未接受任何結果。重試前請檢視復原記錄。',
  'Enable selected startup entry': '啟用所選登入啟動項目',
  'Disable selected startup entry': '停用所選登入啟動項目',
  'This startup entry cannot be changed. Refresh its state before continuing.':
      '此登入啟動項目無法更改。請先重新讀取狀態。',
  'Restore the saved original startup command for this user. An existing entry with the same name will not be overwritten.':
      '還原此使用者已儲存的原始登入啟動命令，不會覆寫同名的現有項目。',
  'Remove this user startup entry after saving its original command for restoration.':
      '先儲存原始命令以供還原，再移除此使用者的登入啟動項目。',
  'This changes future sign-in behavior. It does not start or stop a running process.':
      '這會更改日後登入時的行為，不會啟動或停止目前執行中的程序。',
  'Resolve the existing-entry conflict before restoration.':
      '請先解決現有項目的衝突，再進行還原。',
  'This startup entry is read-only.': '此登入啟動項目只供檢視。',
  'Code category': '代碼類別',
  'Memory or driver condition': '記憶體或驅動程式狀況',
  'Memory condition': '記憶體狀況',
  'Unhandled exception': '未處理的例外',
  'Driver power transition': '驅動程式電源轉換',
  'Hardware error report': '硬件錯誤報告',
  'Watchdog condition': '監察逾時狀況',
  'Critical process stopped': '重要程序已停止',
  'Uncatalogued category': '未收錄的類別',
  'Diagnostic response is invalid. No evidence was accepted. Try again.':
      '診斷回應格式無效，未接受任何證據。請再試。',
  'File modified at UTC': '檔案修改時間（UTC）',
  'Copy Microsoft reference': '複製 Microsoft 參考連結',
  'Microsoft reference copied.': '已複製 Microsoft 參考連結。',
  'Reference copying did not complete. Select the visible reference to copy it manually.':
      '未能完成複製參考連結。你可以選取畫面上嘅參考連結，然後手動複製。',
  'The recorded code is evidence of the reported stop condition. It does not establish the root cause or identify a culprit driver.':
      '記錄的代碼只證明回報的停止狀況，不能確定根本原因或肇因驅動程式。',
  'Compare the event time with recent driver, firmware, hardware, and Windows updates.':
      '將事件時間與最近的驅動程式、韌體、硬件及 Windows 更新作比較。',
  'Preserve available dump files before making changes.': '作出變更前，先保留可用的傾印檔案。',
  'Use Microsoft WinDbg with matching symbols for deeper dump analysis.':
      '使用 Microsoft WinDbg 及相符的符號檔，進行更深入的傾印分析。',
  "Follow the device manufacturer's diagnostics when hardware evidence warrants it.":
      '當硬件證據顯示有需要時，依照裝置製造商的診斷步驟檢查。',
  'Recorded event times can follow the crash or restart; dump modification times are file metadata, not crash timestamps.':
      '記錄的事件時間可能在當機或重新啟動之後；傾印修改時間是檔案資料，不是當機時間。',
  "Services": "服務",
  "Review local services": "檢視本機服務",
  "Read service names, current states and configured start types. This workspace never starts, stops or reconfigures a service.":
      "讀取服務名稱、目前狀態及設定的啟動類型。此工作區不會啟動、停止或重新設定服務。",
  "Read services": "讀取服務",
  "Service state": "服務狀態",
  "All states": "所有狀態",
  "Running": "執行中",
  "Stopped": "已停止",
  "Paused": "已暫停",
  "Filter loaded services": "篩選已載入服務",
  "No services collected. Start an explicit read above.": "尚未收集服務，請在上方主動讀取。",
  "States can change after collection. Start type alone does not establish whether a service is needed or safe to disable.":
      "收集後狀態可能改變。啟動類型本身不能判定服務是否必需或可安全停用。",
  "Matching loaded services": "符合的已載入服務",
  "No matching loaded services.": "沒有符合的已載入服務。",
  "Service name": "服務名稱",
  "Configured start type": "設定的啟動類型",
  "Read-only record. Refresh to obtain current state.": "唯讀記錄，重新讀取可取得目前狀態。",
  "Service names can contain local product details. Records remain transient and are not uploaded or automatically saved.":
      "服務名稱可能包含本機產品資料。記錄僅暫存，不會上傳或自動儲存。",
  "Service inventory is unavailable or invalid. No service was changed.":
      "服務清單無法取得或格式無效，沒有更改任何服務。",
  "Scheduled tasks": "排程工作",
  "Review scheduled tasks": "檢視排程工作",
  "Inspect tasks visible to this account. This workspace never runs, enables, disables or changes a task.":
      "檢視此帳戶可見的排程工作。此工作區不會執行、啟用、停用或更改任何工作。",
  "Maximum records": "最多記錄數",
  "Read scheduled tasks": "讀取排程工作",
  "Filter loaded tasks by name, folder or state": "按名稱、資料夾或狀態篩選已載入工作",
  "No task inventory collected. Start an explicit read above.":
      "尚未收集工作清單，請在上方明確開始讀取。",
  "Collected at UTC": "收集時間（UTC）",
  "The record limit was reached. Filtering searches only the loaded subset; increase the limit for a broader view.":
      "已達記錄上限。篩選只搜尋已載入的部分；增加上限可查看更多記錄。",
  "Task visibility depends on account access. Reported run times have no timezone; missing times do not prove a task never ran.":
      "可見工作取決於帳戶權限。回報時間沒有時區；缺少時間不代表工作從未執行。",
  "No matching loaded tasks.": "已載入工作沒有符合項目。",
  "Enabled state unavailable": "無法取得啟用狀態",
  "Run-time details are unavailable for this task.": "無法取得此工作的執行時間資料。",
  "Reported last run": "回報的上次執行",
  "Reported next run": "回報的下次執行",
  "Last result code": "上次結果代碼",
  "Result codes can describe scheduler status. A nonzero value alone is not a diagnosis.":
      "結果代碼可能表示排程器狀態，單憑非零值不能作出診斷。",
  "Action commands, arguments, principals and credentials are excluded. Results are not uploaded or automatically saved.":
      "不包含動作指令、參數、執行身分或憑證。結果不會上傳或自動儲存。",
  "Scheduled-task inspection exceeded twenty seconds. Try a smaller limit.":
      "排程工作檢查超過二十秒，請嘗試較小上限。",
  "Inspection stopped waiting, but query-process exit is unverified. No task change was requested.":
      "檢查已停止等待，但尚未確認查詢程序退出，沒有要求更改排程工作。",
  "Task Scheduler returned an invalid or oversized inventory. No partial result is shown.":
      "工作排程器回傳無效或過大的清單，不會顯示部分結果。",
  "Scheduled-task inventory is unavailable for this account. No task was run or changed.":
      "此帳戶無法取得排程工作清單，沒有執行或更改任何工作。",
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

String localize(BuildContext context, String text) =>
    localizePreferences(CopyScope.of(context), text);

String localizePreferences(Map<String, dynamic> prefs, String text) {
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
