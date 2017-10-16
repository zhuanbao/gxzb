#include "StdAfx.h"
#include "ClientZcashN.h"
#include "ClientMsgDefine.h"
#include <Tlhelp32.h>
#include "..\Utility\StringOperation.h"
#include "boost/regex.hpp"
#include <boost/algorithm/string.hpp>
#include "../EvenListenHelper/LuaMsgWnd.h"

#define LOGCFG_PATH _T("C:\\GXZB_CONFIG\\Share4Peer.ini")
#define CLIENT_ZCASHN_NAME _T("Share4PeerZN.exe")

CClientZcashN::CClientZcashN(void)
{
	m_hMsgWnd = FindWindow(LUA_MSG_WND_CALSS, NULL);
	m_strLastLeft = "";
}

CClientZcashN::~CClientZcashN(void)
{

}

bool CClientZcashN::IsDebug()
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

void CClientZcashN::TerminateAllClientInstance()
{
	HANDLE hSnap = ::CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	if (hSnap != INVALID_HANDLE_VALUE)
	{
		PROCESSENTRY32 pe;
		pe.dwSize = sizeof(PROCESSENTRY32);
		BOOL bResult = ::Process32First(hSnap, &pe);
		while (bResult)
		{
			if(_tcsicmp(pe.szExeFile, CLIENT_ZCASHN_NAME) == 0 && pe.th32ProcessID != 0)
			{
				HANDLE hProcess = ::OpenProcess(PROCESS_TERMINATE, FALSE, pe.th32ProcessID);
				::TerminateProcess(hProcess, 99);
			}
			bResult = ::Process32Next(hSnap, &pe);
		}
		::CloseHandle(hSnap);
	}
}

void CClientZcashN::LogString(const char *szBuffer)
{
	if (IsDebug())
	{
		std::wstring wstrInfo = ultra::_A2T(szBuffer);
		TSDEBUG4CXX(L"<Client ZN> Output: " <<wstrInfo.c_str());
	}
}

void CClientZcashN::PostWndMsg(WPARAM wParam, LPARAM lParam)
{
	PostMessageA(m_hMsgWnd, WM_ZCASH_N_MSG, wParam, lParam);
}

void CClientZcashN::OnAutoExit(DWORD dwExitCode)
{
	PostWndMsg(WP_ZCASH_N_AUTOEXIT, dwExitCode);
}

void CClientZcashN::RetSet()
{
	TSDEBUG4CXX(L"RetSet ZcashN client Param");
	m_strLastLeft = "";
}


void CClientZcashN::ProcessString(const char *szBuffer)
{
	
	//LogString(szBuffer);
	RegexString(szBuffer);
}

void CClientZcashN::RegexString(const char *szBuffer)
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
	//Temp: GPU0: 78C GPU1: 111C
	exp.assign("GPU([0-9])+: ([0-9]+)C", boost::regex::icase);
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
				PostWndMsg(WP_ZCASH_N_GPUTEMP, lGPUTempInfo);
				TSDEBUG4CXX(L"[RegexString]: GPU"<<iGPUID<<L" "<<iGPUTemp<<L"C");
			}
		}
		start = what[0].second; 
	} 

	//提交share成功
	//成功 示例："INFO 17:53:52: GPU0 Accepted share 72571ms [A:2, R:1]"
	//失败 示例："INFO 17:53:52: GPU0 Rejected share 1703ms [A:2, R:1]"
	exp.assign(".*: GPU[0-9]+ Accepted share [0-9]+ms.*", boost::regex::icase);
	if (boost::regex_match(strBuffer,exp))
	{
		PostWndMsg(WP_ZCASH_N_SHARE, 0);
		TSDEBUG4CXX(L"[RegexString]: " << L"Accepted share");
	}
	exp.assign(".*: GPU[0-9]+ Rejected share [0-9]+ms.*", boost::regex::icase);
	if (boost::regex_match(strBuffer,exp))
	{
		PostWndMsg(WP_ZCASH_N_SHARE, 1);
		TSDEBUG4CXX(L"[RegexString]: " << L"Rejected share");
	}
	//当前算力
	//示例："Total speed: 0 Sol/s"
	exp.assign("Total speed: ([0-9\\.]+) Sol/s", boost::regex::icase);
	INT iCurrentSpeed = -1;
	while(boost::regex_search(start,end,what,exp))
	{
		if (what.size() == 2)
		{
			if (what[1].matched)
			{
				std::string strSpeed = what[1];
				float fNewSpeed = 0.00f;
				{
					std::stringstream ssNewSpeed;
					ssNewSpeed << strSpeed;
					ssNewSpeed >> fNewSpeed;
				}
				int iNewSpeed = ( int )( fNewSpeed * 100 + 0.5 );
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
		PostWndMsg(WP_ZCASH_N_SPEED, iCurrentSpeed);
		TSDEBUG4CXX(L"[RegexString]: " << L"uCurrentSpeed = "<< iCurrentSpeed);
		return;
	}
	
	//重要信息优先处理

	//连接矿次成功
	//1:"INFO: Detected new work" 
	if (boost::icontains(strBuffer,"INFO: Detected new work"))
	{
		PostWndMsg(WP_ZCASH_N_CONNECT_POOL, 0);
		TSDEBUG4CXX(L"[RegexString]: " << L"Detected new work so connect server success");
	}
	//处理错误：

	//发生错误程序自动退出

	//没找到英伟达的相关dll：ERROR: Cannot load nvml.
	if (boost::icontains(strBuffer,"ERROR: Cannot load nvml."))
	{
		PostWndMsg(WP_ZCASH_N_ERROR_INFO, 1);
		PostErrorMsg(strBuffer.c_str(),"error: cannot load nvml");
		TSDEBUG4CXX(L"[RegexString]: " << L"Cannot load nvml");
	}
	else if (boost::icontains(strBuffer,"ERROR: No properly configured pool!"))
	{
		PostWndMsg(WP_ZCASH_N_ERROR_INFO, 2);
		PostErrorMsg(strBuffer.c_str(),"error: no properly configured pool!");
		TSDEBUG4CXX(L"[RegexString]: " << L"Invalid argument");
	}
	else if (boost::icontains(strBuffer,"ERROR: Cannot resolve hostname"))
	{	
		//PostWndMsg(WP_ZCASH_N_ERROR_INFO, 3);
		PostWndMsg(WP_ZCASH_N_CONNECT_POOL, 1);
		PostErrorMsg(strBuffer.c_str(),"error: cannot resolve hostname");
		TSDEBUG4CXX(L"[RegexString]: " << L"Cannot resolve hostname");
	}
	else if(boost::icontains(strBuffer,"ERROR: Cannot connect to the pool"))
	{
		PostWndMsg(WP_ZCASH_N_CONNECT_POOL, 2);
		PostErrorMsg(strBuffer.c_str(),"error: cannot connect to the pool");
		TSDEBUG4CXX(L"[RegexString]: " << L"Cannot connect to the pool");
	}
	else if(boost::icontains(strBuffer,"Error: CUDA driver version is insufficient for CUDA runtime version"))
	{
		PostWndMsg(WP_ZCASH_N_ERROR_INFO, 3);
		PostErrorMsg(strBuffer.c_str(),"error: cuda driver version is insufficient");
		TSDEBUG4CXX(L"[RegexString]: " << L"No GPU device with sufficient memory was found");
	}
	else if(boost::icontains(strBuffer,"Error:"))
	{
		PostWndMsg(WP_ZCASH_N_ERROR_INFO, 99);
		PostErrorMsg(strBuffer.c_str(),"error");
		TSDEBUG4CXX(L"[RegexString]: " << L"No GPU device with sufficient memory was found");
	}
	//发生错误但是进程继续运行
	

}


void CClientZcashN::PostErrorMsg(const char *szBuffer, const char *szBeg)
{
	std::string strInfo = ultra::ToLower(ultra::Trim(std::string(szBuffer)));
	std::string strSep = "\r\n";
	size_t nBegPos = strInfo.find(szBeg);
	if (nBegPos == std::string::npos)
	{
		nBegPos = 0;
	} 
	size_t nEndPos = strInfo.find("\r\n");
	if (nEndPos == std::string::npos)
	{
		nEndPos = strInfo.find("\r");
		if (nEndPos == std::string::npos)
		{
			nEndPos = strInfo.find("\n");
		}
	} 
	strInfo = strInfo.substr(nBegPos,nEndPos);
	if (strInfo.length()>MAX_ERROR_LEN-1)
	{
		strInfo = strInfo.substr(0,MAX_ERROR_LEN-1);
	}
	char * pInfo = new char[MAX_ERROR_LEN];
	strcpy_s(pInfo,MAX_ERROR_LEN,strInfo.c_str());
	PostMessage(m_hMsgWnd, WM_ERROR_INFO, 2, (LPARAM)pInfo);
}