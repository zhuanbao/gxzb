#include "stdafx.h"
#include "WinApiHooker.h"
#include <memory>
#include <cassert>
//#include <process.h>
#include ".\detours\detours.h"

WinApiHooker::ExitWindowsEx_FuncType WinApiHooker::Real_ExitWindowsEx = ::ExitWindowsEx;
WinApiHooker::InitiateSystemShutdown_FuncType WinApiHooker::Real_InitiateSystemShutdown = ::InitiateSystemShutdown;
WinApiHooker::InitiateSystemShutdownEx_FuncType WinApiHooker::Real_InitiateSystemShutdownEx = ::InitiateSystemShutdownEx;

bool WinApiHooker::IsHooked = false;

BOOL WINAPI WinApiHooker::Hooked_ExitWindowsEx(UINT uFlags,  DWORD dwReason)
{
	TSDEBUG(L"uFlags = [%d], dwReason = [%d]", uFlags, dwReason);
	return TRUE;
}

BOOL WINAPI WinApiHooker::Hooked_InitiateSystemShutdown(LPTSTR lpMachineName, LPTSTR lpMessage, DWORD dwTimeout, BOOL bForceAppsClosed, BOOL bRebootAfterShutdown)
{
	TSDEBUG(L"lpMachineName = [%s], lpMessage = [%s], dwTimeout = [%d], bForceAppsClosed = [%d], bRebootAfterShutdown = [%d]", lpMachineName, lpMessage, dwTimeout, bForceAppsClosed, bRebootAfterShutdown);
	return TRUE;
}

BOOL WINAPI WinApiHooker::Hooked_InitiateSystemShutdownEx(LPTSTR lpMachineName, LPTSTR lpMessage, DWORD dwTimeout, BOOL bForceAppsClosed, BOOL bRebootAfterShutdown, DWORD dwReason)
{
	TSDEBUG(L"lpMachineName = [%s], lpMessage = [%s], dwTimeout = [%d], bForceAppsClosed = [%d], bRebootAfterShutdown = [%d], dwReason = [%d]", lpMachineName, lpMessage, dwTimeout, bForceAppsClosed, bRebootAfterShutdown, dwReason);
	return TRUE;
}

bool WinApiHooker::AttachHook()
{
	DetourTransactionBegin();
	DetourUpdateThread(GetCurrentThread());
	DetourAttach(reinterpret_cast<LPVOID*>(&Real_ExitWindowsEx), Hooked_ExitWindowsEx);
	DetourAttach(reinterpret_cast<LPVOID*>(&Real_InitiateSystemShutdown), Hooked_InitiateSystemShutdown);
	DetourAttach(reinterpret_cast<LPVOID*>(&Real_InitiateSystemShutdownEx), Hooked_InitiateSystemShutdownEx);
	DetourTransactionCommit();
	IsHooked = true;
	return true;
}

void WinApiHooker::DetachHook()
{
	if(IsHooked) {
		DetourTransactionBegin();
		DetourUpdateThread(GetCurrentThread());
		DetourDetach(reinterpret_cast<LPVOID*>(&Real_ExitWindowsEx), Hooked_ExitWindowsEx);
		DetourDetach(reinterpret_cast<LPVOID*>(&Real_InitiateSystemShutdown), Hooked_InitiateSystemShutdown);
		DetourDetach(reinterpret_cast<LPVOID*>(&Real_InitiateSystemShutdownEx), Hooked_InitiateSystemShutdownEx);
		DetourTransactionCommit();
		IsHooked = false;
	}
}
