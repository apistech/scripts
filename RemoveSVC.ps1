# ============================
# Service Cleanup
# ============================

Write-Host "Jika PowerShell diblokir, jalankan: Set-ExecutionPolicy Unrestricted"
Write-Host "Setelah selesai, kunci kembali dengan: Set-ExecutionPolicy Restricted"
Write-Host ""

Write-Host "=== SERVICE CLEANUP TOOL ===" -ForegroundColor Cyan
Write-Host "1. Dry Run (lihat service yang akan dihapus)"
Write-Host "2. Eksekusi (stop + delete service)"
$mode = Read-Host "Pilih mode (1/2)"

# Lokasi file log
$logFile = "$PSScriptRoot\ServiceCleanupLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
"=== Service Cleanup Log $(Get-Date) ===" | Out-File $logFile

# === POLA SERVICE ===
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
    "^esifsvc$",
    "^GoogleChromeElevationService([0-9\.]+)?$",
    "^GoogleUpdaterInternalService([0-9\.]+)?$",
    "^GoogleUpdaterService([0-9\.]+)?$",
    "^gupdate([0-9\.]+)?$",
    "^gupdatem([0-9\.]+)?$",
    "^HfcDisableService$",
    "^iaStorAfsService$",
    "^ibtsiva$",
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
    "^VMware NAT Service$"
)

# Ambil semua service
$allServices = Get-Service

foreach ($pattern in $patterns) {
    $matched = $allServices | Where-Object {
        $_.Name -match $pattern -or $_.DisplayName -match $pattern
    }

    if ($matched.Count -eq 0) { continue }

    foreach ($svc in $matched) {
        $svcName = $svc.Name
        $svcDisplay = $svc.DisplayName

        if ($mode -eq "1") {
            $msg = "[DRY RUN] Akan dihapus: $svcName ($svcDisplay)"
            Write-Host $msg
            $msg | Out-File $logFile -Append
        }
        elseif ($mode -eq "2") {
            try {
                if ($svc.Status -eq 'Running') {
                    sc.exe stop $svcName | Out-Null
                    Start-Sleep -Seconds 1
                }
                sc.exe delete $svcName | Out-Null
                $msg = "$svcName dihapus"
                Write-Host $msg -ForegroundColor Green
                $msg | Out-File $logFile -Append
            } catch {
                $msg = "Gagal hapus $svcName : $_"
                Write-Warning $msg
                $msg | Out-File $logFile -Append
            }
        }
    }
}

Write-Host "Selesai. Log tersimpan di: $logFile" -ForegroundColor Cyan
Read-Host "Tekan [Enter] untuk menutup jendela..."
