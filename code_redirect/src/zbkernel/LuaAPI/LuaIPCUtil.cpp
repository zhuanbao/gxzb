#include "StdAfx.h"
#include <Tlhelp32.h>
#include "LuaIPCUtil.h"
#include "../Utility/IPCInterface.h"
#include "../Utility/StringOperation.h"
#include "../MinerType/ClientGenOil.h"
#include "../MinerType/ClientZcashN.h"

CMinerClient *g_pClient = NULL;


//重定向输出管道的长度
#define PIPE_BUFFER_SIZE 4096

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
	Clear();
	if (NULL != g_pClient)
	{
		delete g_pClient;
		g_pClient = NULL;
	}
}

XLLRTGlobalAPI LuaIPCUtil::sm_LuaMemberFunctions[] = 
{
	{"Init", Init},
	{"Start", Start},
	{"Quit", Quit},
	{"Pause", Pause},
	{"Resume", Resume},
	{"IsWorkProcessRunning",IsWorkProcessRunning},
	{NULL, NULL}
};

HANDLE LuaIPCUtil::m_hPipeThread  = NULL;
HANDLE LuaIPCUtil::m_hWorkProcess  = NULL;
HANDLE LuaIPCUtil::m_hStdInRead  = NULL;
HANDLE LuaIPCUtil::m_hStdInWrite  = NULL;
HANDLE LuaIPCUtil::m_hStdOutRead  = NULL;
HANDLE LuaIPCUtil::m_hStdOutWrite  = NULL;

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
	static BOOL bEnableDebug = FALSE;
	if(bEnableDebug)
	{
		bEnableDebug = EnableDebugPrivilege();
	}
	if (NULL == fnNtSuspendProcess)
	{
		fnNtSuspendProcess = (_NtSuspendProcess)GetProcAddress( GetModuleHandle( _T("ntdll") ), "NtSuspendProcess" );  
	}
	if (NULL == fnNtResumeProcess)
	{
		fnNtResumeProcess = (_NtSuspendProcess)GetProcAddress( GetModuleHandle( _T("ntdll") ), "NtResumeProcess" );  
	}
	if (NULL != g_pClient)
	{
		delete g_pClient;
		g_pClient = NULL;
	}

	UINT uMinerType = (DWORD)lua_tointeger(pLuaState, 2);
	if (uMinerType == MINER_GENOIL)
	{
		g_pClient = new CClientGenOil();
	}
	else if(uMinerType == MINER_ZCASH)
	{
		g_pClient = new CClientZcashN();
	}
	return 0;
}

void LuaIPCUtil::Clear()
{
	CLOSE_HANDLE(m_hWorkProcess);
	CLOSE_HANDLE(m_hPipeThread);
	CLOSE_HANDLE(m_hStdInRead);
	CLOSE_HANDLE(m_hStdInWrite);
	CLOSE_HANDLE(m_hStdOutRead);
	CLOSE_HANDLE(m_hStdOutWrite);
	if (NULL != g_pClient)
	{
		//TSDEBUG4CXX(L"Try clear client param");
		g_pClient->RetSet();
		
	}
}

void LuaIPCUtil::CycleHandleInfoFromPipeEx()
{
	DWORD dwExitCode = 0; 
	while (GetExitCodeProcess(m_hWorkProcess,&dwExitCode))  
	{  
		if (dwExitCode != STILL_ACTIVE)
		{
			TSDEBUG4CXX(L"Work process exit,dwExitCode = " << dwExitCode); 
			g_pClient->OnAutoExit(dwExitCode);
			break;
		}
		//dosomeing
		char szPipeOutBuffer[PIPE_BUFFER_SIZE+1] = {0};  
		DWORD dwBytesRead = 0;
		DWORD dwTotalBytesAvail = 0; 
		//TSDEBUG4CXX(L"[CycleHandleInfoFromPipe] begain read " ); 
		PeekNamedPipe(m_hStdOutRead,szPipeOutBuffer,PIPE_BUFFER_SIZE,&dwBytesRead,&dwTotalBytesAvail,NULL);


		if (dwBytesRead != 0)
		{
			ZeroMemory(szPipeOutBuffer,PIPE_BUFFER_SIZE+1);
			if (dwTotalBytesAvail > PIPE_BUFFER_SIZE)
			{
				while (dwBytesRead >= PIPE_BUFFER_SIZE)
				{
					TSDEBUG4CXX(L"[CycleHandleInfoFromPipeEx] begain read " ); 
					ReadFile(m_hStdOutRead,szPipeOutBuffer,PIPE_BUFFER_SIZE,&dwBytesRead,NULL);  //read the stdout pipe
					TSDEBUG4CXX(L"[CycleHandleInfoFromPipeEx] end read ,dwBytesRead = " <<  dwBytesRead);
					ZeroMemory(szPipeOutBuffer,PIPE_BUFFER_SIZE+1);
				}
			}
			else {
				TSDEBUG4CXX(L"[CycleHandleInfoFromPipeEx] begain read " ); 
				ReadFile(m_hStdOutRead,szPipeOutBuffer,1023,&dwBytesRead,NULL);
				TSDEBUG4CXX(L"[CycleHandleInfoFromPipeEx] end read ,dwBytesRead = " <<  dwBytesRead);
			}
			g_pClient->ProcessString(szPipeOutBuffer);
		}
	}
	return;
}

void LuaIPCUtil::CycleHandleInfoFromPipe()
{
	DWORD dwExitCode = 0;  
	while (GetExitCodeProcess(m_hWorkProcess,&dwExitCode))  
	{  
		if (dwExitCode != STILL_ACTIVE)
		{
			TSDEBUG4CXX(L"Work process exit,dwExitCode = " << dwExitCode); 
			g_pClient->OnAutoExit(dwExitCode);
			break;
		}
		//dosomeing
		char szPipeOutBuffer[PIPE_BUFFER_SIZE+1] = {0};  
		DWORD dwBytesRead = 0;  
		TSDEBUG4CXX(L"[CycleHandleInfoFromPipe] begain read " ); 
		BOOL bRead = ReadFile(m_hStdOutRead, szPipeOutBuffer, PIPE_BUFFER_SIZE, &dwBytesRead, NULL);  
		TSDEBUG4CXX(L"[CycleHandleInfoFromPipe] end read ,dwBytesRead = " <<  dwBytesRead);
		if(!bRead || dwBytesRead <= 0)
		{
			DWORD dwLastError = ::GetLastError();
			TSDEBUG4CXX(L"Work process exit,dwExitCode = " << dwLastError);
			continue;
		}
		g_pClient->ProcessString(szPipeOutBuffer);
	}
	return;
}

UINT WINAPI PipeProc(PVOID pArg)
{
	LuaIPCUtil::CycleHandleInfoFromPipeEx();
	return 0;
}

int LuaIPCUtil::Start(lua_State* pLuaState)
{
	TSAUTO();
	TerminateMiningProcess();
	TSDEBUG4CXX(L"After T"); 
	long lRet = 0;
	do
	{
		const char* pParams = lua_tostring(pLuaState, 2);
		CComBSTR bstrParams;
		LuaStringToCComBSTR(pParams,bstrParams);

		SECURITY_ATTRIBUTES sa = {0};  
		sa.nLength = sizeof(sa);  
		sa.bInheritHandle = TRUE;  
		//产生一个用于stdin的管道，得到两个HANDLE:  m_hStdInRead用于子进程读数据，m_hStdInWrite用于主程序写入数据     
		if (!CreatePipe(&m_hStdInRead, &m_hStdInWrite, &sa, 0))  
			break;  

		//产生一个用于stdout的管道，得到两个HANDLE:  m_hStdOutRead用于主程序读出数据，m_hStdOutWrite用于子程序写入数据    
		if (!CreatePipe(&m_hStdOutRead, &m_hStdOutWrite, &sa, 0))  
			break; 
		STARTUPINFO si;
		PROCESS_INFORMATION pi;

		ZeroMemory(&si, sizeof(STARTUPINFO));  
		si.cb = sizeof(STARTUPINFO);  
		si.dwFlags = STARTF_USESHOWWINDOW | STARTF_USESTDHANDLES;  //允许设置showwindow和设置新进程的输入输出句柄参数  
		si.hStdOutput = m_hStdOutWrite;     //意思是：子进程的stdout输出到m_hStdOutWrite    
		si.hStdError = m_hStdOutWrite;      //意思是：子进程的stderr输出到m_hStdOutWrite    
		si.hStdInput = m_hStdInRead;  
		si.wShowWindow = SW_HIDE;

		ZeroMemory(&pi, sizeof(pi));
		TSDEBUG4CXX(L"strCmdLine = "<< bstrParams.m_str); 
		if(!CreateProcess( NULL,(LPTSTR)bstrParams.m_str, NULL, NULL, TRUE, NULL, NULL, NULL,&si,	&pi ))
		{
			TSDEBUG4CXX(L"create process failed, last error = "<< GetLastError()); 
			break; 
		}
		m_hWorkProcess = pi.hProcess;

		m_hPipeThread = (HANDLE)_beginthreadex(NULL, 0, PipeProc, NULL, 0, NULL);
		lRet = 1;
	}while(FALSE);

	lua_pushboolean(pLuaState, lRet);
	return 1;
}

int LuaIPCUtil::Quit(lua_State* pLuaState)
{
	if ((m_hPipeThread !=NULL && WAIT_OBJECT_0 != ::WaitForSingleObject(m_hPipeThread, 0)))
	{
		TerminateThread(m_hPipeThread,-2);
	}
	if (g_pClient)
	{
		g_pClient->TerminateAllClientInstance();
	}
	if (m_hWorkProcess != NULL && WAIT_OBJECT_0 != ::WaitForSingleObject(m_hWorkProcess, 0))
	{
		
		TerminateThread(m_hWorkProcess,-2);
	}
	Clear();
	return 0;
}


int LuaIPCUtil::Pause(lua_State* pLuaState)
{
	BOOL bRet = 0;
	if(fnNtSuspendProcess)
	{
		fnNtSuspendProcess(m_hWorkProcess);  
		bRet = 1;
	}
	lua_pushboolean(pLuaState, bRet);
	return 1;
}

int LuaIPCUtil::Resume(lua_State* pLuaState)
{
	BOOL bRet = 0;
	if(fnNtResumeProcess)
	{
		fnNtResumeProcess(m_hWorkProcess); 
		bRet = 1;
	}
	lua_pushboolean(pLuaState, bRet);
	return 1;
}

int LuaIPCUtil::IsWorkProcessRunning(lua_State* pLuaState)
{
	long lRet = 1;
	if (NULL == m_hWorkProcess  || WAIT_OBJECT_0 == ::WaitForSingleObject(m_hWorkProcess, 0))
	{
		lRet = 0;
	}
	lua_pushboolean(pLuaState, lRet);
	return 1;
}

void LuaIPCUtil::TerminateMiningProcess()
{
	g_pClient->TerminateAllClientInstance();
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