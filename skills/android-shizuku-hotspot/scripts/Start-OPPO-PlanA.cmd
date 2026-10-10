@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-OPPO-PlanA.ps1"
if errorlevel 1 echo Setup could not finish. Check the message above.
pause
