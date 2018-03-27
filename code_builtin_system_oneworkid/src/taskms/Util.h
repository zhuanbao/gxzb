#pragma once
#include <Windows.h>
#include "Utility/PeeIdHelper.h"
#include <Urlmon.h>
#pragma comment(lib, "Urlmon.lib")

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
