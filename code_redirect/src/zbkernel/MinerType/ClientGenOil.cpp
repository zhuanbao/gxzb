#include "StdAfx.h"
#include "ClientGenOil.h"
#include "ClientMsgDefine.h"
#include <Tlhelp32.h>
#include "..\Utility\StringOperation.h"
#include "boost/regex.hpp"
#include <boost/algorithm/string.hpp>
#include "../EvenListenHelper/LuaMsgWnd.h"

#define LOGCFG_PATH _T("C:\\GXZB_CONFIG\\Share4Peer.ini")
#define CLIENT_GENOIL_NAME _T("Share4Peer.exe")

CClientGenOil::CClientGenOil(UINT uClientType)
{
	m_hMsgWnd = FindWindow(LUA_MSG_WND_CALSS, NULL);
	m_strLastLeft = "";
	m_DagProgress = -1;
	m_uClientType = uClientType;
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

void CClientGenOil::TerminateClientInstance()
{
	HANDLE hSnap = ::CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	if (hSnap != INVALID_HANDLE_VALUE)
	{
		PROCESSENTRY32 pe;
		pe.dwSize = sizeof(PROCESSENTRY32);
		BOOL bResult = ::Process32First(hSnap, &pe);
		while (bResult)
		{
			if(_tcsicmp(pe.szExeFile, CLIENT_GENOIL_NAME) == 0 && pe.th32ProcessID != 0)
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

void CClientGenOil::PostWndMsg(int iMsgType, int iDetail)
{
	CLIENTMSG *pInfo = new CLIENTMSG();
	pInfo->uClientType = m_uClientType;
	pInfo->iMsgType = iMsgType;
	pInfo->iDetail = iDetail;

	PostMessageA(m_hMsgWnd, WM_CLIENT_MSG, (WPARAM)pInfo, (LPARAM)0);
}

void CClientGenOil::OnAutoExit(DWORD dwExitCode)
{
	PostWndMsg(MSG_TYPE_AUTOEXIT, dwExitCode);
}

void CClientGenOil::RetSet()
{
	TSDEBUG4CXX(L"RetSet GenOil client Param");
	m_DagProgress = -1; 
	m_strLastLeft = "";
}


void CClientGenOil::ProcessString(const char *szBuffer)
{
	
	//LogString(szBuffer);
	RegexString(szBuffer);
}

void CClientGenOil::RegexString(const char *szBuffer)
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
	//成功 示例："B-) Submitted and accepted."
	//失败 示例：":-( Not accepted."
	if (boost::icontains(strBuffer,"B-) Submitted and accepted."))
	{
		PostWndMsg(MSG_TYPE_SHARE, 0);
		TSDEBUG4CXX(L"[RegexString]: " << L"B-) Submitted and accepted");
	}
	else if (boost::icontains(strBuffer,":-( Not accepted."))
	{
		PostWndMsg(MSG_TYPE_SHARE, 1);
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
		PostWndMsg(MSG_TYPE_SPEED, uCurrentSpeed);
		TSDEBUG4CXX(L"[RegexString]: " << L"uCurrentSpeed = "<< uCurrentSpeed);
		return;
	}
	
	//计算DAG
	//示例："OPENCL#0: 0%"
	//TSDEBUG4CXX(L"[RegexString]: " << L"m_DagProgress = "<< m_DagProgress);
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
			PostWndMsg(MSG_TYPE_UNKNOW, m_DagProgress);
			TSDEBUG4CXX(L"[RegexString]: " << L"m_DagProgress = "<< m_DagProgress);
			return;
		}
	}
	//重要信息优先处理

	//连接矿次成功
	//1:"Connected!" 2:"Connected to stratum server "
	if (boost::icontains(strBuffer,"Connected!") || boost::icontains(strBuffer,"Connected to stratum server "))
	{
		PostWndMsg(MSG_TYPE_CONNECT_POOL, 0);
		TSDEBUG4CXX(L"[RegexString]: " << L"Connecte server success");
	}
	//处理错误：
	//发生错误且进程自动退出
	//命令行参数错误："Invalid argument:"
	//找不到合适的显卡："No GPU device with sufficient memory was found. Can't GPU mine. Remove the -G argument"

	if (boost::icontains(strBuffer,"Invalid argument:"))
	{
		PostWndMsg(MSG_TYPE_ERROR_INFO, 1);

		PostErrorMsg(strBuffer.c_str(),"invalid argument:");

		TSDEBUG4CXX(L"[RegexString]: " << L"Invalid argument");
	}
	else if(boost::icontains(strBuffer,"No GPU device with sufficient memory was found. Can't GPU mine. Remove the -G argument"))
	{
		PostWndMsg(MSG_TYPE_ERROR_INFO, 2);
		PostErrorMsg(strBuffer.c_str(),"no gpu device");
		TSDEBUG4CXX(L"[RegexString]: " << L"No GPU device with sufficient memory was found");
	}
	//发生错误但是进程继续运行
	// 矿池连接失败："Reconnecting in 3 seconds..."
	//opencl 编译错误："error: front end compiler failed build"
	//opencl 内部执行错误："error: invalid storage-class specifiers in OpenCL"


	if(boost::icontains(strBuffer,"Reconnecting in 3 seconds..."))
	{
		PostWndMsg(MSG_TYPE_CONNECT_POOL, 1);
		TSDEBUG4CXX(L"[RegexString]: " << L"Connecte server fail, try to reconnect");
	}
	else if (boost::icontains(strBuffer,"error: front end compiler failed build"))
	{
		PostWndMsg(MSG_TYPE_ERROR_INFO, 3);
		PostErrorMsg(strBuffer.c_str(),"error");
		TSDEBUG4CXX(L"[RegexString]: " << L"Error: front end compiler failed build");
	}
	else if (boost::icontains(strBuffer,"error: invalid storage-class specifiers in OpenCL"))
	{
		PostWndMsg(MSG_TYPE_ERROR_INFO, 4);
		PostErrorMsg(strBuffer.c_str(),"error");
		TSDEBUG4CXX(L"[RegexString]: " << L"Error: invalid storage-class specifiers in OpenCL");
	}
	else if (boost::icontains(strBuffer,"error: "))
	{
		PostWndMsg(MSG_TYPE_ERROR_INFO, 5);
		PostErrorMsg(strBuffer.c_str(),"error");
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
		TSDEBUG4CXX(L"[RegexString]: " << L"OpenCL Error function start");
		PostWndMsg(MSG_TYPE_ERROR_INFO, iErrorCode);
		PostErrorMsg(strBuffer.c_str(),"cl");
		std::wstring wstrErrorFun = ultra::_A2T(strErrorFun);
		TSDEBUG4CXX(L"[RegexString]: " << L"OpenCL Error function(" <<wstrErrorFun.c_str()<<"), ErrorCode = "<<iErrorCode);
	}

}

void CClientGenOil::PostErrorMsg(const char *szBuffer, const char *szBeg)
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
	PostMessage(m_hMsgWnd, WM_ERROR_INFO, 1, (LPARAM)pInfo);
}