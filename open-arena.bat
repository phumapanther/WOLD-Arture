@echo off
rem Open the WOLD Arena place (สนาม PVP 3v3) in Roblox Studio.
rem ⚠️ ใส่เลขเพลสจริงแทน 0 หลังสร้างเพลสในเว็บ/Studio แล้ว (ค่าเดียวกับ ServerConfig.ArenaPlaceId)
set ARENA_PLACE=0
if "%ARENA_PLACE%"=="0" (
  echo ยังไม่ได้ตั้งเลขเพลสสนาม — แก้ ARENA_PLACE ในไฟล์นี้ และ ServerConfig.ArenaPlaceId ให้ตรงกัน
  pause
  exit /b 1
)
start "" "roblox-studio:1+launchmode:edit+task:EditPlace+placeId:%ARENA_PLACE%+universeId:10765335572"
