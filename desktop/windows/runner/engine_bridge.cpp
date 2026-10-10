#include "engine_bridge.h"
#include "engine_transport.h"
#include <flutter/standard_method_codec.h>
#include <sddl.h>
#include <shobjidl.h>
#include <shellapi.h>
#include <array>
#include <algorithm>
#include <stdexcept>
#include <sstream>
#include <iomanip>
#include <cmath>

namespace {
std::string WriteCapture(const flutter::EncodableValue* arguments) {
 const auto* map=arguments?std::get_if<flutter::EncodableMap>(arguments):nullptr;
 if(!map) { return "Expected capture data"; }
 auto pathIt=map->find(flutter::EncodableValue("path")); auto bytesIt=map->find(flutter::EncodableValue("bytes"));
 const auto* path=pathIt==map->end()?nullptr:std::get_if<std::string>(&pathIt->second);
 const auto* bytes=bytesIt==map->end()?nullptr:std::get_if<std::vector<uint8_t>>(&bytesIt->second);
 if(!path || path->size()<7 || path->size()>32760 || path->find('\0')!=std::string::npos || (*path)[1]!=':' || ((*path)[2]!='\\' && (*path)[2]!='/') || !bytes || bytes->size()<8 || bytes->size()>32*1024*1024) { return "Invalid capture path or size"; }
 static constexpr unsigned char png[]{137,80,78,71,13,10,26,10};
 if(!std::equal(std::begin(png),std::end(png),bytes->begin())) { return "Expected PNG data"; }
 int count=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,path->data(),static_cast<int>(path->size()),nullptr,0);
 if(count<=0) { return "Invalid capture path"; }
 std::wstring wide(count,0); MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,path->data(),static_cast<int>(path->size()),wide.data(),count);
 if(_wcsicmp(wide.c_str()+wide.size()-4,L".png")!=0 || wide.find(L':',2)!=std::wstring::npos) { return "Expected a PNG file path"; }
 // CREATE_NEW and writing on the same unshared handle avoid a create/reopen
 // race. Caller-selected drive paths may still resolve to network storage.
 HANDLE file=CreateFileW(wide.c_str(),GENERIC_WRITE,0,nullptr,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,nullptr);
 if(file==INVALID_HANDLE_VALUE) { return "Capture destination could not be exclusively created"; }
 DWORD written=0; bool ok=GetFileType(file)==FILE_TYPE_DISK && WriteFile(file,bytes->data(),static_cast<DWORD>(bytes->size()),&written,nullptr) && written==bytes->size() && FlushFileBuffers(file);
 CloseHandle(file);
 if(!ok) { return "Capture write did not complete"; }
 return {};
}
std::string Quote(const std::string& text) {
 std::string out="\""; const char* hex="0123456789abcdef";
 for(unsigned char c:text) { if(c=='"' || c=='\\') { out+='\\'; out+=static_cast<char>(c); } else if(c<32) { out+="\\u00"; out+=hex[c>>4]; out+=hex[c&15]; } else out+=static_cast<char>(c); }
 return out+'"';
}
std::string Json(const flutter::EncodableValue& value,int depth=0) {
 if(depth>32) throw std::runtime_error("Request nesting exceeds limit");
 if(value.IsNull()) return "null";
 if(auto p=std::get_if<bool>(&value)) return *p?"true":"false";
 if(auto p=std::get_if<int32_t>(&value)) return std::to_string(*p);
 if(auto p=std::get_if<int64_t>(&value)) return std::to_string(*p);
 if(auto p=std::get_if<double>(&value)) { if(!std::isfinite(*p)) throw std::runtime_error("Non-finite request number"); std::ostringstream stream; stream<<std::setprecision(17)<<*p; return stream.str(); }
 if(auto p=std::get_if<std::string>(&value)) return Quote(*p);
 if(auto p=std::get_if<flutter::EncodableList>(&value)) { std::string out="["; for(const auto& item:*p) { if(out.size()>1) out+=','; out+=Json(item,depth+1); } return out+']'; }
 if(auto p=std::get_if<flutter::EncodableMap>(&value)) { std::string out="{"; for(const auto& item:*p) { auto key=std::get_if<std::string>(&item.first); if(!key) throw std::runtime_error("Request object keys must be strings"); if(out.size()>1) out+=','; out+=Quote(*key)+':'+Json(item.second,depth+1); } return out+'}'; }
 throw std::runtime_error("Unsupported request value");
}
void Pick(HWND owner, bool directory, const flutter::EncodableValue* arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
 IFileOpenDialog* dialog=nullptr;
 HRESULT initialized=CoInitializeEx(nullptr,COINIT_APARTMENTTHREADED);
 HRESULT status=CoCreateInstance(CLSID_FileOpenDialog,nullptr,CLSCTX_INPROC_SERVER,IID_PPV_ARGS(&dialog));
 if(FAILED(status)) { result->Error("PICKER_UNAVAILABLE","Native selection dialog is unavailable"); if(SUCCEEDED(initialized)) CoUninitialize(); return; }
 DWORD options=0; dialog->GetOptions(&options); dialog->SetOptions(options|FOS_FORCEFILESYSTEM|FOS_PATHMUSTEXIST|(directory?FOS_PICKFOLDERS:FOS_FILEMUSTEXIST));
 std::wstring pattern;
 if(!directory && arguments) {
  const auto* map=std::get_if<flutter::EncodableMap>(arguments);
  if(map) { auto found=map->find(flutter::EncodableValue("extensions"));
   if(found!=map->end()) { const auto* list=std::get_if<flutter::EncodableList>(&found->second);
    if(list && list->size()<=20) for(const auto& extension:*list) {
     const auto* value=std::get_if<std::string>(&extension);
     if(value && !value->empty() && value->size()<=16 && value->find_first_not_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")==std::string::npos) {
      if(!pattern.empty()) pattern+=L";"; pattern+=L"*."; pattern.append(value->begin(),value->end());
     }
    }
   }
  }
 }
 if(!pattern.empty()) { COMDLG_FILTERSPEC filter{L"Supported files",pattern.c_str()}; dialog->SetFileTypes(1,&filter); }
 status=dialog->Show(owner);
 if(status==HRESULT_FROM_WIN32(ERROR_CANCELLED)) result->Success();
 else if(FAILED(status)) result->Error("PICKER_FAILED","Native selection dialog could not complete");
 else {
  IShellItem* item=nullptr; PWSTR path=nullptr;
  if(SUCCEEDED(dialog->GetResult(&item)) && SUCCEEDED(item->GetDisplayName(SIGDN_FILESYSPATH,&path))) {
   int count=WideCharToMultiByte(CP_UTF8,0,path,-1,nullptr,0,nullptr,nullptr); std::string value(static_cast<size_t>(count),0);
   WideCharToMultiByte(CP_UTF8,0,path,-1,value.data(),count,nullptr,nullptr); value.pop_back();
   result->Success(flutter::EncodableValue(value)); CoTaskMemFree(path);
  } else result->Error("PICKER_FAILED","Selected path is unavailable");
  if(item) item->Release();
 }
 dialog->Release(); if(SUCCEEDED(initialized)) CoUninitialize();
}
constexpr size_t kLimit = 4 * 1024 * 1024;
std::wstring CurrentPipe() {
 HANDLE token=nullptr;
 if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) throw std::runtime_error("Cannot identify local user");
 DWORD size=0; GetTokenInformation(token,TokenUser,nullptr,0,&size);
 std::vector<BYTE> data(size);
 if (!GetTokenInformation(token,TokenUser,data.data(),size,&size)) { CloseHandle(token); throw std::runtime_error("Cannot identify local user"); }
 CloseHandle(token); LPWSTR sid=nullptr;
 if (!ConvertSidToStringSidW(reinterpret_cast<TOKEN_USER*>(data.data())->User.Sid,&sid)) throw std::runtime_error("Cannot identify local user");
 std::wstring name=L"\\\\.\\pipe\\MaterialSystemCare."; name+=sid; LocalFree(sid); return name;
}
}
EngineBridge::EngineBridge(flutter::BinaryMessenger* messenger, HWND window):window_(window),pipe_(CurrentPipe()) {
 std::wstring fixtureArguments;
 int argc=0; auto argv=CommandLineToArgvW(GetCommandLineW(),&argc);
 bool fixtureRequested=false; int fixtureIndex=-1;
 if(!argv) throw std::runtime_error("Cannot read launch arguments");
 for(int i=1;i<argc;i++) if(std::wstring(argv[i]).find(L"--cleanup-fixture")==0) {
  fixtureRequested=true;
  if(std::wstring(argv[i])!=L"--cleanup-fixture-root" || fixtureIndex!=-1 || i+1>=argc) { LocalFree(argv); throw std::runtime_error("Invalid cleanup fixture arguments"); }
  fixtureIndex=i++;
 }
 if(fixtureRequested) {
  std::wstring root=argv[fixtureIndex+1];
  if(root.empty() || root.find(L'"')!=std::wstring::npos || root.back()==L'\\' || root.back()==L'/' || root.find(L"--")==0) { LocalFree(argv); throw std::runtime_error("Invalid cleanup fixture root"); }
  GUID guid{}; wchar_t value[40]{};
  if(FAILED(CoCreateGuid(&guid)) || !StringFromGUID2(guid,value,40)) { LocalFree(argv); throw std::runtime_error("Cannot isolate cleanup fixture transport"); }
  std::wstring suffix;
  for(wchar_t c:std::wstring(value)) if(iswxdigit(c)) suffix+=c;
  pipe_+=L".fixture."+suffix;
  fixtureArguments=L" --cleanup-fixture-root \""+root+L"\" --cleanup-fixture-pipe "+suffix;
 }
 LocalFree(argv);
 wchar_t executable[32768]{}; GetModuleFileNameW(nullptr,executable,32768);
 std::wstring base(executable); base.resize(base.find_last_of(L"\\/"));
 std::wstring engine=base+L"\\engine\\MaterialSystemCare.Engine.exe";
 if(GetFileAttributesW(engine.c_str())!=INVALID_FILE_ATTRIBUTES) {
  STARTUPINFOW startup{}; startup.cb=sizeof(startup); PROCESS_INFORMATION process{};
  std::wstring command=L"\""+engine+L"\""+fixtureArguments;
  if(CreateProcessW(engine.c_str(),command.data(),nullptr,nullptr,FALSE,CREATE_NO_WINDOW|CREATE_SUSPENDED,nullptr,base.c_str(),&startup,&process)) {
   process_=process.hProcess; process_id_=process.dwProcessId;
   job_=CreateJobObjectW(nullptr,nullptr); JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{}; limits.BasicLimitInformation.LimitFlags=JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
   if(job_ && SetInformationJobObject(job_,JobObjectExtendedLimitInformation,&limits,sizeof(limits)) && AssignProcessToJobObject(job_,process_)) ResumeThread(process.hThread);
   else TerminateProcess(process_,1);
   CloseHandle(process.hThread);
  }
 }
 channel_=std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(messenger,"material_system_care/engine",&flutter::StandardMethodCodec::GetInstance());
 channel_->SetMethodCallHandler([this](const auto& call, auto result) {
  if(call.method_name()=="writeCapture") {
   for(auto it=workers_.begin();it!=workers_.end();) { if(*it->done) { it->thread.join(); it=workers_.erase(it); } else ++it; }
   if(workers_.size()>=16 || !call.arguments()) { result->Error("CAPTURE_BUSY","Capture writer is unavailable"); return; }
   auto data=*call.arguments(); auto done=std::make_shared<std::atomic<bool>>(false); auto cancelled=std::make_shared<std::atomic<bool>>(false);
   std::thread worker([this,data=std::move(data),result=std::move(result),done,cancelled]() mutable {
    auto reply=std::make_unique<Reply>(); reply->result=std::move(result); reply->errorCode="CAPTURE_WRITE_FAILED"; reply->nullSuccess=true;
    try { reply->error=*cancelled?"Capture cancelled":WriteCapture(&data); } catch(...) { reply->error="Capture writer could not complete"; }
    { std::lock_guard<std::mutex> lock(mutex_); replies_.push_back(std::move(reply)); }
    if(!stopping_) PostMessageW(window_,kCompletion,0,0); *done=true;
   });
   workers_.push_back(Worker{std::move(worker),done,cancelled,"capture:"}); return;
  }
  if(call.method_name()=="cancel") {
   const auto* id=call.arguments()?std::get_if<std::string>(call.arguments()):nullptr;
   if(!id || id->empty() || id->size()>128) { result->Error("INVALID_ARGUMENT","Expected operation id"); return; }
   bool found=false; for(auto& worker:workers_) if(worker.id==*id) { *worker.cancelled=true; found=true; }
   result->Success(flutter::EncodableValue(found)); return;
  }
  if(call.method_name()=="pickFile" || call.method_name()=="pickDirectory") { Pick(window_,call.method_name()=="pickDirectory",call.arguments(),std::move(result)); return; }
  if(call.method_name()!="invoke") { result->NotImplemented(); return; }
  for(auto it=workers_.begin();it!=workers_.end();) { if(*it->done) { it->thread.join(); it=workers_.erase(it); } else ++it; }
  if(workers_.size()>=16) { result->Error("ENGINE_BUSY","Too many active engine operations"); return; }
  const auto* map=call.arguments() ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
  if(!map) { result->Error("INVALID_ARGUMENT","Expected request map"); return; }
  auto method=map->find(flutter::EncodableValue("method")); auto params=map->find(flutter::EncodableValue("params"));
  const auto* name=method==map->end()?nullptr:std::get_if<std::string>(&method->second);
  if(!name || name->empty() || name->size()>128 || name->find_first_not_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._")!=std::string::npos || params==map->end() || !std::holds_alternative<flutter::EncodableMap>(params->second)) { result->Error("INVALID_ARGUMENT","Invalid method or parameters"); return; }
  auto requestedId=map->find(flutter::EncodableValue("id"));
  const auto* suppliedId=requestedId==map->end()?nullptr:std::get_if<std::string>(&requestedId->second);
  if(requestedId!=map->end() && (!suppliedId || suppliedId->empty() || suppliedId->size()>128)) { result->Error("INVALID_ARGUMENT","Invalid operation id"); return; }
  static uint64_t sequence=0;
  std::string id=suppliedId?*suppliedId:"desktop-"+std::to_string(++sequence);
  for(const auto& worker:workers_) if(worker.id==id && !*worker.done) { result->Error("INVALID_ARGUMENT","Operation id is already active"); return; }
  flutter::EncodableMap request{{flutter::EncodableValue("version"),flutter::EncodableValue(1)},{flutter::EncodableValue("id"),flutter::EncodableValue(id)},{flutter::EncodableValue("method"),method->second},{flutter::EncodableValue("params"),params->second}};
  std::string text;
  try { text=Json(flutter::EncodableValue(request)); } catch(const std::exception& e) { result->Error("INVALID_ARGUMENT",e.what()); return; }
  if(text.size()>kLimit) { result->Error("INVALID_ARGUMENT","Request exceeds limit"); return; }
  auto done=std::make_shared<std::atomic<bool>>(false);
  auto cancelled=std::make_shared<std::atomic<bool>>(false);
  DWORD deadline=engine_transport::DeadlineFor(*name);
  std::thread worker([this,text=std::move(text),result=std::move(result),done,cancelled,deadline]() mutable {
   auto reply=std::make_unique<Reply>(); reply->result=std::move(result);
   try { reply->text=engine_transport::Exchange(pipe_,text,deadline,*cancelled,process_id_); } catch(const std::exception& e) { reply->error=e.what(); if(*cancelled && reply->error=="Engine operation cancelled") reply->errorCode="ENGINE_CANCELLED"; }
   { std::lock_guard<std::mutex> lock(mutex_); replies_.push_back(std::move(reply)); }
   if(!stopping_) PostMessageW(window_,kCompletion,0,0);
   *done=true;
  });
  workers_.push_back(Worker{std::move(worker),done,cancelled,id});
 });
}
void EngineBridge::Complete() {
 std::vector<std::unique_ptr<Reply>> replies; { std::lock_guard<std::mutex> lock(mutex_); replies.swap(replies_); }
 for(auto& reply:replies) { if(reply->error.empty()) { if(reply->nullSuccess) reply->result->Success(); else reply->result->Success(flutter::EncodableValue(reply->text)); } else reply->result->Error(reply->errorCode,reply->error); }
}
EngineBridge::~EngineBridge() {
 stopping_=true; channel_->SetMethodCallHandler(nullptr);
 for(auto& worker:workers_) { *worker.cancelled=true; if(worker.id=="capture:" && worker.thread.joinable()) CancelSynchronousIo(worker.thread.native_handle()); }
 if(job_) CloseHandle(job_);
 for(auto& worker:workers_) if(worker.thread.joinable()) worker.thread.join();
 Complete(); if(process_) CloseHandle(process_);
}
