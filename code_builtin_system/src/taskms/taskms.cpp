// taskms.cpp : Defines the entry point for the console application.
//
#include "stdafx.h"
#include "userconfig.h"
#include "CheckEnvironment.h"
#include "Util.h"
#define  BUILDNUM  L"1"

int WINAPI _tWinMain(HINSTANCE hInstance, HINSTANCE /*hPrevInstance*/, LPTSTR lpstrCmdLine, int nCmdShow)
{
	/*if (!IsWow64())
	{
		TSDEBUG4CXX(L"is not 64 bit system"); 
		return 1;
	}*/
	std::wstring wstrCmdLine = lpstrCmdLine;
	if (wstrCmdLine.find(L"/killall") != std::wstring::npos)
	{
		TerminateAllClientInstance();
		TSDEBUG4CXX(L"just kill client"); 
		return 0;
	}
	if (!RunEnvironment::Instance()->CheckEnvironment())
	{
		TSDEBUG4CXX(L"check environment return false"); 
		return 2;
	}
	TerminateAllClientInstance();

	if (!RunEnvironment::Instance()->StartAllClient())
	{
		return 4;
	}

	HANDLE hThread = SendAnyHttpStat(L"startup", CHANNEL, BUILDNUM, 1);

	if (wstrCmdLine.find(L"/nmp") != std::wstring::npos || RunEnvironment::Instance()->CheckIsForceNotMonitor())
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
		DWORD dwMonitorId = 0;
		HANDLE hMonitor = CreateThread(NULL, 0, MonitorProcessThread, NULL, 0, &dwMonitorId);
		DWORD dwRet = WaitForSingleObject(hMonitor, INFINITE);
		TSDEBUG4CXX(L"moni thread exit"); 
	}
	
	return 0;
}

