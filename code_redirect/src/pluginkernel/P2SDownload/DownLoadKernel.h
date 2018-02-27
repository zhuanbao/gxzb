#ifndef DOWNLOADKERNRL_H
#define DOWNLOADKERNRL_H
#include "..\Utility\Lock.h"
#include "DealSocket.h"
#include "FileHelper.h"
using namespace std;
class  CHttpDownLoad;
typedef struct __TD_PARAM
{
	CHttpDownLoad *pHttpDownLoad;
	int iSectIdx;
}TD_PARAM;

typedef struct __CHTTPDOWNLOADSECT
{
	string   strHost;      // Host地址.
	int      nPort;       // Host端口号.
	string   strHttpAddr;      // Http文件地址(不包含文件名)
	string   strHttpFileName;  // Http文件名.
	string   strTmpFilePath;   // 下载后的临时文件.
	DWORD    nStart;          // 分割的起始位置.
	DWORD    nEnd;            // 分割的起始位置. 
}CHTTPDOWNLOADSECT;

class  CHttpDownLoad  
{
public:
	CHttpDownLoad();
	virtual ~CHttpDownLoad();
public:
	DWORD GetTotalFileSize();
	DWORD GetFinishedSize();//总共已经完成的,包含上次下载的
	string GetRemoteUrl();
public:
	string Start(const string& strUrl, const string& strFolder,UINT nThreadCnt = 3);
	BOOL ThreadWorking(int iSectIdx);
private:
	string m_strUrl;
	DWORD m_nFileSize;


	//断点续传分块
	CHTTPDOWNLOADSECT *m_sect;
	//线程同步变量
	mutable XMLib::CriticalSection m_cs;

	int m_nCount;//线程完成计数器
	DWORD m_nFinishedSize;//总共已经完成的

	static CDealSocket sm_DealSocket;
	static CFileHelper sm_FileHelper;
private:
	BOOL HttpDownLoad(UINT nThreadCnt, const string& strHost, int nPort, const string& strHttpAddr, const string& strHttpFileName, const string& strDownLoadPath);
private:
	
	SOCKET ConnectServer(const string& strHost,int nPort);
	string SendHttpHeader(SOCKET hSocket, const string& strHost, const string& strHttpAddr, const string& strHttpFileName,DWORD nPos);
	BOOL ParseHeader(string strHead, DWORD &dwSize);
	DWORD GetHttpHeader(SOCKET hSocket,char *szHeadBuffer);
	BOOL SocketSend(SOCKET hSocket,const string& strSend);
	
	int GetResponseCode(const string& strResponse);
	string GetHeadValueByKey(const string& strHead, char *szKey);
	BOOL FileCombine(int iSectIdx, FILE *fpwrite);
};









#endif