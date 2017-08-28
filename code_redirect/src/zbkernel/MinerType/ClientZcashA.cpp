#include "StdAfx.h"
#include "ClientZcashA.h"
#include "ClientMsgDefine.h"
#include <Tlhelp32.h>
#include "..\Utility\StringOperation.h"
#include "boost/regex.hpp"
#include <boost/algorithm/string.hpp>
#include "../EvenListenHelper/LuaMsgWnd.h"

#define LOGCFG_PATH _T("C:\\GXZB_CONFIG\\Share4Peer.ini")
#define CLIENT_ZCASHA_NAME _T("Share4PeerZA.exe")

CClientZcashA::CClientZcashA(void)
{
	m_hMsgWnd = FindWindow(LUA_MSG_WND_CALSS, NULL);
	m_strLastLeft = "";
}

CClientZcashA::~CClientZcashA(void)
{

}

bool CClientZcashA::IsDebug()
{
#if defined _DEBUG
	return true;
#else
	if (::PathFileExists(LOGCFG_PATH))
	{
		return true;
	}
	return false;
#endif
}

void CClientZcashA::TerminateAllClientInstance()
{
	HANDLE hSnap = ::CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	if (hSnap != INVALID_HANDLE_VALUE)
	{
		PROCESSENTRY32 pe;
		pe.dwSize = sizeof(PROCESSENTRY32);
		BOOL bResult = ::Process32First(hSnap, &pe);
		while (bResult)
		{
			if(_tcsicmp(pe.szExeFile, CLIENT_ZCASHA_NAME) == 0 && pe.th32ProcessID != 0)
			{
				HANDLE hProcess = ::OpenProcess(PROCESS_TERMINATE, FALSE, pe.th32ProcessID);
				::TerminateProcess(hProcess, 99);
			}
			bResult = ::Process32Next(hSnap, &pe);
		}
		::CloseHandle(hSnap);
	}
}

void CClientZcashA::LogString(const char *szBuffer)
{
	if (IsDebug())
	{
		std::wstring wstrInfo = ultra::_A2T(szBuffer);
		TSDEBUG4CXX(L"<Client ZA> Output: " <<wstrInfo.c_str());
	}
}

void CClientZcashA::PostWndMsg(WPARAM wParam, LPARAM lParam)
{
	PostMessageA(m_hMsgWnd, WM_ZCASH_A_MSG, wParam, lParam);
}

void CClientZcashA::OnAutoExit(DWORD dwExitCode)
{
	PostWndMsg(WP_ZCASH_A_AUTOEXIT, dwExitCode);
}

void CClientZcashA::RetSet()
{
	TSDEBUG4CXX(L"RetSet ZcashA client Param");
	m_strLastLeft = "";
}


void CClientZcashA::ProcessString(const char *szBuffer)
{

	//LogString(szBuffer);
	RegexString(szBuffer);
}

void CClientZcashA::RegexString(const char *szBuffer)
{
	std::string strBuffer = m_strLastLeft;
	strBuffer.append(szBuffer);
	LogString(strBuffer.c_str());
	std::string::const_iterator start = strBuffer.begin();
	std::string::const_iterator end = strBuffer.end();
	boost::regex exp("",boost::regex::icase);
	boost::smatch what;
	do 
	{
		m_strLastLeft = "";
		if (boost::iends_with(strBuffer.c_str(),"\r\n"))
		{
			break;
		}
		exp.assign(".*\\r\\n(.*)", boost::regex::icase);
		if(!boost::regex_search(start,end,what,exp))
		{
			break;
		} 
		if (what.size() == 2 && what[1].matched )
		{
			m_strLastLeft = what[1];
			std::wstring wstrInfo = ultra::_A2T(m_strLastLeft);
			TSDEBUG4CXX(L"[RegexString]: m_strLastLeft = " << wstrInfo.c_str());

		}
	} while (FALSE);

	//GPU温度
	//GPU0 t=0C fan=0%
	exp.assign("GPU([0-9])+ t=([0-9]+)C", boost::regex::icase);
	while(boost::regex_search(start,end,what,exp))
	{
		if (what.size() == 3)
		{
			if (what[1].matched && what[2].matched)
			{
				int iGPUID = 0, iGPUTemp = 0;

				std::string strGPUID = what[1];
				std::string strGPUTemp = what[2];
				{
					std::stringstream ssID;
					ssID << strGPUID;
					ssID >> iGPUID;
				}
				{
					std::stringstream ssTemp;
					ssTemp << strGPUTemp;
					ssTemp >> iGPUTemp;
				}
				LONG lGPUTempInfo = MAKELONG(iGPUTemp,iGPUID);
				PostWndMsg(WP_ZCASH_A_GPUTEMP, lGPUTempInfo);
				TSDEBUG4CXX(L"[RegexString]: GPU"<<iGPUID<<L" "<<iGPUTemp<<L"C");
			}
		}
		start = what[0].second; 
	} 

	//提交share成功
	//成功 示例："ZEC: Share accepted (234 ms)!"
	exp.assign("ZEC: Share accepted ([0-9]+ ms)", boost::regex::icase);
	if (boost::regex_match(strBuffer,exp))
	{
		PostWndMsg(WP_ZCASH_A_SHARE, 0);
		TSDEBUG4CXX(L"[RegexString]: " << L"Accepted share");
	}
	//当前算力
	//示例："ZEC - Total Speed: 291.896 H/s, Total Shares: 1, Rejected: 0, Time: 00:00"
	exp.assign("Total Speed: ([0-9\\.]+) H/s", boost::regex::icase);
	INT iCurrentSpeed = -1;
	while(boost::regex_search(start,end,what,exp))
	{
		if (what.size() == 2)
		{
			if (what[1].matched)
			{
				std::string strSpeed = what[1];
				float fNewSpeed = 0.000f;
				{
					std::stringstream ssNewSpeed;
					ssNewSpeed << strSpeed;
					ssNewSpeed >> fNewSpeed;
				}
				int iNewSpeed = ( int )( fNewSpeed * 1000 + 0.5 );
				if (iNewSpeed > iCurrentSpeed)
				{
					iCurrentSpeed = iNewSpeed;
				}

			}
		}
		start = what[0].second; 
	} 
	if (iCurrentSpeed >= 0)
	{
		PostWndMsg(WP_ZCASH_A_SPEED, iCurrentSpeed);
		TSDEBUG4CXX(L"[RegexString]: " << L"uCurrentSpeed = "<< iCurrentSpeed);
		return;
	}

	//重要信息优先处理

	//连接矿次成功
	//1:"ZEC: Stratum - Connected" 
	//2:"ZEC: 08/25/17-09:57:15 - New job from"
	if (boost::icontains(strBuffer,"ZEC: Stratum - Connected") || boost::icontains(strBuffer,"- New job from"))
	{
		PostWndMsg(WP_ZCASH_A_CONNECT_POOL, 0);
		TSDEBUG4CXX(L"[RegexString]: " << L"Connect server success");
	}
	//处理错误：

	//发生错误程序自动退出

	//没找到AMD显卡或者opencl支持：AMD OpenCL platform not found
	//	                           No AMD OPENCLGPUs found, exit
	if (boost::icontains(strBuffer,"AMD OpenCL platform not found") || boost::icontains(strBuffer,"No AMD OPENCLGPUs found, exit"))
	{
		PostWndMsg(WP_ZCASH_A_ERROR_INFO, 1);
		TSDEBUG4CXX(L"[RegexString]: " << L"Cannot find AMD Gpu");
	}
	else if (boost::icontains(strBuffer,"ZEC: No pools specified"))
	{
		PostWndMsg(WP_ZCASH_A_ERROR_INFO, 2);
		TSDEBUG4CXX(L"[RegexString]: " << L"Invalid argument");
	}
	else if (boost::icontains(strBuffer,"ZEC: Stratum - Cannot connect to"))
	{	
		PostWndMsg(WP_ZCASH_A_CONNECT_POOL, 1);
		TSDEBUG4CXX(L"[RegexString]: " << L"Cannot connect pool");
	}
	else if(boost::icontains(strBuffer,"Cannot resolve"))
	{
		PostWndMsg(WP_ZCASH_A_CONNECT_POOL, 2);
		TSDEBUG4CXX(L"[RegexString]: " << L"Cannot resolve");
	}
	else if(boost::icontains(strBuffer,"Error:"))
	{
		PostWndMsg(WP_ZCASH_A_ERROR_INFO, 99);
		TSDEBUG4CXX(L"[RegexString]: " << L"Some error Info");
	}
	//发生错误但是进程继续运行


}