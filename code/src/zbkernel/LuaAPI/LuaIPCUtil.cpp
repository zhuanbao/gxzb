#include "StdAfx.h"
#include "LuaIPCUtil.h"
#include "../Utility/IPCInterface.h"
#include "../Utility/StringOperation.h"
#include "../Utility/Lock.h"
CIPCMsgWindow g_IPCMsgWnd;

XMLib::CriticalSection csReadChannel;
XMLib::CriticalSection csWriteChannel;

char g_pReadBuffer[MAX_PIPE_BUFFIE_LEN] = {0};
char g_pWriteBuffer[MAX_PIPE_BUFFIE_LEN] = {0};

LuaIPCUtil::LuaIPCUtil(void)
{
}

LuaIPCUtil::~LuaIPCUtil(void)
{
	if (m_hPipeThread)
	{
		CloseHandle(m_hPipeThread);
		m_hPipeThread = NULL;
	}
	if (m_hWorkProcess)
	{
		CloseHandle(m_hWorkProcess);
		m_hWorkProcess = NULL;
	}
	if(m_hPipeQuitEvent)
	{
		CloseHandle(m_hPipeQuitEvent);
		m_hPipeQuitEvent = NULL;
	}
}

XLLRTGlobalAPI LuaIPCUtil::sm_LuaMemberFunctions[] = 
{
	{"Start", Start},
	{"Pause", Pause},
	{"Quit", Quit},
	{"ControlSpeed",ControlSpeed},
	{"QueryWorkState",QueryWorkState},
	{"SendPoolUrl",SendPoolUrl},
	{"IsWorkProcessRunning",IsWorkProcessRunning},
	{NULL, NULL}
};

HANDLE LuaIPCUtil::m_hPipeThread  = NULL;
HANDLE LuaIPCUtil::m_hWorkProcess  = NULL;
HANDLE LuaIPCUtil::m_hPipeQuitEvent  = NULL;

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

BOOL LuaIPCUtil::WaitPipeQuitEvent()
{
	//故意等一秒，为了让pipe线程挂起一会
	DWORD dwMilliseconds = 1*1000;
	if (WAIT_TIMEOUT == ::WaitForSingleObject(m_hPipeQuitEvent, dwMilliseconds))
	{
		return FALSE;
	}
	return TRUE;
}

UINT WINAPI PipeProc(PVOID pArg)
{
	TSAUTO();
	HANDLE hPipe = NULL;
	while(TRUE)
	{
		BOOL bWait = WaitNamedPipeA(IPC_PIPE_NAME, NMPWAIT_WAIT_FOREVER);
		DWORD dwLastError = GetLastError();
		if (!bWait && dwLastError == ERROR_FILE_NOT_FOUND)  
		{  
			Sleep(250);
			continue;	  
		}
		else if (!bWait)
		{
			TSDEBUG4CXX(L"wait named pipe failed, last error =  " << dwLastError);
			return 0; 
		}
		else
		{
			TSDEBUG4CXX("wait named pipe success");  
			break;
		}
	} 
	hPipe = CreateFileA(IPC_PIPE_NAME, GENERIC_READ|GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);  
	if (INVALID_HANDLE_VALUE == hPipe)   
	{
		TSDEBUG4CXX(L"could not create pipe, last error =  " << GetLastError());
		return 0; 
	}
	DWORD dwMode = PIPE_READMODE_MESSAGE;   
	if(!SetNamedPipeHandleState(hPipe, &dwMode, NULL, NULL)) 
	{  
		TSDEBUG4CXX(L"SetNamedPipeHandleState failed,last error = "<< GetLastError());  
		return 0; 
	}  
	while(TRUE)
	{
		if (LuaIPCUtil::WaitPipeQuitEvent())
		{
			break;
		}
		UINT uWriteSize = 0;
		char szBuffer[MAX_PIPE_BUFFIE_LEN] = {0};
		{
			XMLib::CriticalSectionLockGuard lck(csWriteChannel);
			uWriteSize = *((UINT*)(g_pWriteBuffer));
			if (uWriteSize)
			{
				memcpy(szBuffer,g_pWriteBuffer,uWriteSize);
				ZeroMemory(g_pWriteBuffer,MAX_PIPE_BUFFIE_LEN);
			}

		}
		if (uWriteSize)
		{
			DWORD dwWritten = 0;
			BOOL bWrite = WriteFile(hPipe,szBuffer, uWriteSize, &dwWritten, NULL); 
			DWORD dwLastError = GetLastError();
			if (!bWrite)
			{
				TSDEBUG4CXX(L"Write buffer to pipe failed,last error = " << dwLastError); 
				break;
			}
		}
		ZeroMemory(szBuffer,MAX_PIPE_BUFFIE_LEN);
		DWORD dwReaded = 0;
		BOOL bRead = ReadFile(hPipe, szBuffer, MAX_PIPE_BUFFIE_LEN, &dwReaded, NULL); 
		DWORD dwLastError = GetLastError();
		if (!bRead && dwLastError != ERROR_MORE_DATA )  
		{
			TSDEBUG4CXX(L"Read data to buffer failed,last error = "<< dwLastError); 
			break;
		}
		if (dwReaded > 0)
		{
			XMLib::CriticalSectionLockGuard lck(csReadChannel);
			ZeroMemory(g_pReadBuffer,MAX_PIPE_BUFFIE_LEN);
			memcpy(g_pReadBuffer,szBuffer,dwReaded);
		}
	} 

	FlushFileBuffers(hPipe);
	DisconnectNamedPipe(hPipe);

	CloseHandle(hPipe);   
	TSDEBUG4CXX(L"Pipe Proc quit"); 
	return 0;
}

#define REDIRECTPATH DEFAULT_LOGFILE_PATH"\\WorkRedirect.txt"
int LuaIPCUtil::Start(lua_State* pLuaState)
{
	if (NULL == m_hPipeQuitEvent)
	{
		m_hPipeQuitEvent = CreateEventA(NULL, TRUE, FALSE, PIPE_QUIT_EVENT);
	}
	else
	{
		 ResetEvent(m_hPipeQuitEvent);
	}
	long lRet = 0;
	const char* pParams = lua_tostring(pLuaState, 2);
	HWND hWnd = FindWindowA(MSG_WND_CALSS, NULL);
	TSDEBUG4CXX(L"StartWork FindWindowA" << hWnd); 
	if (NULL == hWnd && NULL != pParams)
	{
		CComBSTR bstrParams;
		LuaStringToCComBSTR(pParams,bstrParams);

		STARTUPINFO si;
		PROCESS_INFORMATION pi;
		ZeroMemory( &si, sizeof(si) );
		si.cb = sizeof(si);	
		GetStartupInfo(&si);
		if (!ISTSDEBUGVALID())
		{
			//日志可打印 则显示控制台窗口
			si.dwFlags =STARTF_USESHOWWINDOW|STARTF_USESTDHANDLES;  
			si.wShowWindow =SW_HIDE;//隐藏控制台窗口 
		}
		ZeroMemory( &pi, sizeof(pi) );
		// Start the child process. 
		if(CreateProcess( NULL,(LPTSTR)bstrParams.m_str, NULL, NULL, FALSE, NULL, NULL, NULL,&si,	&pi ))
		{
			lRet = 1;
			m_hWorkProcess = pi.hProcess;
		}
		else
		{
			TSDEBUG4CXX(L"create process failed, last error = "<< GetLastError()); 
		}
	}
	else
	{
		//SendMessageA(hWnd,WM_USER_START,0,0);
		//PostMessageA(hWnd,WM_USER_START,0,0);
		SendMessageTimeout(hWnd, WM_USER_START, 0, 0, SMTO_ABORTIFHUNG, 200, NULL);
		lRet = 1;
	}
	if (lRet && (NULL == m_hPipeThread || WAIT_OBJECT_0 == ::WaitForSingleObject(m_hPipeThread, 0)))
	{
		if (m_hPipeThread)
		{
			::CloseHandle(m_hPipeThread);
		}
		m_hPipeThread = (HANDLE)_beginthreadex(NULL, 0, PipeProc, NULL, 0, NULL);
	}
	lua_pushboolean(pLuaState, lRet);
	return 1;
}


int LuaIPCUtil::Pause(lua_State* pLuaState)
{
	HWND hWnd = FindWindowA(MSG_WND_CALSS, NULL);
	if (hWnd)
	{
		//SendMessageA(hWnd,WM_USER_PAUSE,0,0);
		//PostMessageA(hWnd,WM_USER_PAUSE,0,0);
		SendMessageTimeout(hWnd, WM_USER_PAUSE, 0, 0, SMTO_ABORTIFHUNG, 200, NULL);
	}
	return 0;
}


int LuaIPCUtil::Quit(lua_State* pLuaState)
{
	HWND hWnd = FindWindowA(MSG_WND_CALSS, NULL);
	if (hWnd)
	{
		//SendMessageA(hWnd,WM_EXIT,0,0);
		//PostMessageA(hWnd,WM_EXIT,0,0);
		SendMessageTimeout(hWnd, WM_EXIT, 0, 0, SMTO_ABORTIFHUNG, 200, NULL);
	}
	SetEvent(m_hPipeQuitEvent);
	if (m_hPipeThread)
	{
		CloseHandle(m_hPipeThread);
		m_hPipeThread = NULL;
	}
	if (m_hWorkProcess)
	{
		CloseHandle(m_hWorkProcess);
		m_hWorkProcess = NULL;
	}
	return 0;
}

int LuaIPCUtil::QueryWorkState(lua_State* pLuaState)
{
	UINT uReadSize = 0;
	BYTE szBuffer[MAX_PIPE_BUFFIE_LEN] = {0};
	{
		XMLib::CriticalSectionLockGuard lck(csReadChannel);
		uReadSize = *((UINT*)(g_pReadBuffer));
		if (uReadSize)
		{
			memcpy(szBuffer,g_pReadBuffer,uReadSize);
			ZeroMemory(g_pReadBuffer,MAX_PIPE_BUFFIE_LEN);
		}
	}
	if (uReadSize)
	{
		UINT uType = *((UINT*)(szBuffer)+1);
		switch (uType)
		{
		case MING_CHECK_DAG:
			{
				if (uReadSize == sizeof(MineCheckDAG))
				{
					MineCheckDAG *p = (MineCheckDAG *)szBuffer;
					lua_pushinteger(pLuaState, p->uType);
					lua_pushinteger(pLuaState, p->uState);
					return 2;
				}
			}
			break;
		case MING_CALCULATE_DAG:
			{
				if (uReadSize == sizeof(MineCalculateDAG))
				{
					MineCalculateDAG *p = (MineCalculateDAG *)szBuffer;
					lua_pushinteger(pLuaState, p->uType);
					lua_pushinteger(pLuaState, p->uPrecent);
					return 2;
				}
			}
			break;
		case MING_MINING_SPEED:
			{
				if (uReadSize == sizeof(MineMiningSpeed))
				{
					MineMiningSpeed *p = (MineMiningSpeed *)szBuffer;
					lua_pushinteger(pLuaState, p->uType);
					lua_pushnumber(pLuaState, p->uRate);
					return 2;
				}
			}
			break;
		case MING_MINING_EEEOR:
			{
				if (uReadSize == sizeof(MineMiningError))
				{
					MineMiningError *p = (MineMiningError *)szBuffer;
					lua_pushinteger(pLuaState, p->uType);
					lua_pushinteger(pLuaState, p->uErrorCode);
					return 2;
				}
			}
			break;
		case MING_SOLUTION_FIND:
			{
				if (uReadSize == sizeof(MineSolutionFind))
				{
					MineSolutionFind *p = (MineSolutionFind *)szBuffer;
					lua_pushinteger(pLuaState, p->uType);
					lua_pushstring(pLuaState, ultra::_A2UTF(p->szHeaderHash).c_str());
					lua_pushstring(pLuaState, ultra::_A2UTF(p->szMixHash).c_str());
					lua_pushstring(pLuaState, ultra::_A2UTF(p->szNonce).c_str());
					return 4;
				}
			}
			break;
		default:
			break;
		}
	}
	
	lua_pushnil(pLuaState);
	return 1;
}

int LuaIPCUtil::SendPoolUrl(lua_State* pLuaState)
{

	return 0;
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

int LuaIPCUtil::ControlSpeed(lua_State* pLuaState)
{
	UINT _globalWorkSizeMultiplier = (DWORD)lua_tointeger(pLuaState, 2);
	UINT _msPerBatch = (DWORD)lua_tointeger(pLuaState, 3);
	HWND hWnd = FindWindowA(MSG_WND_CALSS, NULL);
	if (hWnd)
	{
		//SendMessageA(hWnd,WM_USER_CONTRAL_SPEED,(WPARAM)uPrecent,0);
		//PostMessageA(hWnd,WM_USER_CONTRAL_SPEED,(WPARAM)uPrecent,0);
		SendMessageTimeout(hWnd, WM_USER_CONTRAL_SPEED, (WPARAM)_globalWorkSizeMultiplier, (LPARAM)_msPerBatch, SMTO_ABORTIFHUNG, 200, NULL);
	}
	return 0;
}

