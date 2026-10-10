#include "capture_writer.h"
#include <windows.h>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <stdexcept>
#include <cstdio>

namespace {
int assertions=0;
std::string Stamp(uint64_t ticks) {
  FILETIME file{static_cast<DWORD>(ticks),static_cast<DWORD>(ticks>>32)}; SYSTEMTIME time{};
  if(!FileTimeToSystemTime(&file,&time)) throw std::runtime_error("Fixture timestamp unavailable");
  char text[40]{}; std::snprintf(text,sizeof(text),"%04u-%02u-%02uT%02u:%02u:%02u.%06lluZ",time.wYear,time.wMonth,time.wDay,time.wHour,time.wMinute,time.wSecond,static_cast<unsigned long long>((ticks%10000000)/10)); return text;
}
std::string Read(const std::filesystem::path& path) { std::ifstream input(path,std::ios::binary); return {std::istreambuf_iterator<char>(input),std::istreambuf_iterator<char>()}; }
void Check(bool condition,const char* message) { if(!condition) throw std::runtime_error(message); ++assertions; }
}
void CaptureWriterChecks() {
  wchar_t temporary[MAX_PATH]{}; Check(GetTempPathW(MAX_PATH,temporary)>0,"Temporary directory unavailable");
  auto parent=std::filesystem::path(temporary).lexically_normal();
  if(parent.filename().empty()) parent=parent.parent_path();
  const auto root=parent/(L"MaterialSystemCare-capture-"+std::to_wstring(GetCurrentProcessId())+L"-"+std::to_wstring(GetTickCount64()));
  Check(!std::filesystem::exists(root),"Capture fixture directory collision");
  std::filesystem::create_directory(root);
  try {
    FILETIME now{}; GetSystemTimePreciseAsFileTime(&now); const uint64_t ticks=(uint64_t(now.dwHighDateTime)<<32)|now.dwLowDateTime;
    capture_writer::Request request;
    request.path=(root/"frame.png").string();
    request.bytes={137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82,0,0,0,1,0,0,0,1,8,4,0,0,0,181,28,12,2,0,0,0,11,73,68,65,84,120,218,99,252,255,31,0,3,3,2,0,239,163,11,109,0,0,0,0,73,69,78,68,174,66,96,130};
    request.capture_started_utc=Stamp(ticks-20000); request.capture_completed_utc=Stamp(ticks-10000); request.capture_elapsed_microseconds=1000; request.sequence=0; request.width=1; request.height=1; request.pixel_ratio=1;
    auto result=capture_writer::Write(request,[]{return false;});
    Check(result.error.empty() && result.png_saved && result.receipt_saved,"Capture pair was not saved");
    const auto bytes=Read(root/"frame.png"), receipt=Read(root/"frame.png.json");
    Check(bytes==std::string(request.bytes.begin(),request.bytes.end()),"PNG byte mismatch");
    Check(receipt.find("86a2c26bb72fa1a99e131ac0107561ffaf3984865927d1489a8c5acaf8eef873")!=std::string::npos,"PNG hash mismatch");
    for(const auto* field:{"\"schemaVersion\":1","\"captureMethod\":\"flutter-repaint-boundary\"","\"sequence\":0","\"width\":1","\"height\":1","\"pixelRatio\":1","\"pngBytes\":68","\"writeElapsedMicroseconds\":"}) Check(receipt.find(field)!=std::string::npos,"Missing capture receipt field");
    Check(receipt.find(request.path)==std::string::npos && receipt.find("frame.png")==std::string::npos,"Receipt contains a path");
    Check(receipt.find("\"diagnosticStatus\":\"legacy-unverified\",\"diagnostics\":null")!=std::string::npos,"Missing diagnostics became a zero count");
    result=capture_writer::Write(request,[]{return false;}); Check(!result.error.empty() && Read(root/"frame.png")==bytes && Read(root/"frame.png.json")==receipt,"Existing pair overwritten");
    request.path=(root/"dimension.png").string(); request.width=2;
    Check(!capture_writer::Write(request,[]{return false;}).error.empty() && !std::filesystem::exists(request.path),"Dimension mismatch accepted"); request.width=1;
    request.path=(root/"header.png").string(); request.bytes[0]=0;
    Check(!capture_writer::Write(request,[]{return false;}).error.empty(),"Invalid PNG bytes accepted"); request.bytes[0]=137;
    request.path=(root/"time.png").string(); const auto valid=request.capture_started_utc; request.capture_started_utc="2026-02-30T00:00:00.000000Z";
    Check(!capture_writer::Write(request,[]{return false;}).error.empty(),"Malformed timestamp accepted"); request.capture_started_utc=Stamp(ticks+100000);
    Check(!capture_writer::Write(request,[]{return false;}).error.empty(),"Reversed capture clock accepted"); request.capture_started_utc=valid;
    request.path=(root/"sequence.png").string(); request.sequence=1;
    Check(!capture_writer::Write(request,[]{return false;}).error.empty(),"Sequence/path mismatch accepted"); request.path=(root/"sequence-001.png").string();
    result=capture_writer::Write(request,[]{return false;}); Check(result.receipt_saved && Read(root/"sequence-001.png.json").find("\"sequence\":1")!=std::string::npos,"Sequence pair mismatch"); request.sequence=0;
    request.path=(root/"collision.png").string(); { std::ofstream existing(request.path+".json"); existing<<"keep"; }
    result=capture_writer::Write(request,[]{return false;}); Check(result.png_saved && !result.receipt_saved && result.error.find("receipt is incomplete")!=std::string::npos && Read(request.path+".json")=="keep","Receipt collision did not retain PNG and original sidecar");
    request.path=(root/"cancelled.png").string(); result=capture_writer::Write(request,[]{return true;}); Check(!result.png_saved && !std::filesystem::exists(request.path),"Early cancellation created a PNG");
    unsigned calls=0; result=capture_writer::Write(request,[&]{return ++calls>=3;}); Check(result.png_saved && !result.receipt_saved && !std::filesystem::exists(request.path+".json"),"Late cancellation was not reported as an incomplete receipt");
    request.sequence=63; request.path=(root/"boundary-063.png").string();
    result=capture_writer::Write(request,[]{return false;});
    Check(result.receipt_saved && Read(request.path+".json").find("\"sequence\":63")!=std::string::npos,"Sequence 63 rejected");
    request.sequence=64; request.path=(root/"boundary-064.png").string();
    Check(!capture_writer::Write(request,[]{return false;}).png_saved,"Sequence 64 accepted"); request.sequence=0;
    request.path=(root/"diagnostic.png").string();
    request.diagnostics=capture_writer::Diagnostics{1,0,"flutter-framework,platform-dispatcher",valid,request.capture_completed_utc,1,0,0,true};
    result=capture_writer::Write(request,[]{return false;});
    Check(result.receipt_saved && Read(request.path+".json").find("\"frameworkErrorCount\":1")!=std::string::npos,"Observed diagnostic count was not paired");
    request.path=(root/"invalid-diagnostic.png").string();
    auto& diagnostic=*request.diagnostics;
    diagnostic.sequence=1;
    Check(!capture_writer::Write(request,[]{return false;}).png_saved,"Diagnostic sequence mismatch accepted"); diagnostic.sequence=0;
    diagnostic.healthy=false;
    Check(!capture_writer::Write(request,[]{return false;}).png_saved,"Missing diagnostic hook accepted"); diagnostic.healthy=true;
    diagnostic.dropped=1;
    Check(!capture_writer::Write(request,[]{return false;}).png_saved,"Dropped diagnostics accepted"); diagnostic.dropped=0;
    diagnostic.framework_errors=1001;
    Check(!capture_writer::Write(request,[]{return false;}).png_saved,"Unbounded diagnostic count accepted"); diagnostic.framework_errors=1;
    diagnostic.completed_utc=valid;
    Check(!capture_writer::Write(request,[]{return false;}).png_saved,"Diagnostic interval mismatch accepted"); diagnostic.completed_utc=request.capture_completed_utc;
    diagnostic.started_utc="invalid";
    Check(!capture_writer::Write(request,[]{return false;}).png_saved,"Malformed diagnostic time accepted"); diagnostic.started_utc=valid;
    diagnostic.coverage="console";
    Check(!capture_writer::Write(request,[]{return false;}).png_saved,"Invented diagnostic coverage accepted");
  } catch(...) { if(root.parent_path()==parent && root.filename().wstring().starts_with(L"MaterialSystemCare-capture-")) std::filesystem::remove_all(root); throw; }
  Check(root.parent_path()==parent && root.filename().wstring().starts_with(L"MaterialSystemCare-capture-"),"Capture cleanup scope changed"); std::filesystem::remove_all(root);
  std::cout<<"Capture writer: "<<assertions<<" assertions passed"<<std::endl;
}
