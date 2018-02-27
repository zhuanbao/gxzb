#pragma once
#define WM_P2SDOWNLOADPROGRESS           WM_USER+100
#define WM_P2SDOWNLOADERROR              WM_USER+101
#define WM_P2SDOWNLOADFINISH             WM_USER+102

typedef struct _P2S_DOWNLOAD_PROGRESS
{
	std::string strUrl;
	DWORD dwFileSize;
	float fPercent;
	float fSpeed;
}P2S_DOWNLOAD_PROGRESS;

typedef struct _P2S_DOWNLOAD_FINISH
{
	std::string strUrl;
	std::string strPath;
}P2S_DOWNLOAD_FINISH;

typedef struct _P2S_DOWNLOAD_ERROR
{
	std::string strUrl;
	DWORD dwCode;
}P2S_DOWNLOAD_ERROR;