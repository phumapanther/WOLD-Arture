@echo off
REM Starts the self-restarting Rojo server in its own minimized window, detached from this terminal, so it
REM keeps running after this window closes. Run this instead of serve.bat.
cd /d "%~dp0"
start "Rojo (WOLD Arture)" /min cmd /c "%~dp0serve-keepalive.bat"
echo Rojo started in a background window. Connect from the Studio plugin.
