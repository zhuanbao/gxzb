#pragma once

#include "MinerAux.h"
#include "IPCInterface.h"


#define MSG_WND_CALSS	"WorkWnd_{EFBE3E9F-DEC0-4A65-B87C-BAD1145762FD}"
#define WORK_EVENT	"WorkEvent_{EFBE3E9F-DEC0-4A65-B87C-BAD1145762FD}"
#define WORK_MUTEX	"WorkMutex_{EFBE3E9F-DEC0-4A65-B87C-BAD1145762FD}"


struct MsgWndIPCChannel : public LogChannel
{
	static const char* name() { return "msgwnd"; }
	static const bool debug = false;
};
#define msgwndlog clog(MsgWndIPCChannel)

LRESULT CALLBACK WinProc(HWND hWnd, UINT uiMsg, WPARAM wParam, LPARAM lParam);

class MsgWndIPC {

public:
	static MsgWndIPC* Instance()
	{
		static MsgWndIPC s;
		return &s;
	}
	~MsgWndIPC()
	{
		if (m_hMutex)
		{
			CloseHandle(m_hMutex);
			m_hMutex = NULL;
		}
		if (m_hEvent)
		{
			CloseHandle(m_hEvent);
			m_hEvent = NULL;
		}
		m_threadMiner->detach();
		m_threadMiner = nullptr;
	}
	bool Create(MinerCLI* m);
	void RunMsgLoop();
	void WaitWorkEvent();
	bool HandleSingleton();
	void CloseSingletonMutex();
	void StartMining();
	void StopMining();
	void SetContralSpeed(uint32_t precent);
	void UpdateMineState();
	//
	void WaitForConnectPipe();
	void WritePipeData(byte*data,UINT len);
	void ReadPipeData();

	bool FollowParentProcessExit();
private:
	HANDLE m_hParentProcess;
	HANDLE m_hMutex;
	HWND m_hWnd;
	HANDLE m_hEvent;
	HANDLE m_hPipe;
	bool m_bConnectPipe;
	MinerCLI * m_pMinerCLI;
	unique_ptr<thread> m_threadMiner;
	unsigned m_globalWorkSizeMultiplier_Max;
	unsigned m_miningThreads_Max;
};