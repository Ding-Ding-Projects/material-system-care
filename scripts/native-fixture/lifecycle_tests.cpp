#include "squirrel_lifecycle.h"
#include <filesystem>
#include <iostream>
#include <stdexcept>

void LifecycleChecks() {
  int count = 0;
  const auto check = [&](bool value) {
    if (!value) throw std::runtime_error("Squirrel lifecycle assertion failed at " + std::to_string(count + 1));
    ++count;
  };
  using namespace squirrel_lifecycle;
  check(!Handle({"--ordinary"}).has_value());
  check(Handle({"--squirrel-obsolete"}) == 0);
  check(Handle({"--squirrel-unknown"}) == ERROR_INVALID_PARAMETER);
  check(Handle({"--squirrel-install", "--squirrel-obsolete"}) == ERROR_INVALID_PARAMETER);
  check(!UpdaterPath(L"material_system_care.exe"));
  check(!UpdaterPath(L"C:\\material_system_care.exe"));
  check(!UpdaterPath(L"C:\\app-1\\material_system_care.exe"));
  check(!UpdaterPath(L"\\\\server\\share\\app-1\\material_system_care.exe"));
  check(!UpdaterPath(L"C:\\root\\..\\app-1\\material_system_care.exe"));
  check(!UpdaterPath(L"C:\\root\\app-1\\other.exe"));
  check(UpdaterPath(L"C:\\root\\app-1\\material_system_care.exe") == L"C:\\root\\Update.exe");
  check(UpdaterPath(L"C:\\root/app-1/material_system_care.exe") == L"C:\\root\\Update.exe");
  check(UpdaterPath(L"C:\\root\\\\app-1\\material_system_care.exe") == L"C:\\root\\Update.exe");
  check(!UpdaterPath(L"C:\\root/app-1/../material_system_care.exe"));
  check(!UpdaterPath(L"C:\\root\\app-1\\material_system_care.exe:stream"));
  check(!UpdaterPath(L"C:\\root\\app-1\\material_system_care.exe\n"));
  wchar_t module[32768]{};
  const auto length = GetModuleFileNameW(nullptr, module, 32768);
  check(length > 0 && length < 32768);
  const auto directory = std::filesystem::path(module).parent_path();
  const auto child = (directory / L"lifecycle_child.exe").wstring();
  check(RunChild(child, L"success", 2000) == 0);
  check(RunChild(child, L"nonzero", 2000) == 23);
  check(RunChild((directory / L"absent-lifecycle-child.exe").wstring(), L"", 2000) == ERROR_FILE_NOT_FOUND);
  check(RunChild(child, L"timeout", 1) == ERROR_TIMEOUT);
  // The timed-out fixture exits itself; no production or fixture process is killed.
  Sleep(300);
  check(RunChild(child, L"success", 0) == ERROR_INVALID_PARAMETER);
  check(RunChild(child, L"success", 10001) == ERROR_INVALID_PARAMETER);
  check(RunChild(directory.wstring(), L"", 2000) == ERROR_FILE_NOT_FOUND);
  std::cout << "Squirrel lifecycle: " << count << " passed" << std::endl;
}
