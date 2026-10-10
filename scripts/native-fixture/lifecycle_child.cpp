#include <windows.h>
#include <string>
int wmain(int argc, wchar_t** argv) {
  if (argc != 2) return 90;
  const std::wstring mode(argv[1]);
  if (mode == L"success") return 0;
  if (mode == L"nonzero") return 23;
  if (mode == L"timeout") { Sleep(200); return 0; }
  return 91;
}
