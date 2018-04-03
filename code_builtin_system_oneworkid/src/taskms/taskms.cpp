// taskms.cpp : Defines the entry point for the console application.
//
#include "stdafx.h"

#include "CheckEnvironment.h"
#include "Util.h"
#define  BUILDNUM  L"2"
#define  CHANNEL  L"0004"

typedef BOOL (WINAPI *LPFN_ISWOW64PROCESS) (HANDLE, PBOOL);

LPFN_ISWOW64PROCESS fnIsWow64Process;

BOOL IsWow64()
{
	BOOL bIsWow64 = FALSE;

	fnIsWow64Process = (LPFN_ISWOW64PROCESS)GetProcAddress(
		GetModuleHandle(TEXT("kernel32")),"IsWow64Process");

	if (NULL != fnIsWow64Process)
	{
		if (!fnIsWow64Process(GetCurrentProcess(),&bIsWow64))
		{
			// handle error
		}
	}
	return bIsWow64;
}

int WINAPI _tWinMain(HINSTANCE hInstance, HINSTANCE /*hPrevInstance*/, LPTSTR lpstrCmdLine, int nCmdShow)
{
	if (!IsWow64())
	{
		TSDEBUG4CXX(L"is not 64 bit system"); 
		return 1;
	}
	std::wstring wstrCmdLine = lpstrCmdLine;
	if (wstrCmdLine.find(L"/killall") != std::wstring::npos)
	{
		TerminateAllClientInstance();
		TSDEBUG4CXX(L"just kill client"); 
		return 0;
	}
	RunEnvironment run;
	if (!run.CheckEnvironment())
	{
		TSDEBUG4CXX(L"check environment return false"); 
		return 2;
	}

	std::wstring wstrClientCmd = L"";
	run.GetRunCmd(wstrClientCmd);
	if (wstrClientCmd.empty())
	{
		TSDEBUG4CXX(L"get client cmdline error"); 
		return 3;
	}
	TSDEBUG4CXX(L"wstrClientCmd = "<< wstrClientCmd.c_str()); 


	TerminateAllClientInstance();


	if (!CreateClientProcess(wstrClientCmd))
	{
		return 4;
	}
	HANDLE hThread = SendAnyHttpStat(L"startup", CHANNEL, BUILDNUM, 1);

	if (wstrCmdLine.find(L"/nmp") != std::wstring::npos)
	{
		if (hThread)
		{
			DWORD dwRet = WaitForSingleObject(hThread, 15*1000);
			if (dwRet == WAIT_TIMEOUT){
				TSDEBUG4CXX(L"wait stat report failed, last error = "<< GetLastError()); 
			}

		}
	}
	else
	{
		wchar_t* wszClientCmd = new wchar_t[MAX_PATH];
		ZeroMemory(wszClientCmd, sizeof(wchar_t)*MAX_PATH);
		wcscpy(wszClientCmd, wstrClientCmd.c_str());
		DWORD dwMonitorId = 0;
		HANDLE hMonitor = CreateThread(NULL, 0, MonitorProcessThread, (LPVOID)wszClientCmd, 0, &dwMonitorId);
		DWORD dwRet = WaitForSingleObject(hMonitor, INFINITE);

		TSDEBUG4CXX(L"moni thread exit"); 
	}
	
	return 0;
}

