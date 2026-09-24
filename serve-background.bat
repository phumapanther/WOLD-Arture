@echo off
REM Starts the self-restarting Rojo servers for ALL THREE places, each in its own minimized window, detached
REM from this terminal so they keep running after this window closes. The desktop shortcut
REM "Rojo - WOLD Arture" runs this file.
REM
REM   main place     88774255487951  -> port 34872  (default.project.json)
REM   WOLD Farming   136992335889132 -> port 34873  (farming.project.json)
REM   WOLD Arena     134798670267276 -> port 34874  (arena.project.json)
REM
REM In each Studio window: Rojo plugin -> set the port above -> Connect.
REM A port that is already listening is skipped, so running this twice does not start duplicates.
cd /d "%~dp0"

call :start 34872 "Rojo (WOLD Arture :34872)" serve-keepalive.bat
call :start 34873 "Rojo (WOLD Farming :34873)" serve-farming-keepalive.bat
call :start 34874 "Rojo (WOLD Arena :34874)" serve-arena-keepalive.bat

echo.
echo Connect in Studio with these ports:  main 34872 / Farming 34873 / Arena 34874
timeout /t 5 >nul
goto :eof

:start
netstat -ano | findstr /r /c:":%1 .*LISTENING" >nul
if %errorlevel%==0 (
  echo port %1 already running - skipped
) else (
  start "%~2" /min cmd /c "%~dp0%3"
  echo started %~2
)
goto :eof
