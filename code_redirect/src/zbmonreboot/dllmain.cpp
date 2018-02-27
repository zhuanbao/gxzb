// dllmain.cpp : 定义 DLL 应用程序的入口点。
#include "stdafx.h"
#include "WinApiHooker.h"
static class HookModule {
	HANDLE hMutex;
public:
	HookModule() : hMutex(NULL) {
		wchar_t path[MAX_PATH];
		::GetModuleFileName(NULL, path, MAX_PATH);
		size_t length = std::wcslen(path);
		size_t offset = length;
		for(;offset != 0 && path[offset - 1] != '\\'; --offset)
			;
		if(_wcsicmp(path + offset, L"setup.exe") == 0 || wcsstr(path + offset,L"whql") != NULL) {
			OutputDebugStringA("[monreboot] pass check exe name");
			wchar_t szMutexName[MAX_PATH] = {0};
			DWORD dwPID = GetCurrentProcessId();
			swprintf(szMutexName, L"HOOK_{347FEC1C-9AB4-4de0-8D62-55746B8477C5}_%d", dwPID);
			this->hMutex = ::CreateMutex(NULL, FALSE, szMutexName);
			if(this->hMutex != NULL && ::GetLastError() == ERROR_ALREADY_EXISTS) {
				OutputDebugStringA("[monreboot] create mutex failed");
				::CloseHandle(this->hMutex);
				this->hMutex = NULL;
			}
		}
	}

	bool CanLoad() const {
		return this->hMutex != NULL;
	}

	~HookModule() {
		if(this->hMutex != NULL) {
			::CloseHandle(this->hMutex);
			this->hMutex = NULL;
		}
	}
} hookModule;

HMODULE g_hModule = NULL;

BOOL APIENTRY DllMain( HMODULE hModule,
                       DWORD  ul_reason_for_call,
                       LPVOID lpReserved
					 )
{
	switch (ul_reason_for_call)
	{
	case DLL_PROCESS_ATTACH:
		DisableThreadLibraryCalls(hModule);
		g_hModule = hModule;
		if(!hookModule.CanLoad()) {
			OutputDebugStringA("[monreboot] check can load failed");
			return FALSE;
		}
		OutputDebugStringA("[monreboot] success attached");
		WinApiHooker::AttachHook();
		break;
	case DLL_THREAD_ATTACH:
	case DLL_THREAD_DETACH:
	case DLL_PROCESS_DETACH:
		WinApiHooker::DetachHook();
		break;
	}
	return TRUE;
}

