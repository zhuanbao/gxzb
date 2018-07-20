#pragma once
#include "MinerClient.h"

class CClientGenOil : public CMinerClient
{
public:
	CClientGenOil(UINT uClientType);
	~CClientGenOil(void);
public:
	void ProcessString(const char *szBuffer);
	void TerminateClientInstance();
	void OnAutoExit(DWORD dwExitCode);
private:
	bool IsDebug();
	void LogString(const char *szBuffer);
	void RegexString(const char *szBuffer);
	void PostWndMsg(int iMsgType, int iDetail);
	void RetSet();
	void PostErrorMsg(const char *szBuffer, const char *szBeg);
private:
	HWND m_hMsgWnd;
	int  m_DagProgress;
	//为了完整匹配输出，把上一个被截断的\r\n以后的再留到下一次
	std::string m_strLastLeft;
	UINT m_uClientType;
};

