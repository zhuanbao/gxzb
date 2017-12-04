#pragma once
#include "MinerClient.h"

class CClientXmr : public CMinerClient
{
public:
	CClientXmr(UINT uMinerType);
	~CClientXmr(void);
public:
	void ProcessString(const char *szBuffer);
	void TerminateAllClientInstance();
	void OnAutoExit(DWORD dwExitCode);
	void SetMinerType(UINT uNewMinerType) 
	{
		m_uMinerType = uNewMinerType;
	}
private:
	bool IsDebug();
	void LogString(const char *szBuffer);
	void RegexString(const char *szBuffer);
	void PostWndMsg(WPARAM wParam, LPARAM lParam);
	void RetSet();
	void PostErrorMsg(const char *szBuffer, const char *szBeg);
private:
	HWND m_hMsgWnd;
	//为了完整匹配输出，把上一个被截断的\r\n以后的再留到下一次
	std::string m_strLastLeft;
	UINT m_uMinerType;
};