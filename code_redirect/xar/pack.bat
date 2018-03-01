%~dp0XLUEPack.exe option=pack srcpath="%~dp0main" destpath="%~dp0bin" medium="zip" xartype=0 mode=union
copy /y "%~dp0bin\main.xar" "%~dp0..\..\bin_redirect\main\xar\main.xar"
%~dp0XLUEPack.exe option=merge srcpath="%~dp0bin\main.xar" destpath="%~dp0..\src\gxzb\Release\Share4Money.exe" restype="xar_res" resid="1001" mode=resource
copy /y "%~dp0..\src\gxzb\Release\Share4Money.exe" "%~dp0..\..\bin_redirect\main\program\Share4Money.exe"
goto :eof