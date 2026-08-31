@echo off
chcp 65001 >nul
cd /d "%~dp0"
title AIDA Music Orders v1.0.4

set "AIDA_EXE=%~dp0AIDA Music Orders.exe"

if not exist "%AIDA_EXE%" (
    for /r "%~dp0" %%F in ("AIDA Music Orders.exe") do (
        set "AIDA_EXE=%%~fF"
        goto :found
    )
)

:found
if not exist "%AIDA_EXE%" (
    echo.
    echo [AIDA] ERROR: AIDA Music Orders.exe не найден.
    echo Распакуйте этот upgrade-пакет ВНУТРЬ копии рабочей папки AIDA Music Orders.
    echo.
    pause
    exit /b 1
)

echo [AIDA] Запускаю AIDA Music Orders...
start "" "%AIDA_EXE%"

timeout /t 2 /nobreak >nul

echo [AIDA] Запускаю MiniChat Bridge v1.0.4...
start "" powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0AIDA_MINICHAT_BRIDGE.ps1"

echo [AIDA] Готово.
echo MiniChat Bridge работает скрыто. Лог: AIDA_MiniChat_Bridge.log
timeout /t 2 /nobreak >nul
exit /b 0
