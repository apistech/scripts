@echo off
setlocal enabledelayedexpansion
title SVC Toolkit Launcher
color 0A

:: ============================================
:: VARIABLES
:: ============================================
set "SCRIPT_DIR=%~dp0"
set "PS_EXE=powershell.exe -NoProfile -ExecutionPolicy Bypass"
set "TOOLKIT_URL=https://github.com/apistech/scripts/raw/refs/heads/main/SVC_Toolkit.ps1"

:: ============================================
:: MENU UTAMA
:: ============================================
:menu
cls
echo ============================
echo     Pilih Menu
echo ============================
echo  1. SVC Toolkit (Local)
echo  2. SVC Toolkit (Online)
echo.
echo  Tekan tombol lain untuk keluar
echo ============================

set "choice="
set /p "choice=Masukkan pilihan (1-2): "

if not defined choice goto :exit
if "%choice%"=="" goto :exit

if "%choice%"=="1" goto :svc_local
if "%choice%"=="2" goto :svc_online

:: Jika input tidak valid
goto :exit

:: ============================================
:: 1. SVC TOOLKIT (LOCAL)
:: ============================================
:svc_local
set "SVC_SCRIPT=%SCRIPT_DIR%SVC_Toolkit.ps1"
if not exist "%SVC_SCRIPT%" (
    echo [ERROR] File tidak ditemukan: %SVC_SCRIPT%
    echo Pastikan SVC_Toolkit.ps1 berada di folder yang sama.
    pause
    goto :menu
)

echo.
echo [INFO] Menjalankan SVC Toolkit (Local)...
%PS_EXE% -File "%SVC_SCRIPT%"

echo.
echo [INFO] Selesai.
pause
goto :menu

:: ============================================
:: 2. SVC TOOLKIT (ONLINE)
:: ============================================
:svc_online
echo.
echo [INFO] Mengunduh SVC Toolkit dari GitHub...

%PS_EXE% -Command "Invoke-WebRequest -Uri '%TOOLKIT_URL%' -OutFile '%TEMP%\SVC_Toolkit.ps1' -UseBasicParsing"

if not exist "%TEMP%\SVC_Toolkit.ps1" (
    echo [ERROR] File tidak ditemukan setelah download.
    pause
    goto :menu
)

echo [INFO] Download selesai. Menjalankan SVC Toolkit...
%PS_EXE% -File "%TEMP%\SVC_Toolkit.ps1"

echo [INFO] Membersihkan file sementara...
if exist "%TEMP%\SVC_Toolkit.ps1" del "%TEMP%\SVC_Toolkit.ps1"

echo.
echo [INFO] Selesai.
pause
goto :menu

:: ============================================
:: EXIT
:: ============================================
:exit
echo.
echo Keluar...
timeout /t 1 /nobreak >nul
exit /b 0