@echo off
setlocal EnableExtensions
 title Open With Registry Reader - Read Only

rem Always resolve the companion script relative to this BAT file.
set "SCRIPT=%~dp0Read-OpenWithRegistry.ps1"

if not exist "%SCRIPT%" (
    echo [ERROR] Read-OpenWithRegistry.ps1 tidak ditemukan:
    echo         "%SCRIPT%"
    echo.
    echo Pastikan file BAT dan PS1 berada dalam folder yang sama.
    pause
    endlocal & exit /b 1
)

set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS%" set "PS=powershell.exe"

"%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
    echo [OK] Reader selesai tanpa melaporkan error.
) else (
    echo [ERROR] Reader gagal atau selesai dengan kode %RC%.
    echo Periksa pesan error di atas.
)
echo.
pause
endlocal & exit /b %RC%
