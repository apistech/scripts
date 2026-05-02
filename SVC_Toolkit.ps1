# ============================
# WINDOWS MAINTENANCE & SERVICE TOOLKIT
# Gabungan Maintenance.ps1 + SVC_Toolkit.ps1
# ============================

Write-Host "Jika PowerShell diblokir, jalankan: Set-ExecutionPolicy Unrestricted" -ForegroundColor Yellow
Write-Host "Setelah selesai, kunci kembali dengan: Set-ExecutionPolicy Restricted" -ForegroundColor Yellow
Write-Host ""

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$psMajor = $PSVersionTable.PSVersion.Major

do {
    Clear-Host
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "    WINDOWS MAINTENANCE & SERVICE TOOLKIT" -ForegroundColor White
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
    $mainChoice = Read-Host "Pilih menu (0-3)"

    if ($mainChoice -eq "0") { break }

    $logFile = Join-Path $scriptDir "ToolkitLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    "=== Toolkit Log $(Get-Date) ===" | Out-File $logFile

# =====================================================
# 1. MAINTENANCE - REGISTRY VALUE CLEANUP
# =====================================================
if ($mainChoice -eq "1") {
    Write-Host ""
    Write-Host "=== CLEANUP REGISTRY VALUES ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Daftar target registry value (format per baris mudah diedit)
    $registryTargetsRaw = @"
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
"@

    $registryTargets = $registryTargetsRaw -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    
    $successCount = 0
    $failCount = 0
    
    foreach ($target in $registryTargets) {
        $parts = $target -split "\|"
        $path = $parts[0]
        $valueName = $parts[1]
        
        if (Test-Path $path) {
            try {
                Remove-ItemProperty -Path $path -Name $valueName -ErrorAction Stop
                Write-Host "  OK: $valueName dihapus dari $path" -ForegroundColor Green
                Add-Content -Path $logFile -Value "SUCCESS: $path\$valueName dihapus"
                $successCount++
            } catch {
                Write-Host "  SKIP: $valueName tidak ditemukan di $path" -ForegroundColor Yellow
                Add-Content -Path $logFile -Value "NOT FOUND: $path\$valueName - $($_.Exception.Message)"
                $failCount++
            }
        } else {
            Write-Host "  SKIP: Path tidak ditemukan - $path" -ForegroundColor Yellow
            Add-Content -Path $logFile -Value "PATH MISSING: $path"
            $failCount++
        }
    }
    
    Write-Host ""
    Write-Host "=== HASIL CLEANUP ===" -ForegroundColor Cyan
    Write-Host "  Berhasil: $successCount" -ForegroundColor Green
    Write-Host "  Gagal/Skip: $failCount" -ForegroundColor Yellow
}

# =====================================================
# 2. MODE STARTUPTYPE (Disabled / Manual)
# =====================================================
elseif ($mainChoice -eq "2") {
    Write-Host ""
    Write-Host "=== UBAH STARTUP TYPE SERVICES ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Pilih StartupType:" -ForegroundColor Yellow
    Write-Host "1. Disabled (Nonaktifkan service)"
    Write-Host "2. Manual (Jalan saat dibutuhkan)"
    $choice = Read-Host "Masukkan angka (1/2)"

    $TargetStartupType = switch ($choice) {
        "1" { "Disabled" }
        "2" { "Manual" }
        default { Write-Warning "Pilihan tidak valid."; continue }
    }

# ====== DAFTAR SERVICE (format per baris tanpa kutip, mudah sync nLite) ======
$servicesRaw = @"
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
"@

    $services = $servicesRaw -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object | Get-Unique
    
    Write-Host ""
    Write-Host "Memproses service..." -ForegroundColor Yellow
    Write-Host ""
    
    $successCount = 0
    $skipCount = 0
    $failCount = 0

    foreach ($svc in $services) {
        try {
            $service = Get-Service -Name $svc -ErrorAction Stop
            
            if ($psMajor -ge 4) {
                if ($service.StartType -ne $TargetStartupType) {
                    Set-Service -Name $svc -StartupType $TargetStartupType -ErrorAction Stop
                    $msg = "  SUCCESS: $svc -> $TargetStartupType"
                    Write-Host $msg -ForegroundColor Green
                    Add-Content -Path $logFile -Value $msg
                    $successCount++
                } else {
                    $msg = "  SKIP: $svc -> sudah $TargetStartupType"
                    Write-Host $msg -ForegroundColor Gray
                    $skipCount++
                }
            } else {
                $wmi = Get-WmiObject -Class Win32_Service -Filter "Name='$svc'" -ErrorAction Stop
                if ($wmi -and $wmi.StartMode -ne $TargetStartupType) {
                    $null = $wmi.ChangeStartMode($TargetStartupType)
                    $msg = "  SUCCESS: $svc -> $TargetStartupType (via WMI)"
                    Write-Host $msg -ForegroundColor Green
                    Add-Content -Path $logFile -Value $msg
                    $successCount++
                } elseif ($wmi) {
                    $msg = "  SKIP: $svc -> sudah $TargetStartupType"
                    Write-Host $msg -ForegroundColor Gray
                    $skipCount++
                } else {
                    $msg = "  SKIP: $svc -> tidak ditemukan"
                    Write-Host $msg -ForegroundColor Gray
                    $skipCount++
                }
            }
        }
        catch {
            $msg = "  FAILED: $svc -> $($_.Exception.Message)"
            Write-Host $msg -ForegroundColor Red
            Add-Content -Path $logFile -Value $msg
            $failCount++
        }
    }
    
    Write-Host ""
    Write-Host "=== HASIL SERVICE STARTUP ===" -ForegroundColor Cyan
    Write-Host "  Berhasil diubah: $successCount" -ForegroundColor Green
    Write-Host "  Dilewati (sudah sesuai): $skipCount" -ForegroundColor Gray
    Write-Host "  Gagal: $failCount" -ForegroundColor Red
}

# =====================================================
# 3. MODE REMOVE SERVICE (DRY RUN / EKSEKUSI)
# =====================================================
elseif ($mainChoice -eq "3") {
    Write-Host ""
    Write-Host "=== HAPUS SERVICE PIHAK KETIGA ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Dry Run (lihat service yang akan dihapus - TANPA menghapus)" -ForegroundColor Yellow
    Write-Host "2. Eksekusi (STOP + DELETE service)" -ForegroundColor Red
    $mode = Read-Host "Pilih mode (1/2)"

# ====== DAFTAR PATTERN (format per baris tanpa kutip) ======
$patternsRaw = @"
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
^VBoxSDS$
^VMAuthdService$
^VMnetDHCP$
^VMUSBArbService$
^VMware NAT Service$
^WondersharePDFelement12DispatchService$
"@

    $patterns = $patternsRaw -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }

    Write-Host ""
    Write-Host "Scanning service..." -ForegroundColor Yellow
    Write-Host ""
    
    $foundServices = Get-Service | Where-Object {
        $svc = $_
        $matched = $false
        foreach ($pattern in $patterns) {
            if ($svc.DisplayName -match $pattern -or $svc.Name -match $pattern) {
                $matched = $true
                break
            }
        }
        $matched
    }

    $serviceList = @($foundServices)
    
    if ($serviceList.Count -eq 0) {
        $msg = "Tidak ada service yang cocok dengan pola."
        Write-Host $msg -ForegroundColor Green
        Add-Content -Path $logFile -Value $msg
    } else {
        Write-Host "Ditemukan $($serviceList.Count) service yang cocok:" -ForegroundColor Cyan
        Write-Host ""
        
        $deleteCount = 0
        $failCount = 0
        
        foreach ($svc in $serviceList) {
            $info = "  [FOUND] $($svc.DisplayName) ($($svc.Name))"
            Write-Host $info -ForegroundColor Cyan
            Add-Content -Path $logFile -Value $info

            if ($mode -eq "2") {
                try {
                    if ($svc.Status -eq "Running") {
                        Write-Host "    -> Stopping..." -ForegroundColor Yellow
                        Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
                        Start-Sleep -Milliseconds 500
                    }
                    
                    Write-Host "    -> Deleting..." -ForegroundColor Red
                    $deleteOutput = sc.exe delete $svc.Name 2>&1
                    if ($deleteOutput) { 
                        Add-Content -Path $logFile -Value "    $deleteOutput"
                    }
                    Write-Host "    -> DELETED" -ForegroundColor Green
                    $deleteCount++
                } catch {
                    Write-Host "    -> FAILED: $($_.Exception.Message)" -ForegroundColor Red
                    Add-Content -Path $logFile -Value "    FAILED: $($_.Exception.Message)"
                    $failCount++
                }
            }
        }
        
        if ($mode -eq "1") {
            Write-Host ""
            Write-Host "=== DRY RUN SELESAI ===" -ForegroundColor Cyan
            Write-Host "Ditemukan $($serviceList.Count) service. Tidak ada yang dihapus." -ForegroundColor Yellow
            Write-Host "Jalankan mode 2 (Eksekusi) untuk menghapus." -ForegroundColor Yellow
        } else {
            Write-Host ""
            Write-Host "=== HASIL DELETE ===" -ForegroundColor Cyan
            Write-Host "  Berhasil dihapus: $deleteCount" -ForegroundColor Green
            Write-Host "  Gagal dihapus: $failCount" -ForegroundColor Red
        }
    }
}

    Write-Host ""
    Write-Host "=== LOG ===" -ForegroundColor Cyan
    Write-Host "Log tersimpan di: $logFile" -ForegroundColor White
    Write-Host ""
    Write-Host "1. Kembali ke Menu Utama" -ForegroundColor Yellow
    Write-Host "0. Keluar" -ForegroundColor Red
    $afterChoice = Read-Host "Pilih (1/0)"

} while ($afterChoice -eq "1")

Write-Host ""
Write-Host "Sampai jumpa!" -ForegroundColor Cyan
Start-Sleep -Seconds 1