@echo off
rem Live from the PUBLISHED game: pushes events through Open Cloud, no tunnel needed.
rem Needs live.env next to this file with ROBLOX_UNIVERSE_ID and ROBLOX_API_KEY.
setlocal
chcp 65001 >nul
set TIKTOK_USER=phumapanther
cd /d "%~dp0"
if not exist node_modules call npm install --no-audit --no-fund
if not exist live.env echo live.env NOT FOUND - copy live.env.example to live.env and fill it in
node bridge.js --user %TIKTOK_USER% --push
echo.
pause
