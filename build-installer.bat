@echo off
setlocal
powershell.exe -NoProfile -File "%~dp0scripts\build.ps1" --installer %*
exit /b %errorlevel%
