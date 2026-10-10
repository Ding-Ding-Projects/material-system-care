#include <windows.h>

// Task-owned verification window. It holds no documents, reads no user data,
// and performs no host action. Launch only on an isolated test desktop.
namespace {
constexpr UINT_PTR kLifetime = 1;
int exitCode = 0;
LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM w, LPARAM l) {
  switch (message) {
    case WM_PAINT: {
      PAINTSTRUCT paint{};
      HDC dc = BeginPaint(window, &paint);
      RECT area{};
      GetClientRect(window, &area);
      DrawTextW(dc, L"Owned graceful-close verification fixture\nNo documents or user data", -1,
                &area, DT_CENTER | DT_VCENTER | DT_WORDBREAK);
      EndPaint(window, &paint);
      return 0;
    }
    case WM_CLOSE: DestroyWindow(window); return 0;
    case WM_TIMER:
      if (w == kLifetime) { exitCode = 2; DestroyWindow(window); }
      return 0;
    case WM_DESTROY: PostQuitMessage(exitCode); return 0;
    default: return DefWindowProcW(window, message, w, l);
  }
}
}

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int) {
  WNDCLASSW cls{};
  cls.lpfnWndProc = WindowProc;
  cls.hInstance = instance;
  cls.lpszClassName = L"MSC_GracefulCloseFixture";
  cls.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
  if (!RegisterClassW(&cls)) return 1;
  HWND window = CreateWindowW(cls.lpszClassName, L"Material System Care verification fixture",
    WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 480, 240,
    nullptr, nullptr, instance, nullptr);
  if (!window) return 1;
  if (!SetTimer(window, kLifetime, 300000, nullptr)) { DestroyWindow(window); return 1; }
  ShowWindow(window, SW_SHOWNORMAL);
  MSG message{};
  while (GetMessageW(&message, nullptr, 0, 0) > 0) {
    TranslateMessage(&message);
    DispatchMessageW(&message);
  }
  return static_cast<int>(message.wParam);
}
