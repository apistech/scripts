@echo off
set "PS_URL=https://raw.githubusercontent.com/apistech/scripts/refs/heads/main/SVC_Toolkit.ps1"
set "PS_SCRIPT_NAME=SVC_Toolkit_temp.ps1"
set "TEMP_PATH=%~dp0%PS_SCRIPT_NAME%"

echo Mengunduh script PowerShell dari %PS_URL%...
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri '%PS_URL%' -OutFile '%TEMP_PATH%'"

if not exist "%TEMP_PATH%" (
    echo Gagal mengunduh script!
    goto :end
)

echo Pengunduhan selesai. Menjalankan script...
PowerShell -NoProfile -ExecutionPolicy Bypass -File "%TEMP_PATH%"

echo Selesai menjalankan script.
echo Menghapus file sementara...
del "%TEMP_PATH%"

:end
pause