@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Android-Shizuku.ps1" %*
set "startResult=%errorlevel%"
if not "%startResult%"=="0" echo Startup could not finish. Check the message above.
pause
exit /b %startResult%
