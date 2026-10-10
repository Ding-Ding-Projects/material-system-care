#pragma once
#include <windows.h>
#include <optional>
#include <string>
#include <vector>

namespace squirrel_lifecycle {
// An empty result means normal application startup, not a lifecycle event.
std::optional<int> Handle(const std::vector<std::string>& arguments);
std::optional<std::wstring> UpdaterPath(const std::wstring& executable);
int RunChild(const std::wstring& executable, const std::wstring& arguments,
             DWORD timeout_ms);
}
