@echo off
setlocal
powershell.exe -NoProfile -File "%~dp0scripts\bootstrap.ps1" %*
exit /b %errorlevel%
