#pragma once
#include "MinerClient.h"

class CClientUt : public CMinerClient
{
public:
	CClientUt(UINT uClientType);
	~CClientUt(void);
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
	//Ϊ������ƥ�����������һ�����ضϵ�\r\n�Ժ����������һ��
	std::string m_strLastLeft;
	UINT m_uClientType;
	std::wstring m_strClientName;
};