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
	//为了完整匹配输出，把上一个被截断的\r\n以后的再留到下一次
	std::string m_strLastLeft;
};

