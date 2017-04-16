#pragma once

namespace Utility{
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
	};

	BOOL IsWin10(){
		OSVERSIONINFOEX osvi;
		ZeroMemory(&osvi,sizeof(OSVERSIONINFOEX));
		wchar_t szVer[100] = {0};
		if (!GetNtVersionNumbers(osvi)){
			return FALSE;
		}
		return osvi.dwMajorVersion >= 10;
	};

	BOOL IsVistaOrHigher(){
		OSVERSIONINFOEX osvi;
		ZeroMemory(&osvi,sizeof(OSVERSIONINFOEX));
		wchar_t szVer[100] = {0};
		if (!GetNtVersionNumbers(osvi)){
			return FALSE;
		}
		return osvi.dwMajorVersion >= 6;
	}
};