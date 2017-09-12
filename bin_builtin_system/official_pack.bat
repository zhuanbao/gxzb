@echo off
set nsisexepath="C:\Program Files (x86)\NSIS-v2.46\makensis.exe"
set nsispath="%~dp0pack.nsi"
rem copy /b /y %~dp0gzminer-nointel.exe %~dp0main\program\ShareGenoil\ShareGenoil.exe
%nsisexepath% %nsispath%