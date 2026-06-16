@echo off
title GPORTAL Enshrouded Backup Setup

cd /d "%~dp0"

echo Starting GPORTAL Enshrouded Backup Setup...
echo.
echo Using Windows PowerShell 5.1:
echo C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
echo.

if not exist "%~dp0Setup-Enshrouded-Backup.ps1" (
    echo ERROR: Setup-Enshrouded-Backup.ps1 was not found in this folder.
    echo.
    echo Put this BAT file in the same folder as Setup-Enshrouded-Backup.ps1.
    echo.
    pause
    exit /b 1
)

"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" ^
-NoProfile ^
-ExecutionPolicy Bypass ^
-STA ^
-NoExit ^
-File "%~dp0Setup-Enshrouded-Backup.ps1"

echo.
pause