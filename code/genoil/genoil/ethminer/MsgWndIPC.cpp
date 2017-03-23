#include "MsgWndIPC.h"
#include "MinerHelper.h"
#include "MinerHelper.h"

UINT_PTR g_uiTimerID = 110;
UINT g_uiTimerCycleInMs = 1000;

LRESULT CALLBACK WinProc(HWND hWnd, UINT uiMsg, WPARAM wParam, LPARAM lParam)
{
	switch (uiMsg)
	{
	case WM_EXIT:
		{
			msgwndlog << "begain exit process";
			//MsgWndIPC::Instance()->DestroyWindow();
			MsgWndIPC::Instance()->CloseSingletonMutex();
			MsgWndIPC::Instance()->Quit();
			MsgWndIPC::Instance()->WaitThreadExit();
			PostQuitMessage(0);
			msgwndlog << "end exit process";
			exit(0);
		}
		break;
	case WM_USER_PAUSE:
		{
			msgwndlog << "begain pause process";
			//MsgWndIPC::Instance()->DestroyWindow();
			MsgWndIPC::Instance()->CloseSingletonMutex();
			MsgWndIPC::Instance()->Quit();
			MsgWndIPC::Instance()->WaitThreadExit();
			PostQuitMessage(0);
			msgwndlog << "end pause process";
			exit(0);
		}
		break;
	case WM_USER_CONTRAL_SPEED:
		{
			MsgWndIPC::Instance()->SetControlSpeed((uint32_t)wParam, (uint32_t)lParam);
		}
		break;
	case WM_TIMER:
		{
			if (wParam == g_uiTimerID)
			{
				if (!MsgWndIPC::Instance()->FollowParentProcessExit())
				{
					::KillTimer(hWnd, g_uiTimerID);
					MsgWndIPC::Instance()->UpdateMineState();
					::SetTimer(hWnd, g_uiTimerID, g_uiTimerCycleInMs, NULL);
				}
			}
		}
		break;
	default:
		return ::DefWindowProc(hWnd, uiMsg, wParam, lParam);
	}
	return 0;
}

bool MsgWndIPC::Create(MinerCLI* pMinerCLI)
{
	AllowMessageToRecv(WM_EXIT, TRUE);
	AllowMessageToRecv(WM_USER_PAUSE, TRUE);
	AllowMessageToRecv(WM_USER_START, TRUE);
	AllowMessageToRecv(WM_USER_CONTRAL_SPEED, TRUE);
	HINSTANCE instance = GetModuleHandle(NULL);
	TCHAR* lpWndClassName = _T(MSG_WND_CALSS);
	WNDCLASS wc;
	::ZeroMemory(&wc, sizeof(wc));
	wc.style = CS_HREDRAW | CS_VREDRAW;
	wc.lpszClassName = lpWndClassName;
	wc.lpfnWndProc = (WNDPROC)WinProc;
	wc.hInstance = instance;
	if (!::RegisterClass(&wc)) {
		DWORD dwLastError = ::GetLastError();
		msgwndlog << "msg wnd register class failed, dwLastError = " << dwLastError;
		return false;
	}
	m_hWnd = ::CreateWindow(lpWndClassName, NULL, WS_POPUP, 0, 0, 50, 50, NULL, NULL, instance, NULL);
	DWORD dwLastError = ::GetLastError();
	if (!m_hWnd) {
		msgwndlog << "msg wnd create failed, dwLastError = " << dwLastError;
		return false;
	}

	m_pMinerCLI = pMinerCLI;
	
	m_hQuitEvent = CreateEvent(NULL, TRUE, FALSE, _T(QUIT_EVENT));
	m_hPipe = CreateNamedPipe(
		IPC_PIPE_NAME,             // pipe name   
		PIPE_ACCESS_DUPLEX,       // read/write access   
		PIPE_TYPE_MESSAGE |       // message type pipe   
		PIPE_READMODE_MESSAGE |   // message-read mode   
		PIPE_WAIT,                // blocking mode   
		PIPE_UNLIMITED_INSTANCES, // max. instances    
		MAX_PIPE_BUFFIE_LEN,                  // output buffer size   
		MAX_PIPE_BUFFIE_LEN,                  // input buffer size   
		0,                        // client time-out   
		NULL);                    // default security attribute   

	if (m_hPipe == INVALID_HANDLE_VALUE)
	{
		return false;
	}
	m_hParentProcess = GetParentProcessHandle();
	::SetTimer(m_hWnd, g_uiTimerID, g_uiTimerCycleInMs, NULL);
	Start();
	return true;
}


void MsgWndIPC::RunMsgLoop()
{
	ShowWindow(m_hWnd, SW_HIDE);
	UpdateWindow(m_hWnd);
	MSG msg;
	while (GetMessage(&msg, m_hWnd, 0, 0))
	{
		TranslateMessage(&msg);
		DispatchMessage(&msg);
	}

}

bool MsgWndIPC::HandleSingleton()
{
	static TCHAR szMutex[_MAX_PATH] = { 0 };
	_sntprintf(szMutex, _MAX_PATH, _T("#mutex%s_%s"), WORK_MUTEX, _T("1.0"));
	m_hMutex = CreateMutex(NULL, true, szMutex);
	bool bExist = (ERROR_ALREADY_EXISTS == ::GetLastError() || ERROR_ACCESS_DENIED == ::GetLastError());
	if (bExist)
	{
		ReleaseMutex(m_hMutex);
		CloseHandle(m_hMutex);
		return true;
	}
	return false;
}

void MsgWndIPC::DestroyWindow()
{
	msgwndlog <<"destroy window";
	::DestroyWindow(m_hWnd);
}
void MsgWndIPC::CloseSingletonMutex()
{
	if (m_hMutex)
	{
		ReleaseMutex(m_hMutex);
		CloseHandle(m_hMutex);
		m_hMutex = NULL;
	}
}

bool MsgWndIPC::WaitQuitEvent()
{
	if (WAIT_TIMEOUT == ::WaitForSingleObject(m_hQuitEvent, 0))
	{
		return false;
	}
	return true;
}

void MsgWndIPC::Start()
{
	m_pMinerCLI->InitOpenCLParam();
	m_threadMiner = unique_ptr<thread>(new thread([=]() {
		setThreadName("worker");
		m_pMinerCLI->start();
	}));
}

void MsgWndIPC::Pause()
{
	//m_pMinerCLI->quit();
	SetEvent(m_hQuitEvent);
}

void MsgWndIPC::Quit()
{
	//m_pMinerCLI->quit();
	SetEvent(m_hQuitEvent);
}

void MsgWndIPC::SetControlSpeed(unsigned _globalWorkSizeMultiplier, unsigned _msPerBatch)
{
	if (IsDebug())
	{
		msgwndlog << "control speed _globalWorkSizeMultiplier = " << _globalWorkSizeMultiplier << ", _msPerBatch = " << _msPerBatch;
	}
	m_pMinerCLI->setSpeedLimitParam(_globalWorkSizeMultiplier, _msPerBatch);
}

void MsgWndIPC::UpdateMineState()
{

}

void MsgWndIPC::WaitForConnectPipe()
{
	if (IsDebug())
	{
		msgwndlog << "wait for connect pip";
	}
	m_bConnectPipe = ConnectNamedPipe(m_hPipe, NULL) ?TRUE : (GetLastError() == ERROR_PIPE_CONNECTED);
	if (m_bConnectPipe)
	{
		if (IsDebug())
		{
			msgwndlog << "connect pip success";
		}
	}
}

void MsgWndIPC::WritePipeData(byte*data, UINT len)
{
	if (m_bConnectPipe)
	{
		DWORD dwWritten = 0;
		BOOL bSuc = WriteFile(m_hPipe, data, len, &dwWritten, NULL);
		DWORD dwLastError = GetLastError();
		if (!bSuc)
		{
			FlushFileBuffers(m_hPipe);
			DisconnectNamedPipe(m_hPipe);
			m_bConnectPipe = false;
			//msgwndlog << "write pipe data failed, dwLastError = " << dwLastError;
		}
		else
		{
			//msgwndlog << "write pipe data success";
		}
	}
}

void MsgWndIPC::ReadPipeData()
{
	if (m_bConnectPipe)
	{
		byte pBuff[MAX_PIPE_BUFFIE_LEN] = { 0 };
		DWORD dwReaded = 0;
		BOOL bSuc = ReadFile(
			m_hPipe,        // handle to pipe   
			pBuff,    // buffer to receive data   
			MAX_PIPE_BUFFIE_LEN, // size of buffer   
			&dwReaded, // number of bytes read   
			NULL);        // not overlapped I/O   

		if (!bSuc)
		{
			if (GetLastError() == ERROR_BROKEN_PIPE)
			{
				//_tprintf(TEXT("InstanceThread: client disconnected.\n"), GetLastError());
			}
			else
			{
				//_tprintf(TEXT("InstanceThread ReadFile failed, GLE=%d.\n"), GetLastError());
			}
			FlushFileBuffers(m_hPipe);
			DisconnectNamedPipe(m_hPipe);
			m_bConnectPipe = false;
		}
		else if(dwReaded > 0)
		{

		}
	}
}


bool MsgWndIPC::FollowParentProcessExit()
{
	if (m_hParentProcess && WAIT_OBJECT_0 == ::WaitForSingleObject(m_hParentProcess, 0))
	{
		CloseHandle(m_hParentProcess);
		m_hParentProcess = NULL;
		SendMessageA(m_hWnd, WM_EXIT, 0, 0);
		return true;
	}
	return false;
}

//ÅÅ³ýintelÆ½Ì¨cpu
//http://www.cnblogs.com/mikewolf2002/archive/2012/09/05/2671261.html
//cl_uint numPlatforms;
//std::string platformVendor;
//status = clGetPlatformIDs(0, NULL, &numPlatforms);
//if (status != CL_SUCCESS)
//{
//	return 0;
//}
//if (0 < numPlatforms)
//{
//	cl_platform_id* platforms = new cl_platform_id[numPlatforms];
//	status = clGetPlatformIDs(numPlatforms, platforms, NULL);
//
//	char platformName[100];
//	for (unsigned i = 0; i < numPlatforms; ++i)
//	{
//		status = clGetPlatformInfo(platforms[i],
//			CL_PLATFORM_VENDOR,
//			sizeof(platformName),
//			platformName,
//			NULL);
//
//		platform = platforms[i];
//		platformVendor.assign(platformName);
//
//		if (!strcmp(platformName, "Advanced Micro Devices, Inc."))
//		{
//			break;
//		}
//	}
//
//	std::cout << "Platform found : " << platformName << "\n";
//	delete[] platforms;
//}
