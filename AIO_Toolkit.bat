@echo off
setlocal EnableDelayedExpansion
title AIO Toolkit Menu
color 0A

:: Elevation
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARN] Butuh Administrator. Relaunch...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: Variables
set "SCRIPT_DIR=%~dp0"
set "PS_EXE=powershell.exe -NoProfile -ExecutionPolicy Bypass"
set "TOOLKIT_URL=https://github.com/apistech/scripts/raw/refs/heads/main/SVC_Toolkit.ps1"
set "CHIPSET_URL=https://github.com/FirstEverTech/Universal-Intel-Chipset-Updater/raw/refs/heads/main/src/universal-intel-chipset-device-updater.ps1"
set "WIFI_URL=https://github.com/FirstEverTech/Universal-Intel-WiFi-BT-Updater/raw/refs/heads/main/src/universal-intel-wifi-bt-driver-updater.ps1"
set "TEMP_DIR=%TEMP%"

goto :menu

:download_and_run
set "URL=%~1"
set "LOCAL=%TEMP_DIR%\%~2"
set "EXTRA=%~3"

echo.
echo [INFO] Mengunduh %~2 ...
%PS_EXE% -Command ^
  "try { " ^
  "  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; " ^
  "  Invoke-WebRequest -Uri '%URL%' -OutFile '%LOCAL%' -UseBasicParsing -ErrorAction Stop; " ^
  "  if (-not (Test-Path '%LOCAL%')) { throw 'File tidak ada setelah download' } " ^
  "  Write-Host '[OK] Download selesai' -ForegroundColor Green " ^
  "} catch { " ^
  "  Write-Host ('[ERROR] ' + $_.Exception.Message) -ForegroundColor Red; " ^
  "  exit 1 " ^
  "}"

if not exist "%LOCAL%" (
    echo [ERROR] Download gagal / file tidak ditemukan.
    pause
    goto :menu
)

echo [INFO] Menjalankan %~2 ...
if "%EXTRA%"=="" (
    %PS_EXE% -File "%LOCAL%"
) else (
    %PS_EXE% -File "%LOCAL%" %EXTRA%
)

echo [INFO] Membersihkan file sementara...
if exist "%LOCAL%" del /f /q "%LOCAL%" >nul 2>&1

echo.
echo [INFO] Selesai.
pause
goto :menu

:menu
cls
echo ============================
echo        AIO Toolkit
echo ============================
echo  1. Microsoft Activation Scripts ^(MAS^)
echo  2. KMS VL AIO ^(PS1^)
echo  3. KMS VL AIO ^(CMD - Win7^)
echo  4. SVC Toolkit ^(Local^)
echo  5. SVC Toolkit ^(Online^)
echo  6. Intel Chipset Updater ^(Online^)
echo  7. Intel Wifi Updater ^(Online^)
echo.
echo  0. Keluar
echo ============================
echo.

set "choice="
set /p "choice=Masukkan pilihan (0-7): "

if not defined choice goto :exit
if "%choice%"=="" goto :exit

if "%choice%"=="0" goto :exit
if "%choice%"=="1" goto :mas_online
if "%choice%"=="2" goto :kms_ps1
if "%choice%"=="3" goto :kms_cmd
if "%choice%"=="4" goto :svc_local
if "%choice%"=="5" goto :svc_online
if "%choice%"=="6" goto :chipset_online
if "%choice%"=="7" goto :wifi_online

echo [WARN] Pilihan tidak valid.
timeout /t 1 /nobreak >nul
goto :menu

:mas_online
echo.
echo [INFO] Menjalankan MAS Online...
echo [WARN] Script remote - pastikan sumber terpercaya.
%PS_EXE% -Command ^
  "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; " ^
  "try { iwr https://get.activated.win -UseBasicParsing | iex } " ^
  "catch { Write-Host ('[ERROR] ' + $_.Exception.Message) -ForegroundColor Red }"
echo.
echo [INFO] Selesai.
pause
goto :menu

:kms_ps1
set "KMS_SCRIPT=%SCRIPT_DIR%KMS_VL_ALL_AIO.ps1"
if not exist "%KMS_SCRIPT%" (
    echo [ERROR] File tidak ditemukan: %KMS_SCRIPT%
    echo Pastikan KMS_VL_ALL_AIO.ps1 ada di folder yang sama.
    pause
    goto :menu
)

echo.
echo [INFO] Menjalankan KMS VL AIO ^(PS1^)...
echo [INFO] Argumen tambahan opsional ^(contoh: /act  atau  /rem^)
set "kms_args="
set /p "kms_args=Masukkan argumen (kosongkan jika tidak ada): "

if "%kms_args%"=="" (
    %PS_EXE% -File "%KMS_SCRIPT%"
) else (
    %PS_EXE% -File "%KMS_SCRIPT%" %kms_args%
)

echo.
echo [INFO] Selesai.
pause
goto :menu

:kms_cmd
set "KMS_CMD=%SCRIPT_DIR%KMS_VL_ALL_AIO.cmd"
if not exist "%KMS_CMD%" (
    echo [ERROR] File tidak ditemukan: %KMS_CMD%
    echo Pastikan KMS_VL_ALL_AIO.cmd ada di folder yang sama ^(untuk Win7^).
    pause
    goto :menu
)

echo.
echo [INFO] Menjalankan KMS VL AIO ^(CMD - Win7 compatible^)...
call "%KMS_CMD%"
echo.
echo [INFO] Selesai.
pause
goto :menu

:svc_local
set "SVC_SCRIPT=%SCRIPT_DIR%SVC_Toolkit.ps1"
if not exist "%SVC_SCRIPT%" (
    echo [ERROR] File tidak ditemukan: %SVC_SCRIPT%
    echo Pastikan SVC_Toolkit.ps1 ada di folder yang sama.
    pause
    goto :menu
)

echo.
echo [INFO] Menjalankan SVC Toolkit ^(Local^)...
%PS_EXE% -File "%SVC_SCRIPT%"
echo.
echo [INFO] Selesai.
pause
goto :menu

:svc_online
call :download_and_run "%TOOLKIT_URL%" "SVC_Toolkit.ps1"
goto :menu

:chipset_online
call :download_and_run "%CHIPSET_URL%" "universal-intel-chipset-device-updater.ps1" "-auto"
goto :menu

:wifi_online
call :download_and_run "%WIFI_URL%" "universal-intel-wifi-bt-driver-updater.ps1" "-auto"
goto :menu

:exit
echo.
echo Keluar...
timeout /t 1 /nobreak >nul
endlocal
exit /b 0