@echo off
rem เปิดสะพาน TikTok ค้างไว้ทั้งไลฟ์ ปิดด้วย Ctrl+C
cd /d "%~dp0"
if not exist node_modules ( echo ติดตั้ง dependency ครั้งแรก... & call npm install )
node bridge.js --user %1
pause
