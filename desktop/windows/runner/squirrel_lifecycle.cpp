#include "squirrel_lifecycle.h"
#include <filesystem>
#include <limits>

namespace squirrel_lifecycle {
namespace {
class HandleOwner {
 public:
  explicit HandleOwner(HANDLE value) : value_(value) {}
  ~HandleOwner() { if (value_ && value_ != INVALID_HANDLE_VALUE) CloseHandle(value_); }
  HandleOwner(const HandleOwner&) = delete;
  HandleOwner& operator=(const HandleOwner&) = delete;
 private:
  HANDLE value_;
};
bool SafeAbsolutePath(const std::wstring& path) {
  return path.size() > 3 && path.size() < 32700 &&
      ((path[0] >= L'A' && path[0] <= L'Z') ||
       (path[0] >= L'a' && path[0] <= L'z')) &&
      path[1] == L':' && path[2] == L'\\' &&
      path.find_first_of(L"\"\r\n", 2) == std::wstring::npos &&
      path.find(L':', 2) == std::wstring::npos &&
      path.find(L'\0') == std::wstring::npos;
}
}
std::optional<std::wstring> UpdaterPath(const std::wstring& executable) {
  if (!SafeAbsolutePath(executable)) return std::nullopt;
  const std::filesystem::path path(executable);
  if (path.filename() != L"material_system_care.exe") return std::nullopt;
  for (const auto& component : path) {
    if (component == L"." || component == L"..") return std::nullopt;
  }
  const auto version = path.parent_path();
  const auto base = version.parent_path();
  if (version.empty() || base.empty() || base == base.root_path()) return std::nullopt;
  return (base / L"Update.exe").wstring();
}
int RunChild(const std::wstring& executable, const std::wstring& arguments,
             DWORD timeout_ms) {
  if (!SafeAbsolutePath(executable) || timeout_ms == 0 || timeout_ms > 10000)
    return ERROR_INVALID_PARAMETER;
  const DWORD attributes = GetFileAttributesW(executable.c_str());
  if (attributes == INVALID_FILE_ATTRIBUTES || (attributes & FILE_ATTRIBUTE_DIRECTORY))
    return ERROR_FILE_NOT_FOUND;
  std::wstring command = L"\"" + executable + L"\" " + arguments;
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION process{};
  const auto directory = std::filesystem::path(executable).parent_path().wstring();
  if (!CreateProcessW(executable.c_str(), command.data(), nullptr, nullptr, FALSE,
                      CREATE_NO_WINDOW, nullptr, directory.c_str(), &startup, &process)) {
    return ERROR_PROCESS_ABORTED;
  }
  HandleOwner thread(process.hThread);
  HandleOwner child(process.hProcess);
  const DWORD wait = WaitForSingleObject(process.hProcess, timeout_ms);
  if (wait == WAIT_TIMEOUT) return ERROR_TIMEOUT;
  if (wait != WAIT_OBJECT_0) return ERROR_PROCESS_ABORTED;
  DWORD exit_code = 0;
  if (!GetExitCodeProcess(process.hProcess, &exit_code)) return ERROR_PROCESS_ABORTED;
  if (exit_code > static_cast<DWORD>(std::numeric_limits<int>::max()))
    return ERROR_PROCESS_ABORTED;
  return static_cast<int>(exit_code);
}
std::optional<int> Handle(const std::vector<std::string>& arguments) {
  std::string event;
  for (const auto& argument : arguments) {
    if (argument.rfind("--squirrel-", 0) != 0) continue;
    if (!event.empty()) return ERROR_INVALID_PARAMETER;
    if (argument != "--squirrel-install" && argument != "--squirrel-updated" &&
        argument != "--squirrel-uninstall" && argument != "--squirrel-obsolete")
      return ERROR_INVALID_PARAMETER;
    event = argument;
  }
  if (event.empty()) return std::nullopt;
  if (event == "--squirrel-obsolete") return 0;
  wchar_t executable[32768]{};
  const DWORD length = GetModuleFileNameW(nullptr, executable, 32768);
  if (length == 0 || length >= 32768) return ERROR_BAD_PATHNAME;
  const auto updater = UpdaterPath(std::wstring(executable, length));
  if (!updater) return ERROR_BAD_PATHNAME;
  // Never forward command-line input to the updater.
  return RunChild(*updater,
      event == "--squirrel-uninstall"
          ? L"--removeShortcut material_system_care.exe"
          : L"--createShortcut material_system_care.exe", 10000);
}
}
