@echo off
rem Bridge TikTok LIVE -> WOLD Arture.  Leave this window open for the whole live.
rem
rem Change the channel name below if streaming from another account (no @).
rem NOTE: keep this file pure ASCII. Thai text in a .bat is mangled by cmd.exe, and an
rem unbalanced "(" from a broken echo line swallows the node command silently.
setlocal
chcp 65001 >nul
set TIKTOK_USER=phumapanther
cd /d "%~dp0"
if not exist node_modules call npm install --no-audit --no-fund
node bridge.js --user %TIKTOK_USER%
echo.
pause
