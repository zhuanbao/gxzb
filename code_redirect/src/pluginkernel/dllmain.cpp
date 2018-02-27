// dllmain.cpp : 定义 DLL 应用程序的入口点。
#include "stdafx.h"
#include "XLUEApplication.h"
#include ".\EvenListenHelper\LuaMsgWnd.h"

CXLUEApplication theApp;


HANDLE g_hInst = NULL;

BOOL APIENTRY DllMain( HMODULE hModule,
                       DWORD  ul_reason_for_call,
                       LPVOID lpReserved
					 )
{
	g_hInst = hModule;
	switch (ul_reason_for_call)
	{
	case DLL_PROCESS_ATTACH:
	case DLL_THREAD_ATTACH:
	case DLL_THREAD_DETACH:
	case DLL_PROCESS_DETACH:
		break;
	}
	return TRUE;
}

STDAPI_(BOOL) InitXLUE(wchar_t* lpCmdLine)
{
	BOOL bRet = theApp.InitInstance(lpCmdLine);
	if (!bRet)
	{
		TSDEBUG4CXX(L"InitInstance error, exit!");
		theApp.ExitInstance();
	}
	return bRet;
}

STDAPI UnInitXLUE()
{
	theApp.ExitInstance();
	return 0;
}

STDAPI InitMsgWnd()
{
	TSAUTO();
	bool b = LuaMsgWindow::Instance()->InitMsgWnd();
	return b ? S_OK : E_FAIL;
}