#include "stdafx.h"
#include "DownLoadWrap.h"
#include <io.h>
#include "DownLoadKernel.h"
#include "ProgressWrap.h"

CDownLoadWrap::CDownLoadWrap()
{
	m_mapTaskList.clear();
	m_OnProgress = NULL;
	m_OnFinish = NULL;
	m_OnError = NULL;
}

CDownLoadWrap::~CDownLoadWrap()
{

}

//添加下载任务，以传入的url作为唯一标识符
BOOL CDownLoadWrap::AddDownloadTask(const string& strUrl, const string& strFolder)
{
	if (m_mapTaskList.end() != m_mapTaskList.find(strUrl))
	{
		return FALSE;
	}
	m_mapTaskList.insert(std::make_pair(strUrl, strFolder));
	return TRUE;
}

//开始下载
BOOL CDownLoadWrap::StartDownload()
{
	this->start();
	return TRUE;
}

//多线程重构函数
void * CDownLoadWrap::run(void *)
{	
	int nReTryCnt = 0;
	while(m_mapTaskList.size()>0)
	{
		
		while(true){
			TaskMapIte iter = m_mapTaskList.begin();
			printf("start task [%s]\r\n", iter->first.c_str());
			CHttpDownLoad td;
			CProgressWrap progress(&td,m_OnProgress) ;
			progress.Start();
			string strDownLoadPath =  td.Start(iter->first, iter->second);
			//这里阻塞直到一个下载完成
			if(strDownLoadPath.empty() || !Exist(strDownLoadPath))
			{
				if (nReTryCnt >= RECONNECT_COUNT)
				{
					nReTryCnt = 0;
					m_OnError(iter->first, 1);
					m_mapTaskList.erase(iter);
					break;
				}
				else
				{
					nReTryCnt++;
					printf("download task [%s] fail,wait to connect...\r\n", iter->first.c_str());
					m_OnError(iter->first, 0);
					progress.Stop();
					Sleep(RECONNECT_INTERVAL);	//10秒后重连
				}
			}
			else
			{
				progress.Stop();
				//下载成功，删除第一个任务
				nReTryCnt = 0;
				m_OnFinish(iter->first, strDownLoadPath.c_str());
				m_mapTaskList.erase(iter);
				break;	
			}
		}
    }
	return NULL;
}

//判断下载列表的文件是否已经存在
BOOL CDownLoadWrap::Exist(const string& strPath)
{
	return (_access(strPath.c_str(), 0) == 0);
}