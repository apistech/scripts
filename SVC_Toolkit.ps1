#Requires -Version 5.1
# ============================
# WINDOWS MAINTENANCE & SERVICE TOOLKIT
# ============================

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------- Elevation ----------
function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Host "Script butuh Administrator. Relaunch..." -ForegroundColor Yellow
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $args
    exit
}

# ---------- Globals ----------
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$psMajor   = $PSVersionTable.PSVersion.Major
$logFile   = $null

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','SUCCESS','WARN','ERROR','SKIP')]$Level = 'INFO'
    )
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$ts][$Level] $Message"
    if ($logFile) {
        Add-Content -Path $logFile -Value $line -ErrorAction SilentlyContinue
    }
    switch ($Level) {
        'SUCCESS' { Write-Host $Message -ForegroundColor Green }
        'WARN'    { Write-Host $Message -ForegroundColor Yellow }
        'ERROR'   { Write-Host $Message -ForegroundColor Red }
        'SKIP'    { Write-Host $Message -ForegroundColor Gray }
        default   { Write-Host $Message }
    }
}

function New-LogFile {
    $script:logFile = Join-Path $scriptDir ("ToolkitLog_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))
    "=== Toolkit Log $(Get-Date) ===" | Out-File -FilePath $logFile -Encoding utf8
    Write-Log "Log: $logFile" 'INFO'
}

# ---------- Registry Cleanup ----------
function Invoke-RegistryCleanup {
    Write-Host ""
    Write-Host "=== CLEANUP REGISTRY VALUES ===" -ForegroundColor Cyan

    $registryTargetsRaw = @'
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

    $targets = $registryTargetsRaw -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    $ok = 0
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
    Write-Host "  Berhasil : $ok" -ForegroundColor Green
    Write-Host "  Skip     : $skip" -ForegroundColor Yellow
}

# ---------- Service StartupType ----------
function Set-ServiceStartupType {
    Write-Host ""
    Write-Host "=== UBAH STARTUP TYPE SERVICES ===" -ForegroundColor Cyan
    Write-Host "1. Disabled"
    Write-Host "2. Manual"
    $c = Read-Host "Pilih (1/2)"

    $target = switch ($c) {
        '1' { 'Disabled' }
        '2' { 'Manual' }
        default {
            Write-Log "Pilihan tidak valid." 'WARN'
            return
        }
    }

    $servicesRaw = @'
AxInstSV
SensrSvc
AeLookupSvc
AarSvc
ADPSvc
AJRouter
amd3dvcacheSvc
AmdAppCompatSvc
amdpmfservice
AmdPpkgSvc
AppIDSvc
ALG
AppMgmt
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
KeyIso
EventSystem
COMSysApp
CDPSvc
CDPUserSvc
DiagTrack
ConsentUxUserSvc
PimIndexMaintenanceSvc
DsSvc
DusmSvc
dcsvc
DoSvc
DmEnrollmentSvc
dmwappushservice
DevicePickerUserSvc
DevQueryBroker
diagsvc
DPS
WdiServiceHost
WdiSystemHost
defragsvc
TrkWks
MSDTC
MapsBroker
embeddedmode
EFS
EntAppSvc
Eaphost
EapHost
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
irmon
igfxCUIService
iaStorAfsService
HfcDisableService
RstMwService
SharedAccess
InventorySvc
iphlpsvc
IpxlatCfgSvc
PolicyAgent
KtmRm
LxpSvc
lltdsvc
clr_optimization_v2.0.50727_64
clr_optimization_v2.0.50727_32
clr_optimization_v4.0.30319_64
clr_optimization_v4.0.30319_32
wlpasvc
McpManagementService
MessagingService
diagnosticshub.standardcollector.service
cloudidsvc
MicrosoftEdgeElevationService
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
napagent
NcdAutoSetup
NcaSvc
NPSMSvc
CscService
defragsvc
WPCSvc
P9RdrSvc
P9RdrService
WpcMonSvc
SEMgrSvc
PNRPsvc
p2psvc
p2pimsvc
PenService
PerfHost
pla
IPBusEnum
PhoneSvc
PNRPAutoReg
WPDBusEnum
PrintDeviceConfigurationService
PrintScanBrokerService
PrintWorkflowUserSvc
wercplsupport
PcaSvc
ProtectedStorage
QWAVE
RmSvc
TroubleshootingSvc
refsdedupsvc
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
Sense
SensorDataService
SensrSvc
SensorService
SCardSvr
ScDeviceEnum
SCPolicySvc
SNMPTRAP
SNMPTrap
SharedRealitySvc
sppuinotify
SSDPSRV
WiaRpc
StorSvc
TieringEngineService
OneSyncSvc
SysMain
SENS
TabletInputService
SgrmBroker
TapiSrv
TabletInputService
TBS
TextInputManagementService
UdkUserSvc
UsoSvc
upnphost
UserDataSvc
UnistoreSvc
VSS
VacSvc
WaaSMedicSvc
WalletService
WarpJITSvc
WdNisSvc
webthreatdefsvc
webthreatdefusersvc
WebClient
WFDSConMgrSvc
WinDefend
SDRSVC
WbioSrvc
wcncsvc
WEPHOSTSVC
WerSvc
whesvc
MpsSvc
stisvc
StiSvc
ehRecvr
ehSched
wisvc
LicenseManager
WManSvc
midisrv
MixedRealityOpenXRSvc
icssvc
spectrum
perceptionsimulation
WpnService
PushToInstall
WinRM
WSearch
SecurityHealthService
W32Time
wuauserv
ApxSvc
WaaSMedicSvc
WinHttpAutoProxySvc
dot3svc
WMPNetworkSvc
workfolderssvc
WwanSvc
XboxGipSvc
XblAuthManager
XblGameSave
XboxNetApiSvc
ZTHELPER
'@

    $services = $servicesRaw -split "`r?`n" |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ } |
                Sort-Object -Unique

    Write-Host ""
    Write-Host "Target StartupType: $target" -ForegroundColor Yellow
    Write-Host "Memproses $($services.Count) service..."
    Write-Host ""

    $ok = 0
    $skip = 0
    $fail = 0

    foreach ($name in $services) {
        try {
            $svc = Get-Service -Name $name -ErrorAction Stop

            if ($psMajor -ge 4) {
                if ($svc.StartType -eq $target) {
                    Write-Log "SKIP: $name sudah $target" 'SKIP'
                    $skip++
                    continue
                }
                Set-Service -Name $name -StartupType $target -ErrorAction Stop
                Write-Log "SUCCESS: $name -> $target" 'SUCCESS'
                $ok++
            }
            else {
                $wmi = Get-WmiObject -Class Win32_Service -Filter "Name='$name'" -ErrorAction Stop
                if (-not $wmi) {
                    Write-Log "SKIP: $name tidak ditemukan (WMI)" 'SKIP'
                    $skip++
                    continue
                }
                if ($wmi.StartMode -eq $target) {
                    Write-Log "SKIP: $name sudah $target" 'SKIP'
                    $skip++
                    continue
                }
                $result = $wmi.ChangeStartMode($target)
                if ($result.ReturnValue -eq 0) {
                    Write-Log "SUCCESS: $name -> $target (WMI)" 'SUCCESS'
                    $ok++
                }
                else {
                    throw "WMI ReturnValue=$($result.ReturnValue)"
                }
            }
        }
        catch {
            Write-Log "FAILED: $name - $($_.Exception.Message)" 'ERROR'
            $fail++
        }
    }

    Write-Host ""
    Write-Host "=== HASIL SERVICE STARTUP ===" -ForegroundColor Cyan
    Write-Host "  Berhasil : $ok" -ForegroundColor Green
    Write-Host "  Skip     : $skip" -ForegroundColor Gray
    Write-Host "  Gagal    : $fail" -ForegroundColor Red
}

# ---------- Remove 3rd-party services ----------
function Remove-MatchedServices {
    Write-Host ""
    Write-Host "=== HAPUS SERVICE PIHAK KETIGA ===" -ForegroundColor Cyan
    Write-Host "1. Dry Run (lihat saja)"
    Write-Host "2. Eksekusi (STOP + DELETE)" -ForegroundColor Red
    $mode = Read-Host "Pilih (1/2)"

    if ($mode -notin @('1','2')) {
        Write-Log "Pilihan tidak valid." 'WARN'
        return
    }

    $patternsRaw = @'
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

    $patterns = $patternsRaw -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }

    Write-Host ""
    Write-Host "Scanning..." -ForegroundColor Yellow

    $found = @(Get-Service | Where-Object {
        $svc = $_
        foreach ($p in $patterns) {
            if ($svc.Name -match $p -or $svc.DisplayName -match $p) {
                return $true
            }
        }
        return $false
    })

    if ($found.Count -eq 0) {
        Write-Log "Tidak ada service yang cocok." 'SUCCESS'
        return
    }

    Write-Host "Ditemukan $($found.Count) service:" -ForegroundColor Cyan
    foreach ($s in $found) {
        Write-Log "[FOUND] $($s.DisplayName) ($($s.Name))" 'INFO'
    }

    if ($mode -eq '1') {
        Write-Host ""
        Write-Host "=== DRY RUN SELESAI ===" -ForegroundColor Cyan
        Write-Host "Tidak ada yang dihapus. Jalankan mode 2 untuk eksekusi." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "PERINGATAN: Service akan di-STOP lalu DELETE permanen." -ForegroundColor Red
    $confirm = Read-Host "Ketik DELETE untuk lanjut"
    if ($confirm -ne 'DELETE') {
        Write-Log "Dibatalkan user." 'WARN'
        return
    }

    $ok = 0
    $fail = 0

    foreach ($svc in $found) {
        try {
            if ($svc.Status -eq 'Running') {
                Write-Host "  Stopping $($svc.Name)..." -ForegroundColor Yellow
                Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 600
            }

            $out = & sc.exe delete $($svc.Name) 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log "DELETED: $($svc.Name)" 'SUCCESS'
                $ok++
            }
            else {
                throw "sc.exe exit=$LASTEXITCODE | $out"
            }
        }
        catch {
            Write-Log "FAILED: $($svc.Name) - $($_.Exception.Message)" 'ERROR'
            $fail++
        }
    }

    Write-Host ""
    Write-Host "=== HASIL DELETE ===" -ForegroundColor Cyan
    Write-Host "  Berhasil : $ok" -ForegroundColor Green
    Write-Host "  Gagal    : $fail" -ForegroundColor Red
}

# ---------- Main Menu ----------
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
    Write-Host "3.  Hapus Service Pihak Ketiga (Dry Run / Eksekusi)"
    Write-Host ""
    Write-Host "=== UTILITY ===" -ForegroundColor Green
    Write-Host "0.  Keluar"
    Write-Host ""
}

# ---------- Entry ----------
Write-Host "Jika PowerShell diblokir, jalankan: Set-ExecutionPolicy Unrestricted" -ForegroundColor Yellow
Write-Host "Setelah selesai, kunci kembali dengan: Set-ExecutionPolicy Restricted" -ForegroundColor Yellow
Write-Host ""

do {
    Show-MainMenu
    $choice = Read-Host "Pilih menu (0-3)"

    if ($choice -eq '0') { break }

    if ($choice -notin @('1','2','3')) {
        Write-Host "Pilihan tidak valid." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        continue
    }

    New-LogFile

    switch ($choice) {
        '1' { Invoke-RegistryCleanup }
        '2' { Set-ServiceStartupType }
        '3' { Remove-MatchedServices }
    }

    Write-Host ""
    Write-Host "=== LOG ===" -ForegroundColor Cyan
    Write-Host "Log tersimpan di: $logFile" -ForegroundColor White
    Write-Host ""
    Write-Host "1. Kembali ke Menu Utama" -ForegroundColor Yellow
    Write-Host "0. Keluar" -ForegroundColor Red
    $after = Read-Host "Pilih (1/0)"

} while ($after -eq '1')

Write-Host ""
Write-Host "Sampai jumpa!" -ForegroundColor Cyan
Start-Sleep -Seconds 1