@echo off
rem Same as run-live.bat but a FOLLOW also spawns a boss -- the free way to test the sub path.
rem Use this while testing, then switch back to run-live.bat for a normal stream.
setlocal
chcp 65001 >nul
set TIKTOK_USER=phumapanther
cd /d "%~dp0"
if not exist node_modules call npm install --no-audit --no-fund
if not exist live.env echo live.env NOT FOUND - copy live.env.example to live.env and fill it in
node bridge.js --user %TIKTOK_USER% --push --follow-boss --dump
echo.
pause
