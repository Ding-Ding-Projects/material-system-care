#include "engine_bridge.h"
#include <flutter/json_message_codec.h>
#include <flutter/standard_method_codec.h>
#include <sddl.h>
#include <shobjidl.h>
#include <array>
#include <stdexcept>

namespace {
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
bool Transfer(HANDLE pipe, void* buffer, DWORD length, DWORD& count, bool writing) {
 OVERLAPPED op{}; op.hEvent=CreateEventW(nullptr,TRUE,FALSE,nullptr);
 if (!op.hEvent) return false;
 BOOL ok=writing ? WriteFile(pipe,buffer,length,&count,&op) : ReadFile(pipe,buffer,length,&count,&op);
 if (!ok && GetLastError()==ERROR_IO_PENDING) {
  if (WaitForSingleObject(op.hEvent,30000)==WAIT_OBJECT_0) ok=GetOverlappedResult(pipe,&op,&count,FALSE);
  else { CancelIoEx(pipe,&op); GetOverlappedResult(pipe,&op,&count,TRUE); ok=FALSE; }
 }
 CloseHandle(op.hEvent); return ok!=FALSE;
}
std::string Exchange(const std::wstring& name, std::string request) {
 HANDLE pipe=INVALID_HANDLE_VALUE;
 for(int attempt=0;attempt<50 && pipe==INVALID_HANDLE_VALUE;++attempt) {
  pipe=CreateFileW(name.c_str(),GENERIC_READ|GENERIC_WRITE,0,nullptr,OPEN_EXISTING,FILE_FLAG_OVERLAPPED,nullptr);
  if(pipe==INVALID_HANDLE_VALUE) Sleep(100);
 }
 if(pipe==INVALID_HANDLE_VALUE) throw std::runtime_error("Local engine is unavailable");
 request+='\n'; DWORD count=0;
 if(!Transfer(pipe,request.data(),static_cast<DWORD>(request.size()),count,true) || count!=request.size()) { CloseHandle(pipe); throw std::runtime_error("Engine request failed"); }
 std::string response; std::array<char,8192> buffer{};
 while(response.size()<=kLimit) {
  if(!Transfer(pipe,buffer.data(),static_cast<DWORD>(buffer.size()),count,false) || count==0) { CloseHandle(pipe); throw std::runtime_error("Engine response interrupted"); }
  response.append(buffer.data(),count);
  auto end=response.find('\n');
  if(end!=std::string::npos) { response.resize(end); CloseHandle(pipe); if(response.size()>kLimit) throw std::runtime_error("Engine response exceeds limit"); return response; }
 }
 CloseHandle(pipe); throw std::runtime_error("Engine response exceeds limit");
}
}
EngineBridge::EngineBridge(flutter::BinaryMessenger* messenger, HWND window):window_(window),pipe_(CurrentPipe()) {
 wchar_t executable[32768]{}; GetModuleFileNameW(nullptr,executable,32768);
 std::wstring base(executable); base.resize(base.find_last_of(L"\\/"));
 std::wstring engine=base+L"\\engine\\MaterialSystemCare.Engine.exe";
 if(GetFileAttributesW(engine.c_str())!=INVALID_FILE_ATTRIBUTES) {
  STARTUPINFOW startup{}; startup.cb=sizeof(startup); PROCESS_INFORMATION process{};
  std::wstring command=L"\""+engine+L"\"";
  if(CreateProcessW(engine.c_str(),command.data(),nullptr,nullptr,FALSE,CREATE_NO_WINDOW,nullptr,base.c_str(),&startup,&process)) {
   CloseHandle(process.hThread); process_=process.hProcess;
   job_=CreateJobObjectW(nullptr,nullptr); JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{}; limits.BasicLimitInformation.LimitFlags=JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
   if(job_ && SetInformationJobObject(job_,JobObjectExtendedLimitInformation,&limits,sizeof(limits))) AssignProcessToJobObject(job_,process_);
  }
 }
 channel_=std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(messenger,"material_system_care/engine",&flutter::StandardMethodCodec::GetInstance());
 channel_->SetMethodCallHandler([this](const auto& call, auto result) {
  if(call.method_name()=="pickFile" || call.method_name()=="pickDirectory") { Pick(window_,call.method_name()=="pickDirectory",call.arguments(),std::move(result)); return; }
  if(call.method_name()!="invoke") { result->NotImplemented(); return; }
  const auto* map=call.arguments() ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
  if(!map) { result->Error("INVALID_ARGUMENT","Expected request map"); return; }
  auto method=map->find(flutter::EncodableValue("method")); auto params=map->find(flutter::EncodableValue("params"));
  const auto* name=method==map->end()?nullptr:std::get_if<std::string>(&method->second);
  if(!name || name->empty() || name->size()>128 || name->find_first_not_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._")!=std::string::npos || params==map->end() || !std::holds_alternative<flutter::EncodableMap>(params->second)) { result->Error("INVALID_ARGUMENT","Invalid method or parameters"); return; }
  flutter::EncodableMap request{{flutter::EncodableValue("version"),flutter::EncodableValue(1)},{flutter::EncodableValue("id"),flutter::EncodableValue("desktop")},{flutter::EncodableValue("method"),method->second},{flutter::EncodableValue("params"),params->second}};
  auto encoded=flutter::JsonMessageCodec::GetInstance().EncodeMessage(flutter::EncodableValue(request));
  if(!encoded || encoded->size()>kLimit) { result->Error("INVALID_ARGUMENT","Request exceeds limit"); return; }
  std::string text(encoded->begin(),encoded->end());
  workers_.emplace_back([this,text=std::move(text),result=std::move(result)]() mutable {
   auto reply=std::make_unique<Reply>(); reply->result=std::move(result);
   try { reply->text=Exchange(pipe_,text); } catch(const std::exception& e) { reply->error=e.what(); }
   { std::lock_guard<std::mutex> lock(mutex_); replies_.push_back(std::move(reply)); }
   if(!stopping_) PostMessageW(window_,kCompletion,0,0);
  });
 });
}
void EngineBridge::Complete() {
 std::vector<std::unique_ptr<Reply>> replies; { std::lock_guard<std::mutex> lock(mutex_); replies.swap(replies_); }
 for(auto& reply:replies) { if(reply->error.empty()) reply->result->Success(flutter::EncodableValue(reply->text)); else reply->result->Error("ENGINE_UNAVAILABLE",reply->error); }
}
EngineBridge::~EngineBridge() {
 stopping_=true; channel_->SetMethodCallHandler(nullptr);
 if(job_) CloseHandle(job_);
 for(auto& worker:workers_) if(worker.joinable()) worker.join();
 Complete(); if(process_) CloseHandle(process_);
}
