#include<check.h>
//#include "log/Log.h"
#include <Windows.h>
#include <Tlhelp32.h>
#include<string.h>
#include<string>
#include <cstddef>
#include <cwctype>
#include <tchar.h>


wchar_t *szExeName[] = { L"tasklist.", L"taskmgr.", L"procexp", L"wireshark" };

bool IsContainFileName(const wchar_t* szFileName ,const wchar_t* szBlackName)
{
	for (std::size_t i = 0;; ++i) {
		if (szFileName[i] == L'\0') {
			break;
		}
		if (szBlackName[i] == L'\0') {
			return true;
		}
		if (std::towlower(szFileName[i]) != szBlackName[i]) {
			break;
		}
	}
	return false;
}

bool IsUser()
{
	HKEY hKEY;
	if (ERROR_SUCCESS == ::RegOpenKeyExA(HKEY_CURRENT_USER, "Software\\Share4Money", 0, KEY_READ, &hKEY))
		return true;
	else
		return false;
}

UINT WINAPI DoCheck(PVOID pArg)
{
	do {
		HANDLE hSnap = ::CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
		if (hSnap != INVALID_HANDLE_VALUE)
		{
			PROCESSENTRY32 pe;
			pe.dwSize = sizeof(PROCESSENTRY32);
			BOOL bResult = ::Process32First(hSnap, &pe);
			while (bResult)
			{
				for (int i = 0; i < ARRAYSIZE(szExeName); i++)
				{
					if (IsContainFileName(pe.szExeFile, szExeName[i]))
					{
						printf("error occur!\r\n");
						::TerminateProcess(GetCurrentProcess(), 100);
						return 0;
					}
				}
				bResult = ::Process32Next(hSnap, &pe);
			}
			::CloseHandle(hSnap);
		}
		Sleep(2 * 1000);
	} while (true);
	
	return 0;
}