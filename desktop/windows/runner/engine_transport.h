#pragma once
#include <windows.h>
#include <atomic>
#include <string>
namespace engine_transport {
DWORD DeadlineFor(const std::string& method);
std::string Exchange(const std::wstring& name, std::string request, DWORD duration, const std::atomic<bool>& cancelled);
}
