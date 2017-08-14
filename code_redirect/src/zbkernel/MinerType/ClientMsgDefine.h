#pragma once
//GenOil 客户端的消息定义
#define WM_GENOIL_MSG           WM_USER+200

//WPARAM定义
//上报速度
#define WP_GENOIL_SPEED		    1
//上报DAG进度
#define WP_GENOIL_DAG	        2
//share提交结果
#define WP_GENOIL_SHARE         3
//连接矿次结果
#define WP_GENOIL_CONNECT_POOL	4


//错误
//进程自动退出
#define WP_GENOIL_AUTOEXIT	    5
//解析到错误信息
#define WP_GENOIL_ERROR_INFO    6
#define WP_GENOIL_ERROR_OPENCL  7


//Zcash N卡 客户端的消息定义
#define WM_ZCASH_N_MSG           WM_USER+300

//WPARAM定义
//上报速度
#define WP_ZCASH_N_SPEED		 1
//GPU温度
#define WP_ZCASH_N_GPUTEMP       2 
//share提交结果
#define WP_ZCASH_N_SHARE         3
//连接矿次结果
#define WP_ZCASH_N_CONNECT_POOL	 4


//错误
//进程自动退出
#define WP_ZCASH_N_AUTOEXIT	    5
//解析到错误信息
#define WP_ZCASH_N_ERROR_INFO    9