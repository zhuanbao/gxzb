Var MSG
CRCCheck on
SetCompressor /SOLID lzma
SetCompressorDictSize 32
SetCompress force
SetDatablockOptimize on

RequestExecutionLevel admin

; MUI Settings
!define MUI_ABORTWARNING
!define MUI_PAGE_FUNCTION_ABORTWARNING onCloseCallback
!define MUI_CUSTOMFUNCTION_GUIINIT onGUIInit

!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_Left
!define MUI_HEADERIMAGE_BITMAP_STRETCH
!define MUI_HEADERIMAGE_BITMAP ".\res\head.bmp"
!define MUI_HEADERIMAGE_UNBITMAP ".\res\head.bmp"

!define MUI_ICON ".\res\mainexe.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\win-uninstall.ico"
; MUI 1.67 compatible ------
!include "MUI2.nsh"
!include "x64.nsh"
!include "WinCore.nsh"
!include "FileFunc.nsh"
!include "nsWindows.nsh"
!include "WinMessages.nsh"
!include "WordFunc.nsh"
; Language files
!insertmacro MUI_LANGUAGE "SimpChinese"
!define INSTALL_CHANNELID "0001"
; HM NIS Edit Wizard helper defines
!define PRODUCT_NAME "共享赚宝"
!define PRODUCT_VERSION "1.0.0.1"
;TestCheckFlag==1 非测试模式
!if ${TestCheckFlag} == 1
	!define EM_OUTFILE_NAME "Share4MoneySetup_${INSTALL_CHANNELID}.exe"
!else
	!define EM_OUTFILE_NAME "Share4MoneySetup_test_${INSTALL_CHANNELID}.exe"
!endif

Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
BrandingText "${PRODUCT_NAME}"
!if ${PackUninstall} == 1
	OutFile "uninstallhelper.exe"
!else
	OutFile "bin\${EM_OUTFILE_NAME}"
!endif
;InstallDir "$PROGRAMFILES\Share4Money"

ShowInstDetails show
ShowUnInstDetails show

VIProductVersion ${PRODUCT_VERSION}
VIAddVersionKey /LANG=2052 "ProductName" "${PRODUCT_NAME}"
VIAddVersionKey /LANG=2052 "Comments" ""
VIAddVersionKey /LANG=2052 "CompanyName" "深圳开心豆豆科技有限公司"
VIAddVersionKey /LANG=2052 "LegalCopyright" "Copyright (c) 2016-2017 深圳开心豆豆科技有限公司"
VIAddVersionKey /LANG=2052 "FileDescription" "${PRODUCT_NAME}安装程序"
VIAddVersionKey /LANG=2052 "FileVersion" ${PRODUCT_VERSION}
VIAddVersionKey /LANG=2052 "ProductVersion" ${PRODUCT_VERSION}
VIAddVersionKey /LANG=2052 "OriginalFilename" Share4MoneySetup.exe



;page
Page custom check-can-install
;Page custom check-can-install2
Page custom loadingPage

UninstPage uninstConfirm
UninstPage instfiles

Var Int_FontOffset
Var Handle_Font
Var Handle_FontBig
Var Handle_FontMid
Var CheckFlag

Var str_ChannelID
Var BoolExitMsg

;初始化字体
Var Handle_Font6
Var Handle_Font7
Var Handle_Font8
Var Handle_Font9
Var Handle_Font10
Var Handle_Font11
Var Handle_Font12
Var Handle_Font13
Var Handle_Font14
Var Handle_Font15

Function InitFont 
	Push $0
	Push $1
	Push $2
	
	ReadRegStr $1 HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion" "CurrentVersion"
	${VersionCompare} "$1" "6.0" $2
	;xp
	${If} $2 == 2
		StrCpy $0 "宋体"
		StrCpy $Int_FontOffset 4
	${Else}
		StrCpy $0 "微软雅黑"
		StrCpy $Int_FontOffset 0
	${EndIf}
	CreateFont $Handle_Font $0 10 0
	CreateFont $Handle_FontBig $0 22 0
	CreateFont $Handle_FontMid $0 16 0
	CreateFont $Handle_Font6 $0 6 0
	CreateFont $Handle_Font7 $0 7 0
	CreateFont $Handle_Font8 $0 8 0
	CreateFont $Handle_Font9 $0 9 0
	CreateFont $Handle_Font10 $0 10 0
	CreateFont $Handle_Font11 $0 11 0
	CreateFont $Handle_Font12 $0 12 0
	CreateFont $Handle_Font13 $0 13 0
	CreateFont $Handle_Font14 $0 14 0
	CreateFont $Handle_Font15 $0 15 0
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

!macro _GuiInit
	;消除边框
    ;System::Call `user32::SetWindowLong(i$HWNDPARENT,i${GWL_STYLE},0x9480084C)i.R0`
    ;隐藏一些既有控件
	;未知控件
    GetDlgItem $0 $HWNDPARENT 1034
    ShowWindow $0 ${SW_HIDE}
	;线
    GetDlgItem $0 $HWNDPARENT 1035
    ${NSW_SetWindowPos} $0 0 290
	;ShowWindow $0 ${SW_HIDE}
    ;顶部右侧
	;GetDlgItem $0 $HWNDPARENT 1036
    ;ShowWindow $0 ${SW_HIDE}
    ;未知控件
	GetDlgItem $0 $HWNDPARENT 1037
    ShowWindow $0 ${SW_HIDE}
    ;未知控件
	GetDlgItem $0 $HWNDPARENT 1038
    ShowWindow $0 ${SW_HIDE}
    ;未知控件
	GetDlgItem $0 $HWNDPARENT 1039
    ShowWindow $0 ${SW_HIDE}
	;未知控件
    GetDlgItem $0 $HWNDPARENT 1256
    ShowWindow $0 ${SW_HIDE}
	;底部字
    GetDlgItem $0 $HWNDPARENT 1028
	;SetCtlColors $0 "0" transparent ;背景设成透明
    ShowWindow $0 ${SW_HIDE}
!macroend

Function onGUIInit
	!insertmacro _GuiInit
FunctionEnd

Function onCloseCallback
	;这里的Abort相当于 取消退出动作
	${If} $BoolExitMsg == 1
		MessageBox MB_ICONQUESTION|MB_YESNO|MB_DEFBUTTON2 "确定要退出安装吗？" IDYES +2
		Abort
	${EndIf}
	HideWindow
	System::Call "$PLUGINSDIR\zbsetuphelper::WaitForStat()"
	Call cancel
	Abort
FunctionEnd

/*封装创建ui的接口begin*/
!macro _CreateButton nLeft nTop nWidth nHeight strText Func Handle
	Push $0
	Push $1
	${NSD_CreateButton} ${nLeft} ${nTop} ${nWidth} ${nHeight} ${strText}
	Pop $1
	GetFunctionAddress $0 "${Func}"
	nsDialogs::OnClick $1 $0
	StrCpy $0 $1
	StrCpy ${Handle} $1
	Pop $1
	Exch $0
!macroend
!define CreateButton `!insertmacro _CreateButton`

!macro _CreateLabel nLeft nTop nWidth nHeight strText strColor hFont Func Handle
	Push $0
	Push $1
	StrCpy $0 ${nTop}
	IntOp $0 $0 + $Int_FontOffset
	${NSD_CreateLabel} ${nLeft} $0 ${nWidth} ${nHeight} ${strText}
	Pop $1
    ;SetCtlColors $1 ${strColor} transparent ;背景设成透明
	SendMessage $1 ${WM_SETFONT} ${hFont} 0
	${NSD_OnClick} $1 ${Func}
	StrCpy $0 $1
	StrCpy ${Handle} $1
	Pop $1
	Exch $0
!macroend
!define CreateLabel `!insertmacro _CreateLabel`
/*封装创建ui的接口end*/

;循环杀进程
!macro _FKillProc strProcName
	Push $R3
	Push $R1
	Push $R0
	
	StrCpy $R1 0
	ClearErrors
	${GetOptions} $CMDLINE "/s"  $R0
	IfErrors 0 +2
	StrCpy $R1 1
	${For} $R3 0 6
		;FindProcDLL::FindProc "${strProcName}.exe"
		System::Call "$PLUGINSDIR\zbsetuphelper::FindProcessByName(t '${strProcName}.exe') i.r0"
		${If} $0 != 0
			;KillProcDLL::KillProc "${strProcName}.exe"
			System::Call "$PLUGINSDIR\zbsetuphelper::TerminateProcessByName(t '${strProcName}.exe')"
			Sleep 250
		${Else}
			${Break}
		${EndIf}
	${Next}
	Pop $R0
	Pop $R1
	Pop $R3
!macroend
!define FKillProc "!insertmacro _FKillProc"

!macro _SendStat strp1 strp2 strp3 np4
	
	System::Call '$PLUGINSDIR\zbsetuphelper::SendAnyHttpStat(t "${strp1}", t "${strp2}", t "${strp3}", i ${np4}) '

!macroend
!define SendStat "!insertmacro _SendStat"

!macro _GetParent strCallFlag
	Function ${strCallFlag}GetParent
	  Exch $R0 ; input string
	  Push $R1
	  Push $R2
	  Push $R3
	  StrCpy $R1 0
	  StrLen $R2 $R0
	  loop:
		IntOp $R1 $R1 + 1
		IntCmp $R1 $R2 get 0 get
		StrCpy $R3 $R0 1 -$R1
		StrCmp $R3 "\" get
		Goto loop
	  get:
		StrCpy $R0 $R0 -$R1
		Pop $R3
		Pop $R2
		Pop $R1
		Exch $R0 ; output string
	FunctionEnd
!macroend
!insertmacro _GetParent ""
!insertmacro _GetParent "un."

!macro _InitMutex
	Push $0
	System::Call 'kernel32::CreateMutexA(i 0, i 0, t "Global\ethminersetup_{CCE50E5F-9299-4609-9EB5-B9CB4F283E94}") i .r1 ?e'
	Pop $0
	StrCmp $0 0 +2
	Abort
	Pop $0
!macroend
!define InitMutex `!insertmacro _InitMutex`

Function GetLastPart
  Exch $0 ; chop char
  Exch
  Exch $1 ; input string
  Push $2
  Push $3
  StrCpy $2 0
  loop:
    IntOp $2 $2 - 1
    StrCpy $3 $1 1 $2
    StrCmp $3 "" 0 +3
      StrCpy $0 ""
      Goto exit2
    StrCmp $3 $0 exit1
    Goto loop
  exit1:
    IntOp $2 $2 + 1
    StrCpy $0 $1 "" $2
  exit2:
    Pop $3
    Pop $2
    Pop $1
    Exch $0 ; output string
FunctionEnd

Section "jiuyobng" SEC01
SectionEnd

Function CloseExe
	${FKillProc} "Share4Money"
	${FKillProc} "ShareGenoil"
	${FKillProc} "zbsetuphelper-cl"
	${FKillProc} "Share4Peer"
FunctionEnd

Function CheckHasInstall
	StrCpy $0 "$INSTDIR\program\Share4Money.exe"
	IfFileExists $0 0 EndFunction
	${GetFileVersion} $0 $1
	${VersionCompare} $1 ${PRODUCT_VERSION} $2
	System::Call "kernel32::GetCommandLineA() t.R1"
	System::Call "kernel32::GetModuleFileName(i 0, t R2R2, i 256)"
	${WordReplace} $R1 $R2 "" +1 $R3
	${StrFilter} "$R3" "-" "" "" $R4
	ClearErrors
	${GetOptions} $R4 "/write"  $R0
	IfErrors 0 +3
	push "false"
	pop $R0
	${If} $2 == "2" ;已安装的版本低于该版本
		Return
	${ElseIf} $2 == "0" ;版本相同
	${OrIf} $2 == "1"	;已安装的版本高于该版本
		${If} $R0 == "false"
			MessageBox MB_YESNO "检测到已安装${PRODUCT_NAME}$1，是否覆盖安装？" /SD IDNO IDYES +2
			Abort
			Return
		${Else}
			Return
		${EndIf}
	${EndIf}
	EndFunction:
FunctionEnd

Function CheckExeProcExist
	StrCpy $0 0
	;FindProcDLL::FindProc "Share4Money.exe"
	System::Call "$PLUGINSDIR\zbsetuphelper::FindProcessByName(t 'Share4Money.exe') i.r0"
	${If} $0 != 0
		MessageBox MB_YESNO "检测到${PRODUCT_NAME}正在运行，是否强制结束？" /SD IDYES IDYES +2
		Abort
		${FKillProc} "Share4Money"
	${EndIf}
	${FKillProc} "ShareGenoil"
	${FKillProc} "zbsetuphelper-cl"
	${FKillProc} "Share4Peer"
FunctionEnd

Function UpdateChanel
	ReadINIStr $R0 $INSTDIR\config\reg.ini "HKLM" "InstallSource"
	${If} $R0 != 0
	${AndIf} $R0 != ""
	${AndIf} $R0 != "unknown"
		StrCpy $str_ChannelID $R0
	${Else}
		System::Call 'kernel32::GetModuleFileName(i 0, t R2R2, i 256)'
		Push $R2
		Push "\"
		Call GetLastPart
		Pop $R1
		
		${WordFind2X} "$R1" "_" "." +1 $R3
		${If} $R3 == 0
		${OrIf} $R3 == ""
			StrCpy $str_ChannelID ${INSTALL_CHANNELID}
		${ElseIf} $R1 == $R3
			StrCpy $str_ChannelID "unknown"
		${Else}
			StrCpy $str_ChannelID $R3
		${EndIf}
	${EndIf}
FunctionEnd

Function .onInit
	StrCpy $INSTDIR "$EXEDIR\Share4Money"
	${InitMutex}
	${If} ${PackUninstall} == 1
		WriteUninstaller "$EXEDIR\main\uninst.exe"
		Abort
	${EndIf}
	;1：不支持opencl或者显存小于3G， 2：不是64位系统， 0：64位且支持cl
	StrCpy $CheckFlag ${TestCheckFlag}
	ReadRegDWORD $0 HKCU "Software\Share4Money" "Debug"
	${If} $0 == 1
		StrCpy $CheckFlag 0
	${EndIf}
	InitPluginsDir
	IfFileExists $PLUGINSDIR 0 +2
	RMDir /r $PLUGINSDIR
	SetOutPath "$PLUGINSDIR"
	SetOverwrite on
		File "zbsetuphelper.dll"
		File "main\program\Microsoft.VC90.CRT.manifest"
		File "main\program\msvcp90.dll"
		File "main\program\msvcr90.dll"
		File "main\program\Microsoft.VC90.ATL.manifest"
		File "main\program\ATL90.dll"
		
	Call CheckHasInstall
	Call CheckExeProcExist
	
	
	File "res\Error.ico"
	File "res\warning.bmp"
	File "res\2weima.bmp"
	
	Call InitFont
	${If} ${RunningX64}
		File "main\program\Share4Peer\msvcp120.dll"
		File "main\program\Share4Peer\msvcr120.dll"
		File "main\program\Share4Peer\OpenCL.dll"
		File "main\program\Share4Peer\zbsetuphelper-cl.exe"
		
		File "license.txt"
		Call UpdateChanel
		Call FirstSendStart
		
		StrCpy $0 3
		System::Call "$PLUGINSDIR\zbsetuphelper::CheckCLEnvir(t '$PLUGINSDIR\zbsetuphelper-cl.exe') i.r0"
		;返回值FALSE=0 TRUE=1
		${If} $0 == 1
			;MessageBox MB_OK "您的显卡驱动不支持opencl或者显存小于3G， 无法安装"
			;Abort
			StrCpy $CheckFlag 0
		${EndIf}
		;MessageBox MB_OK "可以安装"
	${Else}
		;MessageBox MB_OK "此程序只支持64位操作系统，您使用的操作系统是32位，无法安装"
		StrCpy $CheckFlag 2
	${EndIf}
FunctionEnd

Var Bool_IsInstallSucc
Var Bool_IsUpdate

Function FirstSendStart
	StrCpy $Bool_IsUpdate 0 
	StrCpy $0 "$INSTDIR\program\Share4Money.exe"
	IfFileExists $0 0 +2
	StrCpy $Bool_IsUpdate 1
	${WordFind} "${PRODUCT_VERSION}" "." -1 $R1
	${If} $Bool_IsUpdate == 0
		${SendStat} "installstart" "$R1" "$str_ChannelID" 1
	${Else}
		${SendStat} "updatestart" "$R1" "$str_ChannelID" 1
	${EndIf} 
FunctionEnd

Var ConfigDir
Function DoInstall
	;初始化安装成功标志位
	StrCpy $Bool_IsInstallSucc 0
	;配置文件
	StrCpy $ConfigDir "$INSTDIR\config"
	
	;覆盖安装备份配置
	IfFileExists "$ConfigDir\UserConfig.dat" 0 +3
	IfFileExists "$ConfigDir\UserConfig.dat.bak" +2 0
	Rename "$ConfigDir\UserConfig.dat" "$ConfigDir\UserConfig.dat.bak"
	
	;释放配置
	SetOutPath "$ConfigDir"
	SetOverwrite on
	File /r "config\*"
	
	;先删再装
	RMDir /r "$INSTDIR\program"
	RMDir /r "$INSTDIR\xar"
	
	SetOutPath "$INSTDIR"
	SetOverwrite on
	File /r "main\*"
	
	StrCpy $R0 1
	
	System::Call '$PLUGINSDIR\zbsetuphelper::GetPeerID(t) i(.r0).r1'
	;${If} $0 == ""
		;System::Call '$PLUGINSDIR\zbsetuphelper::GetPeerID(t) i(.r0).r1'
		;WriteRegStr HKLM "software\Share4Money" "PeerId" "$0"
	;${EndIf}
	${WordFind} "${PRODUCT_VERSION}" "." -1 $R1
	${If} $Bool_IsUpdate == 0
		${SendStat} "install" "$R1" "$str_ChannelID" 1
		${SendStat} "installmethod" "$R1" "$R0" 1
	${Else}
		${SendStat} "update" "$R1" "$str_ChannelID" 1
		${SendStat} "updatemethod" "$R1" "$R3" 1
	${EndIf}  
	
	;写入自用的注册表信息
	WriteINIStr '$ConfigDir\reg.ini' 'HKLM' "InstallSource" $str_ChannelID
	System::Call '$PLUGINSDIR\zbsetuphelper::GetTime(*l) i(.r0).r1'
	WriteINIStr '$ConfigDir\reg.ini' 'HKLM' "InstallTimes" "$0"
	WriteINIStr '$ConfigDir\reg.ini' 'HKLM' "Ver" ${PRODUCT_VERSION}
	
	;写入安装包名字
	System::Call "kernel32::GetModuleFileName(i 0, t R2R2, i 256)"
	Push $R2
	Push "\"
	Call GetLastPart
	Pop $R1
	WriteINIStr '$ConfigDir\reg.ini' 'HKLM' "PackageName" "$R1"
	
	;修改环境变量
	ExecShell open "$SYSDIR\setx.exe" "GPU_FORCE_64BIT_PTR 0" SW_HIDE
	ExecShell open "$SYSDIR\setx.exe" "GPU_MAX_HEAP_SIZE 100" SW_HIDE
	ExecShell open "$SYSDIR\setx.exe" "GPU_USE_SYNC_OBJECTS 1" SW_HIDE
	ExecShell open "$SYSDIR\setx.exe" "GPU_MAX_ALLOC_PERCENT 100" SW_HIDE
	ExecShell open "$SYSDIR\setx.exe" "GPU_SINGLE_ALLOC_PERCENT 100" SW_HIDE
	StrCpy $Bool_IsInstallSucc 1
FunctionEnd

Function cancel
	SendMessage $HWNDPARENT "0x408" "120" ""
FunctionEnd


Function check-can-install
	;支持赚宝
	${If} $CheckFlag == 0
		StrCpy $BoolExitMsg 1
		SendMessage $HWNDPARENT "0x408" "1" ""
	;不支持opencl
	${Else}
		GetDlgItem $0 $HWNDPARENT 1
		ShowWindow $0 ${SW_HIDE}
		GetDlgItem $0 $HWNDPARENT 2
		ShowWindow $0 ${SW_HIDE}
		GetDlgItem $0 $HWNDPARENT 3
		ShowWindow $0 ${SW_HIDE}
		HideWindow
		Var /Global Hwnd_Welcome
		nsDialogs::Create 1018
		Pop $Hwnd_Welcome
		${If} $Hwnd_Welcome == error
			Abort
		${EndIf}
		${NSW_SetWindowSize} $HWNDPARENT 503 282 ;改变窗体大小
		${NSW_SetWindowSize} $Hwnd_Welcome 503 282 ;改变Page大小
		SetCtlColors $HWNDPARENT ""  "FFFFFF"
		SetCtlColors $Hwnd_Welcome ""  "FFFFFF"
		System::Call  'User32::GetDesktopWindow() i.R9'
		${NSW_CenterWindow} $HWNDPARENT $R9
		
		
		${NSD_CreateBitmap} 81 14 28 28 ""
		Pop $1
		${NSD_SetBitmap} $1 $PLUGINSDIR\warning.bmp $3
		SetCtlColors $1 ""  "FFFFFF"
		
		StrCpy $4 16
		IntOp $4 $4 + $Int_FontOffset
		${NSD_CreateLabel} 119 $4 210 30 "软件检测到本设备不支持赚宝"
		Pop $2
		SetCtlColors $2 "6D5539"  transparent
		SendMessage $2 ${WM_SETFONT} $Handle_Font12 0
		
		${CreateButton} 175 97 102 38 "退出" cancel $3
		SendMessage $3 ${WM_SETFONT} $Handle_Font10 0
		
		${NSD_CreateLink} 385 150 120 22 "分享赚分成>"
		Pop $4
		SetCtlColors $4 "B08756"  transparent
		SendMessage $4 ${WM_SETFONT} $Handle_Font9 0
		GetFunctionAddress $R0 ClickShare
		nsDialogs::OnClick $4 $R0
		ShowWindow $HWNDPARENT ${SW_SHOW}
		nsDialogs::Show
	${EndIf}
FunctionEnd

Function onMsgBoxCloseCallback
	${If} $MSG = ${WM_CLOSE}
		EnableWindow $HWNDPARENT 1
	${EndIf}
FunctionEnd

Var WarningForm
Function ClickShare
	EnableWindow $HWNDPARENT 0
	IsWindow $WarningForm Create_End
	${NSW_CreateWindowEx} $WarningForm $HWNDPARENT ${ExStyle} ${WS_VISIBLE}|${WS_OVERLAPPED}|${WS_CAPTION}|${WS_SYSMENU}|${WS_MINIMIZEBOX} "共享赚宝 ${PRODUCT_VERSION} 安装" 1018
	
	SetCtlColors $WarningForm ""  "FFFFFF"
	${NSW_SetWindowSize} $WarningForm 503 422
	;System::Call `user32::SetWindowLong(i $WarningForm,i ${GWL_STYLE},0x9480084C)i.R0`
	;标题栏
	StrCpy $3 30
	IntOp $3 $3 + $Int_FontOffset
	${NSW_CreateLabel} 201 $3 120 25 "分享赚分成"
	Pop $4
	SetCtlColors $4 "6D5539"  transparent
	SendMessage $4 ${WM_SETFONT} $Handle_Font14 0
	
	;正文
	StrCpy $5 75
	IntOp $5 $5 + $Int_FontOffset
	${NSW_CreateLabel} 88 $5 320 70 "微信扫描下面的二维码，关注共享赚宝公众号，分享$\n到朋友圈或微信群，\
	邀请好友一起赚宝，当您的好友$\n赚取收益时，您也会有不菲的分成哦！"
	Pop $6
	SetCtlColors $6 "6D5539"  transparent
	SendMessage $6 ${WM_SETFONT} $Handle_Font 0
	
	;二维码
	${NSW_CreateBitmap} 154 166 194 194 ""
  	Pop $7
	${NSW_SetImage} $7 $PLUGINSDIR\2weima.bmp $8
	${NSW_CenterWindow} $WarningForm $HWNDPARENT
	${NSW_Show}
	GetFunctionAddress $0 onMsgBoxCloseCallback
	WndProc::onCallback $WarningForm $0 ;处理关闭消息
	Create_End:
	ShowWindow $WarningForm ${SW_SHOW}
FunctionEnd


Var Lbl_Sumary
Var PB_ProgressBar

Function InstallationMainFun
	SendMessage $PB_ProgressBar ${PBM_SETRANGE32} 0 100  ;总步长为顶部定义值
	Sleep 1
	SendMessage $PB_ProgressBar ${PBM_SETPOS} 2 0
	Sleep 100
	Call CloseExe
    SendMessage $PB_ProgressBar ${PBM_SETPOS} 4 0
	Sleep 100
	SendMessage $PB_ProgressBar ${PBM_SETPOS} 7 0
    Sleep 100
    SendMessage $PB_ProgressBar ${PBM_SETPOS} 14 0
    Sleep 100
    SendMessage $PB_ProgressBar ${PBM_SETPOS} 27 0
	Call DoInstall
    SendMessage $PB_ProgressBar ${PBM_SETPOS} 50 0
    Sleep 100
    SendMessage $PB_ProgressBar ${PBM_SETPOS} 73 0
    Sleep 100
    SendMessage $PB_ProgressBar ${PBM_SETPOS} 100 0
	Sleep 1000
FunctionEnd

Function NSD_TimerFun
	GetFunctionAddress $0 NSD_TimerFun
    nsDialogs::KillTimer $0
    GetFunctionAddress $0 InstallationMainFun
    BgWorker::CallAndWait
	${If} $Bool_IsInstallSucc != 1
		HideWindow
		Call cancel
		Return
	${EndIf}
	${NSD_SetText} $Lbl_Sumary "安装完成"
	ShowWindow $Lbl_Sumary ${SW_HIDE}
	ShowWindow $Lbl_Sumary ${SW_SHOW}
	Call FinishAndRun
FunctionEnd

Function loadingPage
	GetDlgItem $0 $HWNDPARENT 1
    ShowWindow $0 ${SW_HIDE}
    GetDlgItem $0 $HWNDPARENT 2
    ShowWindow $0 ${SW_HIDE}
    GetDlgItem $0 $HWNDPARENT 3
    ShowWindow $0 ${SW_HIDE}
	HideWindow
	Var /Global Hwnd_Welcome3
	nsDialogs::Create 1018
	Pop $Hwnd_Welcome3
	${If} $Hwnd_Welcome3 == error
        Abort
    ${EndIf}
	SetCtlColors $HWNDPARENT ""  "FFFFFF"
	SetCtlColors $Hwnd_Welcome3 ""  "FFFFFF"
	;${NSW_SetWindowSize} $HWNDPARENT 478 320 ;改变窗体大小
    ;${NSW_SetWindowSize} $Hwnd_Welcome3 478 320 ;改变Page大小
	;System::Call  'User32::GetDesktopWindow() i.R9'
	;${NSW_CenterWindow} $HWNDPARENT $R9
	
	;创建简要说明
	StrCpy $3 30
	IntOp $3 $3 + $Int_FontOffset
    ${NSD_CreateLabel} 0 $3 90 20 "正在安装..."
    Pop $Lbl_Sumary
	SetCtlColors $Lbl_Sumary "0"  transparent
	SendMessage $Lbl_Sumary ${WM_SETFONT} $Handle_Font 0
	
	 ${NSD_CreateProgressBar} 0 55 429 16 ""
    Pop $PB_ProgressBar
	GetFunctionAddress $0 NSD_TimerFun
    nsDialogs::CreateTimer $0 1
	
	ShowWindow $HWNDPARENT ${SW_SHOW}
	nsDialogs::Show
FunctionEnd

Function FinishAndRun
	StrCpy $BoolExitMsg 0
	SetOutPath "$INSTDIR\program"
	ExecShell open "$INSTDIR\program\Share4Money.exe" "/forceshow /sstartfrom installfinish" SW_SHOWNORMAL
	HideWindow
	System::Call "$PLUGINSDIR\zbsetuphelper::WaitForStat()"
	;RMDir /r $PLUGINSDIR
	Call cancel
	Abort
FunctionEnd

/*************************************************************************************
以下代码是卸载部分
*************************************************************************************/
Function un.UpdateChanel
	ReadINIStr $R4 $INSTDIR\config\reg.ini "HKLM" "InstallSource"
	${If} $R4 == 0
	${OrIf} $R4 == ""
		StrCpy $str_ChannelID "unknown"
	${Else}
		StrCpy $str_ChannelID $R4
	${EndIf}
FunctionEnd

Function un.onUninstSuccess
  HideWindow
  MessageBox MB_ICONINFORMATION|MB_OK "$(^Name) 卸载成功！$\n我们会不断改进，期待您的再次使用。"
FunctionEnd

Function un.onInit
	${InitMutex}	
	InitPluginsDir
	IfFileExists $PLUGINSDIR 0 +2
	RMDir /r $PLUGINSDIR
	SetOutPath "$PLUGINSDIR"
	SetOverwrite on
		File "zbsetuphelper.dll"
		File "main\program\Microsoft.VC90.CRT.manifest"
		File "main\program\msvcp90.dll"
		File "main\program\msvcr90.dll"
		File "main\program\Microsoft.VC90.ATL.manifest"
		File "main\program\ATL90.dll"
	System::Call "$PLUGINSDIR\zbsetuphelper::FindProcessByName(t 'Share4Money.exe') i.r0"
	${If} $0 != 0
		MessageBox MB_ICONQUESTION|MB_YESNO|MB_DEFBUTTON2 "检测到${PRODUCT_NAME}正在运行，是否强制结束？" IDYES +2
		Abort
		${FKillProc} "Share4Money"
	${EndIf}
	${FKillProc} "ShareGenoil"
	${FKillProc} "zbsetuphelper-cl"
	${FKillProc} "Share4Peer"
	Call un.UpdateChanel
	;InitPluginsDir
	;IfFileExists $PLUGINSDIR 0 +2
	;RMDir /r $PLUGINSDIR
	;SetOutPath "$PLUGINSDIR"
	;SetOverwrite on
	;File "zbsetuphelper.dll"
	;File "main\program\Microsoft.VC90.CRT.manifest"
	;File "main\program\msvcp90.dll"
	;File "main\program\msvcr90.dll"
	;File "main\program\Microsoft.VC90.ATL.manifest"
	;File "main\program\ATL90.dll"
FunctionEnd

Section Uninstall
	;必须在删除文件之前解pin， 否则会失败
	;删除
	RMDir /r "$INSTDIR\xar"
	Delete "$INSTDIR\uninst.exe"
	RMDir /r "$INSTDIR\program"
	;删配置
	RMDir /r "$INSTDIR\config"
	
	StrCpy "$R0" "$INSTDIR"
	System::Call 'Shlwapi::PathIsDirectoryEmpty(t R0)i.s'
	Pop $R1
	${If} $R1 == 1
		RMDir /r "$INSTDIR"
	${EndIf}
	
	${WordFind} "${PRODUCT_VERSION}" "." -1 $R2
	${SendStat} "uninstall" "$R2" $str_ChannelID 1
	
	HideWindow
	System::Call "$PLUGINSDIR\zbsetuphelper::WaitForStat()"
	SetAutoClose true
SectionEnd