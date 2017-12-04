#include "StdAfx.h"
#include "ClientXmr.h"
#include "ClientMsgDefine.h"
#include <Tlhelp32.h>
#include "..\Utility\StringOperation.h"
#include "boost/regex.hpp"
#include <boost/algorithm/string.hpp>
#include "../EvenListenHelper/LuaMsgWnd.h"

#define LOGCFG_PATH _T("C:\\GXZB_CONFIG\\Share4Peer.ini")

TCHAR *tszXmrName[] = {_T("Share4PeerXA.exe"), _T("Share4PeerXA64.exe"), _T("Share4PeerXN64.exe"), _T("Share4PeerXC.exe")};

CClientXmr::CClientXmr(UINT uMinerType)
{
	m_hMsgWnd = FindWindow(LUA_MSG_WND_CALSS, NULL);
	m_strLastLeft = "";
	m_uMinerType = uMinerType;
}

CClientXmr::~CClientXmr(void)
{

}

bool CClientXmr::IsDebug()
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

void CClientXmr::TerminateAllClientInstance()
{
	HANDLE hSnap = ::CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	if (hSnap != INVALID_HANDLE_VALUE)
	{
		PROCESSENTRY32 pe;
		pe.dwSize = sizeof(PROCESSENTRY32);
		BOOL bResult = ::Process32First(hSnap, &pe);
		while (bResult)
		{
			for (int i = 0; i < ARRAYSIZE(tszXmrName); i++)
			{
				if(_tcsicmp(pe.szExeFile, tszXmrName[i]) == 0 && pe.th32ProcessID != 0)
				{
					HANDLE hProcess = ::OpenProcess(PROCESS_TERMINATE, FALSE, pe.th32ProcessID);
					::TerminateProcess(hProcess, 99);
				}
			}
			bResult = ::Process32Next(hSnap, &pe);
		}
		::CloseHandle(hSnap);
	}
}

void CClientXmr::LogString(const char *szBuffer)
{
	if (IsDebug())
	{
		std::wstring wstrInfo = ultra::_A2T(szBuffer);
		TSDEBUG(_T("<Client  X(%u)>  Output: %s"), m_uMinerType,wstrInfo.c_str());
	}
}

void CClientXmr::PostWndMsg(WPARAM wParam, LPARAM lParam)
{
	PostMessageA(m_hMsgWnd, WM_XMR_MSG, wParam, lParam);
}

void CClientXmr::OnAutoExit(DWORD dwExitCode)
{
	PostWndMsg(WP_XMR_AUTOEXIT, dwExitCode);
}

void CClientXmr::RetSet()
{
	TSDEBUG(_T("RetSet X(%u) client Param"), m_uMinerType);
	m_strLastLeft = "";
}


void CClientXmr::ProcessString(const char *szBuffer)
{

	//LogString(szBuffer);
	RegexString(szBuffer);
}

void CClientXmr::RegexString(const char *szBuffer)
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



	//提交share成功
	//成功 示例："accepted (6/0) diff 20000 (276 ms)"
	
	exp.assign(".*accepted \\([0-9]+/[0-9]+\\) diff [0-9]+.*", boost::regex::icase);
	if (boost::regex_match(strBuffer,exp))
	{
		PostWndMsg(WP_XMR_SHARE, 0);
		TSDEBUG4CXX(L"[RegexString]: " << L"Accepted share");
	}
	
	//当前算力
	//示例："speed 10s/60s/15m n/a 435.9 432.5 H/s max: 447.2 H/s"
	//       speed 2.5s/60s/15m 88.4 n/a n/a H/s max: 92.2 H/s
	exp.assign("speed [0-9\\.]+s/[0-9\\.]+s/[0-9\\.]+m ([0-9\\.]+) [na/0-9\\.]+ [na/0-9\\.]+ H/s", boost::regex::icase);
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
		PostWndMsg(WP_XMR_SPEED, iCurrentSpeed);
		TSDEBUG4CXX(L"[RegexString]: " << L"uCurrentSpeed = "<< iCurrentSpeed);
		return;
	}

	//重要信息优先处理

	//连接矿次成功
	//1:"new job from failover.xmrig.com:443 diff 20000" 
	if (boost::icontains(strBuffer,"new job from"))
	{
		PostWndMsg(WP_XMR_CONNECT_POOL, 0);
		TSDEBUG4CXX(L"[RegexString]: " << L"Detected new work so connect server success");
	}


	//处理错误：
	//发生错误程序
	if (boost::icontains(strBuffer,"No AMD device found") 
		|| boost::icontains(strBuffer,"No AMD OpenCL platform found") 
		|| boost::icontains(strBuffer,"Possible driver issues or wrong vendor driver")
		)
	{	
		PostWndMsg(WP_XMR_ERROR_INFO, 1);
		PostErrorMsg(strBuffer.c_str(),"no amd");
		TSDEBUG4CXX(L"[RegexString]: " << L"No AMD device found");
	}
	else if (boost::icontains(strBuffer,"No CUDA device found"))
	{
		PostWndMsg(WP_XMR_ERROR_INFO, 2);
		PostErrorMsg(strBuffer.c_str(),"no cuda");
		TSDEBUG4CXX(L"[RegexString]: " << L"No CUDA device found");
	}
	else if (boost::icontains(strBuffer,"no such file or directory") || boost::icontains(strBuffer,"No pool URL supplied. Exiting"))
	{
		PostWndMsg(WP_XMR_ERROR_INFO, 3);
		PostErrorMsg(strBuffer.c_str(),"no");
		TSDEBUG4CXX(L"[RegexString]: " << L"Cannot find pool cfg");
	}
	//Error CL_MEM_OBJECT_ALLOCATION_FAILURE when calling clEnqueueNDRangeKernel for kernel 0.
	else if(boost::icontains(strBuffer,"Error CL_MEM_OBJECT_ALLOCATION_FAILURE when calling clEnqueueNDRangeKernel for kernel"))
	{
		PostWndMsg(WP_XMR_ERROR_INFO, 4);
		PostErrorMsg(strBuffer.c_str(),"error cl_");
		TSDEBUG4CXX(L"[RegexString]: " << L"Error CL_MEM_OBJECT_ALLOCATION_FAILURE when calling clEnqueueNDRangeKernel for kernel");
	}
	//[CUDA] Error gpu 0: <cryptonight_extra_cpu_final>:231 "unknown error"
	exp.assign(".*<cryptonight_extra_cpu_final>:[0-9]+ \"unknown error\".*", boost::regex::icase);
	if(boost::regex_match(strBuffer,exp))
	{
		PostWndMsg(WP_XMR_ERROR_INFO, 5);
		PostErrorMsg(strBuffer.c_str(),"error gpu");
		TSDEBUG4CXX(L"[RegexString]: " << L"Error CL_MEM_OBJECT_ALLOCATION_FAILURE when calling clEnqueueNDRangeKernel for kernel");
		return;
	}
	//Error CL_MEM_OBJECT_ALLOCATION_FAILURE when calling clEnqueueNDRangeKernel for kernel 0
	exp.assign(".*Error \\w+ when calling \\w+ for kernel [0-9]*.*", boost::regex::icase);
	if(boost::regex_match(strBuffer,exp))
	{
		PostWndMsg(WP_XMR_ERROR_INFO, 98);
		PostErrorMsg(strBuffer.c_str(),"error cl_");
		TSDEBUG4CXX(L"[RegexString]: " << L"opencl error");
		return;
	}

	exp.assign(".*\\[CUDA\\] Error gpu [0-9]+: <[^>]*>:[0-9]+ \"[^\"]+\".*", boost::regex::icase);
	if(boost::regex_match(strBuffer,exp))
	{
		PostWndMsg(WP_XMR_ERROR_INFO, 99);
		PostErrorMsg(strBuffer.c_str(),"error gpu");
		TSDEBUG4CXX(L"[RegexString]: " << L"cuda error");
		return;
	}

	//连接矿池失败
	// DNS error: "unknown node or service"
	if (boost::icontains(strBuffer,"DNS error: \"unknown node or service\""))
	{
		PostWndMsg(WP_XMR_CONNECT_POOL, 1);
		PostErrorMsg(strBuffer.c_str(),"dns error: unknown node or service");
		TSDEBUG4CXX(L"[RegexString]: " << L"unknown node or service");
	}
	return;
}


void CClientXmr::PostErrorMsg(const char *szBuffer, const char *szBeg)
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
	PostMessage(m_hMsgWnd, WM_ERROR_INFO, m_uMinerType, (LPARAM)pInfo);
}