@echo off
cd /d "%~dp0"
:loop
echo [%date% %time%] starting rojo serve arena.project.json --port 34874 ...
"%USERPROFILE%\tools\rojo\rojo.exe" serve arena.project.json --port 34874
echo [%date% %time%] rojo exited, restarting in 2s...
timeout /t 2 /nobreak >nul
goto loop
