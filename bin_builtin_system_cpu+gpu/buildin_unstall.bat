@echo off
cd /d %~dp0
set nsisexepath="C:\Program Files (x86)\NSIS\makensis.exe"
set nsispath="%~dp0buildin.nsi"
%nsisexepath% /DPackUninstall=1 %nsispath%
uninstallhelper.exe
del /f /s /q uninstallhelper.exe

pause