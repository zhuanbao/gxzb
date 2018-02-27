#pragma once
#include "Thread.h"
class CProgressWrap:public Thread
{
public:
	CProgressWrap(CHttpDownLoad * pTD, void (*fnOnProgress)(const string &, DWORD, float,  float));
	~CProgressWrap();
public:
	void Start();
	void Stop();
	void * run(void *);
private:
	void (*m_OnProgress)(const string &, DWORD, float,  float);
	HANDLE m_hEvent;
	CHttpDownLoad * m_pTD;
};