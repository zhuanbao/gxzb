#include "stdafx.h"
#include "DownLoadKernel.h"
#include "ProgressWrap.h"


CProgressWrap::CProgressWrap(CHttpDownLoad * pTD, void (*fnOnProgress)(const string &, DWORD, float,  float))
{
	m_hEvent = NULL;
	m_pTD = pTD;
	m_OnProgress = fnOnProgress;
}

CProgressWrap::~CProgressWrap()
{
	m_OnProgress = NULL;
	m_pTD = NULL;
	if (m_hEvent)
	{
		CloseHandle(m_hEvent);
		m_hEvent = NULL;
	}
}


void * CProgressWrap::run(void *)
{	
	DWORD dwFileSize = 0;
	DWORD dwLastFinishedSize = 0;
	ULONGLONG uLastTime = ::GetTickCount64();;
	while (WAIT_TIMEOUT == WaitForSingleObject(m_hEvent, 500))
	{
		string strUrl = m_pTD->GetRemoteUrl();
		if (0 == dwFileSize)
		{
			dwFileSize = m_pTD->GetTotalFileSize();
		}
		float fSpeed = 0.0f;
		float fPercent = 0.0f;
		if (dwFileSize > 0)
		{
			DWORD dwNewFinishedSize = m_pTD->GetFinishedSize();	
			ULONGLONG uNewTime = ::GetTickCount64();
			ULONGLONG uSpan = uNewTime - uLastTime;
			if (dwNewFinishedSize > dwLastFinishedSize)
			{
				fSpeed = (float)(dwNewFinishedSize-dwLastFinishedSize)/(uSpan/1000);
				uLastTime = uNewTime;
				dwLastFinishedSize = dwNewFinishedSize;
				fPercent = (float)dwLastFinishedSize/dwFileSize;
			}
			else
			{
				continue;
			}
		}
		
		m_OnProgress(strUrl, dwFileSize, fPercent, fSpeed);
	}
	return NULL;
}

void CProgressWrap::Start()
{	
	m_hEvent = CreateEvent(NULL,TRUE,FALSE,NULL);
	this->start();
}

void CProgressWrap::Stop()
{	
	::SetEvent(m_hEvent);
	this->join();
}