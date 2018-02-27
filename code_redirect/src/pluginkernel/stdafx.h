// stdafx.h : 标准系统包含文件的包含文件，
// 或是经常使用但不常更改的
// 特定于项目的包含文件
//

#pragma once

#include "targetver.h"

#define WIN32_LEAN_AND_MEAN             // 从 Windows 头中排除极少使用的资料
// Windows 头文件:
#include <windows.h>


#include <shellapi.h>
#include <Wininet.h>
#include <Shlobj.h>
#include <wininet.h>
#include <mapidbg.h>

// C RunTime Header Files
#include <stdlib.h>
#include <malloc.h>
#include <memory.h>
#include <tchar.h>
#include <time.h>

// STL Header Files
#pragma warning(disable:4702)
#include <string>
#include <vector>
#include <list>
#include <map>
#include <set>
#include <fstream>
#include <algorithm>
#include <assert.h>
using namespace std;

// ATL Header Files
#pragma warning(default:4702)
#include <atlbase.h>
#include <atlwin.h>
#include <atltypes.h>
#include <atlfile.h>
#include <atlcoll.h>
#include <atlstr.h>
#include <atlsecurity.h>
#include <atltime.h>

// WTL Header Files
#include <WTL/atlapp.h>
#include <WTL/atldlgs.h>
#include <WTL/atlcrack.h>

// xlue Header Files
#include <XLI18N.h>
#include <XLUE.h>
#include <XLGraphic.h>
#include <XLGraphicPlus.h>
#include <XLLuaRuntime.h>
#include <XLFS.h>

#include <winsock2.h>
#include <Gdiplus.h>
#define TSLOG
#define TSLOG_GROUP "GXZB"	//可选,默认为 "TSLOG"
#include <tslog/tslog.h>

#include "Utility/LuaAPIHelper.h"
// TODO: 在此处引用程序需要的其他头文件
