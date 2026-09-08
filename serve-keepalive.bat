@echo off
REM Rojo server that survives a closed window and restarts itself if it dies.
REM
REM Why: plain `rojo serve` runs in the foreground of whatever terminal launched it, so closing that window
REM (or any crash) silently kills the sync and Studio starts reporting "Couldn't connect to the Rojo server".
REM Launch this ONCE via serve-background.bat and it keeps re-running rojo until you close the window.
cd /d "%~dp0"
:loop
echo [%date% %time%] starting rojo serve...
"%USERPROFILE%\tools\rojo\rojo.exe" serve
echo [%date% %time%] rojo exited, restarting in 2s...
timeout /t 2 /nobreak >nul
goto loop
