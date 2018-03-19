#include "stdafx.h"
#include "ProcessDetect.h"

#include <cstddef>
#include <cwctype>

#include <Windows.h>
#include <TlHelp32.h>

typedef bool ProccessPredFuncionType(const wchar_t* szFileName);

static bool IsShare4MoneyFileName(const wchar_t* szFileName)
{
	const wchar_t* greenShieldFileName = L"share4money.exe";
	std::size_t i = 0;
	for(;; ++i) {
		if(std::towlower(szFileName[i]) != greenShieldFileName[i]) {
			return false;
		}
		if(szFileName[i] == L'\0' || greenShieldFileName[i] == L'\0') {
			break;
		}
	}
	return szFileName[i] == L'\0' && greenShieldFileName[i] == L'\0';
}

static bool IsShare4MoneySetupFileName(const wchar_t* szFileName)
{
	const wchar_t* setupFileNamePrefix = L"share4moneysetup_";
	for (std::size_t i = 0;; ++i) {
		if (szFileName[i] == L'\0') {
			break;
		}
		if (setupFileNamePrefix[i] == L'\0') {
			return true;
		}
		if (std::towlower(szFileName[i]) != setupFileNamePrefix[i]) {
			break;
		}
	}
	return false;
}

static bool IsShare4MoneyOrShare4MoneySetupFileName(const wchar_t* szFileName)
{
	return IsShare4MoneyFileName(szFileName) || IsShare4MoneySetupFileName(szFileName);
}

static bool IsProccessRunning(ProccessPredFuncionType pred)
{
	HANDLE hProcessSnap = ::CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	if(hProcessSnap == INVALID_HANDLE_VALUE) {
		return false;
	}

	PROCESSENTRY32 pe32;
	pe32.dwSize = sizeof(PROCESSENTRY32);

	if(!Process32First(hProcessSnap, &pe32)) {
		::CloseHandle(hProcessSnap);
		return false;
	}

	bool find = false;
	do {
		if(pred(pe32.szExeFile)) {
			find = true;
			break;
		}
	} while(Process32Next(hProcessSnap, &pe32));

	::CloseHandle(hProcessSnap);
	return find;
}


bool ProcessDetect::IsShare4MoneyRunning()
{
	return IsProccessRunning(&IsShare4MoneyFileName);
}

bool ProcessDetect::IsShare4MoneySetupRunning()
{
	HANDLE hMutex = ::OpenMutex(SYNCHRONIZE, FALSE, L"Global\\gxzbsetup_{CCE50E5F-9299-4609-9EB5-B9CB4F283E94}");
	if(hMutex != NULL) {
		::CloseHandle(hMutex);
		hMutex = NULL;
		return true;
	}
	return IsProccessRunning(&IsShare4MoneySetupFileName);
}

bool ProcessDetect::IsShare4MoneyOrShare4MoneySetupRunning()
{
	HANDLE hMutex = ::OpenMutex(SYNCHRONIZE, FALSE, L"Global\\gxzbsetup_{CCE50E5F-9299-4609-9EB5-B9CB4F283E94}");
	if(hMutex != NULL) {
		::CloseHandle(hMutex);
		hMutex = NULL;
		return true;
	}
	return IsProccessRunning(&IsShare4MoneyOrShare4MoneySetupFileName);
}
