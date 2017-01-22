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
			MsgWndIPC::Instance()->StopMining();
			MsgWndIPC::Instance()->CloseSingletonMutex();
			::PostQuitMessage(0);
		}
		break;
	case WM_USER_START:
		{
			MsgWndIPC::Instance()->StartMining();
		}
		break;
	case WM_USER_PAUSE:
		{
			MsgWndIPC::Instance()->StopMining();
		}
		break;
	case WM_USER_CONTRAL_SPEED:
		{
			MsgWndIPC::Instance()->SetContralSpeed((uint32_t)wParam);
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
	AllowMessageToRecv(WM_USER_START, TRUE);
	AllowMessageToRecv(WM_USER_PAUSE, TRUE);
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
	m_globalWorkSizeMultiplier_Max = ethash_cl_miner::c_defaultGlobalWorkSizeMultiplier;
	m_miningThreads_Max = std::thread::hardware_concurrency();
	m_threadMiner = NULL;
	m_hEvent = CreateEvent(NULL, TRUE, TRUE, _T(WORK_EVENT));
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
	StartMining();
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

void MsgWndIPC::CloseSingletonMutex()
{
	if (m_hMutex)
	{
		ReleaseMutex(m_hMutex);
		CloseHandle(m_hMutex);
		m_hMutex = NULL;
	}
}

void MsgWndIPC::WaitWorkEvent()
{
	WaitForSingleObject(m_hEvent, INFINITE);
}

void MsgWndIPC::StartMining()
{
	if (!m_threadMiner)
	{
		SetEvent(m_hEvent);
		m_pMinerCLI->InitMinerParam();
		m_pMinerCLI->InitFarmParam();
		m_threadMiner = unique_ptr<thread>(new thread([=]() {
			setThreadName("workertd");
			m_pMinerCLI->StartMiningThread();
		}));
	}
	else if(!m_pMinerCLI->IsMining())
	{
		m_pMinerCLI->StartFarmMining();
		SetEvent(m_hEvent);

	}
}

void MsgWndIPC::StopMining()
{
	if (m_pMinerCLI->IsMining())
	{
		m_pMinerCLI->StopFarmMining();
		ResetEvent(m_hEvent);
	}
}

void MsgWndIPC::SetContralSpeed(uint32_t precent)
{
	StopMining();
	unsigned t_num = m_miningThreads_Max*precent / 100;
	m_pMinerCLI->SetCPUThreadCount(t_num == 0 ? 1 : t_num);
	unsigned multiplier = m_globalWorkSizeMultiplier_Max*precent / 100;
	m_pMinerCLI->SetGPUGWSMultiplier(multiplier == 0 ? 1 : multiplier);
	StartMining();
}

void MsgWndIPC::UpdateMineState()
{

}

void MsgWndIPC::WaitForConnectPipe()
{
	msgwndlog << "wait for connect pip";
	m_bConnectPipe = ConnectNamedPipe(m_hPipe, NULL) ?TRUE : (GetLastError() == ERROR_PIPE_CONNECTED);
	if (m_bConnectPipe)
	{
		msgwndlog << "connect pip success";
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