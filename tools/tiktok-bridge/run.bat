@echo off
chcp 65001 >nul
rem เปิดสะพาน TikTok ค้างไว้ทั้งไลฟ์ ปิดด้วยการกดกากบาทหรือ Ctrl+C
rem
rem เปลี่ยนชื่อช่องที่บรรทัดล่างนี้ถ้าไลฟ์จากบัญชีอื่น (ไม่ต้องใส่ @)
set TIKTOK_USER=PHUMAPANTHER

cd /d "%~dp0"
if not exist node_modules (
  echo ติดตั้งครั้งแรก กำลังดาวน์โหลด dependency...
  call npm install --no-audit --no-fund
)
echo.
echo ==========================================
echo  สะพาน TikTok LIVE  ^-^>  WOLD Arture
echo  ช่อง: @%TIKTOK_USER%
echo ==========================================
echo  ต้องกด "ไปไลฟ์" ใน TikTok ให้ขึ้น LIVE จริงก่อน
echo  แล้วเปิดเกม (Studio กด F5 หรือเข้าเกมที่ publish)
echo  ปล่อยหน้าต่างนี้เปิดไว้ทั้งไลฟ์
echo ==========================================
echo.
node bridge.js --user %TIKTOK_USER%
echo.
echo (สะพานหยุดทำงานแล้ว กด Enter เพื่อปิดหน้าต่าง)
pause >nul
