#include "StdAfx.h"
#include <Tlhelp32.h>
#include "LuaIPCUtil.h"
#include "../Utility/IPCInterface.h"
#include "../Utility/StringOperation.h"
#include "../MinerType/ClientGenOil.h"
#include "../MinerType/ClientZcashN.h"
#include "../MinerType/ClientZcashA.h"
#include "../MinerType/ClientXmr.h"
#include "../MinerType/ClientUt.h"
#include "../MinerType/ClientMsgDefine.h"

//CMinerClient *g_pClient = NULL;


//重定向输出管道的长度
#define PIPE_BUFFER_SIZE 4096

#define SLEEP_TIME 10 // reactivity: sleep time to wait for subprocess to output some more data

#define VALID_HANDLE(H) (((H) != NULL) && ((H) != INVALID_HANDLE_VALUE))
/*
 * Close Win32 Handler
 */
#define CLOSE_HANDLE(H) do \
{ \
	if(VALID_HANDLE((H))) { CloseHandle((H)); (H) = NULL; } \
} \
while(0)

typedef LONG ( NTAPI *_NtSuspendProcess )( IN HANDLE hProcessHandle );  
typedef LONG ( NTAPI *_NtResumeProcess )( IN HANDLE hProcessHandle ); 

_NtSuspendProcess fnNtSuspendProcess = NULL;  
_NtResumeProcess fnNtResumeProcess = NULL; 

LuaIPCUtil::LuaIPCUtil(void)
{
}

LuaIPCUtil::~LuaIPCUtil(void)
{
	//Clear();
	//if (NULL != g_pClient)
	//{
	//	delete g_pClient;
	//	g_pClient = NULL;
	//}
}

XLLRTGlobalAPI LuaIPCUtil::sm_LuaMemberFunctions[] = 
{
	{"Init", Init},
	{"StartModeClient", StartModeClient},
	{"QuitMode", QuitMode},
	{"Quit", Quit},
	{"ForceQuit", ForceQuit},
	{NULL, NULL}
};

LuaIPCUtil::rwmutex LuaIPCUtil::m_rwmutex;
LuaIPCUtil::WorkInstMap LuaIPCUtil::m_mapWorkInst;

LuaIPCUtil* __stdcall LuaIPCUtil::Instance(void *)
{
	static LuaIPCUtil s_instance;
	return &s_instance;
}

void LuaIPCUtil::RegisterObj( XL_LRT_ENV_HANDLE hEnv )
{
	if (hEnv == NULL)
	{
		return;
	}

	XLLRTObject theObject;
	theObject.ClassName = IPC_UTIL_CLASS;
	theObject.MemberFunctions = sm_LuaMemberFunctions;
	theObject.ObjName = IPC_UTIL_OBJ;
	theObject.userData = NULL;
	theObject.pfnGetObject = (fnGetObject)LuaIPCUtil::Instance;

	XLLRT_RegisterGlobalObj(hEnv,theObject);
}

int LuaIPCUtil::Init(lua_State* pLuaState)
{
	static BOOL bInit = FALSE;
	if(bInit)
	{
		return 0;
	}
	EnableDebugPrivilege();
	
	if (NULL == fnNtSuspendProcess)
	{
		fnNtSuspendProcess = (_NtSuspendProcess)GetProcAddress( GetModuleHandle( _T("ntdll") ), "NtSuspendProcess" );  
	}
	if (NULL == fnNtResumeProcess)
	{
		fnNtResumeProcess = (_NtSuspendProcess)GetProcAddress( GetModuleHandle( _T("ntdll") ), "NtResumeProcess" );  
	}
	m_mapWorkInst.clear();
	bInit = TRUE;
	return 0;
}

CMinerClient * LuaIPCUtil::CreateClient(UINT uClientType)
{
	CMinerClient *pClient = NULL ;
	if (uClientType == CLIENT_ETC_64)
	{
		pClient = new CClientGenOil(uClientType);
	}
	else if(uClientType == CLIENT_ZCASH_N_64)
	{
		pClient = new CClientZcashN(uClientType);
	}
	else if(uClientType == CLIENT_ZCASH_A_64)
	{
		pClient = new CClientZcashA(uClientType);
	}
	else if(uClientType == CLIENT_XMR_N_64 
		|| uClientType == CLIENT_XMR_A_64
		|| uClientType == CLIENT_XMR_A_32
		|| uClientType == CLIENT_XMR_C_32
		)
	{
		pClient = new CClientXmr(uClientType);
	}
	else if(uClientType == CLIENT_UT_C_64)
	{
		pClient = new CClientUt(uClientType);
	}
	return pClient;
}

BOOL LuaIPCUtil::StartProcess(std::wstring wParam, HANDLE & hWorkProcess, HANDLE & hWorkStdOutRead)
{
	BOOL bRet = FALSE;
	SECURITY_ATTRIBUTES sa = {0};  
	sa.nLength = sizeof(sa);  
	sa.bInheritHandle = TRUE;  

	//定义句柄: 构成stdin管道的两端句柄    
	HANDLE	hStdInRead;         //子进程用的stdin的读入端    
	HANDLE  hStdInWrite;        //主程序用的stdin的写入端    

	//定义句柄: 构成stdout管道的两端句柄    
	HANDLE  hStdOutRead;     ///主程序用的stdout的读入端    
	HANDLE  hStdOutWrite;    ///子进程用的stdout的写入端  
	do 
	{
		if (!CreatePipe(&hStdInRead, &hStdInWrite, &sa, 0))  
		{	
			TSDEBUG4CXX(L"create stdin pipe failed, last error = "<< GetLastError()); 
			break;  
		}

		//产生一个用于stdout的管道，得到两个HANDLE:  hStdOutRead用于主程序读出数据，hStdOutWrite用于子程序写入数据    
		if (!CreatePipe(&hStdOutRead, &hStdOutWrite, &sa, 0))  
		{	
			TSDEBUG4CXX(L"create stdout pipe failed, last error = "<< GetLastError()); 
			break;  
		}

		STARTUPINFO si;
		PROCESS_INFORMATION pi;

		ZeroMemory(&si, sizeof(STARTUPINFO));  
		si.cb = sizeof(STARTUPINFO);  
		si.dwFlags = STARTF_USESHOWWINDOW | STARTF_USESTDHANDLES;  //允许设置showwindow和设置新进程的输入输出句柄参数  
		si.hStdOutput = hStdOutWrite;     //意思是：子进程的stdout输出到hStdOutWrite    
		si.hStdError = hStdOutWrite;      //意思是：子进程的stderr输出到hStdOutWrite    
		si.hStdInput = hStdInRead;  
		si.wShowWindow = SW_HIDE;

		ZeroMemory(&pi, sizeof(pi));
		TSDEBUG4CXX(L"strCmdLine = "<< wParam.c_str()); 
		::SetErrorMode(::SetErrorMode(0)|SEM_FAILCRITICALERRORS|SEM_NOOPENFILEERRORBOX|SEM_NOGPFAULTERRORBOX|SEM_NOALIGNMENTFAULTEXCEPT);
		if(!CreateProcess( NULL,(LPTSTR)wParam.c_str(), NULL, NULL, TRUE, NULL, NULL, NULL,&si,	&pi ))
		{
			TSDEBUG4CXX(L"create process failed, last error = "<< GetLastError()); 
			break;
		}
		hWorkProcess = pi.hProcess;
		hWorkStdOutRead = hStdOutRead;
		bRet = TRUE;
	} while (false);
	CLOSE_HANDLE(hStdInRead);
	CLOSE_HANDLE(hStdInWrite);
	CLOSE_HANDLE(hStdOutWrite);
	if (!bRet)
	{
		CLOSE_HANDLE(hStdOutRead);
	}
	return bRet;

}

#define DELETE_WORKINST() \
{\
	{\
		writeLock wrlock(m_rwmutex);\
		if (NULL != pwi)\
		{\
			delete pwi;\
			pwi = NULL; \
		}\
		WorkInstMapIter iter = m_mapWorkInst.find(wi_old.uMode);\
		if (iter != m_mapWorkInst.end()) {\
			iter->second = NULL;\
		}\
	}\
}

UINT WINAPI LuaIPCUtil::Run(PVOID pArg)
{
	WORKINST* pwi = (WORKINST *)pArg;
	WORKINST wi_old = {0};
	{
		readLock rdLock(m_rwmutex);
		memcpy(&wi_old, pwi, sizeof(WORKINST));
	}
	CMinerClient *pClient = NULL;
	HANDLE hWorkStdOutRead = NULL;
	HANDLE hWorkProcess = NULL;
	
	int iExitCode = 0;
	do 
	{
		TSDEBUG4CXX(L"create client type = "<< wi_old.uClientType); 
		pClient = CreateClient(wi_old.uClientType);
		if (NULL == pClient)
		{
			DELETE_WORKINST();
			TSDEBUG(L"Create client failed, mode %u thread exit", wi_old.uMode); 
			break;
		}

		BOOL bStart = StartProcess(wi_old.wszParam, hWorkProcess, hWorkStdOutRead);
		if (!bStart)
		{
			DELETE_WORKINST();
			pClient->OnAutoExit(-1);
			TSDEBUG(L"Start process failed, mode %u thread exit", wi_old.uMode); 
			break;
		}

		while(true)
		{
			WORKINST wi_new = {0};
			{
				//XMLib::CriticalSectionLockGuard lck(m_cs);
				readLock rdLock(m_rwmutex);
				memcpy(&wi_new, pwi, sizeof(WORKINST));
			}
			if (wi_new.bQuit)
			{
				pClient->TerminateClientInstance();
				Sleep(SLEEP_TIME);
				if (hWorkProcess != NULL && WAIT_OBJECT_0 != ::WaitForSingleObject(hWorkProcess, 0))
				{
					TerminateProcess(hWorkProcess,-3);
				}
				TSDEBUG(L"quit command, mode %u thread exit", wi_new.uMode); 
				break;
			}
			//TSDEBUG(L"uStartCnt old = %u, new = %u", wi_old.uStartCnt, wi_new.uStartCnt); 
			if (wi_new.uClientType != wi_old.uClientType 
				|| wi_new.uStartCnt != wi_old.uStartCnt 
				)
			{
				TSDEBUG(L"param change restart"); 
				pClient->TerminateClientInstance();
				Sleep(SLEEP_TIME);
				if (hWorkProcess != NULL && WAIT_OBJECT_0 != ::WaitForSingleObject(hWorkProcess, 0))
				{
					TerminateProcess(hWorkProcess,-2);
				}
				CLOSE_HANDLE(hWorkProcess);
				CLOSE_HANDLE(hWorkStdOutRead);
				delete pClient;
				pClient = NULL;
				pClient = CreateClient(wi_new.uClientType);
				if (NULL == pClient)
				{
					DELETE_WORKINST();
					TSDEBUG(L"create new client %u failed, mode %u thread exit", wi_new.uClientType, wi_new.uMode); 
					break;
				}
				bStart = StartProcess(wi_new.wszParam, hWorkProcess,hWorkStdOutRead);
				if (!bStart)
				{
					DELETE_WORKINST();
					pClient->OnAutoExit(-1);
					TSDEBUG(L"Start process %u failed, mode %u thread exit", wi_new.uClientType, wi_new.uMode); 
					break;
				}
				memcpy(&wi_old, &wi_new, sizeof(WORKINST));
				Sleep(SLEEP_TIME);
			}
			DWORD dwExitCode = 0; 
			if (GetExitCodeProcess(hWorkProcess,&dwExitCode))
			{
				if (dwExitCode != STILL_ACTIVE)
				{
					DELETE_WORKINST();
					pClient->OnAutoExit(dwExitCode);
					TSDEBUG4CXX(L"Work process exit,dwExitCode = " << dwExitCode); 
					break;
				}
			}
			char szPipeOutBuffer[PIPE_BUFFER_SIZE+1] = {0};  
			DWORD dwTotalBytesAvail = 0;  
			PeekNamedPipe(hWorkStdOutRead, 0, 0, NULL, &dwTotalBytesAvail, NULL);
			if (dwTotalBytesAvail > 0)
			{
				DWORD dwBytesRead = 0;
				while (ReadFile(hWorkStdOutRead, szPipeOutBuffer, dwTotalBytesAvail > PIPE_BUFFER_SIZE ? PIPE_BUFFER_SIZE : dwTotalBytesAvail, &dwBytesRead, 0))
				{
					PeekNamedPipe(hWorkStdOutRead, 0, 0, NULL, &dwTotalBytesAvail, NULL);
					if (0 == dwTotalBytesAvail)
						break;
				}
				pClient->ProcessString(szPipeOutBuffer);
			}
			Sleep(SLEEP_TIME);
		}
	} while (false);
	
	if (NULL != pClient)
	{
		delete pClient;
		pClient = NULL;
	}
	CLOSE_HANDLE(hWorkProcess);
	CLOSE_HANDLE(hWorkStdOutRead);
	DELETE_WORKINST();
	//{
	//	writeLock wrlock(m_rwmutex);
	//	if (NULL != pwi)
	//	{
	//		delete pwi;
	//		pwi = NULL; 
	//		TSDEBUG(L"delete memory");
	//	}
	//	WorkInstMapIter iter = m_mapWorkInst.find(wi_old.uMode);
	//	iter->second = NULL;
	//}
	return 0;
}

//UINT WINAPI WorkThreadProc(PVOID pArg)
//{
//	//LuaIPCUtil::Run(pArg);
//	return 0;
//}

int LuaIPCUtil::StartModeClient(lua_State* pLuaState)
{
	TSAUTO();
	UINT uMode = (UINT)lua_tointeger(pLuaState, 2);
	UINT uClientType = (DWORD)lua_tointeger(pLuaState, 3);
	const char* utf8Params = lua_tostring(pLuaState, 4);
	std::wstring wstrParam = ultra::_UTF2T(utf8Params);
	TSDEBUG(L"m_mapWorkInst size = %u ",m_mapWorkInst.size());
	do 
	{
		WorkInstMapIter iter = m_mapWorkInst.find(uMode);
		if (iter == m_mapWorkInst.end()) {
			break;
		}
		WORKINST wi = {0};
		{
			//XMLib::CriticalSectionLockGuard lck(m_cs);
			readLock rdLock(m_rwmutex);
			if (iter->second == NULL)
			{
				m_mapWorkInst.erase(iter);
				break;
			}
			TSDEBUG(L"has memory");
			memcpy(&wi,iter->second, sizeof(WORKINST));
		}
		wi.uClientType = uClientType;
		wi.uStartCnt++;
		wcscpy_s(wi.wszParam,1024-1,wstrParam.c_str());
		//TSDEBUG(L"uStartCnt = %u", wi.uStartCnt); 
		{
			//XMLib::CriticalSectionLockGuard lck(m_cs);
			writeLock wrlock(m_rwmutex);
			memcpy(iter->second, &wi, sizeof(WORKINST));
		}
		return 0;
		
	} while (FALSE);

	WORKINST* pwi = new WORKINST();
	pwi->uMode = uMode;
	pwi->uStartCnt = 0;
	pwi->uClientType = uClientType;
	wcscpy_s(pwi->wszParam,1024-1,wstrParam.c_str());
	pwi->bQuit = FALSE;
	m_mapWorkInst.insert(std::make_pair(uMode, pwi));
	HANDLE hThread = (HANDLE)_beginthreadex(NULL, 0, LuaIPCUtil::Run,  pwi, 0, NULL);
	return 0;
}

int LuaIPCUtil::QuitMode(lua_State* pLuaState)
{
	TSAUTO();
	UINT uMode = (UINT)lua_tointeger(pLuaState, 2);
	WorkInstMapIter iter = m_mapWorkInst.find(uMode);
	if (iter == m_mapWorkInst.end()) {
		return 0;
	}
	{
		writeLock wrlock(m_rwmutex);
		if (iter->second != NULL)
		{
			iter->second->bQuit = TRUE;
		}
	}
	m_mapWorkInst.erase(iter);
	return 0;
}

int LuaIPCUtil::Quit(lua_State* pLuaState)
{
	TSAUTO();
	for (WorkInstMapIter iter = m_mapWorkInst.begin() ;iter != m_mapWorkInst.end();++iter)
	{
		{
			//XMLib::CriticalSectionLockGuard lck(m_cs);
			writeLock wrlock(m_rwmutex);
			if (iter->second != NULL)
			{
				iter->second->bQuit = TRUE;
				TSDEBUG(L"Quit mode %u ",iter->second->uMode);
			}
			
		}
	}
	m_mapWorkInst.clear();
	TSDEBUG(L"m_mapWorkInst size = %u ",m_mapWorkInst.size());
	return 0;
}

int LuaIPCUtil::ForceQuit(lua_State* pLuaState)
{
	TerminateAllClient();
	return 0;
}

void LuaIPCUtil::TerminateAllClient()
{
	TCHAR *tszClientName[] = {
		_T("Share4Peer.exe"),
		_T("Share4Peer.exe"),
		_T("Share4PeerZN.exe"),
		_T("Share4PeerZA.exe"),
		_T("Share4PeerXA.exe"), 
		_T("Share4PeerXA64.exe"), 
		_T("Share4PeerXN64.exe"), 
		_T("Share4PeerXC.exe"),
		_T("Share4PeerUC.exe"),
		_T("ShareCout.exe"),
	};
	HANDLE hSnap = ::CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	if (hSnap != INVALID_HANDLE_VALUE)
	{
		PROCESSENTRY32 pe;
		pe.dwSize = sizeof(PROCESSENTRY32);
		BOOL bResult = ::Process32First(hSnap, &pe);
		while (bResult)
		{
			for (int i = 0; i < ARRAYSIZE(tszClientName); i++)
			{
				if(_tcsicmp(pe.szExeFile, tszClientName[i]) == 0 && pe.th32ProcessID != 0)
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

BOOL LuaIPCUtil::EnableDebugPrivilege()     
{     
	HANDLE hToken;     
	LUID luid;     
	TOKEN_PRIVILEGES tkp;     
	if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &hToken))  
	{     
		return   FALSE;     
	}     
	if (!LookupPrivilegeValue(NULL, SE_DEBUG_NAME, &luid))   
	{     
		CloseHandle(hToken);     
		return FALSE;     
	}     
	tkp.PrivilegeCount = 1;     
	tkp.Privileges[0].Luid = luid;     
	tkp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;     
	if (!AdjustTokenPrivileges(hToken, FALSE, &tkp, sizeof(tkp), NULL, NULL))   
	{     
		CloseHandle(hToken);     
		return FALSE;     
	}     
	return TRUE;     
}