// dllmain.cpp : Defines the entry point for the DLL application.
#include "stdafx.h"
#include <string>
#include <comdef.h>
#include <atlbase.h>
#include <WTL/atlapp.h>
#include <Urlmon.h>
#pragma comment(lib, "Urlmon.lib")
#pragma comment(lib, "Version.lib")
#include "shlobj.h"
#include <shellapi.h>
#include <tlhelp32.h>
#include <atlstr.h>
#include "..\zbkernel\Utility\PeeIdHelper.h"
#include "base64.h"
#include <openssl/rsa.h>
#include <openssl/aes.h>
#include <openssl/evp.h>
#pragma comment(lib,"libeay32.lib")
#pragma comment(lib,"ssleay32.lib")

#include "shortcut/Shortcut.h"
#include "StringOperation.h"
using namespace std;

extern "C" typedef HRESULT (__stdcall *PSHGetKnownFolderPath)(  const  GUID& rfid, DWORD dwFlags, HANDLE hToken, PWSTR* pszPath);

void EncryptString(const char* pszData,std::string &strOut);
void DecryptString(const char* pszBase64Data,std::string &strOut);

BOOL APIENTRY DllMain( HMODULE hModule,
                       DWORD  ul_reason_for_call,
                       LPVOID lpReserved
					 )
{
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


extern "C" __declspec(dllexport) BOOL CheckCLEnvir(const char* szExePath){
	STARTUPINFOA si = { 0 };
	si.cb = sizeof(STARTUPINFOA);
	GetStartupInfoA(&si);
	si.wShowWindow = SW_HIDE;
	si.dwFlags = STARTF_USESHOWWINDOW;
	PROCESS_INFORMATION   pi = {0};
	if (!CreateProcessA(NULL, (LPSTR)szExePath, NULL, NULL, TRUE, NULL, NULL, NULL, &si, &pi)){
		CloseHandle(pi.hProcess);
		CloseHandle(pi.hThread);
		return FALSE;
	}
	DWORD dwResult = WaitForSingleObject(pi.hProcess, 5000);
	if (dwResult == WAIT_TIMEOUT){
		return FALSE;
	}
	DWORD dwExitCode = 0xFFFFFFFF;
	if (!GetExitCodeProcess(pi.hProcess, &dwExitCode)){
		return FALSE;
	}
	return dwExitCode == 0;
}

//程序退出保证所有子线程结束
static HANDLE s_ListenHandle = CreateEvent(NULL,TRUE,TRUE,NULL);
//引用计数,默认是0
static int s_ListenCount = 0;
static CRITICAL_SECTION s_csListen;
static bool b_Init = false;

void ResetUserHandle()
{
	if(!b_Init){
		InitializeCriticalSection(&s_csListen);
		b_Init = true;
	}
	EnterCriticalSection(&s_csListen);
	if(s_ListenCount == 0)
	{
		ResetEvent(s_ListenHandle);
	}
	++s_ListenCount; //引用计数加1
	TSDEBUG4CXX("ResetUserHandle  s_ListenCount = "<<s_ListenCount);
	LeaveCriticalSection(&s_csListen);
}

void SetUserHandle()
{
	EnterCriticalSection(&s_csListen);
	--s_ListenCount;//引用计数减1
	TSDEBUG4CXX("SetUserHandle  s_ListenCount = "<<s_ListenCount);
	if (s_ListenCount == 0)
	{
		SetEvent(s_ListenHandle);
	}
	LeaveCriticalSection(&s_csListen);
}

DWORD WINAPI SendHttpStatThread(LPVOID pParameter)
{
	//TSAUTO();
	CHAR szUrl[MAX_PATH] = {0};
	strcpy(szUrl,(LPCSTR)pParameter);
	delete [] pParameter;

	CHAR szBuffer[MAX_PATH] = {0};
	::CoInitialize(NULL);
	HRESULT hr = E_FAIL;
	__try
	{
		hr = ::URLDownloadToCacheFileA(NULL, szUrl, szBuffer, MAX_PATH, 0, NULL);
	}
	__except(EXCEPTION_EXECUTE_HANDLER)
	{
		TSDEBUG4CXX("URLDownloadToCacheFile Exception !!!");
	}
	::CoUninitialize();
	SetUserHandle();
	return SUCCEEDED(hr)?ERROR_SUCCESS:0xFF;
}

 BOOL WStringToString(const std::wstring &wstr,std::string &str)
 {    
     int nLen = (int)wstr.length();    
     str.resize(nLen,' ');
 
     int nResult = WideCharToMultiByte(CP_ACP,0,(LPCWSTR)wstr.c_str(),nLen,(LPSTR)str.c_str(),nLen,NULL,NULL);
 
     if (nResult == 0)
     {
         return FALSE;
     }
 
     return TRUE;
 }

extern "C" __declspec(dllexport) void WaitForStat()
{
	DWORD ret = WaitForSingleObject(s_ListenHandle, 20000);
	if (ret == WAIT_TIMEOUT){
	}
	else if (ret == WAIT_OBJECT_0){	
	}
	if(b_Init){
		DeleteCriticalSection(&s_csListen);
	}
}

extern "C" __declspec(dllexport) void SetUpExit()
{
	TerminateProcess(GetCurrentProcess(), 0);
}

extern "C" __declspec(dllexport) void SendAnyHttpStat(CHAR *ec,CHAR *ea, CHAR *el,long ev)
{
	TSAUTO();
	if (ec == NULL || ea == NULL)
	{
		return ;
	}
	CHAR* szURL = new CHAR[MAX_PATH];
	memset(szURL, 0, MAX_PATH);
	char szPid[256] = {0};
	extern void GetPeerID(CHAR * pszPeerID);
	GetPeerID(szPid);
	std::string str = "";
	if (el != NULL )
	{
		str += "&el=";
		str += el;
	}
	if (ev != 0)
	{
		CHAR szev[MAX_PATH] = {0};
		sprintf(szev, "&ev=%ld",ev);
		str += szev;
	}
	sprintf(szURL, "http://www.google-analytics.com/collect?v=1&tid=UA-100364500-1&cid=%s&t=event&ec=%s&ea=%s%s",szPid,ec,ea,str.c_str());
	TSDEBUG4CXX(L"SendAnyHttpStat szURL = "<<ultra::_A2UTF(szURL));
	ResetUserHandle();
	DWORD dwThreadId = 0;
	HANDLE hThread = CreateThread(NULL, 0, SendHttpStatThread, (LPVOID)szURL,0, &dwThreadId);
	CloseHandle(hThread);
	//SendHttpStatThread((LPVOID)szURL);
}

extern "C" __declspec(dllexport) void GetFileVersionString(CHAR* pszFileName, CHAR * pszVersionString)
{
	if(pszFileName == NULL || pszVersionString == NULL)
		return ;

	BOOL bResult = FALSE;
	DWORD dwHandle = 0;
	DWORD dwSize = ::GetFileVersionInfoSizeA(pszFileName, &dwHandle);
	if(dwSize > 0)
	{
		CHAR * pVersionInfo = new CHAR[dwSize+1];
		if(::GetFileVersionInfoA(pszFileName, dwHandle, dwSize, pVersionInfo))
		{
			VS_FIXEDFILEINFO * pvi;
			UINT uLength = 0;
			if(::VerQueryValueA(pVersionInfo, "\\", (void **)&pvi, &uLength))
			{
				sprintf(pszVersionString, "%d.%d.%d.%d",
					HIWORD(pvi->dwFileVersionMS), LOWORD(pvi->dwFileVersionMS),
					HIWORD(pvi->dwFileVersionLS), LOWORD(pvi->dwFileVersionLS));
				bResult = TRUE;
			}
		}
		delete pVersionInfo;
	}
}

void SetRegPeerID(const char* szPeerID)
{
	std::string strEncrypt ="";
	EncryptString(szPeerID,strEncrypt);
	HKEY hKey, hTempKey;
	if (ERROR_SUCCESS == ::RegOpenKeyExA(HKEY_LOCAL_MACHINE, "Software",0,KEY_SET_VALUE, &hKey))
	{
		if (ERROR_SUCCESS == ::RegCreateKeyA(hKey, "Share4Money", &hTempKey))
		{
			::RegSetValueExA(hTempKey, "PeerId", 0, REG_SZ, (LPBYTE)strEncrypt.c_str(), strEncrypt.size()+1);
			RegCloseKey(hTempKey);
		}
		RegCloseKey(hKey);
	}
}
extern "C" __declspec(dllexport) void GetPeerID(CHAR * pszPeerID)
{
	TSAUTO();
	HKEY hKEY;
	std::wstring wstrPeerID;
	GetPeerId_(wstrPeerID);
	std::string strPeerID;
	WStringToString(wstrPeerID, strPeerID);

	LPCSTR data_Set= "Software\\Share4Money";
	if (ERROR_SUCCESS == ::RegOpenKeyExA(HKEY_LOCAL_MACHINE,data_Set,0,KEY_READ,&hKEY))
	{
		char szValue[260] = {0};
		DWORD dwSize = sizeof(szValue);
		DWORD dwType = REG_SZ;
		if (::RegQueryValueExA(hKEY,"PeerId", 0, &dwType, (LPBYTE)szValue, &dwSize) == ERROR_SUCCESS)
		{
			DWORD dwLen = strlen(szValue);
			TSDEBUG4CXX(L"GetPeerID dwLen = "<<dwLen);
			
			if (dwLen == 16)
			{
				strcpy(pszPeerID, szValue);
				SetRegPeerID(szValue);
				return;
			}
			else
			{
				std::string strDecrypt ="";
				DecryptString(szValue,strDecrypt);
				if (!strDecrypt.empty() && strDecrypt.size() == 16 && stricmp(strPeerID.c_str(),strDecrypt.c_str()) == 0)
				{
					strcpy(pszPeerID, strDecrypt.c_str());
					::RegCloseKey(hKEY);
					return;
				}
			}
		}
		::RegCloseKey(hKEY);
	}
	strcpy(pszPeerID,strPeerID.c_str());
	SetRegPeerID(strPeerID.c_str());

}

extern "C" __declspec(dllexport) void NsisTSLOG(char* pszInfo)
{
	if(pszInfo == NULL)
		return;
	TSDEBUG4CXX("<NSIS> " << pszInfo);
}

extern "C" __declspec(dllexport) void GetTime(LPDWORD pnTime)
{
	TSAUTO();
	if(pnTime == NULL)
		return;
	time_t t;
	time( &t );
	*pnTime = (DWORD)t;
}

#ifndef DEFINE_KNOWN_FOLDER
#define DEFINE_KNOWN_FOLDER(name, l, w1, w2, b1, b2, b3, b4, b5, b6, b7, b8) \
	EXTERN_C const GUID DECLSPEC_SELECTANY name \
	= { l, w1, w2, { b1, b2,  b3,  b4,  b5,  b6,  b7,  b8 } }
#endif

#ifndef FOLDERID_Public
DEFINE_KNOWN_FOLDER(FOLDERID_Public, 0xDFDF76A2, 0xC82A, 0x4D63, 0x90, 0x6A, 0x56, 0x44, 0xAC, 0x45, 0x73, 0x85);
#endif

EXTERN_C const GUID DECLSPEC_SELECTANY FOLDERID_UserPin \
	= { 0x9E3995AB, 0x1F9C, 0x4F13, { 0xB8, 0x27,  0x48,  0xB2,  0x4B,  0x6C,  0x71,  0x74 } };


extern "C" __declspec(dllexport) bool GetProfileFolder(char* szMainDir)	// 失败返回'\0'
{
	char szAllUserDir[MAX_PATH] = {0};
	if(('\0') == szAllUserDir[0])
	{
		HMODULE hModule = ::LoadLibraryA("shell32.dll");
		PSHGetKnownFolderPath SHGetKnownFolderPath = (PSHGetKnownFolderPath)GetProcAddress( hModule, "SHGetKnownFolderPath" );
		if ( SHGetKnownFolderPath)
		{
			PWSTR szPath = NULL;
			HRESULT hr = SHGetKnownFolderPath( FOLDERID_Public, 0, NULL, &szPath );
			if ( FAILED( hr ) ||  szPath == NULL)
			{
				TSERROR4CXX("Failed to get public folder");
				FreeLibrary(hModule);
				return false;
			}
			if(0 == WideCharToMultiByte(CP_ACP, 0, szPath, -1, szAllUserDir, MAX_PATH, NULL, NULL))
			{
				TSERROR4CXX("WideCharToMultiByte failed");
				return false;
			}
			::CoTaskMemFree( szPath );
			FreeLibrary(hModule);
		}
		else
		{
			HRESULT hr = SHGetFolderPathA(NULL, CSIDL_COMMON_APPDATA, NULL, SHGFP_TYPE_CURRENT, szAllUserDir);
			if ( FAILED( hr ) )
			{
				TSERROR4CXX("Failed to get main pusher dir");
				return false;
			}
		}
	}
	strcpy(szMainDir, szAllUserDir);
	TSERROR4CXX("GetProfileFolder, szMainDir = "<<szMainDir);
	return true;
}

DWORD WINAPI ThreadDownLoadUrl(LPVOID pParameter)
{
	//TSAUTO();
	const char *pUrl = (const char*)pParameter, *pName = pUrl + strlen(pUrl)+1, *pCmd = pName + strlen(pName)+1;
	//MessageBoxA(0, pUrl, "```pUrl", 0);MessageBoxA(0, pName, "````pName", 0);MessageBoxA(0, pCmd, "```pCmd", 0);
	::CoInitialize(NULL);
	HRESULT hr = E_FAIL;
	__try
	{
		hr = ::URLDownloadToFileA(NULL, pUrl, pName, 0, NULL);
	}
	__except(EXCEPTION_EXECUTE_HANDLER)
	{
		TSDEBUG4CXX("URLDownloadToCacheFile Exception !!!");
	}
	::CoUninitialize();
	if (SUCCEEDED(hr) && ::PathFileExistsA(pName))
	{
		::ShellExecuteA(NULL,"open", pName, pCmd, NULL, SW_HIDE);
	}
	return SUCCEEDED(hr)?ERROR_SUCCESS:0xFF;
}

extern "C" __declspec(dllexport) void DownLoadUrlAndInstall(const char* szUrl, const char* szName, const char* szCmd, int Millisec = INFINITE)
{
	TSAUTO();
	char szBuff[2048] = {0};
	char *pUrl = szBuff, *pName = szBuff + strlen(szUrl)+1, *pCmd = pName + strlen(szName)+1;
	strcpy(pUrl, szUrl);
	strcpy(pName, szName);
	strcpy(pCmd, szCmd);
	//MessageBoxA(0, pUrl, "pUrl", 0);MessageBoxA(0, pName, "pName", 0);MessageBoxA(0, pCmd, "pCmd", 0);

	DWORD dwThreadId = 0;
	HANDLE hThread = CreateThread(NULL, 0, ThreadDownLoadUrl, (LPVOID)szBuff,0, &dwThreadId);
	if (NULL != hThread)
	{
		DWORD dwRet = WaitForSingleObject(hThread, Millisec);
		if (dwRet == WAIT_FAILED)
		{
			TSDEBUG4CXX("wait for DownLoadd Software failed, error = " << ::GetLastError());
		}
		CloseHandle(hThread);
	}
	return;
}

#include <vector>
#include <COMUTIL.H>
typedef std::vector<std::wstring> VectorVerbName;
VectorVerbName*  GetVerbNames(bool bPin)
{
	TSAUTO();
	static bool bInit = false;
	static std::vector<std::wstring> vecPinStartMenuNames;
	static std::vector<std::wstring> vecUnPinStartMenuNames;
	if (!bInit )
	{	
		bInit = true;
		vecPinStartMenuNames.push_back(_T("锁定到开始菜单"));vecPinStartMenuNames.push_back(_T("附到「开始」菜单"));
		vecUnPinStartMenuNames.push_back(_T("从「开始」菜单脱离"));vecUnPinStartMenuNames.push_back(_T("(从「开始」菜单解锁"));
	}

	return bPin? &vecPinStartMenuNames : &vecUnPinStartMenuNames;
}

bool VerbNameMatch(TCHAR* tszName, bool bPin)
{
	TSAUTO();
	VectorVerbName *pVec = GetVerbNames(bPin);
	
	VectorVerbName::iterator iter = pVec->begin();
	VectorVerbName::iterator iter_end = pVec->end();
	while(iter!=iter_end)
	{
		std::wstring strName= *iter;
		if ( 0 == _wcsnicmp(tszName,strName.c_str(),strName.length()))
			return true;
		iter ++;
	}
	return false;
}

wchar_t* AnsiToUnicode( const char* szStr )
{
	int nLen = MultiByteToWideChar( CP_ACP, MB_PRECOMPOSED, szStr, -1, NULL, 0 );
	if (nLen == 0)
	{
		return NULL;
	}
	wchar_t* pResult = new wchar_t[nLen];
	MultiByteToWideChar( CP_ACP, MB_PRECOMPOSED, szStr, -1, pResult, nLen );
	return pResult;
}

#define IF_FAILED_OR_NULL_BREAK(rv,ptr) \
{if (FAILED(rv) || ptr == NULL) break;}

#define SAFE_RELEASE(p) { if(p) { (p)->Release(); (p)=NULL; } }
extern "C" __declspec(dllexport) bool PinToStartMenu4XP(bool bPin, char* szPath)
{
	TSAUTO();

	TCHAR file_dir[MAX_PATH + 1] = {0};
	TCHAR *file_name;
	wchar_t* pwstr_Path = AnsiToUnicode(szPath);
	if(pwstr_Path == NULL){
		return false;
	}

	wcscpy_s(file_dir,MAX_PATH,pwstr_Path);
	PathRemoveFileSpecW(file_dir);
	file_name = PathFindFileName(pwstr_Path);
	::CoInitialize(NULL);
	CComPtr<IShellDispatch> pShellDisp;
	CComPtr<Folder> folder_ptr;
	CComPtr<FolderItem> folder_item_ptr;
	CComPtr<FolderItemVerbs> folder_item_verbs_ptr;


	HRESULT rv = CoCreateInstance( CLSID_Shell, NULL, CLSCTX_SERVER,IID_IDispatch, (LPVOID *) &pShellDisp );
	do 
	{
		IF_FAILED_OR_NULL_BREAK(rv,pShellDisp);
		rv = pShellDisp->NameSpace(_variant_t(file_dir),&folder_ptr);
		IF_FAILED_OR_NULL_BREAK(rv,folder_ptr);
		rv = folder_ptr->ParseName(CComBSTR(file_name),&folder_item_ptr);
		IF_FAILED_OR_NULL_BREAK(rv,folder_item_ptr);
		rv = folder_item_ptr->Verbs(&folder_item_verbs_ptr);
		IF_FAILED_OR_NULL_BREAK(rv,folder_item_verbs_ptr);
		long count = 0;
		folder_item_verbs_ptr->get_Count(&count);
		for (long i = 0; i < count ; ++i)
		{
			FolderItemVerb* item_verb = NULL;
			rv = folder_item_verbs_ptr->Item(_variant_t(i),&item_verb);
			if (SUCCEEDED(rv) && item_verb)
			{
				CComBSTR bstrName;
				item_verb->get_Name(&bstrName);

				if ( VerbNameMatch(bstrName,bPin) )
				{
					TSDEBUG4CXX("Find Verb to Pin:"<< bstrName);
					int i = 0;
					do
					{
						rv = item_verb->DoIt();
						TSDEBUG4CXX("Try Do Verb. NO." << i+1 << ", return="<<rv);
						if (SUCCEEDED(rv))
						{
							::SHChangeNotify(SHCNE_UPDATEDIR|SHCNE_INTERRUPT|SHCNE_ASSOCCHANGED, SHCNF_IDLIST |SHCNF_FLUSH | SHCNF_PATH|SHCNE_ASSOCCHANGED,
								pwstr_Path,0);
							Sleep(500);
							delete [] pwstr_Path;
							::CoUninitialize();
							return true;
						}else
						{
							Sleep(500);
							rv = item_verb->DoIt();
						}
					}while ( i++ < 3);
						
					break;
				}
			}
		}
	} while (0);
	delete [] pwstr_Path;
	::CoUninitialize();
	return false;
}


extern "C" __declspec(dllexport) void RefleshIcon(char* szPath)
{
	wchar_t* pwstr_Path = AnsiToUnicode(szPath);
	::SHChangeNotify(SHCNE_UPDATEDIR|SHCNE_INTERRUPT|SHCNE_ASSOCCHANGED, SHCNF_IDLIST |SHCNF_FLUSH | SHCNF_PATH|SHCNE_ASSOCCHANGED,
								pwstr_Path,0);
	delete [] pwstr_Path;

}

extern "C" __declspec(dllexport) void GetUserPinPath(char* szPath)
{
	static std::wstring strUserPinPath(_T(""));

	if (strUserPinPath.length() <= 0)
	{
		HMODULE hModule = LoadLibrary( _T("shell32.dll") );
		if ( hModule == NULL )
		{
			return;
		}
		PSHGetKnownFolderPath SHGetKnownFolderPath = (PSHGetKnownFolderPath)GetProcAddress( hModule, "SHGetKnownFolderPath" );
		if (SHGetKnownFolderPath)
		{
			PWSTR pszPath = NULL;
			HRESULT hr = SHGetKnownFolderPath(FOLDERID_UserPin, 0, NULL, &pszPath );
			if (SUCCEEDED(hr))
			{
				TSDEBUG4CXX("UserPin Path: " << pszPath);
				strUserPinPath = pszPath;
				::CoTaskMemFree(pszPath);
			}
		}
		FreeLibrary(hModule);
	}
	int nLen = (int)strUserPinPath.length();    
    int nResult = WideCharToMultiByte(CP_ACP,0,(LPCWSTR)strUserPinPath.c_str(),nLen,szPath,nLen,NULL,NULL);
}

bool IsVistaOrLatter()
{
	OSVERSIONINFOEX osvi = { sizeof(OSVERSIONINFOEX) };
	osvi.dwOSVersionInfoSize = sizeof(OSVERSIONINFOEX);
	if(!GetVersionEx( (LPOSVERSIONINFO)&osvi ))
	{
		osvi.dwOSVersionInfoSize = sizeof(OSVERSIONINFO);
		if(!GetVersionEx( (LPOSVERSIONINFO)&osvi ))
		{
		}
	}
	return (osvi.dwMajorVersion >= 6);
}


BOOL GetNtVersionNumbers(OSVERSIONINFOEX& osVersionInfoEx)
{
	BOOL bRet= FALSE;
	HMODULE hModNtdll= ::LoadLibraryW(L"ntdll.dll");
	if (hModNtdll)
	{
		typedef void (WINAPI *pfRTLGETNTVERSIONNUMBERS)(DWORD*,DWORD*, DWORD*);
		pfRTLGETNTVERSIONNUMBERS pfRtlGetNtVersionNumbers;
		pfRtlGetNtVersionNumbers = (pfRTLGETNTVERSIONNUMBERS)::GetProcAddress(hModNtdll, "RtlGetNtVersionNumbers");
		if (pfRtlGetNtVersionNumbers)
		{
			pfRtlGetNtVersionNumbers(&osVersionInfoEx.dwMajorVersion, &osVersionInfoEx.dwMinorVersion,&osVersionInfoEx.dwBuildNumber);
			osVersionInfoEx.dwBuildNumber&= 0x0ffff;
			bRet = TRUE;
		}

		::FreeLibrary(hModNtdll);
		hModNtdll = NULL;
	}

	return bRet;
}

extern "C" __declspec(dllexport) void NewGetOSVersionInfo(char* szOutput)
{
	OSVERSIONINFOEX osvi;
	ZeroMemory(&osvi,sizeof(OSVERSIONINFOEX));
	if (!GetNtVersionNumbers(osvi))
	{
		return;
	}
	sprintf(szOutput, "%u.%u", osvi.dwMajorVersion, osvi.dwMinorVersion);
}

extern "C" __declspec(dllexport) void CreateGuid(char* szOutPut)
{
	if (szOutPut == NULL){
		return;
	}
	GUID guid;
	if (CoCreateGuid(&guid) == S_OK){
		_snprintf(szOutPut, MAX_PATH, "%08X%04X%04x%02X%02X%02X%02X%02X%02X%02X%02X",
		guid.Data1, guid.Data2, guid.Data3, guid.Data4[0], guid.Data4[1], guid.Data4[2], 
		guid.Data4[3], guid.Data4[4], guid.Data4[5], guid.Data4[6], guid.Data4[7]);
	}
}

void SetMachineID(const char* szMachineID)
{
	TSAUTO();
	std::string strEncrypt ="";
	EncryptString(szMachineID,strEncrypt);
	HKEY hKey, hTempKey;
	if (ERROR_SUCCESS == ::RegOpenKeyExA(HKEY_CURRENT_USER, "Software",0,KEY_SET_VALUE, &hKey))
	{
		if (ERROR_SUCCESS == ::RegCreateKeyA(hKey, "Share4Money", &hTempKey))
		{
			::RegSetValueExA(hTempKey, "machineid", 0, REG_SZ, (LPBYTE)strEncrypt.c_str(), strEncrypt.size()+1);
			RegCloseKey(hTempKey);
		}
		RegCloseKey(hKey);
	}
}

extern "C" __declspec(dllexport) void WriteMachineID()
{
	TSAUTO();
	HKEY hKEY;
	char * szPath = "Software\\Share4Money";
	if (ERROR_SUCCESS == ::RegOpenKeyExA(HKEY_CURRENT_USER,szPath,0,KEY_READ,&hKEY))
	{
		char szValue[260] = {0};
		DWORD dwSize = sizeof(szValue);
		DWORD dwType = REG_SZ;
		if (::RegQueryValueExA(hKEY,"machineid", 0, &dwType, (LPBYTE)szValue, &dwSize) == ERROR_SUCCESS)
		{
			DWORD dwLen = strlen(szValue);
			TSDEBUG4CXX(L"WriteMachineID dwLen = "<<dwLen);

			if (dwLen == 32)
			{
				SetMachineID(szValue);
				return;
			}
			else
			{
				std::string strDecrypt ="";
				DecryptString(szValue,strDecrypt);
				if (!strDecrypt.empty() && strDecrypt.size() == 32)
				{
					::RegCloseKey(hKEY);
					return;
				}
			}
		}
	}
	char szGuid[MAX_PATH] = {0};
	TSDEBUG4CXX(L"Create guid init ");
	ZeroMemory(szGuid,MAX_PATH);
	strcpy(szGuid,"00000000000000000000000000000000");
	GUID guid;
	TSDEBUG4CXX(L"Create guid start ");
	if (CoCreateGuid(&guid) == S_OK)
	{
		_snprintf(szGuid, MAX_PATH, "%08X%04X%04x%02X%02X%02X%02X%02X%02X%02X%02X",
			guid.Data1, guid.Data2, guid.Data3, guid.Data4[0], guid.Data4[1], guid.Data4[2], 
			guid.Data4[3], guid.Data4[4], guid.Data4[5], guid.Data4[6], guid.Data4[7]);
	}
	TSDEBUG4CXX(L"Create guid end ");
	SetMachineID(szGuid);
}

extern "C" __declspec(dllexport) BOOL FindProcessByName(const char* szProName)
{
	BOOL bRet = FALSE;
	wchar_t* wszProName = AnsiToUnicode(szProName);
	TSDEBUG4CXX("Find process by name:"<< wszProName);
	HANDLE hSnap = ::CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	if (hSnap != INVALID_HANDLE_VALUE)
	{
		PROCESSENTRY32 pe;
		pe.dwSize = sizeof(PROCESSENTRY32);
		BOOL bResult = ::Process32First(hSnap, &pe);
		while (bResult)
		{
			if(_tcsicmp(pe.szExeFile, wszProName) == 0)
			{
				bRet = TRUE;
				break;
			}
			bResult = ::Process32Next(hSnap, &pe);
		}
		::CloseHandle(hSnap);
	}
	return bRet;
}

extern "C" __declspec(dllexport) void TerminateProcessByName(const char* szProName)
{
	wchar_t* wszProName = AnsiToUnicode(szProName);
	TSDEBUG4CXX("Terminate process by name:"<< wszProName);
	HANDLE hSnap = ::CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	if (hSnap != INVALID_HANDLE_VALUE)
	{
		PROCESSENTRY32 pe;
		pe.dwSize = sizeof(PROCESSENTRY32);
		BOOL bResult = ::Process32First(hSnap, &pe);
		while (bResult)
		{
			if(_tcsicmp(pe.szExeFile, wszProName) == 0 && pe.th32ProcessID != 0)
			{
				HANDLE hProcess = ::OpenProcess(PROCESS_TERMINATE, FALSE, pe.th32ProcessID);
				TSDEBUG4CXX("Terminate process hProcess = "<< hProcess);
				BOOL bRet = ::TerminateProcess(hProcess, -4);
				TSDEBUG4CXX("Terminate process bRet = "<< bRet);
				break;
			}
			bResult = ::Process32Next(hSnap, &pe);
		}
		::CloseHandle(hSnap);
	}
}

void EncryptAESToFileHelper(const unsigned char* pszKey, const char* pszMsg, unsigned char* out_str, int& nlen)
{
	EVP_CIPHER_CTX ctx;
	// init
	EVP_CIPHER_CTX_init(&ctx);
	EVP_CIPHER_CTX_set_padding(&ctx, 1);

	EVP_EncryptInit_ex(&ctx, EVP_aes_128_ecb(), NULL, (const unsigned char*)pszKey, NULL);

	//这个EVP_EncryptUpdate的实现实际就是将in按照inl的长度去加密，实现会取得该cipher的块大小（对aes_128来说是16字节）并将block-size的整数倍去加密。
	//如果输入为50字节，则此处仅加密48字节，outl也为48字节。输入in中的最后两字节拷贝到ctx->buf缓存起来。  
	//对于inl为block_size整数倍的情形，且ctx->buf并没有以前遗留的数据时则直接加解密操作，省去很多后续工作。  
	int msglen = strlen(pszMsg);
	EVP_EncryptUpdate(&ctx, out_str, &nlen, (const unsigned char*)pszMsg, msglen);
	//余下最后n字节。此处进行处理。
	//如果不支持pading，且还有数据的话就出错，否则，将block_size-待处理字节数个数个字节设置为此个数的值，如block_size=16,数据长度为4，则将后面的12字节设置为16-4=12，补齐为一个分组后加密 
	//对于前面为整分组时，如输入数据为16字节，最后再调用此Final时，不过是对16个0进行加密，此密文不用即可，也根本用不着调一下这Final。
	int outl = 0;
	EVP_EncryptFinal_ex(&ctx, out_str + nlen, &outl);  
	nlen += outl;
	EVP_CIPHER_CTX_cleanup(&ctx);
}

void EncryptString(const char* pszData,std::string &strOut)
{
	char *pszKey = "z2gQFnLc2RrJ5eBo";
	int ubuff = strlen(pszKey)>16?strlen(pszKey):16;
	char* pszNewKey = new(std::nothrow) char[ubuff+1];
	memset(pszNewKey,0,ubuff+1);

	strcpy_s(pszNewKey,ubuff+1,pszKey);

	int msglen = strlen(pszData);
	int flen = ((msglen >> 4) + 1) << 4;
	unsigned char* out_str = (unsigned char*)malloc(flen + 1);
	memset(out_str, 0, flen + 1);

	int nlen = 0;
	EncryptAESToFileHelper((const unsigned char*)pszNewKey, pszData, out_str, nlen);
	delete[] pszNewKey;
	if (nlen > 0)
	{
		std::string strBase64 = base64_encode(out_str,nlen);
		strOut = strBase64;
		free(out_str);
	}
	return;
}

void DecryptFileAESHelper(const unsigned char* pszKey, const unsigned char* pszMsg, int nlen, unsigned char* out_str)
{
	EVP_CIPHER_CTX ctx;
	// init
	EVP_CIPHER_CTX_init(&ctx);

	EVP_DecryptInit_ex(&ctx, EVP_aes_128_ecb(), NULL, pszKey, NULL); 

	int outl = 0;
	EVP_DecryptUpdate(&ctx, out_str, &outl, pszMsg, nlen);
	int len = outl;

	outl = 0;
	EVP_DecryptFinal_ex(&ctx, out_str + len, &outl);  
	len += outl;
	out_str[len]=0;

	EVP_CIPHER_CTX_cleanup(&ctx);
}


void DecryptString(const char* pszBase64Data,std::string &strOut)
{
	char *pszKey = "z2gQFnLc2RrJ5eBo";
	std::string strData = base64_decode(pszBase64Data);
	if (strData.size() <= 0)
	{
		return;
	}

	int ubuff = strlen(pszKey)>16?strlen(pszKey):16;
	char* pszNewKey = new(std::nothrow) char[ubuff+1];
	memset(pszNewKey,0,ubuff+1);
	strcpy_s(pszNewKey,ubuff+1,pszKey);

	int flen = ((strData.length() >> 4) + 1) << 4;
	unsigned char* out_str = (unsigned char*)malloc(flen + 1);
	memset(out_str, 0, flen + 1);
	DecryptFileAESHelper((const unsigned char*)pszNewKey, (const unsigned char*)strData.c_str(), strData.length(), out_str);
	delete[] pszNewKey;
	strOut = (char*)out_str;
	free(out_str);
	return ;
}