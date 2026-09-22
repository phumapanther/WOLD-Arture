@echo off
cd /d "%~dp0"
:loop
echo [%date% %time%] starting rojo serve farming.project.json --port 34873 ...
"%USERPROFILE%\tools\rojo\rojo.exe" serve farming.project.json --port 34873
echo [%date% %time%] rojo exited, restarting in 2s...
timeout /t 2 /nobreak >nul
goto loop
