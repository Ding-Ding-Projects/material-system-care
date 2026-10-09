#pragma once
#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>
#include <windows.h>
#include <atomic>
#include <memory>
#include <mutex>
#include <thread>
#include <vector>
class EngineBridge {
 public:
  static constexpr UINT kCompletion = WM_APP + 81;
  EngineBridge(flutter::BinaryMessenger* messenger, HWND window);
  ~EngineBridge();
  void Complete();
 private:
  struct Reply { std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result; std::string text; std::string error; };
  HWND window_;
  HANDLE process_ = nullptr;
  HANDLE job_ = nullptr;
  std::atomic<bool> stopping_{false};
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  struct Worker { std::thread thread; std::shared_ptr<std::atomic<bool>> done; std::shared_ptr<std::atomic<bool>> cancelled; std::string id; };
  std::vector<Worker> workers_;
  std::mutex mutex_;
  std::vector<std::unique_ptr<Reply>> replies_;
  std::wstring pipe_;
};
