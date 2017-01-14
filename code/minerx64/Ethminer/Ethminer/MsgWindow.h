#pragma once
#include <tchar.h>
#include <vector>
#include <Windows.h>
#include <thread>
#include <iostream>
#include <shlobj.h>
#include <Shlwapi.h>
#include <libethashseal/EthashGPUMiner.h>
#include <libethashseal/EthashCPUMiner.h>
using namespace std;
using namespace dev;
using namespace dev::eth;

//开始
#define WM_USER_START				WM_USER+100
//暂停
#define WM_USER_PAUSE				WM_USER+101
//限制线程数，填0不做限制
#define WM_USER_LMT_THRDNUMB		WM_USER+102

unique_ptr<thread> g_msgthread;
HANDLE g_pasuEvent;
GenericFarm<EthashProofOfWork>* g_pfarm = NULL;
string g_minertype;

struct GPUParam {
	unsigned _localworksize;
	unsigned _globalworksizemultiplier;
	unsigned _perbatch;
	unsigned _openclplatform;
	unsigned _opencldevice;
	bool _allowcpu;
	unsigned _extramemory;
	uint64_t _curbloack;
	std::vector<uint32_t> _v_deviceid;
};
GPUParam g_GPUParam;

unsigned g_CPU_MAX_Thread_Num;


#define MSG_WND_CALSS	"WorkWnd_{EFBE3E9F-DEC0-4A65-B87C-BAD1145762FD}"
#define WORK_EVENT	"WorkEvent_{EFBE3E9F-DEC0-4A65-B87C-BAD1145762FD}"
#define WORK_MUTEX	"WorkMutex_{EFBE3E9F-DEC0-4A65-B87C-BAD1145762FD}"


class MsgWindow {
public:
	static LRESULT CALLBACK MyWinProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam)
	{
		switch (msg)
		{
		case WM_CREATE:
			cout << "WM_CREATE" << endl;
			g_pasuEvent = CreateEvent(NULL, TRUE, TRUE, _T(WORK_EVENT));
			break;
		case WM_CLOSE:
			cout << "WM_CLOSE" << endl;
			//TerminateProcess(GetCurrentProcess(), 0);
			g_pfarm->stop();
			CloseSingletonMutex();
			exit((uint32_t)wparam);
			//g_msgthread.reset();
			return 0;
			//break;
		case WM_USER_START:
			cout << "WM_USER_START" << endl;
			g_pfarm->start(g_minertype);
			SetEvent(g_pasuEvent);
			break;
		case WM_USER_PAUSE:
			cout << "WM_USER_PAUSE" << endl;
			ResetEvent(g_pasuEvent);
			g_pfarm->stop();
			break;
		case WM_USER_LMT_THRDNUMB:
		{
			cout << "WM_USER_LMT_THRDNUMB " << wparam << ", " << lparam << endl;
			uint32_t precent = uint32_t(wparam);
			if (precent > 100 || precent < 0)
			{
				break;
			}
			//先停止
			ResetEvent(g_pasuEvent);
			g_pfarm->stop();
			if (stricmp(g_minertype.c_str(), "cpu") == 0)
			{
				unsigned t_num = g_CPU_MAX_Thread_Num*precent / 100;
				EthashCPUMiner::setNumInstances(t_num == 0 ? 1 : t_num);
			}
			else
			{
				unsigned multiplier = g_GPUParam._globalworksizemultiplier*precent / 100;
				if (!EthashGPUMiner::configureGPU(
					g_GPUParam._localworksize,
					g_GPUParam._localworksize*(multiplier == 0 ? 1 : multiplier),
					g_GPUParam._perbatch,
					g_GPUParam._openclplatform,
					g_GPUParam._opencldevice,
					g_GPUParam._allowcpu,
					g_GPUParam._extramemory,
					g_GPUParam._curbloack,
					g_GPUParam._v_deviceid
				))
					exit(1);
			}

			g_pfarm->start(g_minertype);
			SetEvent(g_pasuEvent);
			break;
		}
		default:
			break;
		}
		return ::DefWindowProc(hwnd, msg, wparam, lparam);

	};
	static BOOL AllowMessageToRecv(UINT uiMsg, BOOL bAllowed)
	{
		BOOL bSuc = FALSE;
		TCHAR szUser32DllFilePath[MAX_PATH] = { 0 };
		if (SUCCEEDED(::SHGetFolderPath(NULL, CSIDL_SYSTEM, NULL, 0, szUser32DllFilePath))
			&& ::PathAppend(szUser32DllFilePath, _T("user32.dll"))) {
			if (::PathFileExists(szUser32DllFilePath) && !::PathIsDirectory(szUser32DllFilePath)) {
				HMODULE hUser32Dll = ::LoadLibrary(szUser32DllFilePath);
				if (hUser32Dll) {
					typedef BOOL(__stdcall *PFN_ChangeWindowMessageFilter)(UINT, DWORD);
					PFN_ChangeWindowMessageFilter pfnChangeWindowMessageFilter = (PFN_ChangeWindowMessageFilter)::GetProcAddress(hUser32Dll, "ChangeWindowMessageFilter");
					if (pfnChangeWindowMessageFilter) {
						bSuc = (*pfnChangeWindowMessageFilter)(uiMsg, (bAllowed ? 1 : 2)); // 1 - MSGFLT_ADD; 2 - MSGFLT_REMOVE
					}
					::FreeLibrary(hUser32Dll);
				}
			}
		}
		return bSuc;
	};
	static void WINAPI Create(BOOL bAsyn = FALSE)
	{
		function<void()> fnThread = [&]()
		{
			//cout << "MsgWindow Entry....." << endl;
			AllowMessageToRecv(WM_USER_START, TRUE);
			AllowMessageToRecv(WM_USER_PAUSE, TRUE);
			AllowMessageToRecv(WM_USER_LMT_THRDNUMB, TRUE);
			HINSTANCE instance = GetModuleHandle(NULL);
			TCHAR* lpWndClassName = _T(MSG_WND_CALSS);
			WNDCLASS wc;
			::ZeroMemory(&wc, sizeof(wc));
			wc.style = CS_HREDRAW | CS_VREDRAW;
			wc.lpszClassName = lpWndClassName;
			wc.lpfnWndProc = (WNDPROC)MyWinProc;
			wc.hInstance = instance;
			if (!::RegisterClass(&wc)) {
				DWORD lastError = ::GetLastError();
				cout << "MsgWindow RegisterClass Failed!!!!!" << lastError << endl;
				return;
			}
			HWND hwnd = ::CreateWindow(lpWndClassName, NULL, WS_POPUP, 0, 0, 50, 50, NULL, NULL, instance, NULL);
			DWORD lastError = ::GetLastError();
			if (!hwnd) {
				cout << "MsgWindow Create Failed!!!!!" << lastError << endl;
				return;
			}
			cout << "MsgWindow wait msg....." << endl;
			ShowWindow(hwnd, SW_HIDE);
			UpdateWindow(hwnd);
			MSG msg;
			while (GetMessage(&msg, hwnd, 0, 0))
			{
				TranslateMessage(&msg);
				DispatchMessage(&msg);
			}
		};
		if (bAsyn) {
			g_msgthread.reset(new thread(fnThread));
		}
		else {
			fnThread();
		}

	};
	static void WaitPauseEvent(GenericFarm<EthashProofOfWork>* pFarm, std::string& _m, std::function<void()> const& _f) {
		if (g_pfarm == NULL) {
			g_pfarm = pFarm;
			g_minertype = _m;
		}
		if (g_pasuEvent) {
			WaitForSingleObject(g_pasuEvent, INFINITE);
		}
		_f();
	};

	static void SetGPUParam(
		unsigned _localWorkSize,
		unsigned _globalWorkSizeMultiplier,
		unsigned _msPerBatch,
		unsigned _platformId,
		unsigned _deviceId,
		bool _allowCPU,
		unsigned _extraGPUMemory,
		uint64_t _currentBlock,
		std::vector<uint32_t> _v_deviceID) {

		cout << "SetGPUParam :" << endl
			<< "_localWorkSize :" << _localWorkSize << endl
			<< "_globalWorkSizeMultiplier :" << _globalWorkSizeMultiplier << endl
			<< "_msPerBatch :" << _msPerBatch << endl
			<< "_platformId :" << _platformId << endl
			<< "_deviceId :" << _deviceId << endl
			<< "_allowCPU :" << _allowCPU << endl
			<< "_extraGPUMemory :" << _extraGPUMemory << endl
			<< "_currentBlock :" << _currentBlock << endl;

		g_GPUParam._localworksize = _localWorkSize;
		g_GPUParam._globalworksizemultiplier = _globalWorkSizeMultiplier;
		g_GPUParam._perbatch = _msPerBatch;
		g_GPUParam._openclplatform = _platformId;
		g_GPUParam._opencldevice = _deviceId;
		g_GPUParam._allowcpu = _allowCPU;
		g_GPUParam._extramemory = _extraGPUMemory;
		g_GPUParam._curbloack = _currentBlock;
		g_GPUParam._v_deviceid = _v_deviceID;
	};
	static void SetCPUMaxThread(unsigned num)
	{
		cout << "SetCPUMaxThread : " << num << endl;
		g_CPU_MAX_Thread_Num = num;
	}

	static bool HandleSingleton()
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
	static void CloseSingletonMutex()
	{
		if (m_hMutex)
		{
			ReleaseMutex(m_hMutex);
			CloseHandle(m_hMutex);
			m_hMutex = NULL;
		}
	}
private:
	static HANDLE m_hMutex;
};
HANDLE MsgWindow::m_hMutex = NULL;