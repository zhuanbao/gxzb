#pragma once

#include <vector>
#include <string>
#include <iostream>
using namespace std;
#include "Thread.h"
#include <map>
#include "..\Utility\Lock.h"

//重连时间
#define RECONNECT_INTERVAL 10000	
#define RECONNECT_COUNT 10

class CDownLoadWrap: public Thread
{
public:
	CDownLoadWrap();
	~CDownLoadWrap();
public:
	void * run(void *);
	BOOL StartDownload();
	BOOL AddDownloadTask(const string& strUrl, const string& strFolder);
	//传入函数指针
	void SetOnProgress(void (*func)(const string &, DWORD , float ,  float ))
	{
		m_OnProgress = func;
	}
	void SetOnFinish(void (*func)(const string &, const string &))
	{
		m_OnFinish = func;
	}
	void SetOnError(void (*func)(const string &, DWORD))
	{
		m_OnError = func;
	}
private:
	typedef std::map<string, string> TaskMap;
	typedef TaskMap::iterator TaskMapIte;
	TaskMap m_mapTaskList;
	
	//void (*m_OnFinish)(string &strUrl, DWORD &dwFileSize, DWORD &dwPrecent,  DWORD &dwSpeed);
	void (*m_OnProgress)(const string &, DWORD, float,  float);
	void (*m_OnFinish)(const string &, const string&);
	void (*m_OnError)(const string &, DWORD);
private:

	BOOL Exist(const string& strPath);

};



