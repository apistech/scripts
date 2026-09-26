# ============================================================
#  WINDOWS MAINTENANCE & SERVICE TOOLKIT
#  Compatible: PowerShell 2.0+ (Windows 7 SP1+)
#  Requires : Administrator
# ============================================================

[CmdletBinding()]
param()

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

# ============================================================
#  ELEVATION (PS 2.0 compatible)
# ============================================================
function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Host "Script butuh Administrator. Relaunch..." -ForegroundColor Yellow
    $scriptPath = $MyInvocation.MyCommand.Definition
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
    exit
}

# ============================================================
#  GLOBALS
# ============================================================
$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (Test-Path variable:\PSScriptRoot) {
    if ($PSScriptRoot) { $script:ScriptDir = $PSScriptRoot }
}

$script:PSMajor = $PSVersionTable.PSVersion.Major
$script:LogFile = $null
$script:LogRetentionDays = 7

# ============================================================
#  LOGGING
# ============================================================
function Write-Log {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet('INFO','SUCCESS','WARN','ERROR','SKIP')][string]$Level = 'INFO'
    )

    $ts   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$ts][$Level] $Message"

    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $line -ErrorAction SilentlyContinue
    }

    switch ($Level) {
        'SUCCESS' { Write-Host $Message -ForegroundColor Green }
        'WARN'    { Write-Host $Message -ForegroundColor Yellow }
        'ERROR'   { Write-Host $Message -ForegroundColor Red }
        'SKIP'    { Write-Host $Message -ForegroundColor Gray }
        default   { Write-Host $Message }
    }
}

function Remove-OldLogs {
    $cutoff = (Get-Date).AddDays(-$script:LogRetentionDays)
    Get-ChildItem -Path $script:ScriptDir -Filter 'ToolkitLog_*.log' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

function New-LogFile {
    Remove-OldLogs
    $script:LogFile = Join-Path $script:ScriptDir ("ToolkitLog_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))
    "=== Toolkit Log $(Get-Date) ===" | Out-File -FilePath $script:LogFile -Encoding utf8
    Write-Log "Log: $($script:LogFile)" 'INFO'
}

# ============================================================
#  SERVICE HELPERS (PS 2.0 safe)
# ============================================================

# Catatan: Set-Service -StartupType sudah ada sejak PS 2.0.
# Tidak perlu WMI fallback untuk SET.
function Set-ServiceStartup {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][ValidateSet('Automatic','Manual','Disabled')][string]$StartupType
    )
    Set-Service -Name $Name -StartupType $StartupType -ErrorAction Stop
}

# Untuk GET: normalize WMI StartMode -> StartupType naming.
function Get-ServiceStartType {
    param([Parameter(Mandatory=$true)][string]$Name)

    if ($script:PSMajor -ge 3) {
        try {
            $svc = Get-Service -Name $Name -ErrorAction Stop
            return [string]$svc.StartType
        }
        catch {
            # PS 3.0 + .NET 4.0: properti StartType belum ada -> fallback WMI
        }
    }

    # PS 2.0: WMI. Normalize "Auto" -> "Automatic" agar konsisten.
    $wmi = Get-WmiObject -Class Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
    if (-not $wmi) { return $null }

    switch ($wmi.StartMode) {
        'Auto'     { return 'Automatic' }
        'Manual'   { return 'Manual'   }
        'Disabled' { return 'Disabled' }
        default    { return [string]$wmi.StartMode }
    }
}

# ============================================================
#  REGISTRY CLEANUP
# ============================================================
$script:RegistryTargetsRaw = @'
HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance|Activation Boundary
HKLM:\SOFTWARE\Policies\Microsoft\Edge|AutofillCreditCardEnabled
HKLM:\SOFTWARE\Policies\Microsoft\Edge|BackgroundModeEnabled
HKLM:\SOFTWARE\Policies\Microsoft\Edge|BasicAuthOverHttpEnabled
HKLM:\SOFTWARE\Policies\Microsoft\Edge|BlockThirdPartyCookies
HKLM:\SOFTWARE\Policies\Microsoft\Edge|BookmarkBarEnabled
HKLM:\SOFTWARE\Policies\Microsoft\Edge|DefaultInsecureContentSetting
HKLM:\SOFTWARE\Policies\Microsoft\Edge|PasswordProtectionWarningTrigger
HKLM:\SOFTWARE\Policies\Microsoft\Edge|ShowFullUrlsInAddressBar
HKLM:\SOFTWARE\Policies\Microsoft\Edge|SitePerProcess
HKLM:\SOFTWARE\Policies\Microsoft\Edge|WindowsHelloForHTTPAuthEnabled
HKLM:\SOFTWARE\Policies\Google\Chrome|AutofillCreditCardEnabled
HKLM:\SOFTWARE\Policies\Google\Chrome|BackgroundModeEnabled
HKLM:\SOFTWARE\Policies\Google\Chrome|BasicAuthOverHttpEnabled
HKLM:\SOFTWARE\Policies\Google\Chrome|BlockThirdPartyCookies
HKLM:\SOFTWARE\Policies\Google\Chrome|BookmarkBarEnabled
HKLM:\SOFTWARE\Policies\Google\Chrome|DefaultInsecureContentSetting
HKLM:\SOFTWARE\Policies\Google\Chrome|PasswordProtectionWarningTrigger
HKLM:\SOFTWARE\Policies\Google\Chrome|ShowFullUrlsInAddressBar
HKLM:\SOFTWARE\Policies\Google\Chrome|SitePerProcess
HKLM:\SOFTWARE\Policies\Google\Chrome|WindowsHelloForHTTPAuthEnabled
'@

function Invoke-RegistryCleanup {
    Write-Host ""
    Write-Host "=== CLEANUP REGISTRY VALUES ===" -ForegroundColor Cyan

    $targets = $script:RegistryTargetsRaw -split "`r?`n" |
               ForEach-Object { $_.Trim() } |
               Where-Object { $_ }

    $ok   = 0
    $skip = 0

    foreach ($t in $targets) {
        $parts = $t -split '\|', 2
        if ($parts.Count -ne 2) { continue }

        $path = $parts[0]
        $name = $parts[1]

        if (-not (Test-Path -LiteralPath $path)) {
            Write-Log "PATH MISSING: $path" 'SKIP'
            $skip++
            continue
        }

        try {
            $null = Get-ItemProperty -LiteralPath $path -Name $name -ErrorAction Stop
            Remove-ItemProperty -LiteralPath $path -Name $name -Force -ErrorAction Stop
            Write-Log "OK: $name dihapus dari $path" 'SUCCESS'
            $ok++
        }
        catch {
            Write-Log "SKIP: $name tidak ada / gagal di $path" 'SKIP'
            $skip++
        }
    }

    Write-Host ""
    Write-Host "=== HASIL CLEANUP ===" -ForegroundColor Cyan
    Write-Host "  Berhasil : $ok"   -ForegroundColor Green
    Write-Host "  Skip     : $skip" -ForegroundColor Yellow
}

# ============================================================
#  SERVICE STARTUP TYPE
# ============================================================
$script:ServiceListRaw = @'
AxInstSV
SensrSvc
AarSvc
ADPSvc
AJRouter
amd3dvcacheSvc
AmdAppCompatSvc
amdpmfservice
AmdPpkgSvc
AppReadiness
AppIDSvc
ALG
AssignedAccessManagerSvc
BITS
BDESVC
wbengine
PeerDistSvc
CaptureService
autotimesvc
CertPropSvc
cbdhsvc
CloudBackupRestoreSvc
clr_optimization_v2.0.50727_32
clr_optimization_v2.0.50727_64
clr_optimization_v4.0.30319_32
clr_optimization_v4.0.30319_64
EventSystem
COMSysApp
DiagTrack
ConsentUxUserSvc
PimIndexMaintenanceSvc
DsSvc
DusmSvc
DoSvc
DeviceAssociationService
DmEnrollmentSvc
dmwappushservice
DevicePickerUserSvc
DevQueryBroker
diagsvc
DPS
WdiServiceHost
WdiSystemHost
TrkWks
MSDTC
MapsBroker
embeddedmode
EntAppSvc
EapHost
Eaphost
Fax
fhsvc
fdPHost
FDResPub
hkmsvc
HomeGroupListener
HomeGroupProvider
BcastDVRUserService
GameInputSvc
lfsvc
GraphicsPerfSvc
hpatchmon
HvHost
vmickvpexchange
vmicguestinterface
vmicshutdown
vmicheartbeat
vmicvmsession
vmicrdv
vmictimesync
vmicvss
IKEEXT
UI0Detect
IEEtwCollectorService
iaStorAfsService
HfcDisableService
RstMwService
SharedAccess
InventorySvc
IpxlatCfgSvc
PolicyAgent
IsolationSession
KtmRm
LxpSvc
lltdsvc
wlpasvc
MessagingService
diagnosticshub.standardcollector.service
cloudidsvc
WdNisSvc
WinDefend
MDCoreSvc
edgeupdate
edgeupdatem
MSiSCSI
NgcSvc
NgcCtnrSvc
swprv
smphost
InstallService
wuqisvc
SmsRouter
McmSvc
NaturalAuthentication
Netlogon
napagent
NPSMSvc
CscService
WPCSvc
defragsvc
P9RdrService
WpcMonSvc
SEMgrSvc
PNRPsvc
p2psvc
p2pimsvc
PenService
pla
PhoneSvc
PNRPAutoReg
WPDBusEnum
wercplsupport
PcaSvc
QWAVE
TroubleshootingSvc
RasAuto
RasMan
SessionEnv
TermService
UmRdpService
RpcLocator
RemoteRegistry
RetailDemo
SstpSvc
wscsvc
SensorDataService
SensrSvc
SCardSvr
ScDeviceEnum
SCPolicySvc
sppuinotify
SharedRealitySvc
SSDPSRV
WiaRpc
TieringEngineService
OneSyncSvc
SysMain
SENS
TapiSrv
UsoSvc
upnphost
UserDataSvc
UnistoreSvc
VSS
VacSvc
WaaSMedicSvc
WalletService
WarpJITSvc
webthreatdefsvc
webthreatdefusersvc
WebClient
WFDSConMgrSvc
WSAIFabricSvc
SDRSVC
WbioSrvc
wcncsvc
Sense
mpssvc
WEPHOSTSVC
WerSvc
whesvc
MpsSvc
StiSvc
stisvc
ehRecvr
ehSched
wisvc
WManSvc
WMPNetworkSvc
midisrv
MixedRealityOpenXRSvc
icssvc
spectrum
perceptionsimulation
WpnService
PushToInstall
WinRM
WSearch
W32Time
wuauserv
ApxSvc
WinHttpAutoProxySvc
dot3svc
workfolderssvc
WwanSvc
XboxGipSvc
XblAuthManager
XblGameSave
XboxNetApiSvc
ZTHELPER
'@

function Set-ServiceStartupType {
    Write-Host ""
    Write-Host "=== UBAH STARTUP TYPE SERVICES ===" -ForegroundColor Cyan
    Write-Host "1. Disabled"
    Write-Host "2. Manual"
    $c = Read-Host "Pilih (1/2)"

    $target = switch ($c) {
        '1' { 'Disabled' }
        '2' { 'Manual'   }
        default {
            Write-Log "Pilihan tidak valid." 'WARN'
            return
        }
    }

    $services = $script:ServiceListRaw -split "`r?`n" |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ } |
                Sort-Object -Unique

    Write-Host ""
    Write-Host "Target StartupType: $target" -ForegroundColor Yellow
    Write-Host "Memproses $($services.Count) service..."
    Write-Host ""

    $ok   = 0
    $skip = 0
    $fail = 0

    foreach ($name in $services) {
        try {
            $null = Get-Service -Name $name -ErrorAction Stop

            $current = Get-ServiceStartType -Name $name
            if ($current -and ($current -eq $target)) {
                Write-Log "SKIP: $name sudah $target" 'SKIP'
                $skip++
                continue
            }

            Set-ServiceStartup -Name $name -StartupType $target
            Write-Log "SUCCESS: $name -> $target" 'SUCCESS'
            $ok++
        }
        catch {
            $svcExists = Get-Service -Name $name -ErrorAction SilentlyContinue
            if (-not $svcExists) {
                Write-Log "SKIP: $name tidak ada" 'SKIP'
                $skip++
            }
            else {
                Write-Log "FAILED: $name - $($_.Exception.Message)" 'ERROR'
                $fail++
            }
        }
    }

    Write-Host ""
    Write-Host "=== HASIL SERVICE STARTUP ===" -ForegroundColor Cyan
    Write-Host "  Berhasil : $ok"   -ForegroundColor Green
    Write-Host "  Skip     : $skip" -ForegroundColor Gray
    Write-Host "  Gagal    : $fail" -ForegroundColor Red
}

# ============================================================
#  STOP & DISABLE 3RD-PARTY SERVICES
# ============================================================
$script:ServicePatternsRaw = @'
^AdobeARMservice$
^AMD External Events Utility$
^amd3dvcacheSvc$
^AmdAppCompatSvc$
^amdpmfservice$
^AmdPpkgSvc$
^Backupper Service$
^brave$
^BraveElevationService([0-9\.]+)?$
^bravem$
^cphs$
^DptfPolicyCriticalService$
^DptfPolicyLpmService$
^edgeupdate([0-9\.]+)?$
^edgeupdatem([0-9\.]+)?$
^GoogleChromeElevationService([0-9\.]+)?$
^GoogleUpdaterInternalService([0-9\.]+)?$
^GoogleUpdaterService([0-9\.]+)?$
^gupdate([0-9\.]+)?$
^gupdatem([0-9\.]+)?$
^HfcDisableService$
^iaStorAfsService$
^igfxCUIService([0-9\.]+)?$
^Intel\(R\) Capability Licensing Service TCP IP Interface$
^Intel\(R\) TPM Provisioning Service$
^jhi_service$
^MicrosoftEdgeElevationService([0-9\.]+)?$
^RstMwService$
^ss_conn_service$
^ss_conn_service2$
^VBoxSDS$
^VMAuthdService$
^VMnetDHCP$
^VMUSBArbService$
^VMware NAT Service$
^WondersharePDFelement12DispatchService$
'@

function Find-MatchedServices {
    $patterns = $script:ServicePatternsRaw -split "`r?`n" |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ }

    $found = @()
    foreach ($svc in (Get-Service)) {
        foreach ($p in $patterns) {
            if ($svc.Name -match $p -or $svc.DisplayName -match $p) {
                $found += $svc
                break
            }
        }
    }
    return $found
}

function Stop-Disable-MatchedServices {
    Write-Host ""
    Write-Host "=== STOP & DISABLE SERVICE PIHAK KETIGA ===" -ForegroundColor Cyan
    Write-Host "1. Dry Run (lihat saja)"
    Write-Host "2. Eksekusi (STOP + DISABLE)" -ForegroundColor Yellow
    $mode = Read-Host "Pilih (1/2)"

    if (@('1','2') -notcontains $mode) {
        Write-Log "Pilihan tidak valid." 'WARN'
        return
    }

    Write-Host ""
    Write-Host "Scanning..." -ForegroundColor Yellow

    $found = @(Find-MatchedServices)

    if ($found.Count -eq 0) {
        Write-Log "Tidak ada service yang cocok." 'SUCCESS'
        return
    }

    Write-Host "Ditemukan $($found.Count) service:" -ForegroundColor Cyan
    foreach ($s in $found) {
        $st = Get-ServiceStartType -Name $s.Name
        Write-Log "[FOUND] $($s.DisplayName) ($($s.Name)) | Status=$($s.Status) StartType=$st" 'INFO'
    }

    if ($mode -eq '1') {
        Write-Host ""
        Write-Host "=== DRY RUN SELESAI ===" -ForegroundColor Cyan
        Write-Host "Tidak ada perubahan. Jalankan mode 2 untuk eksekusi." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "PERINGATAN: Service akan di-STOP lalu di-DISABLE." -ForegroundColor Yellow
    $confirm = Read-Host "Ketik YES untuk lanjut"
    if ($confirm -ne 'YES') {
        Write-Log "Dibatalkan user." 'WARN'
        return
    }

    $ok   = 0
    $skip = 0
    $fail = 0

    foreach ($svc in $found) {
        try {
            $name = $svc.Name

            if ($svc.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
                Write-Host "  Stopping $name..." -ForegroundColor Yellow
                Stop-Service -Name $name -Force -ErrorAction Stop
                Start-Sleep -Milliseconds 400
                Write-Log "STOPPED: $name" 'SUCCESS'
            }
            else {
                Write-Log "SKIP STOP: $name sudah $($svc.Status)" 'SKIP'
            }

            $current = Get-ServiceStartType -Name $name
            if ($current -eq 'Disabled') {
                Write-Log "SKIP DISABLE: $name sudah Disabled" 'SKIP'
                $skip++
            }
            else {
                Set-ServiceStartup -Name $name -StartupType 'Disabled'
                Write-Log "DISABLED: $name" 'SUCCESS'
                $ok++
            }
        }
        catch {
            Write-Log "FAILED: $($svc.Name) - $($_.Exception.Message)" 'ERROR'
            $fail++
        }
    }

    Write-Host ""
    Write-Host "=== HASIL STOP + DISABLE ===" -ForegroundColor Cyan
    Write-Host "  Berhasil : $ok"   -ForegroundColor Green
    Write-Host "  Skip     : $skip" -ForegroundColor Gray
    Write-Host "  Gagal    : $fail" -ForegroundColor Red
}

# ============================================================
#  MENU
# ============================================================
function Show-MainMenu {
    Clear-Host
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "    WINDOWS MAINTENANCE and SERVICE TOOLKIT" -ForegroundColor White
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "=== MAINTENANCE (Registry) ===" -ForegroundColor Green
    Write-Host "1.  Cleanup Registry Values (Edge/Chrome/Maintenance)"
    Write-Host ""
    Write-Host "=== SERVICE MANAGEMENT ===" -ForegroundColor Green
    Write-Host "2.  Ubah StartupType Services (Disabled / Manual)"
    Write-Host "3.  Stop & Disable Service Pihak Ketiga (Dry Run / Eksekusi)"
    Write-Host ""
    Write-Host "=== UTILITY ===" -ForegroundColor Green
    Write-Host "0.  Keluar"
    Write-Host ""
}

# ============================================================
#  ENTRY POINT
# ============================================================
Write-Host "Jika PowerShell diblokir, jalankan: Set-ExecutionPolicy Unrestricted" -ForegroundColor Yellow
Write-Host "Setelah selesai, kunci kembali dengan: Set-ExecutionPolicy Restricted"  -ForegroundColor Yellow
Write-Host ""

do {
    Show-MainMenu
    $choice = Read-Host "Pilih menu (0-3)"

    if ($choice -eq '0') { break }

    if (@('1','2','3') -notcontains $choice) {
        Write-Host "Pilihan tidak valid." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        continue
    }

    New-LogFile

    switch ($choice) {
        '1' { Invoke-RegistryCleanup }
        '2' { Set-ServiceStartupType }
        '3' { Stop-Disable-MatchedServices }
    }

    Write-Host ""
    Write-Host "=== LOG ===" -ForegroundColor Cyan
    Write-Host "Log tersimpan di: $($script:LogFile)" -ForegroundColor White
    Write-Host ""
    Write-Host "1. Kembali ke Menu Utama" -ForegroundColor Yellow
    Write-Host "0. Keluar" -ForegroundColor Red
    $after = Read-Host "Pilih (1/0)"

} while ($after -eq '1')

Write-Host ""
Write-Host "Sampai jumpa!" -ForegroundColor Cyan
Start-Sleep -Seconds 1