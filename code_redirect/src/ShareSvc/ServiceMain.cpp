#include "stdafx.h"
#include <windows.h>
#include <tchar.h>
#include <strsafe.h>
#include <Sddl.h>
#include <TlHelp32.h>
#include <cstring>

#include "Utility.h"
#include "ProcessDetect.h"
#include "ScopeResourceHandle.h"
#include "LaunchShare4MoneyConfig.h"
#include "CheckAutoRun.h"

static const wchar_t* szServiceName = L"Share4MoneyService";
#define SVC_ERROR	((DWORD)0xC0020001L)

SERVICE_STATUS          gSvcStatus; 
SERVICE_STATUS_HANDLE   gSvcStatusHandle = NULL; 
HANDLE                  ghSvcStopEvent = NULL;
void WINAPI SvcCtrlHandler(DWORD dwCtrl);
VOID SvcInit(DWORD dwArgc, LPTSTR *lpszArgv);
VOID ReportSvcStatus(DWORD dwCurrentState, DWORD dwWin32ExitCode, DWORD dwWaitHint);
VOID SvcReportEvent(LPTSTR szFunction);

void ServiceMain(int argc, wchar_t *argv[])
{
	gSvcStatusHandle = RegisterServiceCtrlHandler(szServiceName, SvcCtrlHandler);

	if(!gSvcStatusHandle) {
		SvcReportEvent(L"RegisterServiceCtrlHandler");
		return; 
    }

	gSvcStatus.dwServiceType = SERVICE_WIN32; 
	gSvcStatus.dwServiceSpecificExitCode = 0;

	ReportSvcStatus(SERVICE_START_PENDING, NO_ERROR, 3000);

	SvcInit(argc, argv);
}

void WINAPI SvcCtrlHandler(DWORD dwCtrl)
{
	switch(dwCtrl) {  
	  case SERVICE_CONTROL_STOP: 
		 ReportSvcStatus(SERVICE_STOP_PENDING, NO_ERROR, 0);

		 SetEvent(ghSvcStopEvent);
		 ReportSvcStatus(gSvcStatus.dwCurrentState, NO_ERROR, 0);
		 return;
	  case SERVICE_CONTROL_INTERROGATE:
		 break;
	  default:
		 break;
	}
}

VOID SvcInit(DWORD dwArgc, LPTSTR *lpszArgv)
{
	ghSvcStopEvent = CreateEvent(NULL, TRUE, FALSE, NULL);

    if (ghSvcStopEvent == NULL) {
        ReportSvcStatus(SERVICE_STOPPED, NO_ERROR, 0);
        return;
    }

    ReportSvcStatus(SERVICE_RUNNING, NO_ERROR, 0);

	if (CheckAutoRun::ShouldFixAutoRun())
	{
		CheckAutoRun::FixAutoRun();
		if (!ProcessDetect::IsShare4MoneyOrShare4MoneySetupRunning())
		{
			DWORD dwExplorerPID = GetExplorerPID();
			if(dwExplorerPID > 0 && !::LaunchShare4Money(dwExplorerPID)) {
				DWORD waitRet = ::WaitForSingleObject(ghSvcStopEvent, 60 * 1000);
			}
		}
	}
	else
	{
		TSERROR4CXX(L"ShouldFixAutoRun return false");
	}
	LaunchShare4MoneyConfig launchCfg;
    while(1) {
        DWORD dwTimeToWait = 2000;

		if(ProcessDetect::IsShare4MoneyOrShare4MoneySetupRunning()) {
			dwTimeToWait = 2000;
			launchCfg.ClearLastOffLineTime();
		}
		else if(launchCfg.CheckEnableLaunchNow()) {
				DWORD dwExplorerPID = GetExplorerPID();
				if(dwExplorerPID > 0 && !::LaunchShare4Money(dwExplorerPID)) {
					dwTimeToWait = 60 * 1000;
				}

		}

		DWORD waitRet = ::WaitForSingleObject(ghSvcStopEvent, dwTimeToWait);
		if(waitRet == WAIT_FAILED) {
			break;
		}
		else if(waitRet == WAIT_OBJECT_0) {
			break;
		}
    }
	ReportSvcStatus(SERVICE_STOPPED, NO_ERROR, 0);
}

VOID ReportSvcStatus( DWORD dwCurrentState,
                      DWORD dwWin32ExitCode,
                      DWORD dwWaitHint)
{
    static DWORD dwCheckPoint = 1;

    gSvcStatus.dwCurrentState = dwCurrentState;
    gSvcStatus.dwWin32ExitCode = dwWin32ExitCode;
    gSvcStatus.dwWaitHint = dwWaitHint;

    if (dwCurrentState == SERVICE_START_PENDING)
        gSvcStatus.dwControlsAccepted = 0;
    else gSvcStatus.dwControlsAccepted = SERVICE_ACCEPT_STOP;

	if ((dwCurrentState == SERVICE_RUNNING) || (dwCurrentState == SERVICE_STOPPED)) {
		gSvcStatus.dwCheckPoint = 0;
	}
	else {
		gSvcStatus.dwCheckPoint = dwCheckPoint++;	
	}

    SetServiceStatus(gSvcStatusHandle, &gSvcStatus );
}

VOID SvcReportEvent(LPTSTR szFunction) 
{ 
    HANDLE hEventSource;
    LPCTSTR lpszStrings[2];
    TCHAR Buffer[80];

    hEventSource = RegisterEventSource(NULL, szServiceName);

    if(NULL != hEventSource) {
        StringCchPrintf(Buffer, 80, TEXT("%s failed with %d"), szFunction, GetLastError());

		lpszStrings[0] = szServiceName;
        lpszStrings[1] = Buffer;

        ReportEvent(hEventSource, EVENTLOG_ERROR_TYPE, 0, SVC_ERROR, NULL, 2, 0, lpszStrings, NULL);
		DeregisterEventSource(hEventSource);
    }
}
