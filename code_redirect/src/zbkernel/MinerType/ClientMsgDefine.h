#pragma once
/*定义挖矿客户端类型*/
typedef enum
{
	CLIENT_ETC_64 = 1,
	CLIENT_ZCASH_N_64 = 2,
	CLIENT_ZCASH_A_64 = 3,
	CLIENT_XMR_N_64 = 4,
	CLIENT_XMR_A_64 = 5,
	CLIENT_XMR_A_32 = 6,
	CLIENT_XMR_C_32 = 7,
	CLIENT_UT_C_64 = 8
}ClientType;


typedef struct _CLIENTMSG
{
	UINT uClientType;
	int	 iMsgType;    // 消息类别
	int	 iDetail;  // Host端口号.
}CLIENTMSG;

#define WM_CLIENT_MSG           WM_USER+200
//iMsgType定义
//速度
#define MSG_TYPE_SPEED		    1
//上报DAG进度
#define MSG_TYPE_UNKNOW	        2
//share提交结果
#define MSG_TYPE_SHARE         3
//连接矿次结果
#define MSG_TYPE_CONNECT_POOL	4
//进程自动退出
#define MSG_TYPE_AUTOEXIT	    5

//进程自动退出
#define MSG_TYPE_ERROR_INFO	    9


//错误信息
#define WM_ERROR_INFO      WM_USER+100
#define MAX_ERROR_LEN      200

///***************************************************/
////GenOil 客户端的消息定义
//#define WM_GENOIL_MSG           WM_USER+200
//
////WPARAM定义
////上报速度
//#define WP_GENOIL_SPEED		    1
////上报DAG进度
//#define WP_GENOIL_DAG	        2
////share提交结果
//#define WP_GENOIL_SHARE         3
////连接矿次结果
//#define WP_GENOIL_CONNECT_POOL	4
//
//
////错误
////进程自动退出
//#define WP_GENOIL_AUTOEXIT	    5
////解析到错误信息
//#define WP_GENOIL_ERROR_INFO    9
///***************************************************/
//
//
///***************************************************/
////Zcash N卡 客户端的消息定义
//#define WM_ZCASH_N_MSG           WM_USER+300
//
////WPARAM定义
////上报速度
//#define WP_ZCASH_N_SPEED		 1
////GPU温度
//#define WP_ZCASH_N_GPUTEMP       2 
////share提交结果
//#define WP_ZCASH_N_SHARE         3
////连接矿次结果
//#define WP_ZCASH_N_CONNECT_POOL	 4
//
//
////错误
////进程自动退出
//#define WP_ZCASH_N_AUTOEXIT	    5
////解析到错误信息
//#define WP_ZCASH_N_ERROR_INFO    9
///***************************************************/
//
//
///***************************************************/
////Zcash A卡 客户端的消息定义
//#define WM_ZCASH_A_MSG           WM_USER+400
//
////WPARAM定义
////上报速度
//#define WP_ZCASH_A_SPEED		 1
////GPU温度
//#define WP_ZCASH_A_GPUTEMP       2 
////share提交结果
//#define WP_ZCASH_A_SHARE         3
////连接矿次结果
//#define WP_ZCASH_A_CONNECT_POOL	 4
//
//
////错误
////进程自动退出
//#define WP_ZCASH_A_AUTOEXIT	    5
////解析到错误信息
//#define WP_ZCASH_A_ERROR_INFO    9
///***************************************************/
//
//
///***************************************************/
////Xmr 客户端的消息定义
//#define WM_XMR_MSG           WM_USER+500
//
////WPARAM定义
////上报速度
//#define WP_XMR_SPEED		 1
//
////share提交结果
//#define WP_XMR_SHARE         2
////连接矿次结果
//#define WP_XMR_CONNECT_POOL	 3
//
//
////错误
////进程自动退出
//#define WP_XMR_AUTOEXIT	    5
////解析到错误信息
//#define WP_XMR_ERROR_INFO    9
///***************************************************/
//
//
//
///***************************************************/
////UT 客户端的消息定义
//#define WM_UT_MSG           WM_USER+600
//
////WPARAM定义
////上报速度
//#define WP_UT_SPEED		 1
//
////share提交结果
//#define WP_UT_SHARE         2
////连接矿次结果
//#define WP_UT_CONNECT_POOL	 3
//
//
////错误
////进程自动退出
//#define WP_UT_AUTOEXIT	    5
////解析到错误信息
//#define WP_UT_ERROR_INFO    9
///***************************************************/
//
////错误信息
//#define WM_ERROR_INFO      WM_USER+100
//#define MAX_ERROR_LEN      200