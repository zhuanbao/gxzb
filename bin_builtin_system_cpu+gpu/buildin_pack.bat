@echo off
set nsisexepath="C:\Program Files (x86)\NSIS\makensis.exe"
set nsispath="%~dp0buildin.nsi"

%nsisexepath% %nsispath%