#include "stdafx.h"
#include "CheckAutoRun.h"
#include "regtool.h"
#include "Utility.h"
#include "stat.h"

bool CheckAutoRun::IsSysAutoRunExist()
{
	TSAUTO();
	RegImpersonateUser ru;
	std::wstring strRet = L"";
	if (ru.GetUserProfileRegKey()){
		ru.QueryUserRegValue(L"Software\\Microsoft\\Windows\\CurrentVersion\\Run", L"Share4Money", &strRet);
	}
	TSWARN4CXX(L"strRet =  " << strRet.c_str());
	return strRet != L"";
}

bool CheckAutoRun::IsSoftwareAutoRunExist()
{
	TSAUTO();
	RegImpersonateUser ru;
	DWORD  dwRet = 0;
	if (ru.GetUserProfileRegKey()){
		TSWARN4CXX(L"GetToken ok");
		ru.QueryUserRegValue( L"SOFTWARE\\Share4Money", L"LastSetBootTime", &dwRet);
		TSWARN4CXX(L"dwRet =  " << dwRet);
	}
	return dwRet > 0;
}


bool CheckAutoRun::IsRealRebootSystem()
{
	TSAUTO();
	return GetTickCount() < 10*86400*1000;
}

bool CheckAutoRun::ShouldFixAutoRun()
{
	return !IsSysAutoRunExist() && IsSoftwareAutoRunExist() && IsRealRebootSystem();
}

void CheckAutoRun::FixAutoRun()
{
	wchar_t exeFilePath[MAX_PATH];
	// buffer 长度为MAX_PATH * 2 但这里只传MAX_PATH
	if(!GetShare4MoneyExeFilePath(&exeFilePath[0], MAX_PATH)) {
		TSERROR4CXX("Failed to get ExeFilePath");
		return;
	}
	wchar_t szCmdLine[MAX_PATH] = {0};
	swprintf(szCmdLine, L"\"%s\" /sstartfrom sysboot /embedding /working", exeFilePath);
	TSINFO4CXX(L"szCmdLine = " << szCmdLine);
	RegImpersonateUser ru;
	if (ru.GetUserProfileRegKey()){
		ru.SetUserRegValue(HKEY_CURRENT_USER, L"Software\\Microsoft\\Windows\\CurrentVersion\\Run", L"Share4Money", szCmdLine);
		svcstat::Instance()->SendStat(L"fixrun");
	}
	return;
}