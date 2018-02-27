#pragma once
#define MSG_WND_CALSS	"WorkWnd_{EFBE3E9F-DEC0-4A65-B87C-BAD1145762FD}"
//开始
#define WM_USER_START				WM_USER+100
//暂停
#define WM_USER_PAUSE				WM_USER+101
//限制线程数，填0不做限制
#define WM_USER_CONTRAL_SPEED		WM_USER+102

//退出程序
#define WM_EXIT						WM_USER+99

#define IPC_PIPE_NAME	"\\\\.\\pipe\\IPC_{EFBE3E9F-DEC0-4A65-B87C-BAD1145762FD}"
#define MAX_PIPE_BUFFIE_LEN		1024 


typedef enum
{
	MING_CHECK_DAG = 1,
	MING_CALCULATE_DAG,
	MING_MINING_SPEED,
	MING_MINING_EEEOR,
	MING_SOLUTION_FIND
} MineMsgType;

typedef enum
{
	MING_DAG_CHECKING = 1,
	MING_DAG_SUNCCESS,
	MING_DAG_FAIL
}DAGState;

struct MineCheckDAG
{
	UINT uSize;
	UINT uType;
	UINT uState;

};

struct MineCalculateDAG
{
	UINT uSize;
	UINT uType;
	UINT uPrecent;

};

struct MineMiningSpeed
{
	UINT uSize;
	UINT uType;
	ULONG64 uRate;
};

typedef enum
{
	JSON_RPC_CONNECT,
	No_WORK
}MinerErrorCode;

struct MineMiningError
{
	UINT uSize;
	UINT uType;
	UINT uErrorCode;
};

struct MineSolutionFind
{
	UINT uSize;
	UINT uType;
	char szNonce[MAX_PATH];
	char szHeaderHash[MAX_PATH];
	char szMixHash[MAX_PATH];
};

//////////////////////////////////////////////////////////////////
//发送的消息


typedef enum
{
	USER_POOL_CHANGE
} UserMsgType;

struct UserPoolChange
{
	UINT uType;
	char szUrl[MAX_PATH];
};









//inline GetSeverProcPath()
//{
//	//CHAR szExePath[MAX_PATH] = {0};
//	//GetModuleFileNameA(NULL, szExePath, MAX_PATH);
//	//PathRemoveFileSpecA(szExePath);
//}