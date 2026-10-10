#pragma once
#include <cstdint>
#include <functional>
#include <string>
#include <vector>
#include <optional>

namespace capture_writer {
struct Diagnostics {
  int64_t schema_version = -1, sequence = -1;
  std::string coverage, started_utc, completed_utc;
  int64_t framework_errors = -1, platform_errors = -1, dropped = -1;
  bool healthy = false;
};
struct Request {
  std::string path;
  std::vector<uint8_t> bytes;
  std::string capture_started_utc, capture_completed_utc;
  int64_t capture_elapsed_microseconds = -1;
  int64_t sequence = -1, width = 0, height = 0;
  double pixel_ratio = 0;
  std::optional<Diagnostics> diagnostics;
};
struct Result {
  bool png_saved = false, receipt_saved = false;
  std::string error;
};
Result Write(const Request& request, const std::function<bool()>& cancelled);
}
