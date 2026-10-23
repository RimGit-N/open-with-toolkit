@echo off
setlocal EnableExtensions
title Add Open With App - Incremental Registry Helper

rem Always resolve the companion script relative to this BAT file.
set "SCRIPT=%~dp0Add-OpenWithApp.ps1"

if not exist "%SCRIPT%" (
    echo [ERROR] Add-OpenWithApp.ps1 tidak ditemukan:
    echo         "%SCRIPT%"
    echo.
    echo Pastikan file BAT dan PS1 berada dalam folder yang sama.
    pause
    endlocal & exit /b 1
)

rem Prefer Windows PowerShell; fail clearly if it is unavailable.
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
if "%RC%"=="0" (
    echo [OK] Script selesai tanpa melaporkan error.
) else (
    echo [ERROR] Script gagal atau selesai dengan kode %RC%.
    echo Periksa pesan error di atas sebelum mencoba lagi.
)
echo.
pause
endlocal & exit /b %RC%
