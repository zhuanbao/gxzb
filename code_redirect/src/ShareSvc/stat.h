#pragma once
#include "commonshare/md5.h"
#include "utility.h"
#include "..\zbkernel\Utility\PeeIdHelper.h"
#pragma comment(lib, "Urlmon.lib")

class svcstat{
public:
	svcstat(){};
	~svcstat(){};
	static svcstat* Instance(){static svcstat s; return &s;};
	static unsigned int WINAPI SendHttpStatThread(LPVOID pParam){
		wchar_t szStat[MAX_PATH+1] = {0};
		wcscpy(szStat,(wchar_t*)pParam);
		delete [] pParam;
		wchar_t szBuffer[MAX_PATH+1] = {0};
		::CoInitialize(NULL);
		HRESULT hr = E_FAIL;
		__try{
			hr = ::URLDownloadToCacheFile(NULL, szStat, szBuffer, MAX_PATH, 0, NULL);
		}
		__except(EXCEPTION_EXECUTE_HANDLER){
			TSDEBUG4CXX("URLDownloadToCacheFile Exception !!!");
		}
		::CoUninitialize();
		return SUCCEEDED(hr)?ERROR_SUCCESS:0xFF;
	};
	//http://pgv.eastredm.com/pc/event?fu1=plugindriver&fu2=107B447C32A5F6BC&fu3=1.0.0.1&fu4=&fu5=showmainwnd&fu6=&fu7=&fu8=&fu9=&fu10=wiaavnq0&fu11=&md5=FC1A117C84772758AF3DC0AD3560260B&rd=1520921644
	void SendStat(std::wstring strFu5,std::wstring strFu6 = L""){

		wchar_t szParam[MAX_PATH] = {0};
		ZeroMemory(szParam, MAX_PATH);
		wsprintf(szParam, L"/event?fu1=sharesvc&fu2=%s&fu3=%s&fu4=&fu5=%s&fu6=%s&fu7=&fu8=&fu9=&fu10=&fu11=",
			GetPeerID().c_str(),
			GetClientVersion().c_str(),
			strFu5.c_str(),
			strFu6.c_str()
		);

		std::string strParam = _T2A(szParam);
		wchar_t szMD5[MAX_PATH] = {0};
		ZeroMemory(szMD5, MAX_PATH);
		GetStringMd5(strParam,szMD5);

		wchar_t* szStat = new wchar_t[MAX_PATH];
		ZeroMemory(szStat, MAX_PATH);

		__time64_t nCurrentTime = 0;
		_time64(&nCurrentTime);
		wsprintf(szStat, L"http://pgv.eastredm.com/pc%s&md5=%s&rd=%I64d",szParam,szMD5,nCurrentTime);
		TSDEBUG4CXX(L"SendStat szStat = "<<szStat);
		//改为在线程外面Reset, 否则WaitForStat可能会失效
		unsigned int dwThreadId = 0;
		HANDLE hThread = (HANDLE)_beginthreadex(NULL, 0, SendHttpStatThread, (LPVOID)szStat, 0, &dwThreadId);
		CloseHandle(hThread);
	};
private:
	std::wstring GetPeerID()
	{
		static std::wstring wstrPeerID = L"";
		if (wstrPeerID.empty())
		{
			GetPeerId_(wstrPeerID);
		}
		return wstrPeerID;
	}
	std::wstring GetClientVersion()
	{
		static std::wstring wstrVersion = L"";
		if (wstrVersion.empty())
		{
			RegTool rt;
			rt.QueryRegValue(HKEY_LOCAL_MACHINE, L"SOFTWARE\\Share4Money", L"Ver", &wstrVersion);
			if (wstrVersion.empty())
			{
				wstrVersion = L"0.0.0.0";
			}
		}
		return wstrVersion;
	}
};