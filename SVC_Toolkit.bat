@echo off
setlocal EnableDelayedExpansion
title SVC Toolkit Launcher

:: --- Config ---
set "PS_URL=https://raw.githubusercontent.com/apistech/scripts/refs/heads/main/SVC_Toolkit.ps1"
set "LOCAL_PS1=%~dp0SVC_Toolkit.ps1"
set "TEMP_PS1=%~dp0SVC_Toolkit_temp.ps1"

:: --- Pre-flight check ---
where powershell >nul 2>&1
if errorlevel 1 (
    echo [ERROR] PowerShell tidak ditemukan di PATH.
    pause
    exit /b 1
)

:menu
cls
echo ============================
echo   SVC Toolkit Launcher
echo ============================
echo 1. SVC Toolkit (Online - download terbaru)
echo 2. SVC Toolkit (Local)
echo 0. Exit
echo ============================
set /p "choice=Pilih menu: "

if "%choice%"=="1" goto :online
if "%choice%"=="2" goto :local
if "%choice%"=="0" exit /b 0

echo Pilihan tidak valid.
timeout /t 1 >nul
goto :menu

:online
echo Mengunduh script dari %PS_URL% ...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { Invoke-WebRequest -Uri '%PS_URL%' -OutFile '%TEMP_PS1%' -UseBasicParsing -ErrorAction Stop } catch { Write-Host '[ERROR]' $_.Exception.Message; exit 1 }"

if errorlevel 1 (
    echo Gagal mengunduh script.
    pause
    goto :menu
)

if not exist "%TEMP_PS1%" (
    echo File hasil download tidak ditemukan.
    pause
    goto :menu
)

echo Download selesai. Menjalankan...
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP_PS1%"

echo Membersihkan file sementara...
del /f /q "%TEMP_PS1%" 2>nul
pause
goto :menu

:local
if not exist "%LOCAL_PS1%" (
    echo [ERROR] SVC_Toolkit.ps1 tidak ditemukan di folder ini.
    pause
    goto :menu
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%LOCAL_PS1%"
pause
goto :menu