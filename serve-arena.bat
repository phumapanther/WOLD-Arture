@echo off
REM Rojo for the WOLD Arena place (สนาม PVP 3v3) on its own port, so it can run beside the main place (34872)
REM and the farming place (34873). In the Arena Studio window: Rojo plugin -> port 34874 -> Connect.
cd /d "%~dp0"
start "Rojo (WOLD Arena :34874)" /min cmd /c "%~dp0serve-arena-keepalive.bat"
echo Rojo (Arena) started on port 34874 in a background window.
