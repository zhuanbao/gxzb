#include "stdafx.h"
#include <TlHelp32.h>
#include <string>

bool IsInjected(DWORD dwPID)
{
	wchar_t szMutexName[MAX_PATH] = {0};
	swprintf(szMutexName, L"HOOK_{347FEC1C-9AB4-4de0-8D62-55746B8477C5}_%d", dwPID);

	HANDLE hMutex = ::OpenMutex(SYNCHRONIZE, FALSE, szMutexName);
	if(hMutex == NULL) {
		return false;
	}
	::CloseHandle(hMutex);
	return true;
}

#define INJECT_RESULT					int 
#define INJECT_OK						0
#define INJECT_FAIL_NOTIMPLEMENTED		1
#define INJECT_FAIL_OPENPROCESS			2
#define INJECT_FAIL_VIRTUALALLOC		3
#define INJECT_FAIL_WRITEPROCESSMEMERY	4
#define INJECT_FAIL_GETPROCADDRESS		5
#define INJECT_FAIL_CREATEREMOTETHREAD	6

static INJECT_RESULT Win32Inject32(DWORD dwProcessID, const wchar_t* dllFilePath)
{
	int path_length = std::wcslen(dllFilePath);
	int alloc_size = (path_length + 1) * 2;
	HANDLE hTargetProcess = ::OpenProcess(PROCESS_CREATE_THREAD | PROCESS_QUERY_INFORMATION | PROCESS_VM_OPERATION | PROCESS_VM_WRITE | PROCESS_VM_READ, FALSE, dwProcessID);
	if (hTargetProcess == NULL) {
		return INJECT_FAIL_OPENPROCESS;
	}
	LPVOID lpVirtualMem = ::VirtualAllocEx(hTargetProcess, NULL, alloc_size, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
	if (lpVirtualMem == NULL) {
		::CloseHandle(hTargetProcess);
		return INJECT_FAIL_VIRTUALALLOC;
	}
	if (::WriteProcessMemory(hTargetProcess, lpVirtualMem, dllFilePath, alloc_size, NULL) == FALSE) {
		::VirtualFreeEx(hTargetProcess, lpVirtualMem, alloc_size, MEM_RESERVE | MEM_COMMIT);
		::CloseHandle(hTargetProcess);
		return INJECT_FAIL_WRITEPROCESSMEMERY;
	}
	FARPROC LoadLibraryW_Addr = GetProcAddress(GetModuleHandle(L"Kernel32.dll"), "LoadLibraryW");
	if (LoadLibraryW_Addr == NULL) {
		::VirtualFreeEx(hTargetProcess, lpVirtualMem, alloc_size, MEM_RESERVE | MEM_COMMIT);
		::CloseHandle(hTargetProcess);
		return INJECT_FAIL_GETPROCADDRESS;
	}
	HANDLE hRemoteThread = ::CreateRemoteThread(hTargetProcess, NULL, 0, reinterpret_cast<LPTHREAD_START_ROUTINE>(LoadLibraryW_Addr), lpVirtualMem, 0, NULL);
	if(hRemoteThread == NULL) {
		::VirtualFreeEx(hTargetProcess, lpVirtualMem, alloc_size, MEM_RESERVE | MEM_COMMIT);
		::CloseHandle(hTargetProcess);
		return INJECT_FAIL_CREATEREMOTETHREAD;
	}
	::WaitForSingleObject(hRemoteThread, 3000);
	::CloseHandle(hRemoteThread);
	::VirtualFreeEx(hTargetProcess, lpVirtualMem, alloc_size, MEM_RESERVE | MEM_COMMIT);
	::CloseHandle(hTargetProcess);
	return INJECT_OK;
}

bool InjectDll(DWORD dwPID, const wchar_t* dllPath)
{
	return Win32Inject32(dwPID, dllPath) == INJECT_OK;
}