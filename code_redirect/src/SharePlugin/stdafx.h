// stdafx.h : 标准系统包含文件的包含文件，
// 或是经常使用但不常更改的
// 特定于项目的包含文件
//

#pragma once

#include "targetver.h"

#include <stdio.h>
#include <tchar.h>

#pragma warning(disable:4702)
#include <string>
#include <atlbase.h>
#include <WTL/atlapp.h>
#define TSLOG
#define TSLOG_GROUP "GXZB"	//可选,默认为 "TSLOG"
#include <tslog/tslog.h>

extern CAppModule _Module;

#include <atlwin.h>

#ifndef _countof
#define _countof(_Array) (sizeof(_Array) / sizeof(_Array[0]))
#endif


// TODO: 在此处引用程序需要的其他头文件
