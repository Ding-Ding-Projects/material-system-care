#include "engine_transport.h"
#include <array>
#include <stdexcept>
namespace engine_transport {
namespace {
constexpr size_t kLimit=4*1024*1024;
DWORD Remaining(ULONGLONG deadline) {
 auto now=GetTickCount64();
 return now>=deadline?0:static_cast<DWORD>(deadline-now);
}
bool Transfer(HANDLE pipe,void* buffer,DWORD length,DWORD& count,bool writing,ULONGLONG deadline,const std::atomic<bool>& cancelled) {
 OVERLAPPED op{}; op.hEvent=CreateEventW(nullptr,TRUE,FALSE,nullptr);
 if(!op.hEvent) return false;
 BOOL ok=writing?WriteFile(pipe,buffer,length,&count,&op):ReadFile(pipe,buffer,length,&count,&op);
 if(!ok && GetLastError()==ERROR_IO_PENDING) {
  while(!cancelled && Remaining(deadline)>0) {
   DWORD wait=Remaining(deadline); if(wait>100) wait=100;
   auto state=WaitForSingleObject(op.hEvent,wait);
   if(state==WAIT_OBJECT_0) { ok=GetOverlappedResult(pipe,&op,&count,FALSE); break; }
   if(state==WAIT_FAILED) break;
  }
  if(!ok) { CancelIoEx(pipe,&op); GetOverlappedResult(pipe,&op,&count,TRUE); }
 }
 CloseHandle(op.hEvent); return ok!=FALSE;
}
}
DWORD DeadlineFor(const std::string& method) {
 if(method=="security.scan") return 60*60*1000;
 if(method=="storage.analyze" || method=="storage.duplicates" || method=="cleanup.scan" || method=="cleanup.apply" || method=="cleanup.restore") return 30*60*1000;
 if(method=="providers.invoke") return 70*1000;
 if(method=="apps.upgrade" || method=="apps.uninstall" || method=="drivers.install" || method=="drivers.export") return 4*60*1000;
 return 60*1000;
}
std::string Exchange(const std::wstring& name,std::string request,DWORD duration,const std::atomic<bool>& cancelled,DWORD expectedServer) {
 if(duration==0 || duration>60*60*1000) throw std::runtime_error("Invalid engine operation deadline");
 ULONGLONG deadline=GetTickCount64()+duration;
 HANDLE pipe=INVALID_HANDLE_VALUE;
 for(int attempt=0;attempt<50 && pipe==INVALID_HANDLE_VALUE && !cancelled && Remaining(deadline)>0;++attempt) {
  pipe=CreateFileW(name.c_str(),GENERIC_READ|GENERIC_WRITE,0,nullptr,OPEN_EXISTING,FILE_FLAG_OVERLAPPED|SECURITY_SQOS_PRESENT|SECURITY_IDENTIFICATION,nullptr);
  if(pipe==INVALID_HANDLE_VALUE) Sleep(100);
 }
 if(pipe==INVALID_HANDLE_VALUE) throw std::runtime_error(cancelled?"Engine operation cancelled":"Local engine is unavailable");
 ULONG server=0;
 if(expectedServer==0 || !GetNamedPipeServerProcessId(pipe,&server) || server!=expectedServer) { CloseHandle(pipe); throw std::runtime_error("Engine pipe is not owned by the launched engine"); }
 request+='\n'; DWORD count=0;
 if(!Transfer(pipe,request.data(),static_cast<DWORD>(request.size()),count,true,deadline,cancelled) || count!=request.size()) { CloseHandle(pipe); throw std::runtime_error(cancelled?"Engine operation cancelled":"Engine operation deadline exceeded or request interrupted"); }
 std::string response; std::array<char,8192> buffer{};
 while(response.size()<=kLimit) {
  if(!Transfer(pipe,buffer.data(),static_cast<DWORD>(buffer.size()),count,false,deadline,cancelled) || count==0) { CloseHandle(pipe); throw std::runtime_error(cancelled?"Engine operation cancelled":"Engine operation deadline exceeded or response interrupted"); }
  response.append(buffer.data(),count); auto end=response.find('\n');
  if(end!=std::string::npos) { response.resize(end); CloseHandle(pipe); if(response.size()>kLimit) throw std::runtime_error("Engine response exceeds limit"); return response; }
 }
 CloseHandle(pipe); throw std::runtime_error("Engine response exceeds limit");
}
}
