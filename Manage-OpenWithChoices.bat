@echo off
setlocal EnableExtensions
title Open With Toolkit v7

set "SCRIPT=%~dp0Manage-OpenWithChoices.ps1"
if not exist "%SCRIPT%" (
    echo [ERROR] Manage-OpenWithChoices.ps1 tidak ditemukan:
    echo         "%SCRIPT%"
    echo Pastikan file BAT dan PS1 berada dalam folder yang sama.
    pause
    endlocal & exit /b 1
)
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS%" (
    where powershell.exe >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] Windows PowerShell tidak ditemukan.
        pause
        endlocal & exit /b 9009
    )
    set "PS=powershell.exe"
)
"%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (echo [OK] Toolkit selesai.) else (echo [ERROR] Toolkit berhenti dengan kode %RC%.)
echo.
pause
endlocal & exit /b %RC%
