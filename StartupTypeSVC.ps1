# ============================
# Interactive Service StartupType Toggle
# ============================

Write-Host "Jika PowerShell diblokir, jalankan: Set-ExecutionPolicy Unrestricted"
Write-Host "Setelah selesai, kunci kembali dengan: Set-ExecutionPolicy Restricted"
Write-Host ""

# ====== PILIHAN MODE ======
Write-Host "Pilih StartupType untuk semua service di list:" -ForegroundColor Cyan
Write-Host "1. Disabled"
Write-Host "2. Manual"
$choice = Read-Host "Masukkan angka pilihan (1/2)"

switch ($choice) {
    "1" { $TargetStartupType = "Disabled" }
    "2" { $TargetStartupType = "Manual" }
    default {
        Write-Warning "Pilihan tidak valid. Script dihentikan."
        exit
    }
}

Write-Host ""
Write-Host "Mengubah semua service ke mode: $TargetStartupType" -ForegroundColor Yellow
Write-Host ""

# Lokasi log file
$logFile = "$PSScriptRoot\ServiceStartupChange_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
"=== Service Startup Change Log $(Get-Date) ===" | Out-File $logFile

# ====== DAFTAR SERVICE (tanpa duplikat) ======
$services = (@"
AxInstSV
ADPSvc
SensrSvc
AeLookupSvc
AarSvc
AJRouter
amd3dvcacheSvc
AmdAppCompatSvc
amdpmfservice
AmdPpkgSvc
AppReadiness
AppIDSvc
ALG
AppMgmt
AppXSvc
AppXSVC
AssignedAccessManagerSvc
BITS
BDESVC
wbengine
PeerDistSvc
camsvc
CaptureService
autotimesvc
CertPropSvc
ClipSVC
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
LocalKdc
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
Netlogon
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
PrintNotify
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
shpamsvc
SharedRealitySvc
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
McmSvc
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
WinDefend
SDRSVC
WbioSrvc
idsvc
WcsPlugInService
FrameServer
FrameServerMonitor
Wcncsvc
wcncsvc
mpssvc
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
ApxSvc
WinHttpAutoProxySvc
dot3svc
WMPNetworkSvc
workfolderssvc
WSAIFabricSvc
WwanSvc
XboxGipSvc
XblAuthManager
XblGameSave
XboxNetApiSvc
ZTHELPER
"@ -split "`n").Trim() | Sort-Object -Unique

# ====== EKSEKUSI ======
foreach ($svc in $services) {
    if (-not $svc) { continue } # Lewati baris kosong
    try {
        # Cek apakah service ada, jika tidak, langsung ke catch
        $service = Get-Service -Name $svc -ErrorAction Stop
        
        # Hanya ubah jika StartupType berbeda dari yang ditargetkan
        if ($service.StartupType -ne $TargetStartupType) {
            Set-Service -InputObject $service -StartupType $TargetStartupType -ErrorAction Stop
            $msg = "$svc -> $TargetStartupType (SUCCESS)"
            Write-Host $msg -ForegroundColor Green
            $msg | Out-File $logFile -Append
        } else {
            $msg = "$svc -> sudah $TargetStartupType. Dilewati."
            Write-Host $msg -ForegroundColor Gray
            $msg | Out-File $logFile -Append
        }
    } catch {
        $msg = "Gagal memproses $svc : $($_.Exception.Message)"
        Write-Warning $msg
        $msg | Out-File $logFile -Append
    }
}

Write-Host ""
Write-Host "Selesai. Log tersimpan di: $logFile" -ForegroundColor Cyan
