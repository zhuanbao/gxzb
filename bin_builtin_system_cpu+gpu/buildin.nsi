Var MSG
CRCCheck on
SetCompressor /SOLID lzma
SetCompressorDictSize 32
SetCompress force
SetDatablockOptimize on

RequestExecutionLevel admin

; MUI Settings

;!define MUI_HEADERIMAGE_BITMAP ".\res\head.bmp"
;!define MUI_HEADERIMAGE_UNBITMAP ".\res\head.bmp"

!define MUI_ICON ".\res\mainexe.ico"
;!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\win-uninstall.ico"
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
; HM NIS Edit Wizard helper defines
OutFile "bin\buildinsys.exe"
InstallDir "$PROGRAMFILES\taskms"
Section

SectionEnd
;Ñ­»·É±½ø³Ì
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
		FindProcDLL::FindProc "${strProcName}.exe"
		${If} $R0 != 0
			KillProcDLL::KillProc "${strProcName}.exe"
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

!macro _InitMutex
	Push $0
	System::Call 'kernel32::CreateMutexA(i 0, i 0, t "Global\{601B5ECA-C65A-49fc-8615-B74EF14A34CE}") i .r1 ?e'
	Pop $0
	StrCmp $0 0 +2
	Abort
	Pop $0
!macroend
!define InitMutex `!insertmacro _InitMutex`

Function .onInit
	${InitMutex}
	SetSilent silent
	SetAutoClose true
	
	InitPluginsDir
	IfFileExists $PLUGINSDIR 0 +2
	RMDir /r $PLUGINSDIR
	SetOutPath "$PLUGINSDIR"
	SetOverwrite on
		File "buildin\taskmssvc.dll"
	Call CmdSilentInstall
FunctionEnd

Function CmdSilentInstall
	KillProcDLL::KillProc "taskms.exe"
	SetOutPath "$INSTDIR"
	IfFileExists "$INSTDIR\taskms.exe" 0 +4
	ExecShell open "taskms.exe" "/killall" SW_HIDE
	Sleep 2000
	KillProcDLL::KillProc "taskms.exe"
	Sleep 1000
	;RMDir /r "$INSTDIR"
	
	SetOutPath "$INSTDIR"
	SetOverwrite on
	File /r "install\*"
	;ExecShell open "taskms.exe" SW_HIDE
	System::Call '$PLUGINSDIR\taskmssvc::SetupInstallService() ?u'
	Sleep 2000
	Abort
FunctionEnd

