#pragma once
#include <Windows.h>

DWORD WINAPI SendHttpStatThread(LPVOID pParameter);

DWORD WINAPI MonitorProcessThread(LPVOID pParameter);


HANDLE SendAnyHttpStat(TCHAR *ec,TCHAR *ea, TCHAR *el,long ev);

void TerminateAllClientInstance();

BOOL CreateClientProcess(const std::wstring &wstrCmd);

BOOL IsClientRunning(const std::wstring &wstrName);



