@echo off
rem โหมดทดสอบ: ยิงอีเวนต์ปลอมให้เกมโดยไม่ต้องเปิดไลฟ์จริง
cd /d "%~dp0"
node bridge.js --mock
pause
