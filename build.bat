@echo off
setlocal
powershell.exe -NoProfile -File "%~dp0scripts\build.ps1" %*
exit /b %errorlevel%
