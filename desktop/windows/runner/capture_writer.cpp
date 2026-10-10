#include "capture_writer.h"
#include <windows.h>
#include <bcrypt.h>
#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cwchar>
#include <sstream>

namespace capture_writer {
namespace {
struct Handle {
  HANDLE value = INVALID_HANDLE_VALUE;
  ~Handle() { if (value != INVALID_HANDLE_VALUE) CloseHandle(value); }
};
uint64_t Ticks(FILETIME value) { return (uint64_t(value.dwHighDateTime) << 32) | value.dwLowDateTime; }
FILETIME Now() { FILETIME value{}; GetSystemTimePreciseAsFileTime(&value); return value; }
std::string Utc(FILETIME value) {
  SYSTEMTIME time{}; if (!FileTimeToSystemTime(&value, &time)) return {};
  char text[40]{};
  std::snprintf(text, sizeof(text), "%04u-%02u-%02uT%02u:%02u:%02u.%06lluZ", time.wYear, time.wMonth, time.wDay, time.wHour, time.wMinute, time.wSecond, static_cast<unsigned long long>((Ticks(value) % 10000000) / 10));
  return text;
}
bool ParseUtc(const std::string& value, uint64_t& ticks) {
  if (value.size() != 27 || value[4] != '-' || value[7] != '-' || value[10] != 'T' || value[13] != ':' || value[16] != ':' || value[19] != '.' || value[26] != 'Z') return false;
  for (size_t i=0; i<value.size(); ++i) if (i!=4 && i!=7 && i!=10 && i!=13 && i!=16 && i!=19 && i!=26 && (value[i]<'0' || value[i]>'9')) return false;
  auto number=[&](size_t offset,size_t count) { return static_cast<WORD>(std::stoi(value.substr(offset,count))); };
  SYSTEMTIME time{}; time.wYear=number(0,4); time.wMonth=number(5,2); time.wDay=number(8,2); time.wHour=number(11,2); time.wMinute=number(14,2); time.wSecond=number(17,2); time.wMilliseconds=number(20,3);
  if(time.wYear<2020 || time.wMonth<1 || time.wMonth>12 || time.wDay<1 || time.wHour>23 || time.wMinute>59 || time.wSecond>59) return false;
  FILETIME stamp{}; if(!SystemTimeToFileTime(&time,&stamp)) return false;
  ticks=Ticks(stamp)+number(23,3)*10;
  FILETIME exact{static_cast<DWORD>(ticks),static_cast<DWORD>(ticks>>32)};
  return Utc(exact)==value;
}
uint32_t BigEndian(const std::vector<uint8_t>& bytes,size_t offset) {
  return uint32_t(bytes[offset])<<24 | uint32_t(bytes[offset+1])<<16 | uint32_t(bytes[offset+2])<<8 | bytes[offset+3];
}
std::string Hash(const std::vector<uint8_t>& bytes) {
  BCRYPT_ALG_HANDLE algorithm=nullptr; BCRYPT_HASH_HANDLE hash=nullptr;
  if(BCryptOpenAlgorithmProvider(&algorithm,BCRYPT_SHA256_ALGORITHM,nullptr,0)<0) return {};
  DWORD size=0,written=0; std::string result;
  if(BCryptGetProperty(algorithm,BCRYPT_OBJECT_LENGTH,reinterpret_cast<PUCHAR>(&size),sizeof(size),&written,0)>=0) {
    std::vector<uint8_t> object(size); uint8_t digest[32]{};
    if(BCryptCreateHash(algorithm,&hash,object.data(),size,nullptr,0,0)>=0 && BCryptHashData(hash,const_cast<PUCHAR>(bytes.data()),static_cast<ULONG>(bytes.size()),0)>=0 && BCryptFinishHash(hash,digest,sizeof(digest),0)>=0) {
      static const char hex[]="0123456789abcdef";
      for(auto byte:digest) { result+=hex[byte>>4]; result+=hex[byte&15]; }
    }
    if(hash) BCryptDestroyHash(hash);
  }
  BCryptCloseAlgorithmProvider(algorithm,0); return result;
}
bool Save(HANDLE file,const uint8_t* bytes,DWORD size) {
  DWORD written=0; return GetFileType(file)==FILE_TYPE_DISK && WriteFile(file,bytes,size,&written,nullptr) && written==size && FlushFileBuffers(file);
}
}
Result Write(const Request& request,const std::function<bool()>& cancelled) {
  Result result;
  auto fail=[&](const char* error) { result.error=error; return result; };
  try {
  if(cancelled()) return fail("Capture cancelled before writing");
  const auto& path=request.path; const auto& bytes=request.bytes;
  if(path.size()<7 || path.size()>32760 || path.find('\0')!=std::string::npos || path[1]!=':' || (path[2]!='\\' && path[2]!='/') || bytes.size()<33 || bytes.size()>32*1024*1024) return fail("Invalid capture path or size");
  static const uint8_t signature[]{137,80,78,71,13,10,26,10};
  if(!std::equal(std::begin(signature),std::end(signature),bytes.begin()) || BigEndian(bytes,8)!=13 || bytes[12]!='I' || bytes[13]!='H' || bytes[14]!='D' || bytes[15]!='R') return fail("Invalid PNG header");
  if(request.width<1 || request.width>32768 || request.height<1 || request.height>32768 || request.width*request.height>100000000 || BigEndian(bytes,16)!=request.width || BigEndian(bytes,20)!=request.height || request.pixel_ratio!=1 || request.sequence<0 || request.sequence>=20) return fail("Capture dimensions, ratio or sequence are invalid");
  uint64_t started=0,completed=0;
  if(!ParseUtc(request.capture_started_utc,started) || !ParseUtc(request.capture_completed_utc,completed) || completed<started || request.capture_elapsed_microseconds<0 || request.capture_elapsed_microseconds>600000000 || completed-started>6000000000ULL) return fail("Capture timestamps or elapsed duration are invalid");
  if(request.diagnostics) {
    const auto& d=*request.diagnostics;
    uint64_t from=0,through=0;
    if(d.schema_version!=1 || d.sequence!=request.sequence || !d.healthy ||
       d.coverage!="flutter-framework,platform-dispatcher" ||
       d.framework_errors<0 || d.platform_errors<0 || d.dropped!=0 ||
       d.framework_errors>1000 || d.platform_errors>1000 ||
       d.framework_errors+d.platform_errors>1000 ||
       !ParseUtc(d.started_utc,from) || !ParseUtc(d.completed_utc,through) ||
       from>started || through!=completed || through<from ||
       through-from>864000000000ULL)
      return fail("Capture diagnostics are unhealthy, invalid or mismatched");
  }
  int count=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,path.data(),static_cast<int>(path.size()),nullptr,0);
  if(count<=0) return fail("Invalid capture path");
  std::wstring wide(count,0); MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,path.data(),static_cast<int>(path.size()),wide.data(),count);
  if(_wcsicmp(wide.c_str()+wide.size()-4,L".png")!=0 || wide.find(L':',2)!=std::wstring::npos) return fail("Expected a PNG file path");
  if(request.sequence>0) {
    wchar_t suffix[16]{}; std::swprintf(suffix,16,L"-%03lld.png",static_cast<long long>(request.sequence));
    if(wide.size()<8 || _wcsicmp(wide.c_str()+wide.size()-8,suffix)!=0) return fail("Capture sequence does not match the filename");
  }
  const auto digest=Hash(bytes); if(digest.size()!=64) return fail("Capture hash could not be computed");
  const FILETIME writeStarted=Now();
  if(Ticks(writeStarted)<completed || Ticks(writeStarted)-completed>6000000000ULL) return fail("Capture clock order is invalid or the frame expired");
  const auto clockStarted=std::chrono::steady_clock::now();
  if(cancelled()) return fail("Capture cancelled before writing");
  Handle png; png.value=CreateFileW(wide.c_str(),GENERIC_WRITE,0,nullptr,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,nullptr);
  if(png.value==INVALID_HANDLE_VALUE) return fail("Capture destination could not be exclusively created");
  if(!Save(png.value,bytes.data(),static_cast<DWORD>(bytes.size()))) return fail("PNG write is incomplete; no verified receipt was saved");
  result.png_saved=true;
  const auto elapsed=std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now()-clockStarted).count();
  const FILETIME writeCompleted=Now();
  if(Ticks(writeCompleted)<Ticks(writeStarted)) return fail("PNG saved but receipt is incomplete: the write clock reversed");
  if(elapsed<0 || elapsed>600000000) return fail("PNG saved but receipt is incomplete: the write duration exceeded its bound");
  if(cancelled()) return fail("PNG saved but receipt is incomplete: capture cancelled");
  std::ostringstream json;
  json<<"{\"schemaVersion\":1,\"captureMethod\":\"flutter-repaint-boundary\",\"captureStartedUtc\":\""<<request.capture_started_utc<<"\",\"captureCompletedUtc\":\""<<request.capture_completed_utc<<"\",\"captureElapsedMicroseconds\":"<<request.capture_elapsed_microseconds<<",\"writeStartedUtc\":\""<<Utc(writeStarted)<<"\",\"writeCompletedUtc\":\""<<Utc(writeCompleted)<<"\",\"writeElapsedMicroseconds\":"<<elapsed<<",\"sequence\":"<<request.sequence<<",\"width\":"<<request.width<<",\"height\":"<<request.height<<",\"pixelRatio\":1,\"pngBytes\":"<<bytes.size()<<",\"pngSha256\":\""<<digest<<"\"}\n";
  auto text=json.str();
  text.resize(text.size()-2);
  if(request.diagnostics) {
    const auto& d=*request.diagnostics;
    std::ostringstream metadata;
    metadata<<",\"diagnosticStatus\":\"observed\",\"diagnostics\":{\"schemaVersion\":1,\"coverage\":\"flutter-framework,platform-dispatcher\",\"startedUtc\":\""<<d.started_utc<<"\",\"completedUtc\":\""<<d.completed_utc<<"\",\"sequence\":"<<d.sequence<<",\"frameworkErrorCount\":"<<d.framework_errors<<",\"platformErrorCount\":"<<d.platform_errors<<",\"droppedCount\":0,\"healthy\":true}}\n";
    text+=metadata.str();
  } else {
    text+=",\"diagnosticStatus\":\"legacy-unverified\",\"diagnostics\":null}\n";
  }
  Handle receipt; receipt.value=CreateFileW((wide+L".json").c_str(),GENERIC_WRITE,0,nullptr,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,nullptr);
  if(receipt.value==INVALID_HANDLE_VALUE || !Save(receipt.value,reinterpret_cast<const uint8_t*>(text.data()),static_cast<DWORD>(text.size()))) return fail("PNG saved but receipt is incomplete: the sidecar could not be exclusively written and flushed");
  result.receipt_saved=true; return result;
  } catch(...) { return fail(result.png_saved ? "PNG saved but receipt is incomplete: the writer did not complete" : "Capture writer did not complete"); }
}
}
