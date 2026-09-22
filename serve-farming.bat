@echo off
REM Rojo for the WOLD Farming place, on its own port so it can run beside serve-background.bat (34872).
REM In the Farming Studio window: Rojo plugin -> port 34873 -> Connect.
cd /d "%~dp0"
start "Rojo (WOLD Farming :34873)" /min cmd /c "%~dp0serve-farming-keepalive.bat"
echo Rojo (Farming) started on port 34873 in a background window.
