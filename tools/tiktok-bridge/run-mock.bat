@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"
node bridge.js --mock
echo.
pause
