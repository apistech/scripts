# ============================
# Service Toolkit Universal
# ============================

Write-Host "Jika PowerShell diblokir, jalankan: Set-ExecutionPolicy Unrestricted"
Write-Host "Setelah selesai, kunci kembali dengan: Set-ExecutionPolicy Restricted"
Write-Host ""

Write-Host "=== SERVICE TOOLKIT ===" -ForegroundColor Cyan
Write-Host "1. Ubah StartupType (Disabled / Manual)"
Write-Host "2. Hapus Service (Dry Run / Eksekusi)"
$mainChoice = Read-Host "Pilih mode (1/2)"

# Lokasi log universal
if ($PSScriptRoot) {
    $scriptDir = $PSScriptRoot
} else {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
$logFile = Join-Path $scriptDir ("ServiceToolkitLog_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
"=== Service Toolkit Log $(Get-Date) ===" | Out-File $logFile

# Deteksi versi PowerShell
$psMajor = $PSVersionTable.PSVersion.Major

# =====================================================
# 1. MODE STARTUPTYPE (Disabled / Manual)
# =====================================================
if ($mainChoice -eq "1") {
    Write-Host "Pilih StartupType:" -ForegroundColor Cyan
    Write-Host "1. Disabled"
    Write-Host "2. Manual"
    $choice = Read-Host "Masukkan angka (1/2)"

    switch ($choice) {
        "1" { $TargetStartupType = "Disabled" }
        "2" { $TargetStartupType = "Manual" }
        default {
            Write-Warning "Pilihan tidak valid."
            exit
        }
    }

# ====== DAFTAR SERVICE (gabungan Win7–Win11, auto-skip bila tidak ada) ======
$servicesRaw = @"
AxInstSV
SensrSvc
AeLookupSvc
AarSvc
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
SmsRouter
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
PrintWorkflowUserSvc
wercplsupport
PcaSvc
ProtectedStorage
QWAVE
RmSvc
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
MpsSvc
stisvc
StiSvc
ehRecvr
ehSched
wisvc
LicenseManager
WManSvc
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
"@

    $services = $servicesRaw -split "`n" | ForEach-Object { $_.Trim() } | Sort-Object -Unique

    foreach ($svc in $services) {
        if (-not $svc) { continue }
        try {
            $service = Get-Service -Name $svc -ErrorAction Stop

            if ($psMajor -ge 4) {
                if ($service.StartType -ne $TargetStartupType) {
                    Set-Service -Name $svc -StartupType $TargetStartupType -ErrorAction Stop
                    $msg = "$svc -> $TargetStartupType (SUCCESS)"
                } else {
                    $msg = "$svc -> sudah $TargetStartupType. Dilewati."
                }
            } else {
                $wmi = Get-WmiObject -Class Win32_Service -Filter "Name='$svc'"
                if ($wmi -and $wmi.StartMode -ne $TargetStartupType) {
                    $null = $wmi.ChangeStartMode($TargetStartupType)
                    $msg = "$svc -> $TargetStartupType (SUCCESS via WMI)"
                } elseif ($wmi) {
                    $msg = "$svc -> sudah $TargetStartupType. Dilewati."
                } else {
                    $msg = "$svc -> tidak ditemukan."
                }
            }

            Write-Host $msg -ForegroundColor Green
            $msg | Out-File $logFile -Append
        }
        catch {
            $msg = "Gagal $svc : $($_.Exception.Message)"
            Write-Warning $msg
            $msg | Out-File $logFile -Append
        }
    }
}

# =====================================================
# 2. MODE REMOVE SERVICE
# =====================================================
elseif ($mainChoice -eq "2") {
    Write-Host "1. Dry Run (lihat service yang akan dihapus)"
    Write-Host "2. Eksekusi (stop + delete service)"
    $mode = Read-Host "Pilih mode (1/2)"

    $patterns = @(
    "^AdobeARMservice$",
    "^AMD External Events Utility$",
    "^amd3dvcacheSvc$",
    "^AmdAppCompatSvc$",
    "^amdpmfservice$",
    "^AmdPpkgSvc$",
    "^Backupper Service$",
    "^brave$",
    "^BraveElevationService([0-9\.]+)?$",
    "^bravem$",
    "^cphs$",
    "^DptfPolicyCriticalService$",
    "^DptfPolicyLpmService$",
    "^edgeupdate([0-9\.]+)?$",
    "^edgeupdatem([0-9\.]+)?$",
    "^GoogleChromeElevationService([0-9\.]+)?$",
    "^GoogleUpdaterInternalService([0-9\.]+)?$",
    "^GoogleUpdaterService([0-9\.]+)?$",
    "^gupdate([0-9\.]+)?$",
    "^gupdatem([0-9\.]+)?$",
    "^HfcDisableService$",
    "^iaStorAfsService$",
    "^igfxCUIService([0-9\.]+)?$",
    "^Intel\(R\) Capability Licensing Service TCP IP Interface$",
    "^Intel\(R\) TPM Provisioning Service$",
    "^jhi_service$",
    "^MicrosoftEdgeElevationService([0-9\.]+)?$",
    "^RstMwService$",
    "^VBoxSDS$",
    "^VMAuthdService$",
    "^VMnetDHCP$",
    "^VMUSBArbService$",
    "^VMware NAT Service$",
    "^WondersharePDFelement12DispatchService$"
    )

    Write-Host "Scanning service..." -ForegroundColor Yellow
    $services = Get-Service | ForEach-Object {
        $svc = $_
        foreach ($pattern in $patterns) {
            if ($svc.DisplayName -match $pattern -or $svc.Name -match $pattern) {
                $svc
                break
            }
        }
    }

    if (-not $services) {
        Write-Host "Tidak ada service cocok dengan pola." -ForegroundColor Green
        "Tidak ada service cocok dengan pola." | Out-File $logFile -Append
    }

    foreach ($svc in $services) {
        $info = "Service: $($svc.DisplayName) ($($svc.Name))"
        Write-Host $info -ForegroundColor Cyan
        $info | Out-File $logFile -Append

        if ($mode -eq "2") {
            try {
                if ($svc.Status -eq "Running") {
                    Write-Host "  Stop $($svc.Name)" -ForegroundColor Yellow
                    Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
                }
                Write-Host "  Hapus $($svc.Name)" -ForegroundColor Red
                sc.exe delete $svc.Name | Out-File $logFile -Append
            } catch {
                $msg = "  Gagal hapus $($svc.Name): $_"
                Write-Host $msg -ForegroundColor Red
                $msg | Out-File $logFile -Append
            }
        }
    }
}

Write-Host ""
Write-Host "Selesai. Log tersimpan di: $logFile" -ForegroundColor Cyan
Read-Host "Tekan [Enter] untuk keluar"
