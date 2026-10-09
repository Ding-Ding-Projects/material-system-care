#include "engine_transport.h"
#include <thread>
#include <iostream>
#include <stdexcept>
void Case(unsigned number,DWORD delay,DWORD deadline,bool expected,DWORD cancelAfter=0,bool wrongServer=false) {
 std::wstring name=L"\\\\.\\pipe\\MaterialSystemCare.NativeFixture."+std::to_wstring(GetCurrentProcessId())+L"."+std::to_wstring(number);
 HANDLE server=CreateNamedPipeW(name.c_str(),PIPE_ACCESS_DUPLEX,PIPE_TYPE_BYTE|PIPE_WAIT|PIPE_REJECT_REMOTE_CLIENTS,1,8192,8192,0,nullptr);
 if(server==INVALID_HANDLE_VALUE) throw std::runtime_error("Cannot create isolated fixture pipe");
 std::thread producer([&] { if(ConnectNamedPipe(server,nullptr) || GetLastError()==ERROR_PIPE_CONNECTED) { char input[512]{}; DWORD count=0; ReadFile(server,input,sizeof(input),&count,nullptr); Sleep(delay); const char response[]="{\"ok\":true}\n"; WriteFile(server,response,sizeof(response)-1,&count,nullptr); } CloseHandle(server); });
 std::atomic<bool> cancelled=false;
 std::thread cancel;
 if(cancelAfter) cancel=std::thread([&] { Sleep(cancelAfter); cancelled=true; });
 bool success=false;
 try { success=engine_transport::Exchange(name,"{}",deadline,cancelled,GetCurrentProcessId()+(wrongServer?1:0))=="{\"ok\":true}"; } catch(const std::exception&) { }
 if(cancel.joinable()) cancel.join(); producer.join();
 if(success!=expected) throw std::runtime_error("Native deadline/cancellation fixture mismatch");
 std::cout<<"PASS case "<<number<<std::endl;
}
int main() {
 try {
  Case(1,31000,35000,true);
  Case(2,500,100,false);
  Case(3,500,3000,false,50);
  Case(4,0,3000,false,0,true);
  if(engine_transport::DeadlineFor("security.scan")!=3600000 || engine_transport::DeadlineFor("providers.invoke")<=60000 || engine_transport::DeadlineFor("apps.upgrade")<=180000) throw std::runtime_error("Method deadline mismatch");
  std::cout<<"Native transport: 5 passed"<<std::endl; return 0;
 } catch(const std::exception& e) { std::cerr<<e.what()<<std::endl; return 1; }
}
