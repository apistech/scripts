# ============================
# Registry Value Cleanup
# ============================

Write-Host "Jika PowerShell diblokir, jalankan: Set-ExecutionPolicy Unrestricted"
Write-Host "Setelah selesai, kunci kembali dengan: Set-ExecutionPolicy Restricted"
Write-Host ""

# Daftar target registry value
$targets = @(
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance"; Values = @("Activation Boundary") },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Values = @(
        "AutofillCreditCardEnabled",
        "BackgroundModeEnabled",
        "BasicAuthOverHttpEnabled",
        "BlockThirdPartyCookies",
        "BookmarkBarEnabled",
        "DefaultInsecureContentSetting",
        "PasswordProtectionWarningTrigger",
        "ShowFullUrlsInAddressBar",
        "SitePerProcess",
        "WindowsHelloForHTTPAuthEnabled"
    )}
    @{ Path = "HKLM:\SOFTWARE\Policies\Google\Chrome"; Values = @(
        "AutofillCreditCardEnabled",
        "BackgroundModeEnabled",
        "BasicAuthOverHttpEnabled",
        "BlockThirdPartyCookies",
        "BookmarkBarEnabled",
        "DefaultInsecureContentSetting",
        "PasswordProtectionWarningTrigger",
        "ShowFullUrlsInAddressBar",
        "SitePerProcess",
        "WindowsHelloForHTTPAuthEnabled"
    )}
)

# Eksekusi penghapusan
foreach ($target in $targets) {
    $path = $target.Path
    if (Test-Path $path) {
        foreach ($val in $target.Values) {
            try {
                # Coba hapus langsung, jika berhasil akan ada output
                # Jika tidak ada, PowerShell akan memberikan error yang kita tangkap
                Remove-ItemProperty -Path $path -Name $val -ErrorAction Stop
                Write-Host "$val berhasil dihapus dari $path"
            } catch {
                Write-Host "Value '$val' tidak ditemukan atau gagal dihapus dari $path. Pesan error: $($_.Exception.Message)"
            }
        }
    } else {
        Write-Host "Path tidak ditemukan: $path"
    }
}

Write-Host ""
Read-Host "Tekan [Enter] untuk keluar"
