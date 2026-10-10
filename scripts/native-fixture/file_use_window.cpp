#include <windows.h>
#include <shellapi.h>
#include <cwchar>

// Isolated verification helper: creates one NEW fixture file and holds it open.
// It never opens an existing file, reads user data, deletes files or changes the host.
namespace {
HANDLE fixture = INVALID_HANDLE_VALUE;
constexpr UINT_PTR lifetime = 1;
int exitCode = 0;
void CloseFixture() {
  if (fixture != INVALID_HANDLE_VALUE) {
    CloseHandle(fixture);
    fixture = INVALID_HANDLE_VALUE;
  }
}
LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM w, LPARAM l) {
  switch (message) {
    case WM_PAINT: {
      PAINTSTRUCT paint{};
      HDC dc = BeginPaint(window, &paint);
      RECT area{};
      GetClientRect(window, &area);
      DrawTextW(dc, L"Owned file-use verification fixture\nOne newly created file held open", -1,
                &area, DT_CENTER | DT_VCENTER | DT_WORDBREAK);
      EndPaint(window, &paint);
      return 0;
    }
    case WM_CLOSE: DestroyWindow(window); return 0;
    case WM_TIMER:
      if (w == lifetime) { exitCode = 2; DestroyWindow(window); }
      return 0;
    case WM_DESTROY: CloseFixture(); PostQuitMessage(exitCode); return 0;
    default: return DefWindowProcW(window, message, w, l);
  }
}
}

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int) {
  int count = 0;
  auto arguments = CommandLineToArgvW(GetCommandLineW(), &count);
  if (!arguments) return 1;
  const bool valid = count == 2 && std::wcslen(arguments[1]) > 3 &&
    ((arguments[1][0] >= L'A' && arguments[1][0] <= L'Z') ||
     (arguments[1][0] >= L'a' && arguments[1][0] <= L'z')) &&
    arguments[1][1] == L':' && arguments[1][2] == L'\\' &&
    std::wcschr(arguments[1] + 2, L':') == nullptr;
  if (valid) fixture = CreateFileW(arguments[1], GENERIC_READ | GENERIC_WRITE,
    0, nullptr, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
  LocalFree(arguments);
  if (fixture == INVALID_HANDLE_VALUE) return 1;
  constexpr char content[] = "Owned file-use holder fixture.\r\n";
  DWORD written = 0;
  if (!WriteFile(fixture, content, sizeof(content) - 1, &written, nullptr) ||
      written != sizeof(content) - 1 || !FlushFileBuffers(fixture)) {
    CloseFixture(); return 1;
  }
  WNDCLASSW cls{};
  cls.lpfnWndProc = WindowProc;
  cls.hInstance = instance;
  cls.lpszClassName = L"MSC_FileUseFixture";
  cls.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
  if (!RegisterClassW(&cls)) { CloseFixture(); return 1; }
  HWND window = CreateWindowW(cls.lpszClassName, L"Material System Care file-use fixture",
    WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 480, 240,
    nullptr, nullptr, instance, nullptr);
  if (!window) { CloseFixture(); return 1; }
  if (!SetTimer(window, lifetime, 300000, nullptr)) {
    DestroyWindow(window); return 1;
  }
  ShowWindow(window, SW_SHOWNORMAL);
  MSG message{};
  BOOL result;
  while ((result = GetMessageW(&message, nullptr, 0, 0)) > 0) {
    TranslateMessage(&message);
    DispatchMessageW(&message);
  }
  CloseFixture();
  return result == -1 ? 1 : static_cast<int>(message.wParam);
}
