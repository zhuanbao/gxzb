%~dp0XLUEPack.exe option=pack srcpath="%~dp0updatedriver" destpath="%~dp0packxar" medium="zip" xartype=0 mode=union
copy /y "%~dp0packxar\updatedriver.xar" "%~dp0..\..\..\bin_redirect\main\xar\plugin\updatedriver.xar"
pause
goto :eof