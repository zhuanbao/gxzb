#pragma once
#include "MinerClient.h"

class CClientGenOil : public CMinerClient
{
public:
	CClientGenOil(void);
	~CClientGenOil(void);
public:
	void ProcessString(const char *szBuffer);
	void TerminateAllClientInstance();
	void OnAutoExit(DWORD dwExitCode);
private:
	bool IsDebug();
	void LogString(const char *szBuffer);
	void RegexString(const char *szBuffer);
	void PostWndMsg(WPARAM wParam, LPARAM lParam);
	void RetSet();
private:
	HWND m_hMsgWnd;
	int  m_DagProgress;
};

