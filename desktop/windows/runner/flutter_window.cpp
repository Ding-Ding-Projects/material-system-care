#include "flutter_window.h"

#include <optional>
#include <exception>
#include <flutter/standard_method_codec.h>
#include <windowsx.h>
#include <commctrl.h>

#include "flutter/generated_plugin_registrant.h"

namespace {
LRESULT CALLBACK ResizeHitTest(HWND child, UINT message, WPARAM wparam,
                              LPARAM lparam, UINT_PTR id, DWORD_PTR reference) {
  if (message == WM_NCHITTEST) {
    const HWND parent = reinterpret_cast<HWND>(reference);
    if (!IsZoomed(parent)) {
      RECT rect{};
      GetWindowRect(parent, &rect);
      const int border = MulDiv(8, GetDpiForWindow(parent), 96);
      const int x = GET_X_LPARAM(lparam), y = GET_Y_LPARAM(lparam);
      const bool left = x < rect.left + border;
      const bool right = x >= rect.right - border;
      const bool top = y < rect.top + border;
      const bool bottom = y >= rect.bottom - border;
      if (left || right || top || bottom) return HTTRANSPARENT;
    }
  }
  if (message == WM_NCDESTROY) RemoveWindowSubclass(child, ResizeHitTest, id);
  return DefSubclassProc(child, message, wparam, lparam);
}
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  try {
    engine_bridge_ = std::make_unique<EngineBridge>(flutter_controller_->engine()->messenger(), GetHandle());
  } catch (const std::exception&) {
    // Invalid explicit launch modes must exit, never start a normal engine.
    return false;
  }
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  SetWindowSubclass(flutter_controller_->view()->GetNativeWindow(), ResizeHitTest,
                    1, reinterpret_cast<DWORD_PTR>(GetHandle()));
  window_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "material_system_care/window",
      &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    const HWND hwnd = GetHandle();
    const auto& method = call.method_name();
    if (method == "state") {
      result->Success(flutter::EncodableValue(flutter::EncodableMap{
        {flutter::EncodableValue("maximized"), flutter::EncodableValue(IsZoomed(hwnd) != FALSE)}}));
      return;
    }
    if (method == "minimize") ShowWindow(hwnd, SW_MINIMIZE);
    else if (method == "toggleMaximize") ShowWindow(hwnd, IsZoomed(hwnd) ? SW_RESTORE : SW_MAXIMIZE);
    else if (method == "close") { close_approved_ = true; PostMessage(hwnd, WM_CLOSE, 0, 0); }
    else if (method == "drag") {
      ReleaseCapture();
      SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
    } else if (method == "systemMenu") {
      POINT point{};
      GetCursorPos(&point);
      const UINT command = TrackPopupMenu(GetSystemMenu(hwnd, FALSE),
        TPM_RETURNCMD | TPM_RIGHTBUTTON, point.x, point.y, 0, hwnd, nullptr);
      if (command != 0) PostMessage(hwnd, WM_SYSCOMMAND, command, 0);
    } else { result->NotImplemented(); return; }
    result->Success();
  });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  window_channel_.reset();
  engine_bridge_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_CLOSE && window_channel_ && !close_approved_) {
    window_channel_->InvokeMethod("closeRequested", nullptr);
    return 0;
  }
  if (message == WM_SIZE && window_channel_) window_channel_->InvokeMethod("stateChanged", nullptr);
  if (message == WM_NCCALCSIZE && wparam) return 0;
  if (message == WM_GETMINMAXINFO) {
    const auto info = reinterpret_cast<MINMAXINFO*>(lparam);
    const UINT dpi = GetDpiForWindow(hwnd);
    info->ptMinTrackSize = {MulDiv(800, dpi, 96), MulDiv(600, dpi, 96)};
    const HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
    MONITORINFO bounds{sizeof(MONITORINFO)};
    if (GetMonitorInfo(monitor, &bounds)) {
      info->ptMaxPosition = {bounds.rcWork.left - bounds.rcMonitor.left,
                            bounds.rcWork.top - bounds.rcMonitor.top};
      info->ptMaxSize = {bounds.rcWork.right - bounds.rcWork.left,
                        bounds.rcWork.bottom - bounds.rcWork.top};
    }
    return 0;
  }
  if (message == WM_NCHITTEST && !IsZoomed(hwnd)) {
    RECT rect{}; GetWindowRect(hwnd, &rect);
    const int border = MulDiv(8, GetDpiForWindow(hwnd), 96);
    const int x = GET_X_LPARAM(lparam), y = GET_Y_LPARAM(lparam);
    const bool left = x < rect.left + border, right = x >= rect.right - border;
    const bool top = y < rect.top + border, bottom = y >= rect.bottom - border;
    if (top && left) return HTTOPLEFT;
    if (top && right) return HTTOPRIGHT;
    if (bottom && left) return HTBOTTOMLEFT;
    if (bottom && right) return HTBOTTOMRIGHT;
    if (left) return HTLEFT;
    if (right) return HTRIGHT;
    if (top) return HTTOP;
    if (bottom) return HTBOTTOM;
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case EngineBridge::kCompletion:
      if (engine_bridge_) engine_bridge_->Complete();
      return 0;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
