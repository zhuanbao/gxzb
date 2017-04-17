#include "StdAfx.h"
#include "ClientGenOil.h"
#include "ClientMsgDefine.h"
#include <Tlhelp32.h>
#include "..\Utility\StringOperation.h"
#include "boost/regex.hpp"
#include <boost/algorithm/string.hpp>
#include "../EvenListenHelper/LuaMsgWnd.h"

#define LOGCFG_PATH _T("C:\\GXZB_CONFIG\\GenOil.ini")
#define CLIENT_NAME _T("ShareGenoil.exe")

CClientGenOil::CClientGenOil(void)
{
	m_hMsgWnd = FindWindow(LUA_MSG_WND_CALSS, NULL);;
}

CClientGenOil::~CClientGenOil(void)
{

}

bool CClientGenOil::IsDebug()
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

void CClientGenOil::TerminateAllClientInstance()
{
	HANDLE hSnap = ::CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	if (hSnap != INVALID_HANDLE_VALUE)
	{
		PROCESSENTRY32 pe;
		pe.dwSize = sizeof(PROCESSENTRY32);
		BOOL bResult = ::Process32First(hSnap, &pe);
		while (bResult)
		{
			if(_tcsicmp(pe.szExeFile, CLIENT_NAME) == 0 && pe.th32ProcessID != 0)
			{
				HANDLE hProcess = ::OpenProcess(PROCESS_TERMINATE, FALSE, pe.th32ProcessID);
				::TerminateProcess(hProcess, 4);
			}
			bResult = ::Process32Next(hSnap, &pe);
		}
		::CloseHandle(hSnap);
	}
}

void CClientGenOil::LogString(const char *szBuffer)
{
	if (IsDebug())
	{
		std::wstring wstrInfo = ultra::_A2T(szBuffer);
		TSDEBUG4CXX(L"<Client GenOil> Output: " <<wstrInfo.c_str());
	}
}

void CClientGenOil::PostWndMsg(WPARAM wParam, LPARAM lParam)
{
	PostMessageA(m_hMsgWnd, WM_GENOIL_MSG, wParam, lParam);
}

void CClientGenOil::OnAutoExit(DWORD dwExitCode)
{
	PostWndMsg(WP_GENOIL_AUTOEXIT, dwExitCode);
}

void CClientGenOil::RetSet()
{
	m_DagProgress = -1;
}


void CClientGenOil::ProcessString(const char *szBuffer)
{
	LogString(szBuffer);
	RegexString(szBuffer);
}

void CClientGenOil::RegexString(const char *szBuffer)
{
	std::string strBuffer = szBuffer;
	std::string::const_iterator start = strBuffer.begin();
	std::string::const_iterator end = strBuffer.end();
	boost::regex exp("",boost::regex::icase);
	boost::smatch what;

	//提交share成功
	//成功 示例："B-) Submitted and accepted."
	//失败 示例："B-) Submitted and accepted."
	if (boost::icontains(szBuffer,"B-) Submitted and accepted."))
	{
		PostWndMsg(WP_GENOIL_SHARE, 0);
		TSDEBUG4CXX(L"[RegexString]: " << L"B-) Submitted and accepted");
	}
	else if (boost::icontains(szBuffer,":-( Not accepted."))
	{
		PostWndMsg(WP_GENOIL_SHARE, 1);
		TSDEBUG4CXX(L"[RegexString]: " << L":-( Not accepted");
	}
	//当前算力
	//示例："Mining on PoWhash #84f8453a : 0.00MH/s [A0+0:R0+0:F0]"
	exp.assign("Mining on PoWhash #[^:]* : ([0-9\\.]+)MH/s ", boost::regex::icase);
	UINT uCurrentSpeed = 0;
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
				UINT uNewSpeed = ( int )( fNewSpeed * 100 + 0.5 );
				if (uNewSpeed > uCurrentSpeed)
				{
					uCurrentSpeed = uNewSpeed;
				}

			}
		}
		start = what[0].second; 
	} 
	if (uCurrentSpeed >= 1)
	{
		m_DagProgress = 101; //已经有速度了就不再解析DAG了
		PostWndMsg(WP_GENOIL_SPEED, uCurrentSpeed);
		TSDEBUG4CXX(L"[RegexString]: " << L"uCurrentSpeed = "<< uCurrentSpeed);
		return;
	}
	
	//计算DAG
	//示例："OPENCL#0: 0%"
	if (m_DagProgress < 101)
	{
		exp.assign("OPENCL#[0-9]+: ([0-9]+)%", boost::regex::icase);
		while(boost::regex_search(start,end,what,exp))
		{
			if (what.size() == 2)
			{
				if (what[1].matched)
				{
					std::string strProgress = what[1];
					int iNewProgress = 0;
					{
						std::stringstream ssNewProgress;
						ssNewProgress << strProgress;
						ssNewProgress >> iNewProgress;
					}
					if (iNewProgress > m_DagProgress)
					{
						m_DagProgress = iNewProgress;
					}
				}
			}
			start = what[0].second; 
		} 

		if (m_DagProgress >= 0)
		{
			PostWndMsg(WP_GENOIL_DAG, m_DagProgress);
			TSDEBUG4CXX(L"[RegexString]: " << L"iCurrentProgress = "<< m_DagProgress);
			return;
		}
	}
	//重要信息优先处理

	//连接矿次成功
	//1:"Connected!" 2:"Connected to stratum server "
	if (boost::icontains(szBuffer,"Connected!") || boost::icontains(szBuffer,"Connected to stratum server "))
	{
		PostWndMsg(WP_GENOIL_CONNECT_POOL, 0);
		TSDEBUG4CXX(L"[RegexString]: " << L"Connecte server success");
	}
	//处理错误：
	//发生错误且进程自动退出
	//命令行参数错误："Invalid argument:"
	//找不到合适的显卡："No GPU device with sufficient memory was found. Can't GPU mine. Remove the -G argument"

	if (boost::icontains(szBuffer,"Invalid argument:"))
	{
		PostWndMsg(WP_GENOIL_ERROR_INFO, 1);
		TSDEBUG4CXX(L"[RegexString]: " << L"Invalid argument");
	}
	else if(boost::icontains(szBuffer,"No GPU device with sufficient memory was found. Can't GPU mine. Remove the -G argument"))
	{
		PostWndMsg(WP_GENOIL_ERROR_INFO, 2);
		TSDEBUG4CXX(L"[RegexString]: " << L"No GPU device with sufficient memory was found");
	}
	//发生错误但是进程继续运行
	// 矿池连接失败："Reconnecting in 3 seconds..."
	//opencl 编译错误："error: front end compiler failed build"
	//opencl 内部执行错误："error: invalid storage-class specifiers in OpenCL"


	if(boost::icontains(szBuffer,"Reconnecting in 3 seconds..."))
	{
		PostWndMsg(WP_GENOIL_CONNECT_POOL, 1);
		TSDEBUG4CXX(L"[RegexString]: " << L"Connecte server fail, try to reconnect");
	}
	else if (boost::icontains(szBuffer,"error: front end compiler failed build"))
	{
		PostWndMsg(WP_GENOIL_ERROR_INFO, 3);
		TSDEBUG4CXX(L"[RegexString]: " << L"Error: front end compiler failed build");
	}
	else if (boost::icontains(szBuffer,"error: invalid storage-class specifiers in OpenCL"))
	{
		PostWndMsg(WP_GENOIL_ERROR_INFO, 4);
		TSDEBUG4CXX(L"[RegexString]: " << L"Error: invalid storage-class specifiers in OpenCL");
	}
	else if (boost::icontains(szBuffer,"error: "))
	{
		PostWndMsg(WP_GENOIL_ERROR_INFO, 5);
		TSDEBUG4CXX(L"[RegexString]: " << L"Error: new resone");
	}
	//opencl 错误码 clEnqueueWriteBuffer(-38)

	//这里boost::regex 调assign 第2个参数默认是regex_constants::normal 所以是大小写敏感的(这里要求大小写敏感)
	exp.assign("(cl[A-Z][\\w]+)\\((\\-[0-9]+\\))");

	int iErrorCode = 0;
	std::string strErrorFun;
	if(boost::regex_search(start,end,what,exp))
	{
		if (what.size() == 3 && what[1].matched && what[2].matched)
		{
			strErrorFun = what[1];
			std::string strErrorCode = what[2];
			{
				std::stringstream ssErrorCode;
				ssErrorCode << strErrorCode;
				ssErrorCode >> iErrorCode;
			}
		}
	} 
	if (iErrorCode < 0)
	{	
		PostWndMsg(WP_GENOIL_ERROR_OPENCL, iErrorCode);
		std::wstring wstrErrorFun = ultra::_A2T(strErrorFun);
		TSDEBUG4CXX(L"[RegexString]: " << L"OpenCL Error function(" <<wstrErrorFun.c_str()<<"), ErrorCode = "<<iErrorCode);
	}

}