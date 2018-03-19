#pragma once
#include <atlbase.h>
#include <Userenv.h>
#include <Wtsapi32.h>
#pragma comment(lib, "Userenv.lib")
#pragma comment(lib, "WtsApi32.lib")

class RegTool{
public:
	RegTool(){};
	~RegTool(){m_key.Close();};
	ATL::CRegKey * operator->(){
		return &m_key;
	};
	typedef BOOL (WINAPI *LPFN_ISWOW64PROCESS) (HANDLE, PBOOL);
	BOOL IsWow64(){
		BOOL bIsWow64 = FALSE;
		LPFN_ISWOW64PROCESS fnIsWow64Process = (LPFN_ISWOW64PROCESS)GetProcAddress(
			GetModuleHandle(TEXT("kernel32")),"IsWow64Process");
		if (NULL != fnIsWow64Process){
			if (!fnIsWow64Process(GetCurrentProcess(),&bIsWow64)){
			}
		}
		return bIsWow64;
	}

	void QueryRegValue(HKEY root,const wchar_t* szRegPath,const wchar_t* szKey, std::wstring* pRet, REGSAM flag = KEY_READ){
		HRESULT hr;
		if ((hr = m_key.Open(root, szRegPath, flag)) == ERROR_SUCCESS) {
			TCHAR tszValue[MAX_PATH] = {0};
			ULONG lLen = MAX_PATH;
			if (m_key.QueryStringValue(szKey, tszValue, &lLen) == ERROR_SUCCESS){
				std::wstring *pstr = (std::wstring*)pRet;
				*pstr = tszValue;
			}
		}
	}

	void QueryRegValue(HKEY root,const wchar_t* szRegPath,const wchar_t* szKey, DWORD* pRet, REGSAM flag = KEY_READ){
		HRESULT hr;
		if ((hr = m_key.Open(root, szRegPath, flag)) == ERROR_SUCCESS) {
			DWORD dwInfo;
			if((m_key.QueryDWORDValue(szKey, dwInfo) == ERROR_SUCCESS)){
				DWORD *pdwInfo = (DWORD*)pRet;
				*pdwInfo = dwInfo;
			}
		}
	}

	BOOL DeleteRegKey(HKEY root, const wchar_t* szRegPath, const wchar_t* szKey, REGSAM flag = KEY_ALL_ACCESS){
		BOOL bRet = FALSE;
		if (m_key.Open(root, szRegPath, flag) == ERROR_SUCCESS) {
			bRet = ((m_key.RecurseDeleteKey(szKey) != ERROR_SUCCESS) ? (m_key.DeleteSubKey(szKey) == ERROR_SUCCESS) : TRUE);
		}
		return bRet;
	}

	BOOL DeleteRegValue(HKEY root, const wchar_t* szRegPath, const wchar_t* szValue, REGSAM flag = KEY_ALL_ACCESS){
		BOOL bRet = FALSE;
		if (m_key.Open(root, szRegPath, flag) == ERROR_SUCCESS) {
			bRet = m_key.DeleteValue(szValue) == ERROR_SUCCESS;
		}
		return bRet;
	}

	void SetRegValue(HKEY hk, const wchar_t* szRegPath, const wchar_t* szKey, const wchar_t* value, BOOL bWow64 = FALSE){
		REGSAM samDesired = bWow64?(KEY_WOW64_64KEY|KEY_ALL_ACCESS):KEY_ALL_ACCESS;
		HRESULT hr = m_key.Open(hk, szRegPath,samDesired);
		if (hr != ERROR_SUCCESS) {
			hr = m_key.Create(hk,szRegPath, 0, 0, samDesired);
		}
		if (hr != ERROR_SUCCESS) 
			return;
		m_key.SetStringValue(szKey, value);
	}

	void SetRegValue(HKEY hk, const wchar_t* szRegPath, const wchar_t* szKey, const DWORD value, BOOL bWow64 = FALSE){
		REGSAM samDesired = bWow64?(KEY_WOW64_64KEY|KEY_ALL_ACCESS):KEY_ALL_ACCESS;
		HRESULT hr = m_key.Open(hk, szRegPath,samDesired);
		if (hr != ERROR_SUCCESS) {
			hr = m_key.Create(hk,szRegPath, 0, 0, samDesired);
		}
		if (hr != ERROR_SUCCESS) 
			return;
		m_key.SetDWORDValue(szKey, value);
	}
private:
	ATL::CRegKey m_key;
};

template <class Res, class Deletor>
class ScopeResourceHandle {
	Res res_;
	Deletor deletor_;
	ScopeResourceHandle(const ScopeResourceHandle<Res, Deletor>&) {};
	const ScopeResourceHandle& operator=(const ScopeResourceHandle<Res, Deletor>&) { return *this; }
public:
	ScopeResourceHandle(Res res, Deletor deletor) : res_(res){
		this->deletor_ = deletor;
	}
	~ScopeResourceHandle() {
		this->deletor_(this->res_);
	}
	Res get() {
		return this->res_;
	}
};

class RegImpersonateUser : public RegTool {
public:
	RegImpersonateUser(){
		ZeroMemory(&m_pfi, sizeof(PROFILEINFO));
	};
	virtual ~RegImpersonateUser(){
		if (m_pfi.hProfile){
			::UnloadUserProfile(m_hDuplicateToken, m_pfi.hProfile);
			//::RegCloseKey(m_hRoot);
		}
		if (m_hDuplicateToken)
		{
			CloseHandle(m_hDuplicateToken);
			m_hDuplicateToken = NULL;
		}
	};
private:
	PROFILEINFO m_pfi;
	HANDLE m_hDuplicateToken;
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
public:
	BOOL GetUserProfileRegKey(){
		if (!IsVistaOrLatter())
		{
			return TRUE;
		}
		DWORD dwActiveSessionId = ::WTSGetActiveConsoleSessionId();
		TCHAR szActiveUserName[MAX_PATH] = {0};
		LPTSTR pszUserName = NULL;
		DWORD cbUserName = 0;
		if (!::WTSQuerySessionInformation(0, dwActiveSessionId, WTSUserName, &pszUserName, &cbUserName))
		{
			TSERROR4CXX("WTSQuerySessionInformation fail. Error: " << ::GetLastError());
			return FALSE;
		}
		::memcpy(szActiveUserName, pszUserName, cbUserName);
		::WTSFreeMemory(pszUserName);

		HANDLE hUserToken = NULL;
		if(!::WTSQueryUserToken(dwActiveSessionId, &hUserToken)) {
			TSERROR4CXX("WTSQueryUserToken fail. Error: " << ::GetLastError());
			return FALSE;
		}
		TSINFO4CXX("dwActiveSessionId =  " << dwActiveSessionId);
		ScopeResourceHandle<HANDLE, BOOL (WINAPI*)(HANDLE)> autoCloseUserToken(hUserToken, ::CloseHandle);

		TOKEN_ELEVATION_TYPE tokenElevationType;
		DWORD dwSize = sizeof(TOKEN_ELEVATION_TYPE);
		if(!::GetTokenInformation(hUserToken, TokenElevationType, &tokenElevationType, dwSize, &dwSize)) {
			TSERROR4CXX("GetTokenInformation TokenElevationType fail." << ::GetLastError());
			return FALSE;
		}
		if(tokenElevationType == TokenElevationTypeLimited) {
			TOKEN_LINKED_TOKEN linkedToken; 
			dwSize = sizeof(TOKEN_LINKED_TOKEN);
			if (!::GetTokenInformation(hUserToken, TokenLinkedToken, &linkedToken, dwSize, &dwSize)) {
				TSERROR4CXX("GetTokenInformation TokenLinkedToken fail. Error: " << ::GetLastError());
				return FALSE;
			}

			ScopeResourceHandle<HANDLE, BOOL (WINAPI*)(HANDLE)> autoCloseLinkedToken(linkedToken.LinkedToken, ::CloseHandle);

			if(!::DuplicateTokenEx(linkedToken.LinkedToken, MAXIMUM_ALLOWED, NULL,  SecurityImpersonation, TokenPrimary, &m_hDuplicateToken)) {
				TSERROR4CXX("DuplicateTokenEx fail. Error: " << ::GetLastError());
				return FALSE;
			}
		}
		else {
			if(!::DuplicateTokenEx(hUserToken, MAXIMUM_ALLOWED, NULL,  SecurityImpersonation, TokenPrimary, &m_hDuplicateToken)) {
				TSERROR4CXX("DuplicateTokenEx fail. Error: " << ::GetLastError());
				return FALSE;
			}
		}
		m_pfi.dwSize = sizeof(PROFILEINFO);
		m_pfi.lpUserName = szActiveUserName;
		TSINFO4CXX("szActiveUserName = " << szActiveUserName);
		if (::LoadUserProfile(m_hDuplicateToken, &m_pfi))
		{
			return TRUE;
		}
		else
		{
			TSERROR4CXX("LoadUserProfile fail. Error: " << ::GetLastError());
		}
		return FALSE;
	};

	void QueryUserRegValue(const wchar_t* szRegPath,const wchar_t* szKey, std::wstring* pRet, REGSAM flag = KEY_READ){
		if (m_pfi.hProfile)
		{
			QueryRegValue((HKEY)m_pfi.hProfile, szRegPath, szKey, pRet,flag);
		} 
		else
		{
			QueryRegValue(HKEY_CURRENT_USER, szRegPath, szKey, pRet,flag);
		}
	}

	void QueryUserRegValue(const wchar_t* szRegPath,const wchar_t* szKey, DWORD* pRet, REGSAM flag = KEY_READ){
		if (m_pfi.hProfile)
		{
			QueryRegValue((HKEY)m_pfi.hProfile, szRegPath, szKey, pRet,flag);
		} 
		else
		{
			QueryRegValue(HKEY_CURRENT_USER, szRegPath, szKey, pRet,flag);
		}
	}

	BOOL DeleteUserRegKey(const wchar_t* szRegPath, const wchar_t* szKey, REGSAM flag = KEY_ALL_ACCESS){
		if (m_pfi.hProfile)
		{
			return DeleteRegKey((HKEY)m_pfi.hProfile, szRegPath, szKey, flag);
		} 
		else
		{
			return DeleteRegKey(HKEY_CURRENT_USER, szRegPath, szKey, flag);
		}
	}

	BOOL DeleteUserRegValue(HKEY root, const wchar_t* szRegPath, const wchar_t* szValue, REGSAM flag = KEY_ALL_ACCESS){
		if (m_pfi.hProfile)
		{
			return DeleteRegValue((HKEY)m_pfi.hProfile, szRegPath, szValue, flag);
		} 
		else
		{
			return DeleteRegValue(HKEY_CURRENT_USER, szRegPath, szValue, flag);
		}
	}

	void SetUserRegValue(HKEY hk, const wchar_t* szRegPath, const wchar_t* szKey, const wchar_t* value, BOOL bWow64 = FALSE){
		if (m_pfi.hProfile)
		{
			return SetRegValue((HKEY)m_pfi.hProfile, szRegPath, szKey, value, bWow64);
		} 
		else
		{
			return SetRegValue(HKEY_CURRENT_USER, szRegPath, szKey, value, bWow64);
		}
	}

	void SetUserRegValue(HKEY hk, const wchar_t* szRegPath, const wchar_t* szKey, const DWORD value, BOOL bWow64 = FALSE){
		if (m_pfi.hProfile)
		{
			return SetRegValue((HKEY)m_pfi.hProfile, szRegPath, szKey, value, bWow64);
		} 
		else
		{
			return SetRegValue(HKEY_CURRENT_USER, szRegPath, szKey, value, bWow64);
		}
	}
};