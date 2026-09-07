
$uivr = 'v55 PS'

# =========================
# Configuration Options
# =========================

# change to 1 to use alternative Debugger-based DLL hook instead Avrf-based DLL
$AltDLL = 0

# change to 0 to turn OFF Windows or Office activation processing via the script
$ActWindows = 1
$ActOffice  = 1

# change to 0 to turn OFF auto conversion for Office C2R Retail to Volume
$AutoR2V = 1

# change to 0 to keep Office C2R vNext license (subscription or lifetime)
$vNextOverride = 1

# change to 0 to revert Windows 10/11 KMS38 to normal KMS
$SkipKMS38 = 1

# change to 0 to keep configured KMS cache upon removal (recommended only if you plan to reinstall)
$ClearKMSCache = 1

# =========================
# Unattended Options
# =========================

# change External to 1 and set KMS_IP address to activate via external KMS server unattended
$External = 0
$KMS_IP = '172.16.0.2'

# change to 1 to run Manual activation mode unattended
$uManual = 0

# change to 1 to run AutoRenewal activation mode unattended
$uAutoRenewal = 0

# =========================
# Advanced KMS Options
# =========================

# change KMS auto renewal schedule for activated clients, range in minutes: from 15 to 43200
# example: 10080 = weekly, 1440 = daily, 43200 = monthly
$KMS_RenewalInterval = 10080

# change KMS reattempt schedule for unactivated clients, range in minutes: from 15 to 43200
$KMS_ActivationInterval = 120

# change Hardware Hash for KMS emulator server (only affect Windows 8.1 and later)
$KMS_HWID = 0x3A1C049600B60076

# change KMS TCP port
$KMS_Port = '1688'

###################################################################
# NORMALLY THERE IS NO NEED TO CHANGE ANYTHING BELOW THIS COMMENT #
###################################################################

# change to 1 to enable debug mode
$_Debug = 0

# change to 1 to suppress any output
$Silent = 0

# change to 1 to redirect output to a text file, works only with Silent=1
$Logger = 0

$KMS_Emulation = 1
$Unattend = 0
$_uIP = '172.16.0.2'

$uCAS = 0
$col_chg = 0

#############################
$winbuild = 1
try {
	$winbuild = [System.Diagnostics.FileVersionInfo]::GetVersionInfo("$env:SystemRoot\System32\kernel32.dll").FileBuildPart
} catch {
	$winbuild = [Environment]::OSVersion.Version.Build
}

$_err = '==== ERROR ===='
$out_msg = { param($inArg) Out-Host -Input $inArg }
$out_nul = { return }
$out_txt = { param($inArg) $script:strw.WriteLine($inArg) }
$out_inf = $out_msg

function CONOUT($strObj)
{
	& $out_inf $strObj
}

function ExitScript($ExitCode = 0)
{
	if (-not $psISE -and $Unattend -ne 1 -and -not $_quit) {
		Read-Host "`r`nPress Enter to exit" | Out-Null
	}
	if ($_old) {
		$Host.UI.RawUI.WindowTitle = $_old
	}
	if ($_mod) {
		& $_buf
	}
	if ($strw) {
		Out-File -FilePath $_run -Encoding ASCII -Force -Input $strw.ToString()
	}
	if ($col_chg -eq 1) {
		[Console]::BackgroundColor = $org_bgc
		[Console]::ForegroundColor = $org_fgc
	}
	try {ResetColor} catch {}
	Exit $ExitCode
}

$_ps1n = [IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
$_ps1f = $($MyInvocation.MyCommand.Path) -replace "'", "''"
$_work = Split-Path -Path $_ps1f

# =========================
# Prechecks
# =========================

function Prechecks
{
	if (-Not $PSVersionTable) {
		"$_err`r`n"
		"Windows PowerShell 1.0 is not supported by this script."
		ExitScript 1
	}

	if ($ExecutionContext.SessionState.LanguageMode.value__ -NE 0) {
		"$_err`r`n"
		"Windows PowerShell is not running in Full Language Mode."
		ExitScript 1
	}

	if ($winbuild -EQ 1) {
		"$_err`r`n"
		"Could not detect Windows build."
		ExitScript 1
	}

	if ($winbuild -LT 6002) {
		"$_err`r`n"
		"Unsupported OS version Detected."
		"Project is supported only for Windows Vista SP2 / Server 2008 SP2 and later."
		ExitScript 1
	}

	if ((Get-Service -Name WinMgmt).Status -ne 4) {
		"$_err`r`n"
		"Required Windows Management Instrumentation [WinMgmt] service is disabled."
		ExitScript 1
	}

	$eWMI = $false
	try {
		([WMISEARCHER]"SELECT CreationClassName FROM Win32_ComputerSystem").Get() | select -Expand Properties -EA 1 | foreach {$eWMI = $_.Value -match "ComputerSystem"}
	} catch {
	}
	if (-not $eWMI) {
		"$_err`r`n"
		"Windows Management Instrumentation is not working properly"
		ExitScript 1
	}
}

. Prechecks

# =========================
# Auto admin relaunch
# =========================

$_elev = $null
if ($args.Length -gt 0 -and $args -contains "-elevated") {
	$_elev = 1
}

$Admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $Admin) {
	if (-not $_elev) {
		start "powershell.exe" -Verb RunAs -arg "-NoProfile -ExecutionPolicy Bypass -Command & `"'$_ps1f' $args -elevated`""
		Exit
	} else {
		"$_err`r`n"
		"This script requires administrator privileges."
		ExitScript 1
	}
}

$_AIO = 1
$_title = "KMS_VL_ALL_AIO $uivr"

# =========================
# Main Variables
# =========================

$SysPath = "$env:SystemRoot\System32"
if (Test-Path "$env:SystemRoot\Sysnative\reg.exe") {
	$SysPath = "$env:SystemRoot\Sysnative"
}
$bins = @("SppExtComObjHookAvrf.dll","SppExtComObjHook.dll","SppExtComObjPatcher.dll","SppExtComObjPatcher.exe")
$exes = @("SppExtComObj.exe","sppsvc.exe","osppsvc.exe","SLsvc.exe")
$f_a_A64 = '92136c52274585d41217f754cd3c277661790ae5'
$f_a_x64 = 'd6a5ddc9b46285b7babc4b45e8c4914051fdc9c8'
$f_a_x86 = 'cc448ccd58fe65bc02933509e72d359348dcc9be'
$f_d_A64 = '778961e1328235f1d5ca4563d64e523ffcf91e76'
$f_d_x64 = 'f194eae526dfa87a0d2b5a53eb89dbe1c44834fc'
$f_d_x86 = '1f3e35685aa222f1b28d8e79d84742044976f00c'
$n_a_A64 = 3; $t_a_A64 = 133710899771091897
$n_a_x64 = 2; $t_a_x64 = 133710899693922335
$n_a_x86 = 1; $t_a_x86 = 133710899608630184
$n_d_A64 = 6; $t_d_A64 = 134112546622611849
$n_d_x64 = 5; $t_d_x64 = 134112546583547123
$n_d_x86 = 4; $t_d_x86 = 134112546549947564

$archn = [Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
$archw = [Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITEW6432")
if ($archn -eq 'amd64' -or $archw -eq 'amd64') { $xOS = 'x64' }
elseif ($archn -eq 'arm64' -or $archw -eq 'arm64') { $xOS = 'A64' }
elseif ($archn -eq 'x86' -and -not $archw) { $xOS = 'x86' }

$_wNTk  = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$_onat  = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Office'
$_owow  = 'HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Office'
$_Local = "$env:LocalAppData"
$_temp  = "$env:SystemRoot\Temp"

$_old = $Host.UI.RawUI.WindowTitle
$rui = $Host.UI.RawUI
$org_bf = $rui.BufferSize
$org_ws = $rui.WindowSize
$_mod = $false
$_buf = {
	try {$rui.BufferSize=$org_bf; $rui.WindowSize=$org_ws;} catch {}
	try {$rui.WindowSize=$org_ws; $rui.BufferSize=$org_bf;} catch {}
}
$_con128 = {
	if ($IsTerminal) {return}
	$_ws=$rui.WindowSize; $_bf=$rui.BufferSize;
	if ($_ws.Width -ge 100) {return} else {$_mod = $true};
	$_ws.Height=28; $_ws.Width=100; $_bf.Width=100;
	try {$rui.BufferSize=$_bf; $rui.WindowSize=$_ws;} catch {}
	try {$rui.WindowSize=$_ws; $rui.BufferSize=$_bf;} catch {}
}
$_con134 = {
	if ($IsTerminal) {return}
	$_ws=$rui.WindowSize; $_bf=$rui.BufferSize;
	$_mod = $true
	$_ws.Height=34; $_ws.Width=100; $_bf.Width=100;
	try {$rui.BufferSize=$_bf; $rui.WindowSize=$_ws;} catch {}
	try {$rui.WindowSize=$_ws; $rui.BufferSize=$_bf;} catch {}
}
$_con80 = {
	if ($IsTerminal) {return}
	$_ws=$rui.WindowSize; $_bf=$rui.BufferSize;
	$_mod = $true
	$_ws.Height=34; $_ws.Width=80; $_bf.Width=80;
	try {$rui.BufferSize=$_bf; $rui.WindowSize=$_ws;} catch {}
	try {$rui.WindowSize=$_ws; $rui.BufferSize=$_bf;} catch {}
}

$line2 = "=" * 60
$line3 = "_" * 60
$line4 = "_" * 50
$line6 = "`n$line3"
$line9 = "`n$line3`n"

$_wApp = '55c92734-d682-4d71-983e-d6ec3f16059f'
$_oApp = '0ff1ce15-a989-479d-af46-f275c6370663'
$_oA14 = '59a52881-a989-479d-af46-f275c6370663'

$IFEO = $_wNTk + '\Image File Execution Options'
$OPPk = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\OfficeSoftwareProtectionPlatform'
$SPPk = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform'
$SPPn = 'HKEY_USERS\S-1-5-20\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform'
$AVSk = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\Software Protection Platform'

$_TaskEx = '\Microsoft\Windows\SoftwareProtectionPlatform\SvcTrigger'
$_TaskOs = '\Microsoft\Windows\SoftwareProtectionPlatform\SvcRestartTaskLogon'

$w7inf = "$env:SystemRoot\Migration\WTR\KMS_VL_ALL.inf"
$_Hook = "$SysPath\SppExtComObjHook.dll"

$chkVal = "VerifierFlags|Debugger"
$_aDLL  = 1
$fDLL   = "a${xOS}.dll"
$_orig  = (Get-Variable -Name "f_a_$xOS").Value
$alg    = "SHA1"
$offsvc = "osppsvc"
$winsvc = "sppsvc"
$SPPf   = "$SysPath\spp\tokens\skus"
$errVal = @("VerifierDlls","GlobalFlag","KMS_Emulation")
$_NT7   = 1
if ($winbuild -ge 6002 -and (Test-Path "$SysPath\SLsvc.exe")) {
	$_aDLL  = 0
	$fDLL   = "d${xOS}.dll"
	$_orig  = (Get-Variable -Name "f_d_$xOS").Value
	$alg    = ""
	$winsvc = "slsvc"
	$SPPf   = "$SysPath\licensing\skus"
	$SPPk   = $SPPk -replace 'SoftwareProtectionPlatform', 'SL'
	$SPPn   = $SPPn -replace 'SoftwareProtectionPlatform', 'SL'
	$errVal = @("Debugger","KMS_Emulation")
	$_NT7   = 0
	$AutoR2V = 0
}

$OppVer = "$offsvc.exe"
if ($winbuild -ge 9200) {
	$OSType = "Win8"
	$SppVer = "SppExtComObj.exe"
	$SPPx   = "$SysPath\spp\tokens\addons"
} elseif ($winbuild -ge 7600) {
	$OSType = "Win7"
	$SppVer = "sppsvc.exe"
	$SPPx   = "$SysPath\spp\tokens\channels"
} elseif ($winbuild -ge 6002) {
	$OSType = "Vista"
	$SppVer = "SLsvc.exe"
	$SPPx   = "$SysPath\licensing\channels"
}

$SSppHook = 0
Get-ChildItem -Path $SPPf -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer } | ForEach-Object {
	if ([IO.Directory]::GetFiles($_.FullName) -match "GVLK|VLKMS|VL-BYPASS") { $SSppHook = 1 }
}

$OsppHook = 1
try {
	Get-Service -Name $offsvc -ErrorAction Stop | Out-Null
} catch {
	$OsppHook = 0
}

$isAddon = 0
Get-ChildItem -Path $SPPx -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer } | ForEach-Object {
	if ([IO.Directory]::GetFiles($_.FullName) -match "Volume-MAK|VL-DMAK") { $isAddon = 1 }
}
if ($isAddon) {
	$adoff = "and LicenseDependsOn is NULL"
	$adonn = "and LicenseDependsOn is not NULL"
} else {
	$adoff = ""
	$adonn = ""
}

$_iots = 0
$_eval = 0
$_fix7 = 0
$_wlms = 0
if ($OSType -eq "Win7" -and (Test-Path "$SysPath\wlms\wlms.exe")) {
	if ((Get-Service -Name wlms).Status -ne 1) { $_wlms = 1 }
}

$_uRI = $KMS_RenewalInterval
$_uAI = $KMS_ActivationInterval

$UBR = 0
if ($winbuild -ge 7601) {
	try {$UBR = (Get-ItemProperty -Path "Registry::$_wNTk" -Name UBR -ErrorAction Stop).UBR} catch {}
}

# =========================
# Runtime Variables
# =========================

$UNC = 0
if ($_work.StartsWith("\\")) {
	$UNC = 1
} else {
	$driveLetter = Split-Path $_work -Qualifier
	& net.exe use $driveLetter >$null 2>&1
	if ($?) {$UNC = 1}
}

$_dsk = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -Name Desktop -ErrorAction SilentlyContinue).Desktop
if (-not $_dsk) {
	$_dsk = [Environment]::GetFolderPath('DesktopDirectory')
}
if (Test-Path "$env:PUBLIC\Desktop\desktop.ini") {
	$_dsk = "$env:PUBLIC\Desktop"
}

$_pwd = if ($_work.EndsWith("\bin") -and (Test-path "$_work\ps*.ps1")) {Split-Path $_work} else {$_work}
$_htm = $_pwd
$dummy = "$_work\#.rw"
try {
	New-Item -Path $dummy -ItemType File -Force | Out-Null
	if (Test-Path $dummy) { Remove-Item $dummy -Force }
} catch {
	$_pwd = $_dsk
}
$_run = "$_pwd\$($_ps1n)_Silent.log"
$_lld = "$_pwd\kva-bin"
$_dvd = "$_pwd\`$OEM`$"

$_cBlu = "Gray"
$_cRed = "Red"
$_cGrn = "Green"
$_cYel = "Yellow"
$_cWht = "White"

# =========================
# Error Variables
# =========================

$E_SYM = {
	CONOUT "`n$_err"
	CONOUT "Symbolic link creation failed."
	CONOUT "Verify that Antivirus protection is OFF or the current folder is excluded."
	ExitScript 1
}

$E_DLL = {
	CONOUT "`n$_err"
	CONOUT "Required file bin\$fDLL is not found."
	CONOUT "Verify that Antivirus protection is OFF or the current folder is excluded."
	CONOUT "`nTurn External option ON to activate via external KMS Server."
	ExitScript 1
}

$E_PTH = {
	CONOUT "`n=== WARNING ==="
	CONOUT "Disallowed special characters are detected in the file path or name."
	CONOUT "Make sure either do not contain any of the following characters:"
	CONOUT "|`~!@%^&()[]{}+=;,'"
}

# =========================
# Activation Variables
# =========================

$not_slp = "cannot be KMS-activated on this computer due to unqualified OEM BIOS."
$PermPrd = "Product is Permanently Activated."
$nIoTs   = "IoT Enterprise LTSC 2021 require update 19044.2788 or later."
$nKMS    = "does not support KMS activation..."
$nEval   = "Evaluation Editions cannot be activated. Please install full Windows OS."
$nEvlS   = "Server Evaluation cannot be activated. Please convert to full Server OS."
$nEvl7   = "Evaluation service WLMS is running. Restart the system first, then try again."
$_mOuwp  = "Detected Office 365/2016 UWP is not supported by KMS_VL_ALL"
$DO15Ids = @("ProPlus","Standard","Access","Lync","Excel","Groove","InfoPath","OneNote","Outlook","PowerPoint","Publisher","Word")
$DO16Ids = @("ProPlus","Standard","Access","SkypeforBusiness","Excel","Outlook","PowerPoint","Publisher","Word")
$LV16Ids = @("Mondo","ProPlus","ProjectPro","VisioPro","Standard","ProjectStd","VisioStd","Access","SkypeforBusiness","OneNote","Excel","Outlook","PowerPoint","Publisher","Word")
$LR16Ids = $LV16Ids + @("Professional","HomeBusiness","HomeStudent","O365Business","O365SmallBusPrem","O365HomePrem","O365EduCloud")

$evalFiles  = Test-Path "$env:SystemRoot\Servicing\Packages\Microsoft-Windows-*EvalEdition~*.mum"
$evalServer = Test-Path "$env:SystemRoot\Servicing\Packages\Microsoft-Windows-Server*EvalEdition~*.mum"
$evalSrvCor = Test-Path "$env:SystemRoot\Servicing\Packages\Microsoft-Windows-Server*EvalCorEdition~*.mum"
if ($evalFiles) { $_eval = 1 }
if ($evalServer -or $evalSrvCor) { $_eval = 1; $nEval = $nEvlS }

$loc_off = @{}
$msi_off = @{}
$c2r_off = @{}
$vol_off = @{}
$ret_off = @{}
$run_off = @{}
$prr_off = @{}
$prv_off = @{}
$vol_chk = @{}

# =========================
# Menu Variables
# =========================

$fAUR = $null
$rAUR = $null
# $_AIO = 0
$_ReAR = 0
$_rtrn = 0
$_quit = 0
$_verb = 0

# =========================
# Parse Arguments
# =========================

function ParseArguments($params)
{
	foreach ($aaa in $params) {
		switch ($aaa.Trim()) {
			'-elevated' { $_elev = 1; continue }
			'-wow' { $_rel1 = 1; continue }
			'-arm' { $_rel2 = 1; continue }
			'/d'   { $_Debug = 1; continue }
			'/u'   { $Unattend = 1; continue }
			'/s'   { $Silent = 1; continue }
			'/l'   { $Logger = 1; continue }
			'/z'   { $AltDLL = 1; continue }
			'/o'   { $ActOffice = 1; $ActWindows = 0; continue }
			'/w'   { $ActOffice = 0; $ActWindows = 1; continue }
			'/c'   { $AutoR2V = 0; continue }
			'/v'   { $vNextOverride = 0; continue }
			'/x'   { $SkipKMS38 = 0; continue }
			'/k'   { $ClearKMSCache = 0; continue }
			'/e'   { $External = 1; $uManual = 0; $uAutoRenewal = 0; $fAUR = 0; continue }
			'/m'   { $External = 0; $uManual = 1; $uAutoRenewal = 0; $fAUR = 0; continue }
			'/a'   { $External = 0; $uManual = 0; $uAutoRenewal = 1; $fAUR = 1; continue }
			'/r'   { $ForceIns = 0; $ForceRem = 1; $rAUR = 1; continue }
			'/i'   { $ForceIns = 1; $ForceRem = 0; continue }
			'/lp'  { $Logger = 1; $parentLog = $true; continue }
			'/t'   { $uCAS = 1; continue }
			default { $KMS_IP = $aaa; continue }
		}
	}
}

$_args = ($args, $null)[($args.Length -eq 0)]
if ($_args) {
	. ParseArguments $_args
}

###########################
if ($uCAS -eq 1) {
	$f=[IO.File]::ReadAllText("$_ps1f") -split ':sppmgr\:.*'; iex ($f[1])
	$Unattend = 1; $_quit = 1;
	ExitScript 0
}

$out_inf = $out_msg
if ($Silent -eq 1) {
	$out_inf = $out_nul
}
if ($Silent -eq 1 -and $Logger -eq 1) {
	$strw = New-Object System.IO.StringWriter
	$out_inf = $out_txt
}

if ($External -eq 1) { $fAUR = 0; if ($KMS_IP -eq $_uIP) { $External = 0 } }
if ($uManual -eq 1) { $fAUR = 0; $External = 0; $uAutoRenewal = 0; }
if ($uAutoRenewal -eq 1) { $fAUR = 1; $External = 0; $uManual = 0; }
if ($null -ne $fAUR -or $null -ne $rAUR) { $Unattend = 1 }
if ($Silent -eq 1) { $Unattend = 1 }

$_dllPath = "$env:SystemRoot\System32"
if ($xOS -eq 'A64' -and $archn -eq 'x86') { $_dllPath = "$env:SystemRoot\Sysnative" }

$_suf = [DateTime]::Now.ToString('_hhmmss')
$_dDbg = 'No'

# =========================
# Common
# =========================
function IsTerminal
{
	if ($winbuild -lt 17763) { return $false }
	$__t = [AppDomain]::CurrentDomain.DefineDynamicAssembly((Get-Random), 1
	).DefineDynamicModule((Get-Random), $False).DefineType((Get-Random));
	[void]$__t.DefinePInvokeMethod(
		'GetConsoleWindow', 'kernel32.dll', 22, 1, [IntPtr], @(), 1, 3).SetImplementationFlags(128);
	[void]$__t.DefinePInvokeMethod(
		'SendMessageW', 'user32.dll', 22, 1, [IntPtr], @([IntPtr], [UInt32], [IntPtr], [IntPtr]), 1, 3).SetImplementationFlags(128);
	$__w = $__t.CreateType()
	return ($__w::SendMessageW($__w::GetConsoleWindow(), 127, 0, 0) -EQ [IntPtr]::Zero)
}

$IsTerminal = IsTerminal

# =========================
# Colors
# =========================
$org_color = ([Console]::BackgroundColor.value__.ToString('X'), [Console]::ForegroundColor.value__.ToString('X')) -join ''
$org_bgc = [Console]::BackgroundColor
$org_fgc = [Console]::ForegroundColor

function DoColor($attr)
{
	return
	& cmd.exe /c color $attr
}

function ResetColor
{
	return
	& cmd.exe /c color $org_color
}

function COLOUT($_prm1, $_prm2, $_prm3, $_prm4)
{
	if ($_prm3 -eq $_cBlu) {$_bgc = "Black"} else {$_bgc = "DarkMagenta"}
	Write-Host -Background "DarkMagenta" -Foreground $_prm1 $_prm2 -NoNewline
	Write-Host -Background $_bgc -Foreground $_prm3 $_prm4
}

###########################
function NobleBlue
{
	$__t = [AppDomain]::CurrentDomain.DefineDynamicAssembly((Get-Random), 1
	).DefineDynamicModule((Get-Random), $False).DefineType((Get-Random));
	[void]$__t.DefinePInvokeMethod(
		'GetStdHandle', 'kernel32.dll', 22, 1, [IntPtr], @([Int32]), 1, 3).SetImplementationFlags(128);
	[void]$__t.DefinePInvokeMethod(
		'GetConsoleScreenBufferInfoEx', 'kernel32.dll', 22, 1, [Boolean], @([IntPtr], [IntPtr]), 1, 3).SetImplementationFlags(128);
	[void]$__t.DefinePInvokeMethod(
		'SetConsoleScreenBufferInfoEx', 'kernel32.dll', 22, 1, [Boolean], @([IntPtr], [IntPtr]), 1, 3).SetImplementationFlags(128);
	$__w = $__t.CreateType()
	$__m = [System.Runtime.InteropServices.Marshal]
	$__h = $__w::GetStdHandle(-11)
	$__b = $__m::AllocHGlobal(96)
	$__m::WriteInt32($__b, 0, 96)
	$__w::GetConsoleScreenBufferInfoEx($__h, $__b) | Out-Null
	$__m::WriteInt32($__b, 52, 0x562401)
	$__m::WriteInt16($__b, 18, ($__m::ReadInt16($__b, 18) + 1))
	$__m::WriteInt16($__b, 20, ($__m::ReadInt16($__b, 20) + 1))
	$__w::SetConsoleScreenBufferInfoEx($__h, $__b) | Out-Null
}

if ([Console]::BackgroundColor.value__ -ne 5) {
	NobleBlue
	[Console]::BackgroundColor = "DarkMagenta"
	[Console]::ForegroundColor = "White"
	$col_chg = 1
}

# =========================
# WMI Helpers
# =========================

function WmiErr($_x)
{
	$hr = if ($_x.InnerException.ErrorCode) {$_x.InnerException.ErrorCode} elseif ($_x.HResult) {$_x.HResult} else {0}
	return $hr
}

function WmiSLS($strClass, $strMthd, $prmt = @())
{
	try {
		$wmiSvc = ([WMISEARCHER]"SELECT Version FROM $strClass").Get() | where {$_.__CLASS}
		$null = $wmiSvc.InvokeMethod($strMthd, $prmt)
		return 0
	} catch {
		return WmiErr $_.Exception
	}
}

function WmiSLP($strClass, $strID, $strMthd, $prmt = @())
{
	try {
		$wmiPrd = ([WMISEARCHER]"SELECT ID FROM $strClass").Get() | where {$_.ID -eq $strID}
		$null = $wmiPrd.InvokeMethod($strMthd, $prmt)
		return 0
	} catch {
		return WmiErr $_.Exception
	}
}

function WmiQuery($strClass, $strClause, $strProp)
{
	try {
		([WMISEARCHER]"SELECT $strProp FROM $strClass WHERE $strClause").Get() | select -Expand Properties -EA 0 | foreach {$_.Value}
	} catch {
		return $null
	}
}

function CimMPS($opt)
{
	try {
		$null = Invoke-CimMethod MSFT_MpPreference @{ExclusionPath = @($_Hook); Force = $True} $opt -Namespace root/Microsoft/Windows/Defender -EA 1
		return $true
	} catch {
		return $false
	}
}

# =========================
# xrm.txt
# =========================

function InstallLicensePre($_sls)
{
	$_wmi = ([WMISEARCHER]"SELECT Version FROM $_sls").Get() | where {$_.__CLASS}
}

function InstallLicenseFile($Lsc)
{
	try {
		$null = $_wmi.InstallLicense([IO.File]::ReadAllText($Lsc))
		return 0
	} catch {
		return WmiErr $_.Exception
	}
}

function InstallLicenseArr($Lsn)
{
	foreach ($x in $Lsn) {$null = InstallLicenseFile "$x"}
}

function InstallLicenseDir($Loc)
{
	dir $Loc *.xrm-ms -rec | where { !$_.PSIsContainer } | foreach {$_rt = InstallLicenseFile $_.FullName}
	return $_rt
}

function ReinstallLicenses
{
	$Oem = "$env:SystemRoot\system32\oem"
	$Spp = "$env:SystemRoot\system32\spp\tokens"
	$_rt = InstallLicenseDir "$Spp"
	if (Test-Path $Oem) {$null = InstallLicenseDir "$Oem"}
	return $_rt
}

# =========================
# CleanOffice.txt
# =========================

function UninstallLicenses($DllPath)
{
	$TB = [AppDomain]::CurrentDomain.DefineDynamicAssembly((Get-Random), 1).DefineDynamicModule((Get-Random), $False).DefineType((Get-Random))
	[void]$TB.DefinePInvokeMethod('SLClose', $DllPath, 22, 1, [int], @([IntPtr]), 1, 3)
	[void]$TB.DefinePInvokeMethod('SLOpen', $DllPath, 22, 1, [int], @([IntPtr].MakeByRefType()), 1, 3)
	[void]$TB.DefinePInvokeMethod('SLGetSLIDList', $DllPath, 22, 1, [int],
		@([IntPtr], [int], [Guid].MakeByRefType(), [int], [int].MakeByRefType(), [IntPtr].MakeByRefType()), 1, 3).SetImplementationFlags(128)
	[void]$TB.DefinePInvokeMethod('SLUninstallLicense', $DllPath, 22, 1, [int], @([IntPtr], [IntPtr]), 1, 3)

	$SPPC = $TB.CreateType()
	$Handle = 0
	[void]$SPPC::SLOpen([ref]$Handle)
	$pnReturnIds = 0
	$ppReturnIds = 0

	if (!$SPPC::SLGetSLIDList($Handle, 0, [ref][Guid]"0ff1ce15-a989-479d-af46-f275c6370663", 6, [ref]$pnReturnIds, [ref]$ppReturnIds)) {
		foreach ($i in 0..($pnReturnIds - 1)) {
			[void]$SPPC::SLUninstallLicense($Handle, [Int64]$ppReturnIds + [Int64]16 * $i)
		}
	}

	[void]$SPPC::SLClose($Handle)
	$SPPC = $null
}

# =========================
# Registry Helpers
# =========================

function Get-RegValue([string]$strKey, [string]$strName)
{
	try {
		return [Microsoft.Win32.Registry]::GetValue($strKey, $strName, $null)
	} catch {
		return $null
	}
}

function Set-RegValue([string]$strKey, [string]$strName, [string]$strType, [object]$objData)
{
	return [Microsoft.Win32.Registry]::SetValue($strKey, $strName, $objData, $strType)
}

function Del-RegValue([string]$strKey, [string]$strName)
{
	Remove-ItemProperty -Path "Registry::$strKey" -Name $strName -Force -ErrorAction SilentlyContinue
}

function Del-RegKey([string]$strKey)
{
	Remove-Item -Path "Registry::$strKey" -Recurse -Force -ErrorAction SilentlyContinue
}

function New-RegKey([string]$strKey)
{
	$null = New-Item -Path "Registry::$strKey" -Force -ErrorAction SilentlyContinue
}

# =========================
# KMS settings Helpers
# =========================

function Set-KmsReg($reg_Key, $reg_Name, $reg_Port)
{
	Set-RegValue $reg_Key 'KeyManagementServiceName' 'String' $reg_Name
	Set-RegValue $reg_Key 'KeyManagementServicePort' 'String' $reg_Port
}

function Set-KmsHost($KmsKey, $KmsName, $KmsPort, $IsOspp = $false)
{
	if (-not (Test-Path "Registry::$KmsKey")) {
		New-RegKey $KmsKey
	}
	Set-KmsReg $KmsKey $KmsName $KmsPort

	if ($IsOspp -or $winbuild -lt 9200) {
		return
	}

	$aplKey = "$KmsKey\$_oApp"
	if (Test-Path "Registry::$aplKey") {
		Del-RegKey $aplKey
	}
	New-RegKey $aplKey
	Set-KmsReg $aplKey $KmsName $KmsPort

	if ($xOS -eq 'x86') {
		return
	}

	$Kms32 = "$($KmsKey.Replace('SOFTWARE','SOFTWARE\WOW6432Node'))"
	if (-not (Test-Path "Registry::$Kms32")) {
		New-RegKey $Kms32
	}
	Set-KmsReg $Kms32 $KmsName $KmsPort

	$aplK32  = "$Kms32\$_oApp"
	if (Test-Path "Registry::$aplK32") {
		Del-RegKey $aplK32
	}
	New-RegKey $aplK32
	Set-KmsReg $aplK32 $KmsName $KmsPort
}

function Del-KmsHost($reg_Key)
{
	Del-RegValue $reg_Key 'KeyManagementServiceName'
	Del-RegValue $reg_Key 'KeyManagementServicePort'
}

function Del-KmsDns($reg_Key)
{
	Del-RegValue $reg_Key 'DisableDnsPublishing'
	Del-RegValue $reg_Key 'DisableKeyManagementServiceHostCaching'
}

function Del-KmsReg
{
	Del-KmsHost $SPPk
	Del-KmsDns $SPPk
	Del-RegKey "$SPPk\$_wApp"
	if ($winbuild -ge 9200) {
		$Kms32 = "$($SPPk.Replace('SOFTWARE','SOFTWARE\WOW6432Node'))"
		Del-KmsHost $Kms32
		Del-RegKey "$Kms32\$_oApp"
		Del-RegKey "$SPPk\$_oApp"
	}
	if ($winbuild -ge 9600) {
		Del-RegKey "$SPPn\$_wApp"
		Del-RegKey "$SPPn\$_oApp"
		Del-RegKey "$SPPn\PersistedSystemState"
	}
	Del-KmsHost $OPPk
	Del-KmsDns $OPPk
	Del-RegKey "$OPPk\$_oA14"
	Del-RegKey "$OPPk\$_oApp"
}

function Clr-KmsReg
{
	Del-RegKey "$SPPk\$_wApp"
	Del-KmsDns $SPPk
	Set-KmsHost $SPPk $_uIP "1688"
	if ($winbuild -ge 9600) {
		Del-RegKey "$SPPn\$_wApp"
		Del-RegKey "$SPPn\$_oApp"
		Del-RegKey "$SPPn\PersistedSystemState"
	}
	if ($OsppHook -eq 0) {
		return
	}
	Del-KmsDns $OPPk
	Set-KmsHost $OPPk $_uIP "1688" $true
	Del-RegKey "$OPPk\$_oA14"
	Del-RegKey "$OPPk\$_oApp"
}

# =========================
# Office Detection Checks
# =========================

function officeCtr
{
	# Initialize variables
	$_C16R = $null
	$_C15R = $null
	$_C14R = $null

	$installPath16 = Get-RegValue "$_onat\ClickToRun" 'InstallPath'
	if ($installPath16 -and (Get-ChildItem -Path "$installPath16\root\Licenses16" -Filter "ProPlus*.xrm-ms" -ErrorAction SilentlyContinue)) {
		$chkIds = Get-RegValue "$_onat\ClickToRun\Configuration" 'ProductReleaseIds'
		if ($chkIds) { $_C16R = "$_onat\ClickToRun\Configuration" }
	}

	if (-not $_C16R) {
		$installPath16 = Get-RegValue "$_owow\ClickToRun" 'InstallPath'
		if ($installPath16 -and (Get-ChildItem -Path "$installPath16\root\Licenses16" -Filter "ProPlus*.xrm-ms" -ErrorAction SilentlyContinue)) {
			$chkIds = Get-RegValue "$_owow\ClickToRun\Configuration" 'ProductReleaseIds'
			if ($chkIds) { $_C16R = "$_owow\ClickToRun\Configuration" }
		}
	}

	$installPath15 = Get-RegValue "$_onat\15.0\ClickToRun" 'InstallPath'
	if ($installPath15 -and (Get-ChildItem -Path "$installPath15\root\Licenses" -Filter "ProPlus*.xrm-ms" -ErrorAction SilentlyContinue)) {
		$chkIds = Get-RegValue "$_onat\15.0\ClickToRun\Configuration" 'ProductReleaseIds'
		if ($chkIds) { $_C15R = "$_onat\15.0\ClickToRun\Configuration" } 
		else {
			$chkIds = Get-RegValue "$_onat\15.0\ClickToRun\propertyBag" -Name productreleaseid -ErrorAction SilentlyContinue
			if ($chkIds) { $_C15R = "$_onat\15.0\ClickToRun\propertyBag" }
		}
	}

	if ($xOS -eq 'x86') {
		$installPath14 = "$_onat\14.0\CVH"
	} else {
		$installPath14 = "$_owow\14.0\CVH"
	}
	if (Get-ChildItem -Path "Registry::$installPath14" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Click2run" }) {
		$_C14R = 1
	}
}

###########################
function officeLoc($Ver)
{
	# Initialize
	$loc_off[$Ver] = 0
	$msi_off[$Ver] = 0

	# --- Version-specific checks ---
	if ($Ver -match "19|21|24") {
		if (-not $_C16R) { return }
		$ids = Get-RegValue $_C16R 'ProductReleaseIds'
		if ($ids -match "20$Ver") { $loc_off[$Ver] = 1 }
		return
	}

	# --- MSI InstallRoot checks ---
	foreach ($regPath in "$_onat\$Ver.0\Common\InstallRoot", "$_owow\$Ver.0\Common\InstallRoot") {
		$installPath = Get-RegValue $regPath 'Path'
		if ($installPath -and (Test-Path "$installPath\*Picker.dll")) {
			$loc_off[$Ver] = 1
			$msi_off[$Ver] = 1
		}
	}

	# --- Office 2016 Click-to-Run ---
	if ($Ver -eq 16 -and $_C16R) {
		$ids = Get-RegValue $_C16R 'ProductReleaseIds'
		foreach ($id in ($LV16Ids -split ','), 'ProjectProX','ProjectStdX','VisioProX','VisioStdX') {
			if ($ids -match "$idVolume") { $loc_off[$Ver] = 1 }
		}
		foreach ($id in ($LR16Ids -split ',')) {
			if ($ids -match "$idRetail") { $loc_off[$Ver] = 1 }
		}
		return
	}

	# --- Office 2015 Click-to-Run ---
	if ($Ver -eq 15 -and $_C15R) {
		$loc_off[$Ver] = 1
		return
	}

	# --- Fallback OSPP.VBS presence checks ---
	foreach ($vbs in "${env:ProgramFiles}", "${env:ProgramW6432}", "${env:ProgramFiles(x86)}") {
		if (Test-Path "$vbs$("\Microsoft Office\Office$Ver\OSPP.VBS")") {
			$loc_off[$Ver] = 1
		}
	}
}

###########################
function subOffice
{
	# Initialize flags
	$sub_next = 0
	$sub_o365 = 0
	$sub_proj = 0
	$sub_vsio = 0
	$_Identity = 0

	if ($_NT7 -ne 1) {return}

	# --- License file checks ---
	foreach ($__p in "$env:LocalAppData", "$env:ProgramData") {
		try {
			$found = Get-ChildItem -Path "$__p\Microsoft\Office\Licenses" -Recurse -ErrorAction Stop | Where-Object { !$_.PSIsContainer }
			if ($found -and $found.Length -gt 0) {
				$_Identity = 1
				$sub_next  = 1
				break
			}
		} catch {
		}
	}

	if ($_Identity -ne 0) {return}

	# --- Registry existence check ---
	$kNext = 'HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\Licensing\LicensingNext'
	if (-not (Test-Path $kNext)) {
		return
	}

	# Read all values under the key
	$regValues = Get-ItemProperty -Path $kNext | Get-Member -MemberType NoteProperty | ForEach-Object {
		if ($_.Name -notmatch 'PSChildName|PSDrive|PSParentPath|PSPath|PSProvider') {
			[PSCustomObject]@{ Name  = $_.Name; Value = (Get-ItemProperty -Path $kNext).$($_.Name) }
		}
	}

	# --- Office 365 (Retail / Volume, excluding Project / Visio) ---
	foreach ($entry in $regValues) {
		$name  = $entry.Name
		$value = "$($entry.Value)"

		# --- Office ---
		if ($name -match 'retail|volume' -and $name -notmatch 'project|visio' -and (($value -match '^2|^3'))) {
			$sub_o365 = 1
		}

		# --- Project ---
		if ($name -match 'project' -and ($value -match '^2|^3')) {
			$sub_proj = 1
		}

		# --- Visio ---
		if ($name -match 'visio' -and ($value -match '^2|^3')) {
			$sub_vsio = 1
		}
	}

	# --- Final aggregation ---
	if ($sub_o365 -eq 1 -or $sub_proj -eq 1 -or $sub_vsio -eq 1) {
		$sub_next = 1
	}
}

###########################
function officeMsg($_ov)
{
	$_oy = $_ov
	if ($_ov -eq 14) { $_oy = '10' }
	if ($_ov -eq 15) { $_oy = '13' }
	Set-Variable "_mO${_ov}a" "Detected Office 20${_oy} C2R Retail is activated"
	Set-Variable "_mO${_ov}c" "Detected Office 20${_oy} C2R Retail could not be converted to Volume"
	Set-Variable "_mO${_ov}m" "Detected Office 20${_oy} MSI Retail is not supported by KMS_VL_ALL"
	if ($_ov -eq 14) { Set-Variable "_mO${_ov}c" "Detected Office 20${_oy} C2R Retail is not supported by KMS_VL_ALL" }
}

###########################
function offoem
{
	if ($OffVer -eq 14) { return }
	if ($OffVer -eq 15) { $_orv = 15 } else { $_orv = 16 }
	Del-RegKey "$_onat\${_orv}.0\Common\OEM"
	if ($xOS -ne 'x86') {Del-RegKey "$_owow\${_orv}.0\Common\OEM"}
}

# =========================
# SPP Licensing Checks
# =========================

function RunSPP
{
	$spp = 'SoftwareLicensingProduct'
	$sps = 'SoftwareLicensingService'
	$W1nd0ws = 1
	$WinPerm = 0
	$WinVL = 0
	$Off1ce = 0
	$RanR2V = 0
	foreach ($id in 15,16,19,21,24) {
		$c2r_off[$id] = 0
	}

	StartService $winsvc

	if ($winbuild -ge 9200 -and $ActOffice -ne 0) {
		. sppoff
	}

	$_qr = WmiQuery $spp "Description like '%KMSCLIENT%'" "Name" | Where-Object { $_ -notmatch 'add-on' -and $_ -match 'Windows' }
	if ($_qr -match 'Windows') {
		$WinVL = 1
	}

	if ($_wlms -and $_eval) { 
		$SSppHook = 0
		$WinVL = 0
	}
	if ($_iots) {
		$SSppHook = 0
		$WinVL = 0
	}
	if ($WinVL -eq 0) {
		if ($ActWindows -ne 0 -and $SSppHook -ne 0) {
			nVolErr
			return
		}
		nVolMsg
	}
	if ($WinVL -eq 0 -and $Off1ce -eq 0) {
		return
	}

	if ($_AUR -eq 0) {
		Del-RegKey "$SPPk\$_wApp"
		# Del-RegKey "$SPPk\$_oApp"
		Del-RegKey "$SPPn\$_wApp"
		Del-RegKey "$SPPn\$_oApp"
	}

	$_nt10 = "ApplicationID='$_wApp' and Description like '%KMSCLIENT%' $adoff and PartialProductKey is not NULL"
	$_gvlk = 0
	if ($winbuild -ge 10240) {
		$_qr = WmiQuery $spp $_nt10 "Name" | Where-Object { $_ -notmatch 'add-on' -and $_ -match 'Windows' }
		if ($_qr -match 'Windows') { $_gvlk = 1 }
	}

	$gpr1 = 0
	if ($winbuild -ge 10240 -and $SkipKMS38 -eq 1 -and $_gvlk -eq 1) {
		$_qr = WmiQuery $spp $_nt10 "GracePeriodRemaining"
		$gpr1 = [int]$_qr
	}
	if ($gpr1 -ne 0 -and $gpr1 -gt 259200 -and $Win10Gov -eq 0) {
		$_yyy = [DateTime]::Now.AddMinutes($gpr1).Year
		if ($_yyy -lt 6100) { $W1nd0ws = 0 }
	}

	Set-KmsHost $SPPk $KMS_IP $KMS_Port

	if ($W1nd0ws -eq 0) {
		$_qr = WmiQuery $spp "ApplicationID='$_wApp' and Description like '%KMSCLIENT%'" "ID"
		$_qr | foreach { $aid = $_; . sppchkwin }
	}
	if ($W1nd0ws -eq 1 -and $ActWindows -ne 0) {
		$_qr = WmiQuery $spp "ApplicationID='$_wApp' and Description like '%KMSCLIENT%' $adoff" "ID"
		$_qr | foreach { $aid = $_; . sppchkwin }
	}
	if ($W1nd0ws -eq 1 -and $ActWindows -eq 0) {
		CONOUT "`nWindows activation is OFF..."
	}
	if ($Off1ce -eq 1 -and $ActOffice -ne 0) {
		$_qr = WmiQuery $spp "ApplicationID='$_oApp' and Description like '%KMSCLIENT%'" "ID"
		$_qr | foreach { $aid = $_; . sppchkoff 1 }
	}

	if ($_AUR -eq 0) {
		Clr-KmsReg
	} else {
		Del-KmsDns $SPPk
	}
}

###########################
function nVolMsg
{
	if ($ActWindows -eq 0) {
		CONOUT "`nWindows activation is OFF..."
		return
	}
	if ($SSppHook -eq 0) {
		CONOUT ""
		if ($_wlms -eq 0) { CONOUT "$_winos $nKMS" }
		if ($_eval -eq 1) { if ($_fix7 -eq 1) { CONOUT "$nEvl7" } else { CONOUT "$nEval" } }
		if ($_iots -eq 1) { CONOUT "$nIoTs" }
	}
}

function nVolErr
{
	CONOUT "`nFailed checking KMS Activation ID(s) for Windows."
	CONOUT "Either $winsvc service or SppExtComObjHook.dll is not functional."
	CheckWS
}

###########################
function sppchkoff($isSPP)
{
	$_qr = WmiQuery $spp "ID='$aid'" "Name"
	$_eof = 0
	foreach ($ver in 14,15,16,19,21,24) {
		if (($_qr -match "Office $ver") -and $loc_off[$ver] -eq 0) { $_eof = 1 }
	}
	if ($_eof -eq 1) {
		return
	}
	$_officespp = $isSPP
	$OffVer = ($_qr -split ",| ")[1]
	$_qr = WmiQuery $spp "PartialProductKey is not NULL" "ID"
	if ($_qr -contains $aid) {
		CONOUT ""
		execActivate
		return
	}
	offchkVer $OffVer
}

# =========================
# Windows Licensing Checks
# =========================

$insiderIds = @(
	'b71515d9-89a2-4c60-88c8-656fbcca7f3a',
	'af43f7f0-3b1e-4266-a123-1fdb53f4323b',
	'075aca1f-05d7-42e5-a3ce-e349e7be7078',
	'11a37f09-fb7f-4002-bd84-f3ae71d11e90',
	'43f2ab05-7c87-4d56-b27c-44d0f9a3dabd',
	'2cf5af84-abab-4ff0-83f8-f040fb2576eb',
	'6ae51eeb-c268-4a21-9aae-df74c38b586d',
	'ff808201-fec6-4fd4-ae16-abbddade5706',
	'34260150-69ac-49a3-8a0d-4a403ab55763',
	'4dfd543d-caa6-4f69-a95f-5ddfe2b89567',
	'5fe40dd6-cf1f-4cf2-8729-92121ac2e997',
	'903663f7-d2ab-49c9-8942-14aa9e0a9c72',
	'2cc171ef-db48-4adc-af09-7c574b37f139',
	'5b2add49-b8f4-42e0-a77c-adad4efeeeb1'
)

$EditionMap = @{
	'59eb965c-9150-42b7-a0ec-22151b9897c5' = 'IoTEnterpriseS'
	'32d2fab3-e4a8-42c2-923b-4bf4fd13e6ee' = 'EnterpriseS'
	'ca7df2e3-5ea0-47b8-9ac1-b1be4d8edd69' = 'CloudEdition'
	'd30136fc-cb4b-416e-a23d-87207abc44a9' = 'CloudEditionN'
	'0df4f814-3f57-4b8b-9a9d-fddadcd69fac' = 'CloudE'
	'e0c42288-980c-4788-a014-c080d2e1926e' = 'Education'
	'73111121-5638-40f6-bc11-f1d7b0d64300' = 'Enterprise'
	'2de67392-b7a7-462a-b1ca-108dd189f588' = 'Professional'
	'3f1afc82-f8ac-4f6c-8005-1d233e606eee' = 'ProfessionalEducation'
	'82bbc092-bc50-4e16-8e18-b74fc486aec3' = 'ProfessionalWorkstation'
	'3c102355-d027-42c6-ad23-2e7ef8a02585' = 'EducationN'
	'e272e3e2-732f-4c65-a8f0-484747d0d947' = 'EnterpriseN'
	'a80b5abf-76ad-428b-b05d-a47d2dffeebf' = 'ProfessionalN'
	'5300b18c-2e33-4dc2-8291-47ffcec746dd' = 'ProfessionalEducationN'
	'4b1571d3-bafb-4b40-8087-a961be2caf65' = 'ProfessionalWorkstationN'
	'58e97c99-f377-4ef1-81d5-4ad5522b5fd8' = 'Core'
	'cd918a57-a41b-4c82-8dce-1a538e221a83' = 'CoreSingleLanguage'
	'ec868e65-fadf-4759-b23e-93fe37f2cc29' = 'ServerRdsh'
	'e4db50ea-bda1-4566-b047-0ca50abc6f07' = 'ServerRdsh'
}

function sppchkwin
{
	$_officespp = 0

	if ($winbuild -ge 14393 -and $WinPerm -eq 0 -and $_gvlk -eq 0) {
		$_qr = WmiQuery $spp $_nt10 "Name" | Where-Object { $_ -notmatch 'add-on' -and $_ -match 'Windows' }
		if ($_qr -match 'Windows') { $_gvlk = 1 }
	}

	$_qr = WmiQuery $spp "ID='$aid'" "LicenseStatus"
	if ($_qr -eq '1') {
		CONOUT ""
		execActivate
		return
	}
	$_qr = WmiQuery $spp "PartialProductKey is not NULL" "ID"
	if ($_qr -contains $aid) {
		CONOUT ""
		execActivate
		return
	}

	if ($winbuild -ge 14393 -and $_gvlk -eq 1) {
		return
	}
	if ($WinPerm -eq 1) {
		return
	}
	if ($winbuild -lt 10240) {
		. winchk
		return
	}
	if ($insiderIds -contains $aid) {
		return
	}

	if (-not $EditionID -or $winbuild -lt 14393) {
		. winchk
		return
	}
	if ($EditionMap.ContainsKey($aid)) {
		if ($EditionID -ne $EditionMap[$aid]) {
			return
		}
	}
	if ($aid -eq 'e4db50ea-bda1-4566-b047-0ca50abc6f07') {
		$_qr = WmiQuery $spp "Description like '%KMSCLIENT%'" "ID"
		if ($_qr -contains 'ec868e65-fadf-4759-b23e-93fe37f2cc29') {
			return
		}
	}
	if ($aid -eq '19b5e0fb-4431-46bc-bac1-2f1873e4ae73') {
		$_qr = WmiQuery $spp "Description like '%KMSCLIENT%'" "ID"
		if ($_qr -contains 'c2e946d1-cfa2-4523-8c87-30bc696ee584') {
			return
		}
	}

	. winchk
}

###########################
function winchk
{
	$_qr = WmiQuery $spp "LicenseStatus='1' and Description like '%KMSCLIENT%'" "Name"
	if ($_qr -match 'Windows') {
		return
	}
	CONOUT ""
	$_qr = WmiQuery $spp "LicenseStatus='1' and GracePeriodRemaining='0' $adoff and PartialProductKey is not NULL" "Name"
	if ($_qr -match 'Windows') {
		$WinPerm = 1
	}
	$WinOEM = 0
	if ($WinPerm -eq 0) {
		$_qr = WmiQuery $spp "ApplicationID='$_wApp' and LicenseStatus='1' $adoff" "Name"
		if ($_qr -match 'Windows') {
			$WinOEM = 1
		}
	}
	if ($WinOEM -eq 1) {
		$_qr = WmiQuery $spp "ApplicationID='$_wApp' and LicenseStatus='1' $adoff" "Description"
		$channel = (($_qr -split ",")[1] -split " ")[1]
		if (@('VOLUME_MAK','RETAIL','OEM_DM','OEM_SLP','OEM_COA','OEM_COA_SLP','OEM_COA_NSLP','OEM_NONSLP','OEM') -contains $channel) {
			$WinPerm = 1
		}
	}
	if ($WinPerm -eq 0 -and (Test-Path "$SysPath\slmgr.vbs")) {
		Copy-Item -Path "$SysPath\slmgr.vbs" -Destination "$_temp\slmgr.vbs" -Force
		$_SLMGROutput = & cscript.exe "$_temp\slmgr.vbs" /xpr 2>$null
		if ($_SLMGROutput -match "edition" -and $_SLMGROutput -match "permanently") {
			$WinPerm = 1
		}
		Remove-Item "$_temp\slmgr.vbs" -Force -ErrorAction SilentlyContinue
	}
	if ($WinPerm -eq 1) {
		$_qr = WmiQuery $spp "ApplicationID='$_wApp' and LicenseStatus='1' $adoff" "Name"
		CONOUT "Checking: $_qr"
		CONOUT "$PermPrd`n"
		return
	}
	instKey
}

# =========================
# OSPP Licensing Checks
# =========================

function RunOSPP
{
	$spp = 'OfficeSoftwareProtectionProduct'
	$sps = 'OfficeSoftwareProtectionService'
	$Off1ce = 0
	$RanR2V = 0
	$vPrem = $null
	$vProf = $null
	foreach ($id in 15,16,19,21,24) {
		$c2r_off[$id] = 0
	}

	if ($winbuild -lt 9200) {$aword = "2010-2024"} else {$aword = "2010"}
	if ($OsppHook -eq 0) {
		CONOUT "`nNo Installed Office $aword Product Detected..."
		return
	}
	if ($winbuild -ge 9200 -and $loc_off[14] -eq 0) {
		CONOUT "`nNo Installed Office $aword Product Detected..."
		return
	}

	StartService $offsvc
	if ((Get-Service -Name $offsvc).Status -ne 4) {
		CONOUT "`nError: $offsvc service is not running..."
		return
	}
	if ($winbuild -ge 9200) {
		. oppoff
	} else {
		. sppoff
	}
	if ($Off1ce -eq 0) {
		return
	}

	if ($_AUR -eq 0) {
		Del-RegKey "$OPPk\$_oA14"
		Del-RegKey "$OPPk\$_oApp"
	}

	if ($loc_off[14] -eq 1) {
		$vPrem = WmiQuery $spp "LicenseFamily='OfficeVisioPrem-MAK'" "LicenseStatus"
		$vProf = WmiQuery $spp "LicenseFamily='OfficeVisioPro-MAK'" "LicenseStatus"
	}

	Set-KmsHost $OPPk $KMS_IP $KMS_Port $true

	$_qr = WmiQuery $spp "Description like '%KMSCLIENT%'" "ID"
	$_qr | foreach { $aid = $_; . sppchkoff 0 }

	if ($_AUR -eq 0) {
		Clr-KmsReg
	} else {
		Del-KmsDns $OPPk
	}
}

###########################
function oppoff
{
	$_qr = WmiQuery $spp "Description is not NULL" "Description"
	if ($_qr -match 'KMSCLIENT') {
		$Off1ce = 1
		return
	}
	$ret_off[14] = 0
	if ($_qr -match 'channel') { $ret_off[14] = 1 }
	if ($_C14R) { CONOUT "`n$_mO14c" }
	elseif ($msi_off[14] -eq 1 -and $ret_off[14] -eq 1) { CONOUT "`n$_mO14m" }
}

# =========================
# Office Licensing Checks
# =========================

function sppoff
{
	foreach ($__v in 14,15,16,19,21,24) {
		$vol_off[$__v] = 0
		$ret_off[$__v] = 0
		$run_off[$__v] = 0
		$prr_off[$__v] = 0
		$prv_off[$__v] = 0
		$vol_chk[$__v] = 0
	}

	$OffUWP = 0
	if ($winbuild -ge 10240) {
		if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msoxmled.exe") {
			if (Test-Path "$env:ProgramFiles\WindowsApps\Microsoft.Office.Desktop*") { $OffUWP = 1 }
			if ($xOS -ne 'x86' -and (Test-Path "$env:ProgramW6432\WindowsApps\Microsoft.Office.Desktop*")) { $OffUWP = 1 }
		}
	}

	# -----------------------------------
	# Exit if no Office installed
	# -----------------------------------
	if ($loc_off[24] -eq 0 -and $loc_off[21] -eq 0 -and $loc_off[19] -eq 0 -and $loc_off[16] -eq 0 -and $loc_off[15] -eq 0) {
		if ($winbuild -ge 9200) {
			if ($OffUWP -eq 0) { CONOUT "`nNo Installed Office 2013-2024 Product Detected..." }
			else { CONOUT "`n$_mOuwp" }
			return
		}
		if ($winbuild -lt 9200) {
			if ($loc_off[14] -eq 0) { CONOUT "`nNo Installed Office $aword Product Detected..."; return }
		}
	}

	# -----------------------------------
	# Clean vNext licensing if required
	# -----------------------------------
	if ($vNextOverride -eq 1 -and $AutoR2V -eq 1) {
		$sub_o365 = 0
		$sub_proj = 0
		$sub_vsio = 0
		if ($sub_next -eq 1) {
			Del-RegKey "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Office\16.0\Common\Licensing"
			Remove-Item "$env:LocalAppData\Microsoft\Office\Licenses" -Recurse -Force -ErrorAction SilentlyContinue
			Remove-Item "$env:ProgramData\Microsoft\Office\Licenses" -Recurse -Force -ErrorAction SilentlyContinue
		}
	}

	$Off1ce = 1

	# -----------------------------------
	# Check volume licenses
	# -----------------------------------
	$spp_chk = WmiQuery $spp "Description like '%KMSCLIENT%' AND NOT Name like '%MondoR_KMS_Automation%'" "Name"
	foreach ($ver in 14,15,16,19,21,24) {
		if ($loc_off[$ver] -eq 1 -and ($spp_chk -match "Office $ver")) { $vol_off[$ver] = 1 }
	}

	# -----------------------------------
	# Check O365 licenses if Mondo detected
	# -----------------------------------
	if ($vol_off[16] -eq 1 -and ($spp_chk -match 'Office16MondoVL_KMS_Client')) {
		$_qr = WmiQuery $spp "ApplicationID='$_oApp' AND LicenseFamily like 'Office16O365%" "LicenseFamily"
		if (-not ($_qr -match 'O365')) { $vol_off[16] = 0 }
	}
	if ($vol_off[15] -eq 1 -and ($spp_chk -match 'OfficeMondoVL_KMS_Client')) {
		$_qr = WmiQuery $spp "ApplicationID='$_oApp' AND LicenseFamily like 'OfficeO365%" "LicenseFamily"
		if (-not ($_qr -match 'O365')) { $vol_off[15] = 0 }
	}

	# -----------------------------------
	# Check retail licenses
	# -----------------------------------
	$spp_chk = WmiQuery $spp "ApplicationID='$_oApp' AND NOT Name like '%O365%'" "Name"
	foreach ($ver in 14,15,16,19,21,24) {
		if (($spp_chk | Select-String "R_Retail" | Select-String "Office $ver" -Quiet)) {
			$ret_off[$ver] = 1
		}
	}

	if ($winbuild -lt 9200 -and $vol_off[14] -eq 0) {
		$_qr = WmiQuery $spp "ApplicationID='$_oA14'" "Description"
		if ($_qr -match 'channel') { $ret_off[14] = 1 }
	}

	# -----------------------------------
	# Handle Office conflict checks
	# -----------------------------------
	if ($_NT7 -eq 1) { foreach ($ver in 24,21,19) {
		. chkConflict $ver 16
		}
	}
	if ($_C16R) {
		. chkConflict 16 16
	}
	if ($_C15R) {
		. chkConflict 15 15
	}

	# -----------------------------------
	# Check Mondo licenses if O365 detected
	# -----------------------------------
	if ($loc_off[16] -eq 1 -and $run_off[16] -eq 0 -and $sub_o365 -eq 0 -and $_C16R) {
		$_qr = WmiQuery $spp "ApplicationID='$_oApp' AND LicenseFamily like 'Office16O365%" "LicenseFamily"
		if ($_qr -match 'O365' -and -not ($spp_chk | Select-String 'Office16MondoVL' -Quiet)) { $run_off[16] = 1 }
	}
	if ($loc_off[15] -eq 1 -and $run_off[15] -eq 0 -and $_C15R) {
		$_qr = WmiQuery $spp "ApplicationID='$_oApp' AND LicenseFamily like 'OfficeO365%" "LicenseFamily"
		if ($_qr -match 'O365' -and -not ($spp_chk | Select-String 'OfficeMondoVL' -Quiet)) { $run_off[15] = 1 }
	}

	# -----------------------------------
	# General volume flag
	# -----------------------------------
	$vol_offgl = 1
	if ($vol_off[24] -eq 0 -and $vol_off[21] -eq 0 -and $vol_off[19] -eq 0 -and $vol_off[16] -eq 0 -and $vol_off[15] -eq 0) {
		if ($winbuild -ge 9200) { $vol_offgl = 0 }
		if ($winbuild -lt 9200 -and $vol_off[14] -eq 0) { $vol_offgl = 0 }
	}

	# -----------------------------------
	# mixed Volume + Retail
	# -----------------------------------
	if ($run_off[24] -eq 1 -and $AutoR2V -eq 1 -and $RanR2V -eq 0) {
		. C2RR2V
	}
	if ($run_off[21] -eq 1 -and $AutoR2V -eq 1 -and $RanR2V -eq 0) {
		. C2RR2V
	}
	if ($run_off[19] -eq 1 -and $AutoR2V -eq 1 -and $RanR2V -eq 0) {
		. C2RR2V
	}
	if ($run_off[16] -eq 1 -and $AutoR2V -eq 1 -and $RanR2V -eq 0) {
		. C2RR2V
	}
	if ($run_off[15] -eq 1 -and $AutoR2V -eq 1 -and $RanR2V -eq 0) {
		. C2RR2V
	}

	# -----------------------------------
	# all supported Volume + message for unsupported
	# -----------------------------------
	if ($loc_off[16] -eq 0 -and $msi_off[16] -eq 0 -and $ret_off[16] -eq 1 -and $OffUWP -eq 1) { CONOUT "`n$_mOuwp" }
	if ($vol_offgl -eq 1) {
		if ($ret_off[16] -eq 1 -and $msi_off[16] -eq 1) { CONOUT "`n$_mO16m" }
		if ($ret_off[15] -eq 1 -and $msi_off[15] -eq 1) { CONOUT "`n$_mO15m" }
		if ($winbuild -lt 9200 -and $loc_off[14] -eq 1 -and $vol_off[14] -eq 0) {
			if ($_C14R) { CONOUT "`n$_mO14c" }
			elseif ($msi_off[14] -eq 1 -and $ret_off[14] -eq 1) { CONOUT "`n$_mO14m" }
		}
		return
	}

	# -----------------------------------
	# All Retail C2R
	# -----------------------------------
	$Off1ce = 0
	if ($AutoR2V -eq 1 -and $RanR2V -eq 0) {
		. C2RR2V
	}

	# -----------------------------------
	# Retail MSI/C2R or failed C2R-R2V
	# -----------------------------------
	return _fC2R
}

# =========================
function _fC2R
{
	foreach ($__v in 24,21,19,16,15,14) {
		if ($loc_off[$__v] -eq 1 -and $vol_off[$__v] -eq 0) {
			switch ($__v) {
				24 { if ($c2r_off[24] -eq 1) { CONOUT "`n$_mO24a" } else { CONOUT "`n$_mO24c" } }
				21 { if ($c2r_off[21] -eq 1) { CONOUT "`n$_mO21a" } else { CONOUT "`n$_mO21c" } }
				19 { if ($c2r_off[19] -eq 1) { CONOUT "`n$_mO19a" } else { CONOUT "`n$_mO19c" } }
				16 { 
					if ($_C16R) { if ($c2r_off[16] -eq 1) { CONOUT "`n$_mO16a" } elseif ($sub_o365 -eq 0) { CONOUT "`n$_mO16c" } }
					elseif ($msi_off[16] -eq 1 -and $ret_off[16] -eq 1) { CONOUT "`n$_mO16m" }
				}
				15 { 
					if ($_C15R) { if ($c2r_off[15] -eq 1) { CONOUT "`n$_mO15a" } else { CONOUT "`n$_mO15c" } }
					elseif ($msi_off[15] -eq 1 -and $ret_off[15] -eq 1) { CONOUT "`n$_mO15m" }
				}
				14 { if ($winbuild -lt 9200) {
					if ($_C14R) { CONOUT "`n$_mO14c" }
					elseif ($msi_off[14] -eq 1 -and $ret_off[14] -eq 1) { CONOUT "`n$_mO14m" }
					}
				}
			}
		}
	}
	return
}

###########################
function chkConflict($_v_, $_i_)
{
	if ($_v_ -eq 15 -or $_v_ -eq 16) {
		$_n_ = $null
		$_y_ = $null
	} else {
		$_n_ = "$_v_"
		$_y_ = "20$_v_"
	}

	$doCount = 0
	if ($loc_off[$_v_] -eq 1 -and $ret_off[$_v_] -eq 1 -and $msi_off[$_v_] -eq 0) {
		if ($_v_ -eq 16) { $doCount = 1 }
		else { if ($vol_off[$_v_] -eq 0) { $run_off[$_v_] = 1 } else { $doCount = 1 } }
	}
	if ($doCount -eq 0) {
		return
	}

	if ($_v_ -eq 16) {
		if ($vol_off[16] -eq 1 -and $vol_off[24] -eq 0 -and $vol_off[21] -eq 0 -and $vol_off[19] -eq 0) { $vol_chk[16] = 1 }
		foreach ($_t_ in 24,21,19) { if ($vol_off[16] -eq 0 -and $vol_off[$_t_] -eq 1) { $vol_chk[$_t_] = 1 } }
	} else {
		$vol_chk[$_v_] = 1
	}

	foreach ($_t_ in (Get-Variable "DO${_i_}Ids" -Scope Script).Value) {
		. chkLoop $_t_ $_t_
	}
	foreach ($_t_ in "Professional") {
		. chkLoop $_t_ ProPlus
	}
	foreach ($_t_ in "HomeBusiness","HomeStudent","Home") {
		. chkLoop $_t_ Standard
	}
	if ($sub_proj -eq 0) { foreach ($_t_ in "ProjectPro","ProjectStd") {
		. chkLoop $_t_ $_t_
	} }
	if ($sub_vsio -eq 0) { foreach ($_t_ in "VisioPro","VisioStd") {
		. chkLoop $_t_ $_t_
	} }

	if ($prv_off[$_v_] -lt $prr_off[$_v_]) {
		$vol_off[$_v_] = 0
		$run_off[$_v_] = 1
	}
}

# =========================
function chkLoop($_r_, $_p_)
{
	if (-not ($spp_chk -match "Office${_n_}${_r_}${_y_}R")) {
		return
	}
	$prr_off[$_v_]++
	if ($vol_chk[$_v_] -eq 1 -and ($spp_chk -match "Office${_n_}${_p_}${_y_}VL")) {
		$prv_off[$_v_]++
	}
	if ($_v_ -ne 16) {
		return
	}
	foreach ($_t_ in 24,21,19) { if ($vol_chk[$_t_] -eq 1 -and ($spp_chk -match "Office${_t_}${_p_}20${_t_}VL")) { 
		$prv_off[16]++
	} }
}

# =========================
# Office MAK Checks
# =========================

function offchk
{
	param(
		[Parameter(ValueFromRemainingArguments = $true)]
		[string[]]$inpt
	)

	$ls1 = 0
	$ls3 = 0
	$ls5 = 0
	$ls7 = 0
	if ($inpt[0]) {
		$ls1 = WmiQuery $spp "LicenseFamily='Office$($inpt[0])'" "LicenseStatus"
	}
	if ($inpt[2]) {
		$ls3 = WmiQuery $spp "LicenseFamily='Office$($inpt[2])'" "LicenseStatus"
	}
	if ($inpt[4]) {
		$ls5 = WmiQuery $spp "LicenseFamily='Office$($inpt[4])'" "LicenseStatus"
	}
	if ($inpt[6]) {
		$ls7 = WmiQuery $spp "LicenseFamily='Office$($inpt[6])'" "LicenseStatus"
	}
	if ($ls7 -eq 1) {
		CONOUT "Checking: $($inpt[7])"
		CONOUT "$PermPrd`n"
		return
	}
	if ($ls5 -eq 1) {
		CONOUT "Checking: $($inpt[5])"
		CONOUT "$PermPrd`n"
		return
	}
	if ($ls3 -eq 1) {
		CONOUT "Checking: $($inpt[3])"
		CONOUT "$PermPrd`n"
		return
	}
	if ($ls1 -eq 1) {
		CONOUT "Checking: $($inpt[1])"
		CONOUT "$PermPrd`n"
		return
	}
	instKey
}

###########################
function offchkVer($OffVer)
{
	try {
		$Dispatcher = (Get-Variable "table${OffVer}" -Scope Script -ErrorAction Stop).Value
	} catch {
		return
	}
	if ($Dispatcher.ContainsKey($aid)) {
		& $Dispatcher[$aid]
	} else {
		instKey
	}
}

###########################
$table24 = @{
	'fceda083-1203-402a-8ec4-3d7ed9f3648c' = { return }
	'aaea0dc8-78e1-4343-9f25-b69b83dd1bce' = { return }
	'4ab4d849-aabc-43fb-87ee-3aed02518891' = { return }

	'8d368fc1-9470-4be2-8d66-90e836cbb051' = {
		offchk '24ProPlus2024VL_MAK_AE1' 'Office ProPlus 2024' '24ProPlus2024VL_MAK_AE2' 'Office ProPlus 2024' '24ProPlus2024VL_MAK_AE3' 'Office ProPlus 2024'
		return
	}
	'bbac904f-6a7e-418a-bb4b-24c85da06187' = {
		offchk '24Standard2024VL_MAK_AE1' 'Office Standard 2024' '24Standard2024VL_MAK_AE2' 'Office Standard 2024'
		return
	}
	'f510af75-8ab7-4426-a236-1bfb95c34ff8' = {
		offchk '24ProjectPro2024VL_MAK_AE1' 'Project Pro 2024' '24ProjectPro2024VL_MAK_AE2' 'Project Pro 2024'
		return
	}
	'9f144f27-2ac5-40b9-899d-898c2b8b4f81' = {
		offchk '24ProjectStd2024VL_MAK_AE' 'Project Standard 2024'
		return
	}
	'fa187091-8246-47b1-964f-80a0b1e5d69a' = {
		offchk '24VisioPro2024VL_MAK_AE' 'Visio Pro 2024'
		return
	}
	'923fa470-aa71-4b8b-b35c-36b79bf9f44b' = {
		offchk '24VisioStd2024VL_MAK_AE' 'Visio Standard 2024'
		return
	}
}

$table21 = @{
	'f3fb2d68-83dd-4c8b-8f09-08e0d950ac3b' = { return }
	'76093b1b-7057-49d7-b970-638ebcbfd873' = { return }
	'a3b44174-2451-4cd6-b25f-66638bfb9046' = { return }
	'fbdb3e18-a8ef-4fb3-9183-dffd60bd0984' = {
		offchk '21ProPlus2021VL_MAK_AE1' 'Office ProPlus 2021' '21ProPlus2021VL_MAK_AE2' 'Office ProPlus 2021'
		return
	}
	'080a45c5-9f9f-49eb-b4b0-c3c610a5ebd3' = {
		offchk '21Standard2021VL_MAK_AE' 'Office Standard 2021'
		return
	}
	'76881159-155c-43e0-9db7-2d70a9a3a4ca' = {
		offchk '21ProjectPro2021VL_MAK_AE1' 'Project Pro 2021' '21ProjectPro2021VL_MAK_AE2' 'Project Pro 2021'
		return
	}
	'6dd72704-f752-4b71-94c7-11cec6bfc355' = {
		offchk '21ProjectStd2021VL_MAK_AE' 'Project Standard 2021'
		return
	}
	'fb61ac9a-1688-45d2-8f6b-0674dbffa33c' = {
		offchk '21VisioPro2021VL_MAK_AE' 'Visio Pro 2021'
		return
	}
	'72fce797-1884-48dd-a860-b2f6a5efd3ca' = {
		offchk '21VisioStd2021VL_MAK_AE' 'Visio Standard 2021'
		return
	}
}

$table19 = @{
	'0bc88885-718c-491d-921f-6f214349e79c' = { return }
	'fc7c4d0c-2e85-4bb9-afd4-01ed1476b5e9' = { return }
	'500f6619-ef93-4b75-bcb4-82819998a3ca' = { return }
	'85dd8b5f-eaa4-4af3-a628-cce9e77c9a03' = {
		offchk '19ProPlus2019VL_MAK_AE' 'Office ProPlus 2019'
		return
	}
	'6912a74b-a5fb-401a-bfdb-2e3ab46f4b02' = {
		offchk '19Standard2019VL_MAK_AE' 'Office Standard 2019'
		return
	}
	'2ca2bf3f-949e-446a-82c7-e25a15ec78c4' = {
		offchk '19ProjectPro2019VL_MAK_AE' 'Project Pro 2019'
		return
	}
	'1777f0e3-7392-4198-97ea-8ae4de6f6381' = {
		offchk '19ProjectStd2019VL_MAK_AE' 'Project Standard 2019'
		return
	}
	'5b5cf08f-b81a-431d-b080-3450d8620565' = {
		offchk '19VisioPro2019VL_MAK_AE' 'Visio Pro 2019'
		return
	}
	'e06d7df3-aad0-419d-8dfb-0ac37e2bdf39' = {
		offchk '19VisioStd2019VL_MAK_AE' 'Visio Standard 2019'
		return
	}
}

$table16 = @{
	'd450596f-894d-49e0-966a-fd39ed4c4c64' = {
		offchk '16ProPlusVL_MAK' 'Office ProPlus 2016'
		return
	}
	'dedfa23d-6ed1-45a6-85dc-63cae0546de6' = {
		offchk '16StandardVL_MAK' 'Office Standard 2016'
		return
	}
	'4f414197-0fc2-4c01-b68a-86cbb9ac254c' = {
		offchk '16ProjectProVL_MAK' 'Project Pro 2016'
		return
	}
	'da7ddabc-3fbe-4447-9e01-6ab7440b4cd4' = {
		offchk '16ProjectStdVL_MAK' 'Project Standard 2016'
		return
	}
	'6bf301c1-b94a-43e9-ba31-d494598c47fb' = {
		offchk '16VisioProVL_MAK' 'Visio Pro 2016'
		return
	}
	'aa2a7821-1827-4c2c-8f1d-4513a34dda97' = {
		offchk '16VisioStdVL_MAK' 'Visio Standard 2016'
		return
	}
	'829b8110-0e6f-4349-bca4-42803577788d' = {
		offchk '16ProjectProXC2RVL_MAKC2R' 'Project Pro 2016 C2R'
		return
	}
	'cbbaca45-556a-4416-ad03-bda598eaa7c8' = {
		offchk '16ProjectStdXC2RVL_MAKC2R' 'Project Standard 2016 C2R'
		return
	}
	'b234abe3-0857-4f9c-b05a-4dc314f85557' = {
		offchk '16VisioProXC2RVL_MAKC2R' 'Visio Pro 2016 C2R'
		return
	}
	'361fe620-64f4-41b5-ba77-84f8e079b1f7' = {
		offchk '16VisioStdXC2RVL_MAKC2R' 'Visio Standard 2016 C2R'
		return
	}
}

$table15 = @{
	'b322da9c-a2e2-4058-9e4e-f59a6970bd69' = {
		offchk 'ProPlusVL_MAK' 'Office ProPlus 2013'
		return
	}
	'b13afb38-cd79-4ae5-9f7f-eed058d750ca' = {
		offchk 'StandardVL_MAK' 'Office Standard 2013'
		return
	}
	'4a5d124a-e620-44ba-b6ff-658961b33b9a' = {
		offchk 'ProjectProVL_MAK' 'Project Pro 2013'
		return
	}
	'427a28d1-d17c-4abf-b717-32c780ba6f07' = {
		offchk 'ProjectStdVL_MAK' 'Project Standard 2013'
		return
	}
	'e13ac10e-75d0-4aff-a0cd-764982cf541c' = {
		offchk 'VisioProVL_MAK' 'Visio Pro 2013'
		return
	}
	'ac4efaf0-f81f-4f61-bdf7-ea32b02ab117' = {
		offchk 'VisioStdVL_MAK' 'Visio Standard 2013'
		return
	}
}

$table14 = @{
	'6f327760-8c5c-417c-9b61-836a98287e0c' = {
		offchk 'ProPlus-MAK' 'Office ProPlus 2010' 'ProPlusAcad-MAK' 'Office Professional Academic 2010'
		return
	}
	'9da2a678-fb6b-4e67-ab84-60dd6a9c819a' = {
		offchk 'Standard-MAK' 'Office Standard 2010' 'StandardAcad-MAK' 'Office Standard Academic 2010'
		return
	}
	'ea509e87-07a1-4a45-9edc-eba5a39f36af' = {
		offchk 'SmallBusBasics-MAK' 'Office Small Business Basics 2010'
		return
	}
	'df133ff7-bf14-4f95-afe3-7b48e7e331ef' = {
		offchk 'ProjectPro-MAK' 'Project Pro 2010'
		return
	}
	'5dc7bf61-5ec9-4996-9ccb-df806a2d0efe' = {
		offchk 'ProjectStd-MAK' 'Project Standard 2010' 'ProjectStd-MAK2' 'Project Standard 2010'
		return
	}
	'92236105-bb67-494f-94c7-7f7a607929bd' = {
		offchk 'VisioPrem-MAK' 'Visio Premium 2010' 'VisioPro-MAK' 'Visio Pro 2010'
		return
	}
	'e558389c-83c3-4b29-adfe-5e4d7f46c358' = {
		if ($null -ne $vPrem) { return }
		offchk 'VisioPro-MAK' 'Visio Pro 2010' 'VisioStd-MAK' 'Visio Standard 2010'
		return
	}
	'9ed833ff-4f92-4f36-b370-8683a4f13275' = {
		if ($null -ne $vProf) { return }
		offchk 'VisioStd-MAK' 'Visio Standard 2010'
		return
	}
}

# =========================
# Activation
# =========================

function instKey
{
	CONOUT ""
	$script:S_OK = 1
	$_qr = WmiQuery $spp "ID='$aid'" "Name"
	CONOUT ("Installing Key: {0}" -f $_qr)

	$_key = $null
	if ($KeysDB.ContainsKey($aid)) {
		$_key = $KeysDB[$aid]
	} else {
		CONOUT "No associated KMS Client key found"
		return
	}

	$ERRORCODE = WmiSLS $sps "InstallProductKey" @($_key)
	if ($ERRORCODE -ne 0) {
		CONOUT ("Failed: 0x{0}" -f ($ERRORCODE).ToString("X"))
		$script:S_OK = 0
		return
	}

	if ($sps -eq "SoftwareLicensingService") {
		$_rt = WmiSLS $sps "RefreshLicenseStatus"
	}
	execActivate
	return
}

###########################
function execActivate
{
	$script:S_OK = 1

	if ($sps -eq "SoftwareLicensingService") {
		$actsvc = $winsvc
		if ($_officespp -eq 0) {
			Del-RegKey "$SPPk\$_wApp\$aid"
		} else {
			Del-RegKey "$SPPk\$_oApp\$aid"
			offoem
		}
		if ($winbuild -ge 9600) {
			Del-RegKey "$SPPn\PersistedSystemState"
		}
	} else {
		$actsvc = $offsvc
		Del-RegKey "$OPPk\$_oA14\$aid"
		Del-RegKey "$OPPk\$_oApp\$aid"
		offoem
	}

	$gpr1 = 0; $gpr2 = 0
	$_qr = WmiQuery $spp "ID='$aid'" "GracePeriodRemaining"
	$gpr1 = [int]$_qr; $gpr2 = [Math]::Round($gpr1/1440)
	$_qr = WmiQuery $spp "ID='$aid'" "Name"

	if ($sps -eq "SoftwareLicensingService" -and $W1nd0ws -eq 0 -and $_officespp -eq 0) {
		Set-KmsReg "$SPPk\$_wApp\$aid" "127.0.0.2" $KMS_Port
		Set-RegValue "$SPPn\$_wApp\$aid" 'DiscoveredKeyManagementServiceIpAddress' 'String' "127.0.0.2"
		CONOUT "Checking: $_qr"
		CONOUT "Product is KMS 2038 Activated."
		CONOUT "Remaining Period: $gpr2 days ($gpr1 minutes)`n"
		return
	}

	if ($gpr1 -ne 0 -and $gpr1 -gt 259200 -and $aid -ne 'e0b2d383-d112-413f-8a80-97f373a5820c' -and $aid -ne 'e38454fb-41a4-4f59-a5dc-25080e354730') {
		CONOUT "Checking: $_qr"
		CONOUT "Product is KMS4k Activated."
		CONOUT "Remaining Period: $gpr2 days ($gpr1 minutes)"
		if ($sps -eq "SoftwareLicensingService" -and $_officespp -eq 0) {CONOUT ""}
		return
	}

	CONOUT "Activating: $_qr"
	$ERRORCODE = WmiSLP $spp $aid "Activate"

	if ($ERRORCODE -eq -1073418187) {
		CONOUT "Product Activation Failed: 0xC004F035"
		if ($OSType -eq "Win7") { CONOUT "Windows 7 $not_slp" }
		if ($OSType -eq "Vista") { CONOUT "Vista $not_slp" }
		CONOUT "See Read Me for details."
		return
	}
	if ($ERRORCODE -eq -1073417728) {
		CONOUT "Product Activation Failed: 0xC004F200"
		CONOUT "Windows needs to rebuild the activation-related files."
		CONOUT "See KB2736303 for details."
		return
	}
	if ($ERRORCODE -eq -1073422315) {
		CONOUT "Product Activation Failed: 0xC004E015"
		CONOUT "Running slmgr.vbs /rilc to mitigate."
		. InstallLicensePre $sps; $null = ReinstallLicenses
	}

	if ($ERRORCODE -ne 0) {
		RerunService $actsvc
		$ERRORCODE = WmiSLP $spp $aid "Activate"
	}

	$gpr1 = 0; $gpr2 = 0
	$_qr = WmiQuery $spp "ID='$aid'" "GracePeriodRemaining"
	$gpr1 = [int]$_qr; $gpr2 = [Math]::Round($gpr1/1440)

	if ($ERRORCODE -eq 0 -and $gpr1 -eq 0) {
		CONOUT "Product Activation succeeded, but Remaining Period failed to increase."
		CONOUT "You may need to Rearm the product."
		if ($OSType -eq "Win7") { CONOUT "This could be related to the error described in KB4487266" }
		return
	}

	$Act_OK = 0
	if (($gpr1 -eq 43200 -and $_officespp -eq 0 -and $winbuild -ge 9200) -or
		($gpr1 -eq 64800) -or
		($gpr1 -gt 259200 -and $Win10Gov -eq 1) -or
		($gpr1 -eq 259200)) {
		$Act_OK = 1
	}
	if ($ERRORCODE -eq 0 -and $Act_OK -eq 1) {
		CONOUT "Product Activation Successful"
		CONOUT "Remaining Period: $gpr2 days ($gpr1 minutes)"
		return
	}

	if ($ERRORCODE -ne 0) {
		CONOUT ("Product Activation Failed: 0x{0}" -f ($ERRORCODE).ToString("X"))
	} else {
		CONOUT ("Product Activation Failed")
	}
	CONOUT "Remaining Period: $gpr2 days ($gpr1 minutes)"
	$script:S_OK = 0
}

# =========================
# Misc.
# =========================

function ActiveEdition
{
	$Win10Gov = 0
	$EditionWMI = $null
	$EditionID = $null

	if ($winbuild -lt 14393 -and $SSppHook -ne 0) {
		return
	}

	$RegKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages"
	$Pattern = "Microsoft-Windows-*Edition~31bf3856ad364e35"
	$EditionPKG = "FFFFFFFF"

	Get-ChildItem -Path $RegKey | Where-Object { $_.Name -like "*$Pattern*" } | ForEach-Object {
		$state = (Get-ItemProperty -Path $_.PSPath -Name "CurrentState" -ErrorAction SilentlyContinue).CurrentState
		if ($state -match "112|7") {
			$pkgParts = $_.PSChildName -split '[-~]'
			$EditionPKG = $pkgParts[2]
		}
	}

	if ($EditionPKG -match "Edition") {
		$EditionID = $EditionPKG.Substring(0, $EditionPKG.Length - 7)
	} elseif ($_NT7 -eq 1) {
		# Fallback via DISM
		$dismOutput = & DISM.exe /English /Online /Get-CurrentEdition 2>$null
		$EditionLine = $dismOutput | Where-Object { $_ -match "Current Edition\s*:" }
		if ($EditionLine) {
			$EditionID = ($EditionLine -split ":\s*")[1].Trim()
		}
	}

	StartService $winsvc

	if ($winbuild -ge 6001) {
		$EditionWMI = WmiQuery "SoftwareLicensingProduct" "ApplicationID='$_wApp' $adoff AND PartialProductKey is not NULL" "LicenseFamily"
	}
	if (-not $EditionWMI) {
		if ($winbuild -ge 17063) { $EditionID = Get-RegValue $_wNTk 'EditionId' }
		if ($winbuild -lt 14393) { $EditionID = Get-RegValue $_wNTk 'EditionId'; return }
	}
	if ($EditionWMI) {
		$EditionID = $EditionWMI
	}

	switch ($EditionID) {
		"IoTEnterprise" { $EditionID = "Enterprise" }
		"IoTEnterpriseK" { $EditionID = "Enterprise" }
		"IoTEnterpriseSK" { $EditionID = "EnterpriseS" }
		"IoTEnterpriseS" { if ($winbuild -lt 19046 -and $winbuild -ge 19041 -and [int]$UBR -lt 2788) {$_iots = 1} }
		"ProfessionalSingleLanguage" { $EditionID = "Professional" }
		"ProfessionalCountrySpecific" { $EditionID = "Professional" }
		"EnterpriseG" { $Win10Gov = 1 }
		"EnterpriseGN" { $Win10Gov = 1 }
	}
}

###########################
function SppTrigger
{
	$__t = [AppDomain]::CurrentDomain.DefineDynamicAssembly((Get-Random), 1
	).DefineDynamicModule((Get-Random), $False).DefineType((Get-Random));
	[void]$__t.DefinePInvokeMethod(
		"SLpTriggerServiceWorker",
		"sppc.dll",
		"Public,Static",
		"Standard",
		[Int32],
		@( [UInt32], [IntPtr], [String], [UInt32] ),
		"Winapi",
		"Unicode"
	);
	[void]$__t.CreateType()::SLpTriggerServiceWorker(0, 0, 'reeval', 0);
}

###########################
function stopWLMS
{
	try {
		$tskService = New-Object -Com "Schedule.Service"
		$tskService.Connect()
		$tskFolder = $tskService.GetFolder("\")
		$tskDefinition = $tskService.NewTask(0) 
		$tskPrincipal = $tskDefinition.Principal
		$tskPrincipal.UserId = "SYSTEM"
		$tskPrincipal.LogonType = 5
		$tskPrincipal.RunLevel = 1
		$tskSettings = $tskDefinition.Settings
		$tskSettings.Enabled = $True
		$tskTrigger = $tskDefinition.Triggers.Create(7)
		$tskAction = $tskDefinition.Actions.Create(0)
		$tskAction.Path = 'powershell.exe'
		$tskAction.Arguments = '-nop -c "sp ''HKLM:\SYSTEM\CurrentControlSet\Services\WLMS'' ''Start'' 4 -Force -EA 0; spsv WLMS -Force -EA 0; Exit 0"'
		[void]$tskFolder.RegisterTaskDefinition("stop_wlms", $tskDefinition, 6, $null, $null, 5, $null)
		Start-Sleep -Seconds 3
		$tskFolder.DeleteTask("stop_wlms", 0)
	} catch {
		$taskName = 'stop_wlms'
		$taskCommand = 'cmd /c \"reg add HKLM\SYSTEM\CurrentControlSet\Services\WLMS /v Start /t REG_DWORD /d 4 /f &net stop WLMS /y &exit /b 0 \"'
		& schtasks.exe /Create /F /RU "SYSTEM" /RL HIGHEST /SC HOURLY /TN $taskName /TR $taskCommand >$null 2>&1
		& schtasks.exe /Run /I /TN $taskName >$null 2>&1
		Start-Sleep -Seconds 3
		& schtasks.exe /Delete /F /TN $taskName >$null 2>&1
	}
	$startValue = Get-RegValue 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\WLMS' 'Start'
	if ($startValue -eq 4) {
		$_fix7 = 1
	}
}

# =========================
# ServiceController
# =========================

function RerunService($_svc)
{
	Restart-Service -Name $_svc -Force -ErrorAction SilentlyContinue
}

function StopService($_svc)
{
	$scm = Stop-Service -Name $_svc -PassThru -Force
	if ($scm -and $scm.Status -ne 'Stopped') {
		$scm.WaitForStatus('Stopped','00:00:05')
	}
}

function StartService($_svc)
{
	$scm = Start-Service -Name $_svc -PassThru
	if ($scm -and $scm.Status -ne 'Running') {
		$scm.WaitForStatus('Running','00:00:05')
	}
}

# =========================
# Scheduled Tasks
# =========================

function SchedulerService
{
	$tskService = New-Object -Com "Schedule.Service"
	$tskService.Connect()
}

function SchedulerExists($tskTask)
{
	$tskPath = Split-Path $tskTask -Parent
	$tskName = Split-Path $tskTask -Leaf
	try {
		$tskService.GetFolder($tskPath).GetTask($tskName).Name | Out-Null
		return $true
	} catch {
		return $false
	}
}

function SchedulerRemove($tskTask)
{
	$tskPath = Split-Path $tskTask -Parent
	$tskName = Split-Path $tskTask -Leaf
	try {
		$tskService.GetFolder($tskPath).DeleteTask($tskName, 0)
	} catch {
	}
}

function SchedulerEnable($tskTask)
{
	$tskPath = Split-Path $tskTask -Parent
	$tskName = Split-Path $tskTask -Leaf
	$tskReg = $tskService.GetFolder($tskPath).GetTask($tskName)
	$tskReg.Enabled = $true
}

function SchedulerExport($tskTask)
{
	$tskPath = Split-Path $tskTask -Parent
	$tskName = Split-Path $tskTask -Leaf
	return $tskService.GetFolder($tskPath).GetTask($tskName).Xml
}

function SchedulerRegister($tskTask, $tskXml)
{
	$tskPath = Split-Path $tskTask -Parent
	$tskName = Split-Path $tskTask -Leaf
	$tskRoot = $tskService.GetFolder("\")
	try {
		$tskFolder = $tskRoot.GetFolder($tskPath)
	} catch {
		$tskFolder = $tskRoot.CreateFolder($tskPath)
	}
	$tskFolder.RegisterTask($tskName, $tskXml, 6, $null, $null, 4, $null) | Out-Null
}

$_TaskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Source>Microsoft Corporation</Source>
    <Author>Microsoft Corporation</Author>
    <Version>1.0</Version>
    <Description>This task restarts the Software Protection Platform service when user logon occurs</Description>
    <URI>\Microsoft\Windows\SoftwareProtectionPlatform\SvcTrigger</URI>
    <SecurityDescriptor>D:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;FRFW;;;S-1-5-80-123231216-2592883651-3715271367-3753151631-4175906628)(A;;FR;;;S-1-5-4)</SecurityDescriptor>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="InteractiveUser">
      <GroupId>S-1-5-4</GroupId>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>false</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>true</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>7</Priority>
    <RestartOnFailure>
      <Interval>PT1M</Interval>
      <Count>3</Count>
    </RestartOnFailure>
  </Settings>
  <Actions Context="InteractiveUser">
    <ComHandler>
      <ClassId>{B1AEBB5D-EAD9-4476-B375-9C3ED9F32AFC}</ClassId>
      <Data>logon</Data>
    </ComHandler>
  </Actions>
</Task>
"@

# =========================
# Hook Handlers
# =========================

function chkAUR
{
	# default state
	$_AUR = 0

	# check if hook file exist
	if (-not (Test-Path $_Hook)) {
		return
	}

	# check if hook file is a symbolic link
	if ((Get-Item -Path $_Hook).Attributes -band [IO.FileAttributes]::ReparsePoint) {
		return
	}

	# Check hooked Windows executable
	if (Get-Item -Path "Registry::$IFEO\$SppVer" -ErrorAction SilentlyContinue) {
		$props = Get-ItemProperty -Path "Registry::$IFEO\$SppVer" -ErrorAction SilentlyContinue | Out-String
		if ($props -match $chkVal) {
			$_AUR = 1
			$_dMode = 'Auto Renewal'
			if ($props -match "Debugger") {$AltDLL = 1}
			return
		}
	}

	# Check hooked Office executable
	if (Get-Item -Path "Registry::$IFEO\$OppVer" -ErrorAction SilentlyContinue) {
		$props = Get-ItemProperty -Path "Registry::$IFEO\$OppVer" -ErrorAction SilentlyContinue | Out-String
		if ($props -match $chkVal) {
			$_AUR = 1
			$_dMode = 'Auto Renewal'
			if ($props -match "Debugger") {$AltDLL = 1}
		}
	}

	return
}

# =========================
# IFEO Helpers
# =========================

function InstallIFEO($_msg = 0, $ARsetup = 0)
{
	if ($SSppHook -ne 0) {
		CreateIFEOEntry $SppVer $_msg
	}
	if (($ARsetup -eq 1 -or $_AUR -eq 1) -or $OsppHook -ne 0) {
		CreateIFEOEntry $OppVer $_msg
	}
	if (($ARsetup -eq 1 -or $_AUR -eq 1) -and $OSType -eq 'Win7') {
		CreateIFEOEntry "SppExtComObj.exe" $_msg
	}
}

###########################
function CreateIFEOEntry($_exe, $_msg = 0)
{
	if ($_msg -eq 1) {
		CONOUT "[$IFEO`n\$_exe]"
	}
	$_ifeo = "$IFEO\$_exe"
	if ($_aDLL -eq 1) {
		Del-RegValue $_ifeo 'Debugger'
		Set-RegValue $_ifeo 'VerifierDlls' 'String' "SppExtComObjHook.dll"
		Set-RegValue $_ifeo 'VerifierDebug' 'DWord' 0
		Set-RegValue $_ifeo 'VerifierFlags' 'DWord' 0x80000000
		Set-RegValue $_ifeo 'GlobalFlag' 'DWord' 0x100
	} else {
		Set-RegValue $_ifeo 'Debugger' 'String' "rundll32.exe SppExtComObjHook.dll,PatcherMain"
		Del-RegValue $_ifeo 'VerifierDlls'
		Del-RegValue $_ifeo 'VerifierDebug'
		Del-RegValue $_ifeo 'VerifierFlags'
		Del-RegValue $_ifeo 'GlobalFlag'
	}
	Set-RegValue $_ifeo 'KMS_Emulation' 'DWord' $KMS_Emulation
	UpdateIFEOEntry $_exe
}

###########################
function UpdateIFEOEntry($_exe)
{
	$_ifeo = "$IFEO\$_exe"
	Set-RegValue $_ifeo 'KMS_ActivationInterval' 'DWord' $KMS_ActivationInterval
	Set-RegValue $_ifeo 'KMS_RenewalInterval' 'DWord' $KMS_RenewalInterval
	if ($_exe -eq 'SppExtComObj.exe' -and $winbuild -ge 9600) {
		Set-RegValue $_ifeo 'KMS_HWID' 'QWord' $KMS_HWID
	}
	if ($_exe -eq 'sppsvc.exe') {
		UpdateIFEOEntry "$IFEO\SppExtComObj.exe"
	}
	if ($_exe -eq $OppVer) {
		UpdateOSPPEntry
	}
}

function UpdateOSPPEntry
{
	Set-KmsReg $OPPk $KMS_IP $KMS_Port
}

###########################
$valuesToDelete = @(
	'Debugger','VerifierDlls','VerifierDebug','VerifierFlags','GlobalFlag',
	'KMS_Emulation','KMS_ActivationInterval','KMS_RenewalInterval',
	'Office2010','Office2013','Office2016','Office2019','Office2021','Office2024'
)

function RemoveIFEOEntry($_exe, $_msg = 0)
{
	if ($_msg -eq 1) {
		CONOUT "[$IFEO`n\$_exe]"
	}
	$_ifeo = "$IFEO\$_exe"
	if ($_exe -ne $OppVer) {
		Del-RegKey $_ifeo
		return
	}
	if ($OsppHook -eq 0) {
		Del-RegKey $_ifeo
	} else {
		foreach ($__v in $valuesToDelete) {
			Del-RegValue $_ifeo $__v
		}
	}
	Set-KmsReg $OPPk $_uIP "1688"
}

###########################
function cCache
{
	CONOUT "`nClearing KMS Cache..."

	Del-KmsReg

	$bC16R = $false
	foreach ($__p in "$_onat\ClickToRun", "$_owow\ClickToRun") {
		$chkPath = Get-RegValue "$__p" 'InstallPath'
		if ($chkPath -and (Test-Path "$chkPath\root\Licenses16\ProPlus*.xrm-ms")) {
			$bC16R = $true
			break
		}
	}

	if ($winbuild -ge 9200 -and $bC16R) {
		CONOUT "`n## Notice ##"
		CONOUT "`nTo make sure Office programs do not show a non-genuine banner"
		CONOUT "please apply manual or auto-renewal activation, and don't uninstall afterward."
	}

	if ($Unattend -ne 0) {
		return TheEnd
	}
	CONOUT $line9
	cPause
	return MainMenu
}

# =========================
# AutoRenewal Functions
# =========================

function InstallW7Inf($_msg = 1)
{
	if ($_msg -eq 1) { CONOUT "`nAdding migration fail-safe..."; CONOUT $w7inf }
	$w7dir = Split-Path $w7inf
	if (-not (Test-Path $w7dir)) { New-Item -ItemType Directory -Path $w7dir -Force | Out-Null }
	@"
[WTR]
Name="KMS_VL_ALL"

[WTR.*]
NotifyUser="No"

[System.Registry]
"$_wNTk\Image File Execution Options\sppsvc.exe [*]"
"@ | Out-File -FilePath $w7inf -Encoding ASCII -Force
}

###########################
function CreateTask($_msg = 1)
{
	. SchedulerService
	if (-not (SchedulerExists $_TaskEx) -and (SchedulerExists $_TaskOs)) {
		SchedulerRegister $_TaskEx (SchedulerExport $_TaskOs)
	}
	if (-not (SchedulerExists $_TaskEx)) {
		SchedulerRegister $_TaskEx $_TaskXml
	}
	if (SchedulerExists $_TaskEx) {
		if ($_msg -eq 1) { CONOUT "`nAdding Scheduled Task..."; CONOUT $_TaskEx }
		SchedulerEnable $_TaskEx
	}
}

###########################
function RemoveTask($_msg = 1)
{
	. SchedulerService
	if (SchedulerExists $_TaskEx) {
		if ($_msg -eq 1) { CONOUT "`nRemoving Scheduled Task..."; CONOUT $_TaskEx }
		SchedulerRemove $_TaskEx
	}
}

# =========================
# KMS_VL_ALL Functions
# =========================

function casWm
{
	Clear-Host
	$_old2 = $Host.UI.RawUI.WindowTitle
	$f=[IO.File]::ReadAllText("$_ps1f") -split ':sppmgr\:.*'; iex ($f[1])
	cPause
	$Host.UI.RawUI.WindowTitle = $_old2
}

#############################
function CreateReadMe
{
	if (-not (Test-Path "$env:PUBLIC\ReadMeAIO.html")) {
		$pop = (Get-Location -PSProvider FileSystem).ProviderPath
		Push-Location -Lit "$env:PUBLIC"
		[Environment]::CurrentDirectory = $pwd
		$f=[IO.File]::ReadAllText("$_ps1f") -split ':readme\:.*'; [IO.File]::WriteAllText('ReadMeAIO.html',$f[1].Trim(),[System.Text.Encoding]::UTF8)
		Pop-Location
		[Environment]::CurrentDirectory = $pop
	}
	if (Test-Path "$env:PUBLIC\ReadMeAIO.html") {
		start "$env:PUBLIC\ReadMeAIO.html"
		Start-Sleep -Seconds 2
	}
}

#############################
function CreateOEM
{
	Clear-Host
	if (Test-Path "$_dvd") {
		CONOUT $line9
		CONOUT "Folder already exist..."
		CONOUT "$_dvd"
		CONOUT "`nManually remove it if you wish to create a fresh copy."
		CONOUT $line9
		cPause
		return
	}

	$_stp = $_dvd + '\$$\Setup\Scripts'
	if (-not (Test-Path "$_stp\KMS_VL_ALL_AIO.ps1")) { New-Item -ItemType Directory -Path "$_stp" -Force | Out-Null }
	Copy-Item -Path "$_ps1f" -Destination "$_stp\KMS_VL_ALL_AIO.ps1" -Force
	@"
@echo off
set "_PSf=%~dp0KMS_VL_ALL_AIO.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^& "'%_PSf%' /s /a"
if /i "%~dp0"=="%SystemRoot%\Setup\Scripts\" ((goto) 2>nul &cd \ &rd /s /q "%~dp0")
"@ | Out-File -FilePath "$_stp\setupcomplete.cmd" -Encoding ASCII -Force

	CONOUT $line9
	CONOUT "Folder Created..."
	CONOUT "`n$_dvd"
	CONOUT $line9
	cPause
}

#############################
function CreateBIN
{
	Clear-Host
	if (Test-Path "$_lld\*.dll") {
		CONOUT $line9
		CONOUT "Folder already exist..."
		CONOUT "$_lld"
		CONOUT "`nManually remove it if you wish to create a fresh copy."
		CONOUT $line9
		cPause
		return
	}

	if (-not (Test-Path "$_lld")) { New-Item -ItemType Directory -Path "$_lld" -Force | Out-Null }
	$pop = (Get-Location -PSProvider FileSystem).ProviderPath
	Push-Location -Lit "$_lld"
	[Environment]::CurrentDirectory = $pwd

	$_ft = @( @{n='2';t=133710899608630184}, @{n='3';t=133710899693922335}, @{n='4';t=133710899771091897}, @{n='5';t=134112546549947564}, @{n='6';t=134112546583547123}, @{n='7';t=134112546622611849} )
	$f=[IO.File]::ReadAllText("$_ps1f") -split ':niblld\:.*'; iex ($f[1]); 2..7 | foreach {[BAT91]::Dec([ref]$f,$_,$_,$k)};
	$_ft | foreach {[IO.File]::SetLastWriteTimeUtc($_.n, [DateTime]::FromFileTimeUtc([long]$_.t))}

	Rename-Item '2' 'SppExtComObjHook-x86.dll'
	Rename-Item '3' 'SppExtComObjHook-x64.dll'
	Rename-Item '4' 'SppExtComObjHook-arm64.dll'
	Rename-Item '5' 'SppExtComObjHook-Alt-x86.dll'
	Rename-Item '6' 'SppExtComObjHook-Alt-x64.dll'
	Rename-Item '7' 'SppExtComObjHook-Alt-arm64.dll'
	Pop-Location
	[Environment]::CurrentDirectory = $pop

	CONOUT $line9
	CONOUT "Folder Created..."
	CONOUT "`n$_lld"
	CONOUT $line9
	cPause
}

#############################
function DoActivate
{
	if ($External -eq 1 -and $KMS_IP -eq $_uIP) {
		$External = 0
	}
	if ($External -eq 1) {
		$_AUR = 1
	}
	if ($External -eq 0) {
		$KMS_IP = $_uIP
	}
	if ($_AUR -eq 0) {
		$KMS_RenewalInterval = 43200
		$KMS_ActivationInterval = 43200
	} else {
		$KMS_RenewalInterval = $_uRI
		$KMS_ActivationInterval = $_uAI
	}

	if ($External -eq 1) {
		$_mode = "External [$KMS_IP]"
		$_cc = "8F"
	} elseif ($_AUR -eq 0) {
		$_mode = "Manual"
		$_cc = "5F"
	} else {
		$_mode = "Auto Renewal"
		$_cc = "07"
	}
	if ($Silent -eq 0) { DoColor $_cc }

	if ($Unattend -eq 0) {
		if ($_Debug -eq 0) {
			$Host.UI.RawUI.WindowTitle = $_title
		} else {
			$_title = "$_title`: $_mode"
			$Host.UI.RawUI.WindowTitle = $_title
		}
	} else {
		CONOUT "`nRunning $_title"
	}
	CONOUT "`nActivation Mode: $_mode"

	if ($winbuild -ge 9600) {
		Set-RegValue $AVSk 'NoGenTicket' 'DWord' 1
	}
	if ($winbuild -eq 14393) {
		Set-RegValue $AVSk 'NoAcquireGT' 'DWord' 1
	}

	# if ($External -eq 0 -and -not (Test-Path "$_work\$fDLL")) { & $E_DLL }

	if ($_wlms) {
		stopWLMS
	}
	StopService $winsvc
	if ($_wlms) {
		if ((Get-Service -Name $winsvc).Status -ne 1) { $_eval = 1 }
	}
	if ($OsppHook -ne 0) {
		StopService $offsvc
	}
	if ($External -eq 0 -and $_ReAR -eq 0) {
		$_verb = 0; $_rtrn = 0; HookInstall
	}

	if ($External -eq 0 -and $_AUR -eq 1) {
		UpdateIFEOEntry $SppVer
		UpdateIFEOEntry $OppVer
	}
	if ($External -eq 1 -and $_AUR -eq 1) {
		UpdateOSPPEntry
	}

	. ActiveEdition

	$_regos = Get-RegValue $_wNTk 'ProductName'
	if ($_regos) {
		$_winos = $_regos
	} elseif ($EditionID) {
		$_winos = "Windows $EditionID edition"
	} else {
		$_winos = "Detected Windows"
	}

	. officeCtr
	foreach ($__A in 14,15,16,19,21,24) {
		. officeLoc $__A
		. officeMsg $__A
	}
	if ($msi_off[14] -eq 1) {
		$_C14R = $null
	}

	$script:S_OK = 1
	. RunSPP
	if ($ActOffice -ne 0) {
		. RunOSPP
	} else {
		CONOUT "`nOffice activation is OFF..."
	}
	if ($script:S_OK -eq 0 -and $External -eq 0) {
		CheckFR
	}

	StopService $winsvc
	if ($OsppHook -ne 0) {
		StopService $offsvc
	}
	if ($_AUR -eq 0) {
		HookRemove
	}
	if ($_NT7 -eq 0) {
		StartService $winsvc
	}
	if ($winbuild -ge 9200) {
		SppTrigger
	}

	if ($_verb -eq 1) {
		CONOUT $line6
		if ($External -eq 0 -and $_rtrn -eq 1) {
			CONOUT "`nMake sure to exclude this file in the Antivirus protection."
			CONOUT "`"$env:SystemRoot\System32\SppExtComObjHook.dll`""
		}
	}
	$KMS_IP = $_uIP
	$External = 0
	if ($Silent -eq 0 -and $_Debug -eq 0) {
		if ($uManual -eq 1 -or $uAutoRenewal -eq 1) { & timeout.exe /t 5 }
	}
	if ($Unattend -ne 0) {
		return TheEnd
	}
	cPause
	return MainMenu
}

###########################
function HookInstall
{
	if ($AltDLL -eq 1) {
		$_aDLL  = 0
		$fDLL   = "d${xOS}.dll"
		$_orig  = (Get-Variable -Name "f_d_$xOS").Value
	}
	if ($_aDLL -eq 1) {
		$_dllNum  = (Get-Variable -Name "n_a_$xOS").Value
		$_dllStm  = (Get-Variable -Name "t_a_$xOS").Value
	} else {
		$_dllNum  = (Get-Variable -Name "n_d_$xOS").Value
		$_dllStm  = (Get-Variable -Name "t_d_$xOS").Value
	}
	# if (-not (Test-Path "$_work\$fDLL")) { & $E_DLL }

	$AddExc = $null
	if ($winbuild -ge 9600) {
		$qrWD = CimMPS "Add"
		if ($qrWD) { $AddExc = " and Windows Defender exclusion" }
	}
	if ($_verb -eq 1) {
		if ($Silent -eq 0 -and $_Debug -eq 0) { . $_con134 }
		CONOUT $line9
		CONOUT "Installing Local KMS Emulator..."
		CONOUT "`nAdding File$AddExc..."
		CONOUT "`"$env:SystemRoot\System32\SppExtComObjHook.dll`""
	}

	StopService $winsvc
	if ($OsppHook -ne 0) { StopService $offsvc }

	foreach ($__f in $bins) {
		if (Test-Path "$SysPath\$__f") {
			Remove-Item "$SysPath\$__f" -Force -ErrorAction SilentlyContinue
		}
		if (Test-Path "$env:SystemRoot\SysWOW64\$__f") {
			Remove-Item "$env:SystemRoot\SysWOW64\$__f" -Force -ErrorAction SilentlyContinue
		}
	}

	$d=$_dllPath+'\SppExtComObjHook.dll';
	$f=[IO.File]::ReadAllText("$_ps1f") -split ':niblld\:.*'; iex ($f[1]); X $_dllNum;
	[IO.File]::SetLastWriteTimeUtc($d, [DateTime]::FromFileTimeUtc([long]$_dllStm));
	# try { Copy-Item -Path "$_work\$fDLL" -Destination $_Hook -Force } catch {}

	if ($_verb -eq 1) {
		CONOUT "`nAdding Registry Keys..."
	}
	InstallIFEO $_verb
	if ($_AUR -eq 1 -and $OSType -eq 'Win7' -and $SSppHook -ne 0 -and -not (Test-Path $w7inf)) {
		InstallW7Inf $_verb
	}

	if ($_AUR -eq 1 -and $OSType -eq 'Win8') {
		CreateTask $_verb
	}
	if ($_verb -eq 1) {
		CONOUT $line6
	}
	if ($_rtrn -eq 1) {
		. DoActivate
	}
}

###########################
function HookRemove
{
	StopService $winsvc
	if ($OsppHook -ne 0) { StopService $offsvc }

	$RemExc = $null
	if ($winbuild -ge 9600) {
		Del-RegValue $AVSk 'NoGenTicket'
		Del-RegValue $AVSk 'NoAcquireGT'
		$qrWD = CimMPS "Remove"
		if ($qrWD) { $RemExc = " and Windows Defender exclusion" }
	}

	if ($_verb -eq 1) {
		if ($Silent -eq 0 -and $_Debug -eq 0) { . $_con134 }
		CONOUT $line9
		CONOUT "Uninstalling Local KMS Emulator..."
		CONOUT "`nRemoving Files$RemExc..."
	}

	foreach ($__f in $bins) {
		if (Test-Path "$SysPath\$__f") {
			if ($_verb -eq 1) { CONOUT "`"$env:SystemRoot\System32\$__f`"" }
			Remove-Item "$SysPath\$__f" -Force -ErrorAction SilentlyContinue
		}
		if (Test-Path "$env:SystemRoot\SysWOW64\$__f") {
			if ($_verb -eq 1) { CONOUT "`"$env:SystemRoot\SysWOW64\$__f`"" }
			Remove-Item "$env:SystemRoot\SysWOW64\$__f" -Force -ErrorAction SilentlyContinue
		}
	}
	if (Test-Path $w7inf) {
		if ($_verb -eq 1) { CONOUT $w7inf }
		Remove-Item $w7inf -Force
	}

	if ($_verb -eq 1) {
		CONOUT "`nRemoving Registry Keys..."
	}
	foreach ($__x in $exes) {
		if (Get-Item -Path "Registry::$IFEO\$__x" -ErrorAction SilentlyContinue) {
			RemoveIFEOEntry $__x $_verb
		}
	}

	if ($OSType -eq 'Win8') {
		RemoveTask $_verb
	}

	if ($_NT7 -eq 0) {
		StartService $winsvc
	}
}

# =========================
# Errors helpers
# =========================

function CheckWS
{
	$chSLS = $false
	try {
		([WMISEARCHER]"SELECT Version FROM SoftwareLicensingService").Get() | select -Expand Properties -EA 1 | foreach {$chSLS = $_.Value -match "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*"}
	} catch {
	}
	if ($chSLS) {
		return
	}
	$WMIe = 1
	$chWMI = $false
	try {
		([WMISEARCHER]"SELECT CreationClassName FROM Win32_ComputerSystem").Get() | select -Expand Properties -EA 1 | foreach {$chWMI = $_.Value -match "ComputerSystem"}
	} catch {
	}
	if ($chWMI) {
		CONOUT "Error: SoftwareLicensingService is not responding"
	} else {
		CONOUT "Error: WMI and SoftwareLicensingService are not responding"
	}
}

function msgEreg($__e)
{
	CONOUT "`n$_err"
	CONOUT "Some or all required registry values are missing."
	CONOUT "[$IFEO\$__e]"
	CONOUT ($errVal -join ", ")
	CONOUT "`nVerify that Antivirus protection is OFF or the registry path is excluded."
}

function CheckFR
{
	if (-not (Test-Path $_Hook)) {
		CONOUT "`n$_err"
		CONOUT "File existence failed."
		CONOUT "`"$env:SystemRoot\System32\SppExtComObjHook.dll`""
		CONOUT "`nVerify that Antivirus protection is OFF or the file path is excluded."
	}

	if (Test-Path $_Hook) {
		$_hash = [BitConverter]::ToString([Security.Cryptography.SHA1]::Create().ComputeHash(([IO.StreamReader]"$_Hook").BaseStream)) -replace '-'
		if ($_hash -ne $_orig) {
			CONOUT "`n=== WARNING ==="
			CONOUT "SHA1 hash verification mismatch."
			CONOUT "`"$env:SystemRoot\System32\SppExtComObjHook.dll`""
			CONOUT "Expected: $_orig"
			CONOUT "Detected: $_hash"
			CONOUT "`nIf you compiled the file yourself, then ignore this message."
		}
	}

	$E_REG = 0
	if ($SSppHook -ne 0) {
		foreach ($__r in $errVal) {
			if ($null -eq (Get-RegValue "$IFEO\$SppVer" $__r)) { $E_REG = 1 }
		}
	}
	if ($E_REG -eq 1) {
		msgEreg $SppVer
	}

	$E_REG = 0
	if ($OsppHook -ne 0) {
		foreach ($__r in $errVal) {
			if ($null -eq (Get-RegValue "$IFEO\$OppVer" $__r)) { $E_REG = 1 }
		}
	}
	if ($E_REG -eq 1) {
		msgEreg $OppVer
	}

	$WMIe = 0
	. CheckWS
	if ($WMIe -eq 1) {
		CONOUT "`n$_err"
		CONOUT "Failed running WMI query check."
		CONOUT "`nVerify that these services are working correctly:"
		CONOUT "Windows Management Instrumentation [WinMgmt]"
		CONOUT "Software Protection/Licensing [$winsvc]"
	}
	return

	$certutil = Join-Path "$SysPath\certutil.exe"
	if (Test-Path "$SysPath\certutil.exe") {
		$_hashOutput = certutil.exe -hashfile $_Hook $alg 2>$null | Select-Object -Skip 1 | Where-Object { $_ -notmatch "CertUtil" }
		$_hash = ($_hashOutput -join "").Replace(" ", "")
	}

}

# =========================
# Click-to-Run Retail-to-Volume
# =========================

function C2RR2V
{
	$RanR2V = 1
	$_LTS19 = 0
	$_LTS21 = 0
	$_LTS24 = 0
	$tag = ""
	$ons = " 2016"

	# Check if ClickToRun services exist
	$error1 = (Get-Service -Name "ClickToRunSvc" -ErrorAction SilentlyContinue) -eq $null
	$error2 = (Get-Service -Name "OfficeSvc" -ErrorAction SilentlyContinue) -eq $null
	if ($error1 -and $error2) {
		CONOUT "Error: Office C2R service is not detected"
		return _fC2R
	}

	# Check Office InstallPaths
	$_Office16 = 0
	$_Office15 = 0
	foreach ($__p in "$_onat\ClickToRun", "$_owow\ClickToRun") {
		$chkPath = Get-RegValue "$__p" 'InstallPath'
		if ($chkPath -and (Test-Path "$chkPath\root\Licenses16\ProPlus*.xrm-ms")) {
			$_Office16 = 1
			break
		}
	}
	foreach ($__p in "$_onat\15.0\ClickToRun", "$_owow\15.0\ClickToRun") {
		$chkPath = Get-RegValue "$__p" 'InstallPath'
		if ($chkPath -and (Test-Path "$chkPath\root\Licenses\ProPlus*.xrm-ms")) {
			$_Office15 = 1
			break
		}
	}
	if ($_Office16 -eq 0 -and $_Office15 -eq 0) {
		CONOUT "Error: Office C2R InstallPath is not detected"
		return _fC2R
	}

	# Reg16istry
	$_InstallRoot = $null
	$_ProductIds = $null
	$_GUID = $null
	$_Config = $null
	$_PRIDs = $null
	$_OSPPVBS = $null
	$_LicensesPath = $null
	$_Integrator = $null
	switch ($_Office16) {
		1 {
			$_queryPath = if (Get-RegValue "$_onat\ClickToRun" 'InstallPath') { "$_onat\ClickToRun" } else { "$_owow\ClickToRun" }
			$_InstallRoot = (Get-RegValue "$_queryPath" 'InstallPath') + '\root'
			$_OSPPVBS = (Get-RegValue "$_queryPath" 'InstallPath') + '\Office16\OSPP.VBS'
			$_GUID = Get-RegValue "$_queryPath" 'PackageGUID'
			$_ProductIds = Get-RegValue "$_queryPath\Configuration" 'ProductReleaseIds'
			$_Config = "$_queryPath\Configuration"
			$_PRIDs = "$_queryPath\ProductReleaseIDs"
			$_LicensesPath = "$_InstallRoot\Licenses16"
			$_Integrator = "$_InstallRoot\integration\integrator.exe"
			$activeConfig = Get-RegValue "$_PRIDs" 'ActiveConfiguration'
			$_PRIDs = "$_PRIDs\$activeConfig"
			if (-not $_ProductIds) { if ($_Office15 -eq 0) {
				CONOUT "Error: Office C2R ProductIDs are not detected"
				return _fC2R
				} else { break }
			}
			if (-not (Get-ChildItem -Path "$_LicensesPath\ProPlus*.xrm-ms" -ErrorAction SilentlyContinue)) { if ($_Office15 -eq 0) {
				CONOUT "Error: Office C2R Licenses files are not detected"
				return _fC2R
				} else { break }
			}
			if (-not (Test-Path $_Integrator)) { if ($_Office15 -eq 0) {
				CONOUT "Error: Office C2R Licenses Integrator is not detected"
				return _fC2R
				} else { break }
			}
			if (Get-ChildItem -Path "$_LicensesPath\Word2019VL_KMS_Client_AE*.xrm-ms" -ErrorAction SilentlyContinue) {
				$_LTS19 = 1
				$tag = "2019"
				$ons = " 2019"
			}
			if (Get-ChildItem -Path "$_LicensesPath\Word2021VL_KMS_Client_AE*.xrm-ms" -ErrorAction SilentlyContinue) {
				$_LTS21 = 1
			}
			if (Get-ChildItem -Path "$_LicensesPath\Word2024VL_KMS_Client_AE*.xrm-ms" -ErrorAction SilentlyContinue) {
				$_LTS24 = 1
			}
			if ($winbuild -lt 10240 -and $_LTS21 -eq 1) {
				$tag = "2021"
				$ons = " 2021"
			}
		}
		default { break }
	}

	# Reg15istry
	$_Install15Root = $null
	$_Product15Ids = $null
	$_Con15figP = $null
	$_PR15IDs = $null
	$_OSPP15VBS = $null
	$_Licenses15Path = $null
	$_OSPP15Ready = $null
	$_OSPP15ReadT = "String"
	switch ($_Office15) {
		1 {
			$_queryPath = if (Get-RegValue "$_onat\15.0\ClickToRun" 'InstallPath') { "$_onat\15.0\ClickToRun" } else { "$_owow\15.0\ClickToRun" }
			$_Install15Root = (Get-RegValue "$_queryPath" 'InstallPath') + '\root'
			$_Product15Ids = Get-RegValue "$_queryPath\Configuration" 'ProductReleaseIds'
			$_Con15figP = "$_queryPath\Configuration"
			$_Con15figV = "ProductReleaseIds"
			$_OSPP15Ready = "$_queryPath\Configuration"
			$_PR15IDs = "$_queryPath\ProductReleaseIDs"
			if (-not $_Product15Ids) {
				$_queryPath = if (Get-RegValue "$_onat\15.0\ClickToRun\propertyBag" 'productreleaseid') { "$_onat\15.0\ClickToRun" } else { "$_owow\15.0\ClickToRun" }
				$_Product15Ids = Get-RegValue "$_queryPath\propertyBag" 'productreleaseid'
				$_Con15figP = "$_queryPath\propertyBag"
				$_Con15figV = "productreleaseid"
				$_OSPP15Ready = "$_queryPath"
				$_OSPP15ReadT = "DWord"
			}
			$_Licenses15Path = "$_Install15Root\Licenses16"
			foreach ($__p in "${env:ProgramFiles}", "${env:ProgramW6432}", "${env:ProgramFiles(x86)}") {
				$candidate = Join-Path $__p "Microsoft Office\Office15\OSPP.VBS"
				if (Test-Path $candidate) {
					$_OSPP15VBS = $candidate
					break
				}
			}
			if (-not $_Product15Ids) { if ($_Office16 -eq 0) {
				CONOUT "Error: Office 2013 C2R ProductIDs are not detected"
				return _fC2R
				} else { break }
			}
			if (-not (Get-ChildItem -Path "$_LicensesPath\ProPlus*.xrm-ms" -ErrorAction SilentlyContinue)) { if ($_Office16 -eq 0) {
				CONOUT "Error: Office 2013 C2R Licenses files are not detected"
				return _fC2R
				} else { break }
			}
			if ($winbuild -lt 9200 -and -not $_OSPP15VBS) { if ($_Office16 -eq 0) {
				CONOUT "Error: Office 2013 C2R Licensing tool OSPP.vbs is not detected"
				return _fC2R
				} else { break }
			}
		}
		default { break }
	}

	# CheckC2R
	$_OMSI = 0
	if ($_Office16 -eq 0) {
		foreach ($__p in "$_onat", "$_owow") {
			$chkPath = Get-RegValue "$__p\16.0\Common\InstallRoot" 'Path'
			if ($chkPath -and (Get-ChildItem -Path "$chkPath\*Picker.dll" -ErrorAction SilentlyContinue)) {
				$_OMSI = 1
				break
			}
		}
	}
	if ($_Office15 -eq 0) {
		foreach ($__p in "$_onat", "$_owow") {
			$chkPath = Get-RegValue "$__p\15.0\Common\InstallRoot" 'Path'
			if ($chkPath -and (Get-ChildItem -Path "$chkPath\*Picker.dll" -ErrorAction SilentlyContinue)) {
				$_OMSI = 1
				break
			}
		}
	}
	if ($winbuild -ge 9200) {
		$_spp = "SoftwareLicensingProduct"
		$_sps = "SoftwareLicensingService"
	} else {
		$_spp = "OfficeSoftwareProtectionProduct"
		$_sps = "OfficeSoftwareProtectionService"
	}

	try {
		([WMISEARCHER]"SELECT Version FROM $_sps").Get() | select -Expand Properties -EA 1 | foreach {$_rt = $_.Value}
	} catch {
		CONOUT "Error: $_sps version is not detected"
		CheckWS
		return _fC2R
	}

	# Check and clean licenses
	$_Retail = 0
	$_qr = WmiQuery $_spp "ApplicationID='$_oApp' AND LicenseStatus='1' AND PartialProductKey is not NULL" "Description"
	if ($_qr | Select-String "RETAIL channel","RETAIL\(MAK\) channel","TIMEBASED_SUB channel" -Quiet) {
		$_Retail = 1
	}
	$rancopp = 0
	if ($_Retail -eq 0 -and $_OMSI -eq 0) {
		$rancopp = 1
		if ($OsppHook -ne 0) {
			$osppc = Get-RegValue $OPPk 'Path'
			if ($osppc) { UninstallLicenses ($osppc + "osppc.dll") }
		}
		if ($winbuild -ge 9200) {
			UninstallLicenses "sppc.dll"
		}
	}

	$_SubID = "O365ProPlus,O365Business,O365SmallBusPrem,O365HomePrem,O365EduCloud"
	$_O16O365 = 0
	$_C16Msg = 0
	$_C15Msg = 0
	if ($_Retail -eq 1) {
		$crv_Retail = WmiQuery $_spp "ApplicationID='$_oApp' AND LicenseStatus='1' AND PartialProductKey is not NULL" "LicenseFamily"
	}
	$crv_Volume = WmiQuery $_spp "ApplicationID='$_oApp'" "LicenseFamily"

	if ($_Office16 -eq 0) {
		return C2R15R2V
	} else {
		return C2R16R2V
	}
}

###########################
# R16V
function C2R16R2V
{
	$S24ID = "ProPlus2024,Standard2024".Split(',')
	$S21ID = "ProPlus2021,Standard2021".Split(',')
	$S19ID = "ProPlus2019,Standard2019".Split(',')
	$S16ID = "Mondo,Standard".Split(',')
	$P24ID = "ProjectPro2024,ProjectStd2024".Split(',')
	$P21ID = "ProjectPro2021,ProjectStd2021".Split(',')
	$P19ID = "ProjectPro2019,ProjectStd2019".Split(',')
	$P16ID = "ProjectPro,ProjectStd".Split(',')
	$I24ID = "VisioPro2024,VisioStd2024".Split(',')
	$I21ID = "VisioPro2021,VisioStd2021".Split(',')
	$I19ID = "VisioPro2019,VisioStd2019".Split(',')
	$I16ID = "VisioPro,VisioStd".Split(',')
	$A24ID = "Excel2024,Outlook2024,PowerPoint2024,Word2024".Split(',')
	$A21ID = "Excel2021,Outlook2021,PowerPoint2021,Publisher2021,Word2021".Split(',')
	$A19ID = "Excel2019,Outlook2019,PowerPoint2019,Publisher2019,Word2019".Split(',')
	$A16ID = "Excel,Outlook,PowerPoint,Publisher,Word".Split(',')
	$E24ID = "Access2024,SkypeforBusiness2024".Split(',')
	$E21ID = "Access2021,SkypeforBusiness2021".Split(',')
	$E19ID = "Access2019,SkypeforBusiness2019".Split(',')
	$E16ID = "Access,SkypeforBusiness".Split(',')
	$R24ID = "Professional2024,HomeBusiness2024,HomeStudent2024,Home2024".Split(',')
	$R21ID = "Professional2021,HomeBusiness2021,HomeStudent2021".Split(',')
	$R19ID = "Professional2019,HomeBusiness2019,HomeStudent2019".Split(',')
	$R16ID = ("Professional,HomeBusiness,HomeStudent," + $_SubID).Split(',')
	$V24ID = $S24ID + $A24ID + $E24ID + $P24ID + $I24ID
	$V21ID = $S21ID + $A21ID + $E21ID + $P21ID + $I21ID
	$V19ID = $S19ID + $A19ID + $E19ID + $P19ID + $I19ID
	$V16ID = $S16ID + $A16ID + $E16ID + $P16ID + $I16ID
	$RetID = $R24ID + $V24ID + $R21ID + $V21ID + $R19ID + $V19ID + $R16ID + $V16ID
	$Suites = "ProPlus," + ($S16ID + $R16ID + $S19ID + $R19ID + $S21ID + $R21ID + $S24ID + $R24ID -join ',')
	$PrjSKU = $P16ID + $P19ID + $P21ID + $P24ID
	$VisSKU = $I16ID + $I19ID + $I21ID + $I24ID
	$UniqID = $RetID + "ProPlus,OneNote,Publisher2024,Home,Home2019,Home2021".Split(',')

	$crv_ProductIds = $_ProductIds

	# Initialize all products to 0
	$cn16IDs = @{}
	foreach ($a in $UniqID) {
		$cn16IDs[$a] = 0
	}

	# Mark Retail products as 1
	foreach ($a in ($RetID + "OneNote")) {
		if ($crv_ProductIds | Select-String "${a}Retail" -Quiet) {
			$cn16IDs[$a] = 1
		}
	}

	# Office 24 Volume
	if ($_LTS24 -eq 0) {
		foreach ($a in $V24ID) {
			$cn16IDs[$a] = 0
		}
	} else {
		foreach ($a in $V24ID) {
			if ($crv_ProductIds | Select-String "${a}Volume" -Quiet) {
				if ($crv_Volume | Select-String "Office24${a}VL_KMS_Client" -Quiet) {
					$cn16IDs[$a] = 0
				} else {
					$cn16IDs[$a] = 1
				}
			}
		}
	}

	# Office 21 Volume
	if ($_LTS21 -eq 0) {
		foreach ($a in $V21ID) {
			$cn16IDs[$a] = 0
		}
	} else {
		foreach ($a in $V21ID) {
			if ($crv_ProductIds | Select-String "${a}Volume" -Quiet) {
				if ($crv_Volume | Select-String "Office21${a}VL_KMS_Client" -Quiet) {
					$cn16IDs[$a] = 0
				} else {
					$cn16IDs[$a] = 1
				}
			}
		}
	}

	# Office 19 Volume
	if ($_LTS19 -eq 0) {
		foreach ($a in $V19ID) {
			$cn16IDs[$a] = 0
		}
	} else {
		foreach ($a in $V19ID) {
			if ($crv_ProductIds | Select-String "${a}Volume" -Quiet) {
				if ($crv_Volume | Select-String "Office19${a}VL_KMS_Client" -Quiet) {
					$cn16IDs[$a] = 0
				} else {
					$cn16IDs[$a] = 1
				}
			}
		}
	}

	# Office 16 Volume
	foreach ($a in $V16ID + "OneNote") {
		if ($crv_ProductIds | Select-String "${a}Volume" -Quiet) {
			if ($crv_Volume | Select-String "Office16${a}VL_KMS_Client" -Quiet) {
				$cn16IDs[$a] = 0
			} else {
				$cn16IDs[$a] = 1
			}
		}
	}

	# Check ProPlus Retail/Volume
	if ((Test-Path "Registry::$_PRIDs\ProPlusRetail.16") -or (Test-Path "Registry::$_PRIDs\ProPlusVolume.16")) {
		if ($crv_Volume | Select-String "Office16ProPlusVL_KMS_Client" -Quiet) {
			$cn16IDs['ProPlus'] = 0
		} else {
			$cn16IDs['ProPlus'] = 1
		}
	}

	if ($_Retail -eq 1) {
		foreach ($a in ($RetID + "OneNote")) {
			if ($crv_ProductIds | Select-String "${a}Retail" -Quiet) {
				$patterns16 = @(
					"Office16${a}R_Retail",
					"Office16${a}R_OEM",
					"Office16${a}R_Sub",
					"Office16${a}R_PIN",
					"Office16${a}E5R_",
					"Office16${a}EDUR_",
					"Office16${a}MSDNR_",
					"Office16${a}O365R_",
					"Office16${a}CO365R_",
					"Office16${a}VL_MAK",
					"Office16${a}XC2RVL_MAKC2R"
				)
				$patterns19 = @(
					"Office19${a}R_Retail",
					"Office19${a}R_OEM",
					"Office19${a}MSDNR_",
					"Office19${a}VL_MAK"
				)
				$patterns21 = @(
					"Office21${a}R_Retail",
					"Office21${a}R_OEM",
					"Office21${a}MSDNR_",
					"Office21${a}VL_MAK"
				)
				$patterns24 = @(
					"Office24${a}R_Retail",
					"Office24${a}R_OEM",
					"Office24${a}MSDNR_",
					"Office24${a}VL_MAK"
				)
				$allPatterns = $patterns16 + $patterns19 + $patterns21 + $patterns24
				foreach ($pattern in $allPatterns) {
					if ($crv_Retail | Select-String $pattern -Quiet) {
						$cn16IDs[$a] = 0
						switch -Regex ($pattern) {
							{$_ -like "Office16*"} { $c2r_off[16] = 1 }
							{$_ -like "Office19*"} { $c2r_off[19] = 1 }
							{$_ -like "Office21*"} { $c2r_off[21] = 1 }
							{$_ -like "Office24*"} { $c2r_off[24] = 1 }
						}
					}
				}
			}
		}

		# Special handling for ProPlus Retail
		if (Test-Path "Registry::$_PRIDs\ProPlusRetail.16") {
			$proPlusPatterns = @(
				"Office16ProPlusR_Retail",
				"Office16ProPlusR_OEM",
				"Office16ProPlusMSDNR_",
				"Office16ProPlusVL_MAK"
			)
			foreach ($pattern in $proPlusPatterns) {
				if ($crv_Retail | Select-String $pattern -Quiet) {
					$cn16IDs['ProPlus'] = 0
					$c2r_off[16] = 1
				}
			}
		}
	}

	# Check Office16 Mondo VL_KMS_Client for O365 activation
	if ($crv_Volume | Select-String 'Office16MondoVL_KMS_Client' -Quiet) {
		$_qr = WmiQuery $spp "ApplicationID='$_oApp' AND LicenseFamily like 'Office16O365%'" "LicenseFamily"
		if ($_qr -match 'O365') {
			foreach ($a in ($_SubID -split ',')) { $cn16IDs[$a] = 0 }
		}
	}

	# vNext activation for sub-products
	if ($sub_o365 -eq 1) {
		foreach ($a in $Suites) { $cn16IDs[$a] = 0 }
		CONOUT "`nMicrosoft Office is activated with a vNext license."
	}
	if ($sub_proj -eq 1) {
		foreach ($a in $PrjSKU) { $cn16IDs[$a] = 0 }
		CONOUT "`nMicrosoft Project is activated with a vNext license."
	}
	if ($sub_vsio -eq 1) {
		foreach ($a in $VisSKU) { $cn16IDs[$a] = 0 }
		CONOUT "`nMicrosoft Visio is activated with a vNext license."
	}

	# Set C16 message flag if any product is still 1
	foreach ($a in ($RetID + "ProPlus","OneNote")) {
		if ($cn16IDs[$a] -eq 1) {
			$_C16Msg = 1
			break
		}
	}
	if ($_C16Msg -eq 1) {
		CONOUT "`nConverting Office C2R Retail-to-Volume:"
	} else {
		return endRV16
	}

	$_arr = @()
	Get-ChildItem -Path "$_LicensesPath" -Filter "client-issuance-*.xrm-ms" | ForEach-Object { $_arr += $_.FullName }
	. InstallLicensePre $_sps
	InstallLicenseArr $_arr
	$null = InstallLicenseFile "$_LicensesPath\pkeyconfig-office.xrm-ms"

	# Initialize flags
	$_jump = 0
	$_DidO365 = 0
	# Handle Mondo
	if ($_Mondo -eq 1) {
		InsLic "Mondo"
	}
	# Handle O365 suites
	$O365Suites = @(
		@{Name="_O365ProPlus"; Key="DRNV7-VGMM2-B3G9T-4BF84-VMFTK"},
		@{Name="_O365Business"; Key="NCHRJ-3VPGW-X73DM-6B36K-3RQ6B"},
		@{Name="_O365SmallBusPrem"; Key="3FBRX-NFP7C-6JWVK-F2YGK-H499R"},
		@{Name="_O365HomePrem"; Key="9FNY8-PWWTY-8RY4F-GJMTV-KHGM9"},
		@{Name="_O365EduCloud"; Key="8843N-BCXXD-Q84H8-R4Q37-T3CPT"}
	)
	foreach ($suite in $O365Suites) {
		if ($cn16IDs[$suite.Name] -eq 1 -and $_DidO365 -eq 0) {
			$_DidO365 = 1
			CONOUT "$($suite.Name) 2016 Suite <> Mondo 2016 Licenses"
			InsLic $suite.Name $suite.Key
			if ($Mondo -eq 0) { InsLic "Mondo" }
			break
		}
	}
	if ($_DidO365 -eq 1) {
		$_jump = 1
		$_O16O365 = 1
	}
	# If only Mondo is left and no O365 suite installed
	if ($Mondo -eq 1 -and $_DidO365 -eq 0) {
		CONOUT "Mondo 2016 Suite"
		InsLic $O365Suites[0].Name $O365Suites[0].Key
		return endRV16
	}

	foreach ($a in ($P16ID + "," + $I16ID -split ',')) {
		if ($cn16IDs["${a}2024"] -eq 1) {
			CONOUT "$a 2024 SKU"
			InsLic "${a}2024"
			continue
		}
		if ($cn16IDs["${a}2021"] -eq 1) {
			CONOUT "$a 2021 SKU"
			InsLic "${a}2021"
			continue
		}
		if ($cn16IDs["${a}2019"] -eq 1) {
			CONOUT "$a 2019 SKU -> $a$_ons Licenses"
			InsLic "$a$_tag"
			continue
		}
		if ($cn16IDs[$a] -eq 1) {
			CONOUT "$a 2016 SKU -> $a$_ons Licenses"
			InsLic "$a$_tag"
		}
	}
	if ($_jump -eq 1) { return endRV16 }

	foreach ($a in "ProPlus") {
		if ($cn16IDs["${a}2024"] -eq 1) {
			$_jump = 1
			CONOUT "$a 2024 Suite"
			InsLic "${a}2024"
			continue
		}
		if ($cn16IDs["${a}2021"] -eq 1) {
			$_jump = 1
			CONOUT "$a 2021 Suite"
			InsLic "${a}2021"
			continue
		}
		if ($cn16IDs["${a}2019"] -eq 1) {
			$_jump = 1
			CONOUT "$a 2019 Suite -> $a$_ons Licenses"
			InsLic "$a$_tag"
			continue
		}
		if ($cn16IDs[$a] -eq 1) {
			$_jump = 1
			CONOUT "$a 2016 Suite -> $a$_ons Licenses"
			InsLic "$a$_tag"
		}
	}
	if ($_jump -eq 1) { return endRV16 }

	foreach ($a in "Professional") {
		if ($cn16IDs["${a}2024"] -eq 1) {
			$_jump = 1
			CONOUT "$a 2024 Suite -> ProPlus 2024 Licenses"
			InsLic "${a}2024"
			continue
		}
		if ($cn16IDs["${a}2021"] -eq 1) {
			$_jump = 1
			CONOUT "$a 2021 Suite -> ProPlus 2021 Licenses"
			InsLic "${a}2021"
			continue
		}
		if ($cn16IDs["${a}2019"] -eq 1) {
			$_jump = 1
			CONOUT "$a 2019 Suite -> ProPlus$_ons Licenses"
			InsLic "$a$_tag"
			continue
		}
		if ($cn16IDs[$a] -eq 1) {
			$_jump = 1
			CONOUT "$a 2016 Suite -> ProPlus$_ons Licenses"
			InsLic "$a$_tag"
		}
	}
	if ($_jump -eq 1) { return endRV16 }

	foreach ($a in "SkypeforBusiness","Access") {
		if ($cn16IDs["${a}2024"] -eq 1) {
			CONOUT "$a 2024 App"
			InsLic "${a}2024"
			continue
		}
		if ($cn16IDs["${a}2021"] -eq 1) {
			CONOUT "$a 2021 App"
			InsLic "${a}2021"
			continue
		}
		if ($cn16IDs["${a}2019"] -eq 1) {
			CONOUT "$a 2019 App -> $a$_ons Licenses"
			InsLic "$a$_tag"
			continue
		}
		if ($cn16IDs[$a] -eq 1) {
			CONOUT "$a 2016 App -> $a$_ons Licenses"
			InsLic "$a$_tag"
		}
	}

	foreach ($a in "Standard") {
		if ($cn16IDs["${a}2024"] -eq 1) {
			$_jump = 1
			CONOUT "$a 2024 Suite"
			InsLic "${a}2024"
			continue
		}
		if ($cn16IDs["${a}2021"] -eq 1) {
			$_jump = 1
			CONOUT "$a 2021 Suite"
			InsLic "${a}2021"
			continue
		}
		if ($cn16IDs["${a}2019"] -eq 1) {
			$_jump = 1
			CONOUT "$a 2019 Suite -> $a$_ons Licenses"
			InsLic "$a$_tag"
			continue
		}
		if ($cn16IDs[$a] -eq 1) {
			$_jump = 1
			CONOUT "$a 2016 Suite -> $a$_ons Licenses"
			InsLic "$a$_tag"
		}
	}
	if ($_jump -eq 1) { return endRV16 }

	foreach ($a in "HomeBusiness,HomeStudent,Home".Split(',')) {
		if ($cn16IDs["${a}2024"] -eq 1) {
			$_jump = 1
			CONOUT "$a 2024 Suite -> Standard 2024 Licenses"
			InsLic "${a}2024"
			continue
		}
		if ($cn16IDs["${a}2021"] -eq 1) {
			$_jump = 1
			CONOUT "$a 2021 Suite -> Standard 2021 Licenses"
			InsLic "${a}2021"
			continue
		}
		if ($cn16IDs["${a}2019"] -eq 1) {
			$_jump = 1
			CONOUT "$a 2019 Suite -> Standard$_ons Licenses"
			InsLic "$a$_tag"
			continue
		}
		if ($cn16IDs[$a] -eq 1) {
			$_jump = 1
			CONOUT "$a 2016 Suite -> Standard$_ons Licenses"
			InsLic "$a$_tag"
		}
	}
	if ($_jump -eq 1) { return endRV16 }

	foreach ($a in $_A16ID) {
		if ($cn16IDs["${a}2024"] -eq 1) {
			CONOUT "$a 2024 App"
			InsLic "${a}2024"
			continue
		}
		if ($cn16IDs["${a}2021"] -eq 1) {
			CONOUT "$a 2021 App"
			InsLic "${a}2021"
			continue
		}
		if ($cn16IDs["${a}2019"] -eq 1) {
			CONOUT "$a 2019 App -> $a$_ons Licenses"
			InsLic "$a$_tag"
			continue
		}
		if ($cn16IDs[$a] -eq 1) {
			CONOUT "$a 2016 App -> $a$_ons Licenses"
			InsLic "$a$_tag"
		}
	}
	foreach ($a in "OneNote") {
		if ($cn16IDs[$a] -eq 1) {
			CONOUT "$a 2016 App"
			InsLic "$a$_tag"
		}
	}
	return endRV16
}

###########################
function endRV16
{
	$doPublisher = 0
	if ($_DidO365 -eq 0) { foreach ($a in ("ProPlus2024,Professional2024,Standard2024" -split ',')) {
		if ($cn16IDs[$a] -eq 1) {
			$doPublisher = 1
			break
		}
	} }
	if ($doPublisher -eq 1) {
		foreach ($a in "Publisher") {
			if ($cn16IDs["${a}2021"] -eq 1) {
				CONOUT "$a 2021 App"
				InsLic "${a}2021"
				continue
			}
			if ($cn16IDs["${a}2019"] -eq 1) {
				CONOUT "$a 2019 App -> $a$_ons Licenses"
				InsLic "$a$_tag"
				continue
			}
			if ($cn16IDs[$a] -eq 1) {
				CONOUT "$a 2016 App -> $a$_ons Licenses"
				InsLic "$a$_tag"
			}
		}
	}
	if ($_Office15 -eq 0) {
		return GVLKC2R
	} else {
		return C2R15R2V
	}
}

###########################
# R15V
function C2R15R2V
{
	$S15ID = "Mondo,Standard".Split(',')
	$P15ID = "ProjectPro,ProjectStd".Split(',')
	$I15ID = "VisioPro,VisioStd".Split(',')
	$A15ID = "Excel,Groove,InfoPath,OneNote,Outlook,PowerPoint,Publisher,Word".Split(',')
	$E15ID = "Access,Lync".Split(',')
	$V15ID = $S15ID + $A15ID + $E15ID + $P15ID + $I15ID
	$R15ID = $V15ID + ("SPD,Professional,HomeBusiness,HomeStudent," + $_SubID).Split(',')

	# Initialize Hashtable with flags
	$cn15IDs = @{}
	foreach ($a in ($R15ID + "ProPlus")) {
		$cn15IDs[$a] = 0
	}

	$crvProduct15s = $_Product15Ids

	# Default Retail products as 1
	foreach ($a in $R15ID) {
		if ($crvProduct15s -match "${a}Retail") {
			$cn15IDs[$a] = 1
		}
	}

	### ---- Volume Checks ---- ###
	foreach ($a in $V15ID) {
		if ($crvProduct15s -match "${a}Volume") {
			if ($crv_Volume -match "Office${a}VL_KMS_Client") {
				$cn15IDs[$a] = 0
			} else {
				$cn15IDs[$a] = 1
			}
		}
	}
	if ((Test-Path "Registry::$_PR15IDs\Active\ProPlusRetail\x-none") -or (Test-Path "Registry::$_PR15IDs\Active\ProPlusVolume\x-none")) {
		if ($crv_Volume -match "OfficeProPlusVL_KMS_Client") {
			$cn15IDs['ProPlus'] = 0
		} else {
			$cn15IDs['ProPlus'] = 1
		}
	}

	### ---- Retail Checks ---- ###
	if ($_Retail -eq 1) {
		foreach ($a in $R15ID) {
			if ($crvProduct15s -match "${a}Retail") {
				$patterns15 = @(
					"Office${a}R_Retail",
					"Office${a}R_OEM",
					"Office${a}R_Sub",
					"Office${a}R_PIN",
					"Office${a}MSDNR_",
					"Office${a}O365R_",
					"Office${a}CO365R_",
					"Office${a}VL_MAK"
				)

				foreach ($pat in $patterns15) {
					if ($crv_Retail -match $pat) {
						$cn15IDs[$a] = 0
						$c2r_off[15] = 1
					}
				}
			}
		}
		if (Test-Path "Registry::$_PR15IDs\Active\ProPlusRetail\x-none") {
			$proPlusPatterns = @(
				"OfficeProPlusR_Retail",
				"OfficeProPlusR_OEM",
				"OfficeProPlusMSDNR_",
				"OfficeProPlusVL_MAK"
			)
			foreach ($pat in $proPlusPatterns) {
				if ($crv_Retail -match $pat) {
					$cn15IDs['ProPlus'] = 0
					$c2r_off[15] = 1
				}
			}
		}
	}

	### ---- C2R Retail-to-Volume check ---- ###
	if ($crv_Volume -match 'OfficeMondoVL_KMS_Client') {
		$_qr = WmiQuery $spp "ApplicationID='$_oApp' AND LicenseFamily like 'OfficeO365%'" "LicenseFamily"
		if ($_qr -match 'O365') {
			foreach ($a in ($_SubID -split ',')) { $cn15IDs[$a] = 0 }
		}
	}

	# Set C15 message flag if any product is still 1
	foreach ($a in ($R15ID + "ProPlus")) {
		if ($cn15IDs[$a] -eq 1) {
			$_C15Msg = 1
			break
		}
	}
	if ($_C15Msg -eq 1 -and $_C16Msg -eq 0) {
		CONOUT "`nConverting Office C2R Retail-to-Volume:"
	} elseif ($_C15Msg -eq 0) {
		return endRV15
	}

	$_arr = @()
	Get-ChildItem -Path "$_Licenses15Path" -Filter "client-issuance-*.xrm-ms" | ForEach-Object { $_arr += $_.FullName }
	. InstallLicensePre $_sps
	InstallLicenseArr $_arr
	$null = InstallLicenseFile "$_Licenses15Path\pkeyconfig-office.xrm-ms"

	$_jump = 0
	$_DidO365 = 0
	if ($_Mondo -eq 1) {
		Ins15Lic "Mondo"
	}
	$O365Suites = @(
		@{Name="O365ProPlus"; Key="DRNV7-VGMM2-B3G9T-4BF84-VMFTK"},
		@{Name="O365SmallBusPrem"; Key="3FBRX-NFP7C-6JWVK-F2YGK-H499R"},
		@{Name="O365HomePrem"; Key="9FNY8-PWWTY-8RY4F-GJMTV-KHGM9"},
		@{Name="O365Business"; Key="NCHRJ-3VPGW-X73DM-6B36K-3RQ6B"}
	)
	if ($_O16O365 -eq 0) {foreach ($suite in $O365Suites) {
		if ($cn15IDs[$suite.Name] -eq 1 -and $_DidO365 -eq 0) {
			$_DidO365 = 1
			CONOUT "$($suite.Name) 2013 Suite <> Mondo 2013 Licenses"
			Ins15Lic $suite.Name $suite.Key
			if ($Mondo -eq 0) { Ins15Lic "Mondo" }
			break
		}
	} }
	if ($_DidO365 -eq 1) {
		$_jump = 1
	}
	if ($Mondo -eq 1 -and $_DidO365 -eq 0 -and $_O16O365 -eq 0) {
		CONOUT "Mondo 2013 Suite"
		Ins15Lic $O365Suites[0].Name $O365Suites[0].Key
		return endRV15
	}
	foreach ($a in ($P15ID + "," + $I15ID -split ',')) {
		if ($cn15IDs[$a] -eq 1) {
			CONOUT "$a 2013 SKU"
			Ins15Lic "$a"
		}
	}
	if ($Mondo -eq 0 -and $_DidO365 -eq 0) { foreach ($a in "SPD") {
		if ($cn15IDs[$a] -eq 1) {
			$_jump = 1
			CONOUT "SharePoint Designer 2013 App -> Mondo 2013 Licenses"
			Ins15Lic "Mondo"
		}
	} }
	if ($_jump -eq 1) { return endRV15 }
	foreach ($a in "ProPlus") {
		if ($cn15IDs[$a] -eq 1) {
			$_jump = 1
			CONOUT "$a 2013 Suite"
			Ins15Lic "$a"
		}
	}
	if ($_jump -eq 1) { return endRV15 }
	foreach ($a in "Professional") {
		if ($cn15IDs[$a] -eq 1) {
			$_jump = 1
			CONOUT "$a 2013 Suite -> ProPlus 2013 Licenses"
			Ins15Lic "ProPlus"
		}
	}
	if ($_jump -eq 1) { return endRV15 }
	foreach ($a in "Lync") {
		if ($cn15IDs[$a] -eq 1) {
			CONOUT "SkypeforBusiness 2015 App"
			Ins15Lic "$a"
		}
	}
	foreach ($a in "Access") {
		if ($cn15IDs[$a] -eq 1) {
			CONOUT "$a 2013 App"
			Ins15Lic "$a"
		}
	}
	foreach ($a in "Standard") {
		if ($cn15IDs[$a] -eq 1) {
			$_jump = 1
			CONOUT "$a 2013 Suite"
			Ins15Lic "$a"
		}
	}
	if ($_jump -eq 1) { return endRV15 }
	foreach ($a in "HomeBusiness,HomeStudent".Split(',')) {
		if ($cn15IDs[$a] -eq 1) {
			$_jump = 1
			CONOUT "$a 2013 Suite -> Standard 2013 Licenses"
			Ins15Lic "Standard"
		}
	}
	if ($_jump -eq 1) { return endRV15 }
	foreach ($a in $_A15ID) {
		if ($cn15IDs[$a] -eq 1) {
			CONOUT "$a 2013 App"
			Ins15Lic "$a"
		}
	}

	return endRV15
}

###########################
function endRV15
{
	return GVLKC2R
}

###########################
function InsLic($inPrd, $inKey = $null)
{
	$_ID = "$inPrd`Volume"
	$_patt = "${inPrd}VL_"
	$_pkey = $null
	$_kpey = $null
	if ($null -ne $inKey) {
		$_ID = "$inPrd`Retail"
		$_patt = "${inPrd}R_"
		$_pkey = "PidKey=$inKey"
		$_kpey = $inKey
	}

	Del-RegValue "$_Config" "$_ID.OSPPReady"

	& "$_Integrator" /I /License "PRIDName=$_ID.16" $_pkey "PackageGUID=$_GUID" "PackageRoot=$_InstallRoot" >$null

	$fallback = 0
	$_qr = WmiQuery $_spp "ApplicationID='$_oApp'" "LicenseFamily"
	if (-not ($_qr -match $_patt)) {
		$fallback = 1
	}

	if ($fallback -eq 1) {
		$_lsfs = @()
		Get-ChildItem -Path "$_LicensesPath" -Filter "$_patt*.xrm-ms" | ForEach-Object { $_lsfs += $_.FullName }
		if ($_kpey) {
			$patterns = @(
				"${inPrd}DemoR*.xrm-ms",
				"${inPrd}E5R*.xrm-ms",
				"${inPrd}EDUR*.xrm-ms",
				"${inPrd}MSDNR*.xrm-ms",
				"${inPrd}O365R*.xrm-ms",
				"${inPrd}CO365R*.xrm-ms"
			)
			foreach ($pattern in $patterns) {
				Get-ChildItem -Path "$_LicensesPath" -Filter $pattern | ForEach-Object { $_lsfs += $_.FullName }
			}
		}
		. InstallLicensePre $_sps; InstallLicenseArr $_lsfs
		if ($_kpey) {
			$_rt = WmiSLS $_sps "InstallProductKey" @($_kpey)
		}
	}

	Set-RegValue $_Config "$_ID.OSPPReady" 'String' 1
	$prodIds = Get-RegValue "$_Config" 'ProductReleaseIds'
	if (-not ($prodIds -match $_ID)) {
		$newValue = if ($prodIds) { "$prodIds,$_ID" } else { $_ID }
		Set-RegValue $_Config 'ProductReleaseIds' 'String' $newValue
	}
}

###########################
function Ins15Lic($inPrd, $inKey = $null)
{
	$_ID = "$inPrd`Volume"
	$_patt = "${inPrd}VL_"
	$_kpey = $null
	if ($null -ne $inKey) {
		$_ID = "$inPrd`Retail"
		$_patt = "${inPrd}R_"
		$_kpey = $inKey
	}

	Del-RegValue "$_OSPP15Ready" "$_ID.OSPPReady"

	$_lsfs = @()
	Get-ChildItem -Path "$_Licenses15Path" -Filter "$_patt*.xrm-ms" | ForEach-Object { $_lsfs += $_.FullName }
	. InstallLicensePre $_sps; InstallLicenseArr $_lsfs
	if ($_kpey) {
		$_rt = WmiSLS $_sps "InstallProductKey" @($_kpey)
	}

	Set-RegValue $_OSPP15Ready "$_ID.OSPPReady" $_OSPP15ReadT 1
	$prodIds = Get-RegValue "$_Con15figP" "$_Con15figV"
	if (-not ($prodIds -match $_ID)) {
		$newValue = if ($prodIds) { "$prodIds,$_ID" } else { $_ID }
		Set-RegValue $_Con15figP $_Con15figV 'String' $newValue
	}
}

###########################
function GVLKC2R
{
	$_CtRMsg = 0
	if ($_C16Msg -eq 1 -or $_C15Msg -eq 1) {
		$_CtRMsg = 1
	}
	if ($_Office16 -eq 1) {
		$cn16IDs.Clear()
		$cn16IDs = $null
		foreach ($__A in 19,21,24) {
			. officeLoc $__A
		}
	}
	if ($_Office15 -eq 1) {
		$cn15IDs.Clear()
		$cn15IDs = $null
	}
	if ($winbuild -ge 9200) {
		$_rt = WmiSLS $_sps "RefreshLicenseStatus"
	}
	if ((Test-Path "$SysPath\spp\store_test\2.0\tokens.dat" -PathType Leaf) -and $rancopp -eq 1 -and $_CtRMsg -eq 1) {
		. InstallLicensePre $_sps; $ERRORCODE = ReinstallLicenses
		if ($ERRORCODE -ne 0) { . InstallLicensePre $_sps; $null = ReinstallLicenses }
	}
	return sppoff
}

# =========================
# KMS Client Keys
# =========================

$KeysDB = @{
	# Windows 11 [Ni]
	"59eb965c-9150-42b7-a0ec-22151b9897c5" = "KBN8V-HFGQ4-MGXVD-347P6-PDQGT"   # IoT Enterprise LTSC
	# Windows 11 [Co]
	"ca7df2e3-5ea0-47b8-9ac1-b1be4d8edd69" = "37D7F-N49CB-WQR8W-TBJ73-FM8RX"   # SE {Cloud}
	"d30136fc-cb4b-416e-a23d-87207abc44a9" = "6XN7V-PCBDC-BDBRH-8DQY7-G6R44"   # SE N {Cloud N}
	# Windows 10 [RS5]
	"32d2fab3-e4a8-42c2-923b-4bf4fd13e6ee" = "M7XTQ-FN8P6-TTKYV-9D4CC-J462D"   # Enterprise LTSC 2019
	"7103a333-b8c8-49cc-93ce-d37c09687f92" = "92NFX-8DJQP-P6BBQ-THF9C-7CG2H"   # Enterprise LTSC 2019 N
	"ec868e65-fadf-4759-b23e-93fe37f2cc29" = "CPWHC-NT2C7-VYW78-DHDB2-PG3GK"   # Enterprise for Virtual Desktops
	"0df4f814-3f57-4b8b-9a9d-fddadcd69fac" = "NBTWJ-3DR69-3C4V8-C26MC-GQ9M6"   # Lean
	# Windows 10 [RS3]
	"82bbc092-bc50-4e16-8e18-b74fc486aec3" = "NRG8B-VKK3Q-CXVCJ-9G2XF-6Q84J"   # Pro Workstation
	"4b1571d3-bafb-4b40-8087-a961be2caf65" = "9FNHH-K3HBT-3W4TD-6383H-6XYWF"   # Pro Workstation N
	"e4db50ea-bda1-4566-b047-0ca50abc6f07" = "7NBT4-WGBQX-MP4H7-QXFF8-YP3KX"   # Enterprise Remote Server
	# Windows 10 [RS2]
	"e0b2d383-d112-413f-8a80-97f373a5820c" = "YYVX9-NTFWV-6MDM3-9PT4T-4M68B"   # Enterprise G
	"e38454fb-41a4-4f59-a5dc-25080e354730" = "44RPN-FTY23-9VTTB-MP9BX-T84FV"   # Enterprise G N
	# Windows 10 [RS1]
	"2d5a5a60-3040-48bf-beb0-fcd770c20ce0" = "DCPHK-NFMTC-H88MJ-PFHPY-QJ4BJ"   # Enterprise 2016 LTSB
	"9f776d83-7156-45b2-8a5c-359b9c9f22a3" = "QFFDN-GRT3P-VKWWX-X7T3R-8B639"   # Enterprise 2016 LTSB N
	# Windows 10 [TH]
	"3f1afc82-f8ac-4f6c-8005-1d233e606eee" = "6TP4R-GNPTD-KYYHQ-7B7DP-J447Y"   # Pro Education
	"5300b18c-2e33-4dc2-8291-47ffcec746dd" = "YVWGF-BXNMC-HTQYQ-CPQ99-66QFC"   # Pro Education N
	"58e97c99-f377-4ef1-81d5-4ad5522b5fd8" = "TX9XD-98N7V-6WMQ6-BX7FG-H8Q99"   # Home
	"7b9e1751-a8da-4f75-9560-5fadfe3d8e38" = "3KHY7-WNT83-DGQKR-F7HPR-844BM"   # Home N
	"cd918a57-a41b-4c82-8dce-1a538e221a83" = "7HNRX-D7KGG-3K4RQ-4WPJ4-YTDFH"   # Home Single Language
	"a9107544-f4a0-4053-a96a-1479abdef912" = "PVMJN-6DFY6-9CCP6-7BKTT-D3WVR"   # Home China
	"2de67392-b7a7-462a-b1ca-108dd189f588" = "W269N-WFGWX-YVC9B-4J6C9-T83GX"   # Pro
	"a80b5abf-76ad-428b-b05d-a47d2dffeebf" = "MH37W-N47XK-V7XM9-C7227-GCQG9"   # Pro N
	"e0c42288-980c-4788-a014-c080d2e1926e" = "NW6C2-QMPVW-D7KKK-3GKT6-VCFB2"   # Education
	"3c102355-d027-42c6-ad23-2e7ef8a02585" = "2WH4N-8QGBV-H22JP-CT43Q-MDWWJ"   # Education N
	"73111121-5638-40f6-bc11-f1d7b0d64300" = "NPPR9-FWDCX-D2C8J-H872K-2YT43"   # Enterprise
	"e272e3e2-732f-4c65-a8f0-484747d0d947" = "DPH2V-TTNVB-4X9Q3-TJR4H-KHJW4"   # Enterprise N
	"7b51a46c-0c04-4e8f-9af4-8496cca90d5e" = "WNMTR-4C88C-JK8YV-HQ7T2-76DF9"   # Enterprise 2015 LTSB
	"87b838b7-41b6-4590-8318-5797951d8529" = "2F77B-TNFGY-69QQF-B8YKP-D69TJ"   # Enterprise 2015 LTSB N

	# Windows Server 2025 [Ge]
	"7dc26449-db21-4e09-ba37-28f2958506a6" = "TVRH6-WHNXV-R9WG3-9XRFY-MY832"   # Standard
	"c052f164-cdf6-409a-a0cb-853ba0f0f55a" = "D764K-2NDRG-47T6Q-P8T8W-YP6DF"   # Datacenter
	"45b5aff2-60a0-42f2-bc4b-ec6e5f7b527e" = "FCNV3-279Q9-BQB46-FTKXX-9HPRH"   # Azure Core
	"c2e946d1-cfa2-4523-8c87-30bc696ee584" = "XGN3F-F394H-FD2MY-PP6FD-8MCRC"   # Turbine
	# Windows Server 2022 [Fe]
	"9bd77860-9b31-4b7b-96ad-2564017315bf" = "VDYBN-27WPP-V4HQT-9VMD4-VMK7H"   # Standard
	"ef6cfc9f-8c5d-44ac-9aad-de6a2ea0ae03" = "WX4NM-KYWYW-QJJR4-XV3QB-6VM33"   # Datacenter
	"8c8f0ad3-9a43-4e05-b840-93b8d1475cbc" = "6N379-GGTMK-23C6M-XVVTC-CKFRQ"   # Azure Core
	"f5e9429c-f50b-4b98-b15c-ef92eb5cff39" = "67KN8-4FYJW-2487Q-MQ2J7-4C4RG"   # Standard ACor
	"39e69c41-42b4-4a0a-abad-8e3c10a797cc" = "QFND9-D3Y9C-J3KKY-6RPVP-2DPYV"   # Datacenter ACor
	# Windows Server 2019 [RS5]
	"de32eafd-aaee-4662-9444-c1befb41bde2" = "N69G4-B89J2-4G8F4-WWYCC-J464C"   # Standard
	"34e1ae55-27f8-4950-8877-7a03be5fb181" = "WMDGN-G9PQG-XVVXX-R3X43-63DFG"   # Datacenter
	"a99cc1f0-7719-4306-9645-294102fbff95" = "FDNH6-VW9RW-BXPJ7-4XTYG-239TB"   # Azure Core
	"73e3957c-fc0c-400d-9184-5f7b6f2eb409" = "N2KJX-J94YW-TQVFB-DG9YT-724CC"   # Standard ACor
	"90c362e5-0da1-4bfd-b53b-b87d309ade43" = "6NMRW-2C8FM-D24W7-TQWMY-CWH2D"   # Datacenter ACor
	"034d3cbb-5d4b-4245-b3f8-f84571314078" = "WVDHN-86M7X-466P6-VHXV7-YY726"   # Essentials
	"8de8eb62-bbe0-40ac-ac17-f75595071ea3" = "GRFBW-QNDC4-6QBHG-CCK3B-2PR88"   # ServerARM64
	"19b5e0fb-4431-46bc-bac1-2f1873e4ae73" = "NTBV8-9K7Q8-V27C6-M2BTV-KHMXV"   # Datacenter Azure - Turbine
	# Windows Server 2016 [RS4]
	"43d9af6e-5e86-4be8-a797-d072a046896c" = "K9FYF-G6NCK-73M32-XMVPY-F9DRR"   # ServerARM64
	# Windows Server 2016 [RS3]
	"61c5ef22-f14f-4553-a824-c4b31e84b100" = "PTXN8-JFHJM-4WC78-MPCBR-9W4KR"   # Standard ACor
	"e49c08e7-da82-42f8-bde2-b570fbcae76c" = "2HXDN-KRXHB-GPYC7-YCKFJ-7FVDG"   # Datacenter ACor
	# Windows Server 2016 [RS1]
	"8c1c5410-9f39-4805-8c9d-63a07706358f" = "WC2BQ-8NRM3-FDDYY-2BFGV-KHKQY"   # Standard
	"21c56779-b449-4d20-adfc-eece0e1ad74b" = "CB7KF-BWN84-R7R2Y-793K2-8XDDG"   # Datacenter
	"3dbf341b-5f6c-4fa7-b936-699dce9e263f" = "VP34G-4NPPG-79JTQ-864T4-R3MQX"   # Azure Core
	"2b5a1b0f-a5ab-4c54-ac2f-a6d94824a283" = "JCKRF-N37P4-C2D82-9YXRT-4M63B"   # Essentials
	"7b4433f4-b1e7-4788-895a-c45378d38253" = "QN4C6-GBJD2-FB422-GHWJK-GJG2R"   # Cloud Storage

	# Windows 8.1
	"fe1c3238-432a-43a1-8e25-97e7d1ef10f3" = "M9Q9P-WNJJT-6PXPY-DWX8H-6XWKK"   # Core
	"78558a64-dc19-43fe-a0d0-8075b2a370a3" = "7B9N3-D94CG-YTVHR-QBPX3-RJP64"   # Core N
	"c72c6a1d-f252-4e7e-bdd1-3fca342acb35" = "BB6NG-PQ82V-VRDPW-8XVD2-V8P66"   # Core Single Language
	"db78b74f-ef1c-4892-abfe-1e66b8231df6" = "NCTT7-2RGK8-WMHRF-RY7YQ-JTXG3"   # Core China
	"ffee456a-cd87-4390-8e07-16146c672fd0" = "XYTND-K6QKT-K2MRH-66RTM-43JKP"   # Core ARM
	"c06b6981-d7fd-4a35-b7b4-054742b7af67" = "GCRJD-8NW9H-F2CDX-CCM8D-9D6T9"   # Pro
	"7476d79f-8e48-49b4-ab63-4d0b813a16e4" = "HMCNV-VVBFX-7HMBH-CTY9B-B4FXY"   # Pro N
	"096ce63d-4fac-48a9-82a9-61ae9e800e5f" = "789NJ-TQK6T-6XTH8-J39CJ-J8D3P"   # Pro with Media Center
	"81671aaf-79d1-4eb1-b004-8cbbe173afea" = "MHF9N-XY6XB-WVXMC-BTDCT-MKKG7"   # Enterprise
	"113e705c-fa49-48a4-beea-7dd879b46b14" = "TT4HM-HN7YT-62K67-RGRQJ-JFFXW"   # Enterprise N
	"0ab82d54-47f4-4acb-818c-cc5bf0ecb649" = "NMMPB-38DD4-R2823-62W8D-VXKJB"   # Embedded Industry Pro
	"cd4e2d9f-5059-4a50-a92d-05d5bb1267c7" = "FNFKF-PWTVT-9RC8H-32HB2-JB34X"   # Embedded Industry Enterprise
	"f7e88590-dfc7-4c78-bccb-6f3865b99d1a" = "VHXM3-NR6FT-RY6RT-CK882-KW2CJ"   # Embedded Industry Automotive
	"e9942b32-2e55-4197-b0bd-5ff58cba8860" = "3PY8R-QHNP9-W7XQD-G6DPH-3J2C9"   # with Bing
	"c6ddecd6-2354-4c19-909b-306a3058484e" = "Q6HTR-N24GM-PMJFP-69CD8-2GXKR"   # with Bing N
	"b8f5e3a3-ed33-4608-81e1-37d6c9dcfd9c" = "KF37N-VDV38-GRRTV-XH8X6-6F3BB"   # with Bing Single Language
	"ba998212-460a-44db-bfb5-71bf09d1c68b" = "R962J-37N87-9VVK2-WJ74P-XTMHR"   # with Bing China
	"e58d87b5-8126-4580-80fb-861b22f79296" = "MX3RK-9HNGX-K3QKC-6PJ3F-W8D7B"   # Pro for Students
	"cab491c7-a918-4f60-b502-dab75e334f40" = "TNFGH-2R6PB-8XM3K-QYHX2-J4296"   # Pro for Students N

	# Windows Server 2012 R2
	"b3ca044e-a358-4d68-9883-aaa2941aca99" = "D2N9P-3P6X9-2R39C-7RTCD-MDVJX"   # Standard
	"00091344-1ea4-4f37-b789-01750ba6988c" = "W3GGN-FT8W3-Y4M27-J84CP-Q3VJ9"   # Datacenter
	"21db6ba4-9a7b-4a14-9e29-64a60c59301d" = "KNC87-3J2TX-XB4WP-VCPJV-M4FWM"   # Essentials
	"b743a2be-68d4-4dd3-af32-92425b7bb623" = "3NPTF-33KPT-GGBPR-YX76B-39KDD"   # Cloud Storage

	# Windows 8
	"c04ed6bf-55c8-4b47-9f8e-5a1f31ceee60" = "BN3D2-R7TKB-3YPBD-8DRP2-27GG4"   # Core
	"197390a0-65f6-4a95-bdc4-55d58a3b0253" = "8N2M2-HWPGY-7PGT9-HGDD8-GVGGY"   # Core N
	"8860fcd4-a77b-4a20-9045-a150ff11d609" = "2WN2H-YGCQR-KFX6K-CD6TF-84YXQ"   # Core Single Language
	"9d5584a2-2d85-419a-982c-a00888bb9ddf" = "4K36P-JN4VD-GDC6V-KDT89-DYFKP"   # Core China
	"af35d7b7-5035-4b63-8972-f0b747b9f4dc" = "DXHJF-N9KQX-MFPVR-GHGQK-Y7RKV"   # Core ARM
	"a98bcd6d-5343-4603-8afe-5908e4611112" = "NG4HW-VH26C-733KW-K6F98-J8CK4"   # Pro
	"ebf245c1-29a8-4daf-9cb1-38dfc608a8c8" = "XCVCF-2NXM9-723PB-MHCB7-2RYQQ"   # Pro N
	"a00018a3-f20f-4632-bf7c-8daa5351c914" = "GNBB8-YVD74-QJHX6-27H4K-8QHDG"   # Pro with Media Center
	"458e1bec-837a-45f6-b9d5-925ed5d299de" = "32JNW-9KQ84-P47T8-D8GGY-CWCK7"   # Enterprise
	"e14997e7-800a-4cf7-ad10-de4b45b578db" = "JMNMF-RHW7P-DMY6X-RF3DR-X2BQT"   # Enterprise N
	"10018baf-ce21-4060-80bd-47fe74ed4dab" = "RYXVT-BNQG7-VD29F-DBMRY-HT73M"   # Embedded Industry Pro
	"18db1848-12e0-4167-b9d7-da7fcda507db" = "NKB3R-R2F8T-3XCDP-7Q2KW-XWYQ2"   # Embedded Industry Enterprise

	# Windows Server 2012
	"f0f5ec41-0d55-4732-af02-440a44a3cf0f" = "XC9B7-NBPP2-83J2H-RHMBY-92BT4"   # Standard
	"d3643d60-0c42-412d-a7d6-52e6635327f6" = "48HP8-DN98B-MYWDG-T2DCC-8W83P"   # Datacenter
	"8f365ba6-c1b9-4223-98fc-282a0756a3ed" = "HTDQM-NBMMG-KGYDT-2DTKT-J2MPV"   # Essentials
	"7d5486c7-e120-4771-b7f1-7b56c6d3170c" = "HM7DN-YVMH3-46JC3-XYTG7-CYQJJ"   # MultiPoint Standard
	"95fd1c83-7df5-494a-be8b-1300e1c9d1cd" = "XNH6W-2V9GX-RGJ4K-Y8X6F-QGJ2G"   # MultiPoint Premium

	# Windows 7
	"b92e9980-b9d5-4821-9c94-140f632f6312" = "FJ82H-XT6CR-J8D7P-XQJJ2-GPDD4"   # Professional
	"54a09a0d-d57b-4c10-8b69-a842d6590ad5" = "MRPKT-YTG23-K7D7T-X2JMM-QY7MG"   # Professional N
	"5a041529-fef8-4d07-b06f-b59b573b32d2" = "W82YF-2Q76Y-63HXB-FGJG9-GF7QX"   # Professional E
	"ae2ee509-1b34-41c0-acb7-6d4650168915" = "33PXH-7Y6KF-2VJC9-XBBR8-HVTHH"   # Enterprise
	"1cb6d605-11b3-4e14-bb30-da91c8e3983a" = "YDRBP-3D83W-TY26F-D46B2-XCKRJ"   # Enterprise N
	"46bbed08-9c7b-48fc-a614-95250573f4ea" = "C29WB-22CC8-VJ326-GHFJW-H9DH4"   # Enterprise E
	"db537896-376f-48ae-a492-53d0547773d0" = "YBYF6-BHCR3-JPKRB-CDW7B-F9BK4"   # Embedded POSReady 7
	"e1a8296a-db37-44d1-8cce-7bc961d59c54" = "XGY72-BRBBT-FF8MH-2GG8H-W7KCW"   # Embedded Standard
	"aa6dd3aa-c2b4-40e2-a544-a6bbb3f5c395" = "73KQT-CD9G6-K7TQG-66MRP-CQ22C"   # Embedded ThinPC

	# Windows Server 2008 R2
	"a78b8bd9-8017-4df5-b86a-09f756affa7c" = "6TPJF-RBVHG-WBW2R-86QPH-6RTM4"   # Web
	"cda18cf3-c196-46ad-b289-60c072869994" = "TT8MH-CG224-D3D7Q-498W2-9QCTX"   # HPC
	"68531fb9-5511-4989-97be-d11a0f55633f" = "YC6KT-GKW9T-YTKYR-T4X34-R7VHC"   # Standard
	"620e2b3d-09e7-42fd-802a-17a13652fe7a" = "489J6-VHDMP-X63PK-3K798-CPX3Y"   # Enterprise
	"7482e61b-c589-4b7f-8ecc-46d455ac3b87" = "74YFP-3QFB3-KQT8W-PMXWJ-7M648"   # Datacenter
	"8a26851c-1c7e-48d3-a687-fbca9b9ac16b" = "GT63C-RJFQ3-4GMB6-BRFB9-CB83V"   # Itanium
	"f772515c-0e87-48d5-a676-e6962c3e1195" = "736RG-XDKJK-V34PF-BHK87-J6X3K"   # MultiPoint Server - ServerEmbeddedSolution

	# Windows Vista
	"4f3d1606-3fea-4c01-be3c-8d671c401e3b" = "YFKBB-PQJJV-G996G-VWGXY-2V3X8"   # Business
	"2c682dc2-8b68-4f63-a165-ae291d4cf138" = "HMBQG-8H2RH-C77VX-27R82-VMQBT"   # Business N
	"cfd8ff08-c0d7-452b-9f60-ef5c70c32094" = "VKK3X-68KWM-X2YGT-QR4M6-4BWMV"   # Enterprise
	"d4f54950-26f2-4fb4-ba21-ffab16afcade" = "VTC42-BM838-43QHV-84HX6-XJXKV"   # Enterprise N

	# Windows Server 2008
	"ddfa9f7c-f09e-40b9-8c1a-be877a9a7f4b" = "WYR28-R7TFJ-3X2YQ-YCY4H-M249D"   # Web
	"7afb1156-2c1d-40fc-b260-aab7442b62fe" = "RCTX3-KWVHP-BR6TB-RB6DM-6X7HP"   # HPC
	"ad2542d4-9154-4c6d-8a44-30f11ee96989" = "TM24T-X9RMF-VWXK6-X8JC9-BFGM2"   # Standard
	"c1af4d90-d1bc-44ca-85d4-003ba33db3b9" = "YQGMW-MPWTJ-34KDK-48M3W-X4Q6V"   # Enterprise
	"68b6e220-cf09-466b-92d3-45cd964b9509" = "7M67G-PC374-GR742-YH8V4-TCBY3"   # Datacenter
	"01ef176b-3e0d-422a-b4f8-4ea880035e8f" = "4DWFP-JF3DJ-B7DTH-78FJB-PDRHK"   # Itanium
	"2401e3d0-c50a-4b58-87b2-7e794b7d2607" = "W7VD6-7JFBR-RX26B-YKQ3Y-6FFFJ"   # StandardV
	"8198490a-add0-47b2-b3ba-316b12d647b4" = "39BXF-X8Q23-P2WWT-38T2F-G3FPG"   # EnterpriseV
	"fd09ef77-5647-4eff-809c-af2b64659a45" = "22XQ2-VRXRG-P8D42-K34TD-G3QQC"   # DatacenterV

	# Office 2024
	"8d368fc1-9470-4be2-8d66-90e836cbb051" = "XJ2XN-FW8RK-P4HMP-DKDBV-GCVGB"   # Professional Plus
	"bbac904f-6a7e-418a-bb4b-24c85da06187" = "V28N4-JG22K-W66P8-VTMGK-H6HGR"   # Standard
	"f510af75-8ab7-4426-a236-1bfb95c34ff8" = "FQQ23-N4YCY-73HQ3-FM9WC-76HF4"   # Project Professional
	"9f144f27-2ac5-40b9-899d-898c2b8b4f81" = "PD3TT-NTHQQ-VC7CY-MFXK3-G87F8"   # Project Standard
	"fa187091-8246-47b1-964f-80a0b1e5d69a" = "B7TN8-FJ8V3-7QYCP-HQPMV-YY89G"   # Visio Professional
	"923fa470-aa71-4b8b-b35c-36b79bf9f44b" = "JMMVY-XFNQC-KK4HK-9H7R3-WQQTV"   # Visio Standard
	"72e9faa7-ead1-4f3d-9f6e-3abc090a81d7" = "82FTR-NCHR7-W3944-MGRHM-JMCWD"   # Access
	"cbbba2c3-0ff5-4558-846a-043ef9d78559" = "F4DYN-89BP2-WQTWJ-GR8YC-CKGJG"   # Excel
	"bef3152a-8a04-40f2-a065-340c3f23516d" = "D2F8D-N3Q3B-J28PV-X27HD-RJWB9"   # Outlook
	"b63626a4-5f05-4ced-9639-31ba730a127e" = "CW94N-K6GJH-9CTXY-MG2VC-FYCWP"   # PowerPoint
	"0002290a-2091-4324-9e53-3cfe28884cde" = "4NKHF-9HBQF-Q3B6C-7YV34-F64P3"   # Skype for Business
	"d0eded01-0881-4b37-9738-190400095098" = "MQ84N-7VYDM-FXV7C-6K7CC-VFW9J"   # Word
	"fceda083-1203-402a-8ec4-3d7ed9f3648c" = "2TDPW-NDQ7G-FMG99-DXQ7M-TX3T2"   # Pro Plus Preview
	"aaea0dc8-78e1-4343-9f25-b69b83dd1bce" = "D9GTG-NP7DV-T6JP3-B6B62-JB89R"   # Project Pro Preview
	"4ab4d849-aabc-43fb-87ee-3aed02518891" = "YW66X-NH62M-G6YFP-B7KCT-WXGKQ"   # Visio Pro Preview

	# Office 2021
	"fbdb3e18-a8ef-4fb3-9183-dffd60bd0984" = "FXYTK-NJJ8C-GB6DW-3DYQT-6F7TH"   # Professional Plus
	"080a45c5-9f9f-49eb-b4b0-c3c610a5ebd3" = "KDX7X-BNVR8-TXXGX-4Q7Y8-78VT3"   # Standard
	"76881159-155c-43e0-9db7-2d70a9a3a4ca" = "FTNWT-C6WBT-8HMGF-K9PRX-QV9H8"   # Project Professional
	"6dd72704-f752-4b71-94c7-11cec6bfc355" = "J2JDC-NJCYY-9RGQ4-YXWMH-T3D4T"   # Project Standard
	"fb61ac9a-1688-45d2-8f6b-0674dbffa33c" = "KNH8D-FGHT4-T8RK3-CTDYJ-K2HT4"   # Visio Professional
	"72fce797-1884-48dd-a860-b2f6a5efd3ca" = "MJVNY-BYWPY-CWV6J-2RKRT-4M8QG"   # Visio Standard
	"1fe429d8-3fa7-4a39-b6f0-03dded42fe14" = "WM8YG-YNGDD-4JHDC-PG3F4-FC4T4"   # Access
	"ea71effc-69f1-4925-9991-2f5e319bbc24" = "NWG3X-87C9K-TC7YY-BC2G7-G6RVC"   # Excel
	"a5799e4c-f83c-4c6e-9516-dfe9b696150b" = "C9FM6-3N72F-HFJXB-TM3V9-T86R9"   # Outlook
	"6e166cc3-495d-438a-89e7-d7c9e6fd4dea" = "TY7XF-NFRBR-KJ44C-G83KF-GX27K"   # PowerPoint
	"aa66521f-2370-4ad8-a2bb-c095e3e4338f" = "2MW9D-N4BXM-9VBPG-Q7W6M-KFBGQ"   # Publisher
	"1f32a9af-1274-48bd-ba1e-1ab7508a23e8" = "HWCXN-K3WBT-WJBKY-R8BD9-XK29P"   # Skype for Business
	"abe28aea-625a-43b1-8e30-225eb8fbd9e5" = "TN8H9-M34D3-Y64V9-TR72V-X79KV"   # Word
	"f3fb2d68-83dd-4c8b-8f09-08e0d950ac3b" = "HFPBN-RYGG8-HQWCW-26CH6-PDPVF"   # Pro Plus Preview
	"76093b1b-7057-49d7-b970-638ebcbfd873" = "WDNBY-PCYFY-9WP6G-BXVXM-92HDV"   # Project Pro Preview
	"a3b44174-2451-4cd6-b25f-66638bfb9046" = "2XYX7-NXXBK-9CK7W-K2TKW-JFJ7G"   # Visio Pro Preview

	# Office 2019
	"85dd8b5f-eaa4-4af3-a628-cce9e77c9a03" = "NMMKJ-6RK4F-KMJVX-8D9MJ-6MWKP"   # Professional Plus
	"6912a74b-a5fb-401a-bfdb-2e3ab46f4b02" = "6NWWJ-YQWMR-QKGCB-6TMB3-9D9HK"   # Standard
	"2ca2bf3f-949e-446a-82c7-e25a15ec78c4" = "B4NPR-3FKK7-T2MBV-FRQ4W-PKD2B"   # Project Professional
	"1777f0e3-7392-4198-97ea-8ae4de6f6381" = "C4F7P-NCP8C-6CQPT-MQHV9-JXD2M"   # Project Standard
	"5b5cf08f-b81a-431d-b080-3450d8620565" = "9BGNQ-K37YR-RQHF2-38RQ3-7VCBB"   # Visio Professional
	"e06d7df3-aad0-419d-8dfb-0ac37e2bdf39" = "7TQNQ-K3YQQ-3PFH7-CCPPM-X4VQ2"   # Visio Standard
	"9e9bceeb-e736-4f26-88de-763f87dcc485" = "9N9PT-27V4Y-VJ2PD-YXFMF-YTFQT"   # Access
	"237854e9-79fc-4497-a0c1-a70969691c6b" = "TMJWT-YYNMB-3BKTF-644FC-RVXBD"   # Excel
	"c8f8a301-19f5-4132-96ce-2de9d4adbd33" = "7HD7K-N4PVK-BHBCQ-YWQRW-XW4VK"   # Outlook
	"3131fd61-5e4f-4308-8d6d-62be1987c92c" = "RRNCX-C64HY-W2MM7-MCH9G-TJHMQ"   # PowerPoint
	"9d3e4cca-e172-46f1-a2f4-1d2107051444" = "G2KWX-3NW6P-PY93R-JXK2T-C9Y9V"   # Publisher
	"734c6c6e-b0ba-4298-a891-671772b2bd1b" = "NCJ33-JHBBY-HTK98-MYCV8-HMKHJ"   # Skype for Business
	"059834fe-a8ea-4bff-b67b-4d006b5447d3" = "PBX3G-NWMT6-Q7XBW-PYJGG-WXD33"   # Word
	"0bc88885-718c-491d-921f-6f214349e79c" = "VQ9DP-NVHPH-T9HJC-J9PDT-KTQRG"   # Pro Plus Preview
	"fc7c4d0c-2e85-4bb9-afd4-01ed1476b5e9" = "XM2V9-DN9HH-QB449-XDGKC-W2RMW"   # Project Pro Preview
	"500f6619-ef93-4b75-bcb4-82819998a3ca" = "N2CG9-YD3YK-936X4-3WR82-Q3X4H"   # Visio Pro Preview

	# Office 2016
	"829b8110-0e6f-4349-bca4-42803577788d" = "WGT24-HCNMF-FQ7XH-6M8K7-DRTW9"   # Project Professional C2R-P
	"cbbaca45-556a-4416-ad03-bda598eaa7c8" = "D8NRQ-JTYM3-7J2DX-646CT-6836M"   # Project Standard C2R-P
	"b234abe3-0857-4f9c-b05a-4dc314f85557" = "69WXN-MBYV6-22PQG-3WGHK-RM6XC"   # Visio Professional C2R-P
	"361fe620-64f4-41b5-ba77-84f8e079b1f7" = "NY48V-PPYYH-3F4PX-XJRKJ-W4423"   # Visio Standard C2R-P
	"e914ea6e-a5fa-4439-a394-a9bb3293ca09" = "DMTCJ-KNRKX-26982-JYCKT-P7KB6"   # MondoR
	"9caabccb-61b1-4b4b-8bec-d10a3c3ac2ce" = "HFTND-W9MK4-8B7MJ-B6C4G-XQBR2"   # Mondo
	"d450596f-894d-49e0-966a-fd39ed4c4c64" = "XQNVK-8JYDB-WJ9W3-YJ8YR-WFG99"   # Professional Plus
	"dedfa23d-6ed1-45a6-85dc-63cae0546de6" = "JNRGM-WHDWX-FJJG3-K47QV-DRTFM"   # Standard
	"4f414197-0fc2-4c01-b68a-86cbb9ac254c" = "YG9NW-3K39V-2T3HJ-93F3Q-G83KT"   # Project Professional
	"da7ddabc-3fbe-4447-9e01-6ab7440b4cd4" = "GNFHQ-F6YQM-KQDGJ-327XX-KQBVC"   # Project Standard
	"6bf301c1-b94a-43e9-ba31-d494598c47fb" = "PD3PC-RHNGV-FXJ29-8JK7D-RJRJK"   # Visio Professional
	"aa2a7821-1827-4c2c-8f1d-4513a34dda97" = "7WHWN-4T7MP-G96JF-G33KR-W8GF4"   # Visio Standard
	"67c0fc0c-deba-401b-bf8b-9c8ad8395804" = "GNH9Y-D2J4T-FJHGG-QRVH7-QPFDW"   # Access
	"c3e65d36-141f-4d2f-a303-a842ee756a29" = "9C2PK-NWTVB-JMPW8-BFT28-7FTBF"   # Excel
	"d8cace59-33d2-4ac7-9b1b-9b72339c51c8" = "DR92N-9HTF2-97XKM-XW2WJ-XW3J6"   # OneNote
	"ec9d9265-9d1e-4ed0-838a-cdc20f2551a1" = "R69KK-NTPKF-7M3Q4-QYBHW-6MT9B"   # Outlook
	"d70b1bba-b893-4544-96e2-b7a318091c33" = "J7MQP-HNJ4Y-WJ7YM-PFYGF-BY6C6"   # Powerpoint
	"041a06cb-c5b8-4772-809f-416d03d16654" = "F47MM-N3XJP-TQXJ9-BP99D-8K837"   # Publisher
	"83e04ee1-fa8d-436d-8994-d31a862cab77" = "869NQ-FJ69K-466HW-QYCP2-DDBV6"   # Skype for Business
	"bb11badf-d8aa-470e-9311-20eaf80fe5cc" = "WXY84-JN2Q9-RBCCQ-3Q3J3-3PFJ6"   # Word

	# Office 2013
	"1dc00701-03af-4680-b2af-007ffc758a1f" = "CWH2Y-NPYJW-3C7HD-BJQWB-G28JJ"   # MondoR
	"dc981c6b-fc8e-420f-aa43-f8f33e5c0923" = "42QTK-RN8M7-J3C4G-BBGYM-88CYV"   # Mondo
	"b322da9c-a2e2-4058-9e4e-f59a6970bd69" = "YC7DK-G2NP3-2QQC3-J6H88-GVGXT"   # Professional Plus
	"b13afb38-cd79-4ae5-9f7f-eed058d750ca" = "KBKQT-2NMXY-JJWGP-M62JB-92CD4"   # Standard
	"4a5d124a-e620-44ba-b6ff-658961b33b9a" = "FN8TT-7WMH6-2D4X9-M337T-2342K"   # Project Professional
	"427a28d1-d17c-4abf-b717-32c780ba6f07" = "6NTH3-CW976-3G3Y2-JK3TX-8QHTT"   # Project Standard
	"e13ac10e-75d0-4aff-a0cd-764982cf541c" = "C2FG9-N6J68-H8BTJ-BW3QX-RM3B3"   # Visio Professional
	"ac4efaf0-f81f-4f61-bdf7-ea32b02ab117" = "J484Y-4NKBF-W2HMG-DBMJC-PGWR7"   # Visio Standard
	"6ee7622c-18d8-4005-9fb7-92db644a279b" = "NG2JY-H4JBT-HQXYP-78QH9-4JM2D"   # Access
	"f7461d52-7c2b-43b2-8744-ea958e0bd09a" = "VGPNG-Y7HQW-9RHP7-TKPV3-BG7GB"   # Excel
	"fb4875ec-0c6b-450f-b82b-ab57d8d1677f" = "H7R7V-WPNXQ-WCYYC-76BGV-VT7GH"   # Groove
	"a30b8040-d68a-423f-b0b5-9ce292ea5a8f" = "DKT8B-N7VXH-D963P-Q4PHY-F8894"   # InfoPath
	"1b9f11e3-c85c-4e1b-bb29-879ad2c909e3" = "2MG3G-3BNTT-3MFW9-KDQW3-TCK7R"   # Lync
	"efe1f3e6-aea2-4144-a208-32aa872b6545" = "TGN6P-8MMBC-37P2F-XHXXK-P34VW"   # OneNote
	"771c3afa-50c5-443f-b151-ff2546d863a0" = "QPN8Q-BJBTJ-334K3-93TGY-2PMBT"   # Outlook
	"8c762649-97d1-4953-ad27-b7e2c25b972e" = "4NT99-8RJFH-Q2VDH-KYG2C-4RD4F"   # Powerpoint
	"00c79ff1-6850-443d-bf61-71cde0de305f" = "PN2WF-29XG2-T9HJ7-JQPJR-FCXK4"   # Publisher
	"d9f5b1c6-5386-495a-88f9-9ad6b41ac9b3" = "6Q7VD-NX8JD-WJ2VH-88V73-4GBJ7"   # Word

	# Office 2010
	"09ed9640-f020-400a-acd8-d7d867dfd9c2" = "YBJTT-JG6MD-V9Q7P-DBKXJ-38W9R"   # Mondo
	"ef3d4e49-a53d-4d81-a2b1-2ca6c2556b2c" = "7TC2V-WXF6P-TD7RT-BQRXR-B8K32"   # Mondo2
	"6f327760-8c5c-417c-9b61-836a98287e0c" = "VYBBJ-TRJPB-QFQRF-QFT4D-H3GVB"   # Professional Plus
	"9da2a678-fb6b-4e67-ab84-60dd6a9c819a" = "V7QKV-4XVVR-XYV4D-F7DFM-8R6BM"   # Standard
	"df133ff7-bf14-4f95-afe3-7b48e7e331ef" = "YGX6F-PGV49-PGW3J-9BTGG-VHKC6"   # Project Professional
	"5dc7bf61-5ec9-4996-9ccb-df806a2d0efe" = "4HP3K-88W3F-W2K3D-6677X-F9PGB"   # Project Standard
	"92236105-bb67-494f-94c7-7f7a607929bd" = "D9DWC-HPYVV-JGF4P-BTWQB-WX8BJ"   # Visio Premium
	"e558389c-83c3-4b29-adfe-5e4d7f46c358" = "7MCW8-VRQVK-G677T-PDJCM-Q8TCP"   # Visio Professional
	"9ed833ff-4f92-4f36-b370-8683a4f13275" = "767HD-QGMWX-8QTDB-9G3R2-KHFGJ"   # Visio Standard
	"8ce7e872-188c-4b98-9d90-f8f90b7aad02" = "V7Y44-9T38C-R2VJK-666HK-T7DDX"   # Access
	"cee5d470-6e3b-4fcc-8c2b-d17428568a9f" = "H62QG-HXVKF-PP4HP-66KMR-CW9BM"   # Excel
	"8947d0b8-c33b-43e1-8c56-9b674c052832" = "QYYW6-QP4CB-MBV6G-HYMCJ-4T3J4"   # Groove - SharePoint Workspace
	"ca6b6639-4ad6-40ae-a575-14dee07f6430" = "K96W8-67RPQ-62T9Y-J8FQJ-BT37T"   # InfoPath
	"ab586f5c-5256-4632-962f-fefd8b49e6f4" = "Q4Y4M-RHWJM-PY37F-MTKWH-D3XHX"   # OneNote
	"ecb7c192-73ab-4ded-acf4-2399b095d0cc" = "7YDC2-CWM8M-RRTJC-8MDVC-X3DWQ"   # Outlook
	"45593b1d-dfb1-4e91-bbfb-2d5d0ce2227a" = "RC8FX-88JRY-3PF7C-X8P67-P4VTT"   # Powerpoint
	"b50c4f75-599b-43e8-8dcd-1081a7967241" = "BFK7F-9MYHM-V68C7-DRQ66-83YTP"   # Publisher
	"2d0882e7-a4e7-423b-8ccc-70d91e0158b1" = "HVHB3-C6FV7-KQX9W-YQG79-CRY7T"   # Word
	"ea509e87-07a1-4a45-9edc-eba5a39f36af" = "D6QFG-VBYP2-XQHM7-J97RH-VVRCK"   # Small Business Basics
}

# =========================
# Menu Definitions
# =========================

function TheEnd
{
	if (Test-Path "$env:PUBLIC\ReadMe*.html") {
		Remove-Item "$env:PUBLIC\ReadMe*.html" -Force -ErrorAction SilentlyContinue
	}
	ExitScript 0
}

###########################
function cPause
{
	if (-not $psISE -and $Unattend -ne 1) {
		Read-Host "`r`nPress Enter to continue" | Out-Null
	}
}

###########################
function psCLS
{
	if ($Silent -eq 0 -and $_Debug -eq 0) {
		Clear-Host
	}
}

###########################
function E_IP
{
	Clear-Host
	CONOUT "`nWrite / Paste the external KMS Server address, or just press Enter to return:`n"
	$kip = ''
	$kip = Read-Host
	if ([String]::IsNullOrEmpty($kip)) {
		return MainMenu
	}
	$KMS_IP = $kip -replace ' '
	$External = 1
	. $optActivate
}

###########################
function MainMenu
{
	Clear-Host
	DoColor "07"
	$Host.UI.RawUI.WindowTitle = $_title
	. $_con80
	$_dMode = 'Manual'
	$_ReAR = 0
	$_rtrn = 0
	$_quit = 0
	$_erlv = 255
	. subOffice
	. chkAUR
	$_dAlt = 0; if ($AltDLL -eq 1 -or $_aDLL -eq 0) { $_dAlt = 1 }

	if ($_AUR -eq 0) {
		$_Opt1 = {COLOUT $_cWht "               [1] Activate " $_cBlu "[$_dMode Mode]"}
		$_Opt2 = {CONOUT "               [2] Install Activation Auto-Renewal"}
	} else {
		$_Opt1 = {COLOUT $_cWht "               [1] Activate " $_cGrn "[$_dMode Mode]"}
		$_Opt2 = {COLOUT $_cWht "               [2] Install Activation Auto-Renewal " $_cGrn "[Installed]"}
	}
	if ($_Debug -eq 0) {
		$_Opt4 = {CONOUT "               [4] Enable Debug Mode         [No]"}
	} else {
		$_Opt4 = {COLOUT $_cWht "               [4] Enable Debug Mode         " $_cRed "[Yes]"}
	}
	if ($ActWindows -eq 1) {
		$_Opt5 = {CONOUT "               [5] Process Windows           [Yes]"}
	} else {
		$_Opt5 = {COLOUT $_cWht "               [5] Process Windows           " $_cYel "[No]"}
	}
	if ($ActOffice -eq 1) {
		$_Opt6 = {CONOUT "               [6] Process Office            [Yes]"}
	} else {
		$_Opt6 = {COLOUT $_cWht "               [6] Process Office            " $_cYel "[No]"}
	}
	if ($AutoR2V -eq 1) {
		$_Opt7 = {CONOUT "               [7] Convert Office C2R-R2V    [Yes]"}
	} else {
		$_Opt7 = {COLOUT $_cWht "               [7] Convert Office C2R-R2V    " $_cYel "[No]"}
	}
	if ($vNextOverride -eq 0) {
		$_OptV = {CONOUT "               [V] Override Office C2R vNext [No]"}
		if ($sub_next -eq 1) {$_OptV = {COLOUT $_cYel "               [V] Override Office C2R vNext " $_cYel "[No]"}}
	} else {
		$_OptV = {CONOUT "               [V] Override Office C2R vNext [Yes]"}
		if ($sub_next -eq 1) {$_OptV = {COLOUT $_cYel "               [V] Override Office C2R vNext " $_cRed "[Yes]"}}
	}
	if ($SkipKMS38 -eq 1) {
		$_OptX = {CONOUT "               [X] Skip Windows KMS38        [Yes]"}
	} else {
		$_OptX = {COLOUT $_cWht "               [X] Skip Windows KMS38        " $_cYel "[No]"}
	}
	if ($_dAlt -eq 0) {
		$_Opt9 = {CONOUT "               [9] Use Alternative DLL hook  [No]"}
	} else {
		$_Opt9 = {COLOUT $_cWht "               [9] Use Alternative DLL hook  " $_cYel "[Yes]"}
	}

	CONOUT ""
	CONOUT "          $line3`n"
	& $_Opt1
	& $_Opt2
	CONOUT "               [3] Uninstall Completely"
	CONOUT "               $line4`n"
	CONOUT "                   Configuration:`n"
	# & $_Opt4
	& $_Opt5
	& $_Opt6
	if ($_NT7 -eq 1) {
		& $_Opt7
		& $_OptV
	}
	if ($winbuild -ge 10240) {
		& $_OptX
	}
	if ($_NT7 -eq 1) {
		& $_Opt9
	}
	CONOUT "               $line4`n"
	CONOUT "                   Miscellaneous:`n"
	CONOUT "               [8] Check Activation Status"
	CONOUT "               [S] Create `$OEM`$ Folder"
	CONOUT "               [D] Decode Embedded DLL Files"
	CONOUT "               [R] Open ReadMeAIO.html"
	CONOUT "               [E] Activate {External Mode}"
	CONOUT "          $line3`n"

	CONOUT ">           Choose a menu option, or press 0 to Exit: "
	choice.exe /C 1234567890EDRSVX /N >$null 2>&1
	$_erlv = $LASTEXITCODE
	switch ($_erlv) {
		16 { if ($winbuild -ge 10240) {if ($SkipKMS38 -eq 0) {$SkipKMS38 = 1} else {$SkipKMS38 = 0}}; break; }
		15 { if ($_NT7 -eq 1) {if ($vNextOverride -eq 0) {$vNextOverride = 1} else {$vNextOverride = 0}}; break; }
		14 { CreateOEM; break; }
		13 { CreateReadMe; break; }
		12 { CreateBIN; break; }
		11 { return E_IP; }
		10 { $_quit = 1; return TheEnd; }
		9  { if ($_NT7 -eq 1) {if ($AltDLL -eq 0) {$AltDLL = 1} else {$AltDLL = 0}}; break; }
		8  { casWm; break; }
		7  { if ($_NT7 -eq 1) {if ($AutoR2V -eq 0) {$AutoR2V = 1} else {$AutoR2V = 0}}; break; }
		6  { if ($ActOffice -eq 0) {$ActOffice = 1} else {$ActWindows = 1; $ActOffice = 0}; break; }
		5  { if ($ActWindows -eq 0) {$ActWindows = 1} else {$ActWindows = 0; $ActOffice = 1}; break; }
		4  { if ($_Debug -eq 0) {$_Debug = 1} else {$_Debug = 0}; break; }
		3  { if ($_dDbg -eq 'No') {. $optRemoveAR} else {$_verb = 1; . psCLS; return HookRemove} }
		2  { . $optInstallAR }
		1  { . $optActivate }
	}
	return MainMenu
}

###########################
$optInstallAR = {
	$_ReAR = 1
	if ($_AUR -eq 0) {
		$_AUR = 1; $_verb = 1; $_rtrn = 1; . psCLS; return HookInstall;
	} else {
		$_verb = 0; $_rtrn = 1; . psCLS; return HookInstall;
	}
}

$optRemoveAR = {
	$_verb = 1; . psCLS; HookRemove; return cCache;
}

$optActivate = {
	. psCLS; . DoActivate;
}

# =========================
# Entry Point
# =========================

if ($OSType -eq "Win8" -and (Test-Path "$IFEO\sppsvc.exe")) {
	Del-RegKey "$IFEO\sppsvc.exe"
	StopService "sppsvc"
}

if ($ActWindows -eq 0 -and $ActOffice -eq 0) {
	$ActWindows = 1
}
if ($null -eq $fAUR -and ($_Debug -eq 1 -or  $Unattend -eq 1)) {
	$fAUR = 0; $External = 0;
}

. subOffice
. chkAUR

if ($null -ne $rAUR) {
	. $optRemoveAR
}
if ($null -ne $fAUR) {
	$Unattend = 1
	if ($fAUR -eq 1) { . $optInstallAR }
	if ($External -eq 0) { $_AUR = 0 }
	. $optActivate
}

MainMenu
ExitScript 0

####
:sppmgr:
function CONOUT($strObj)
{
	Out-Host -Input $strObj
}

function ReturnScript($ExitCode = 0)
{
	return
}

$winbuild = 1
try {
	$winbuild = [System.Diagnostics.FileVersionInfo]::GetVersionInfo("$env:SystemRoot\System32\kernel32.dll").FileBuildPart
} catch {
	$winbuild = [int]([wmi]'Win32_OperatingSystem=@').BuildNumber
}

if ($winbuild -EQ 1) {
	"==== ERROR ====`r`n"
	"Could not detect Windows build."
	ReturnScript 1
}

if ($winbuild -LT 2600) {
	"==== ERROR ====`r`n"
	"This build of Windows is not supported by this script."
	ReturnScript 1
}

if ($All.IsPresent)
{
	$isAll = {CONOUT "`r"}
	$noAll = {$null}
}
else
{
	$isAll = {$null}
	$noAll = {CONOUT "`r"}
}
$Dlv = $Dlv.IsPresent
$IID = $IID.IsPresent -Or $Dlv.IsPresent

$NT6 = $winbuild -GE 6000
$NT7 = $winbuild -GE 7600
$NT8 = $winbuild -GE 9200
$NT9 = $winbuild -GE 9600

$Admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$line2 = "============================================================"
$line3 = "____________________________________________________________"

function echoWindows
{
	CONOUT "$line2"
	CONOUT "===                   Windows Status                     ==="
	CONOUT "$line2"
	& $noAll
}

function echoOffice
{
	if ($doMSG -EQ 0) {
		return
	}

	& $isAll
	CONOUT "$line2"
	CONOUT "===                   Office Status                      ==="
	CONOUT "$line2"
	& $noAll

	$script:doMSG = 0
}

function strGetRegistry($strKey, $strName)
{
	try {
		return [Microsoft.Win32.Registry]::GetValue($strKey, $strName, $null)
	} catch {
		return $null
	}
}

function CheckOhook
{
	$ohook = 0
	$paths = "${env:ProgramFiles}", "${env:ProgramW6432}", "${env:ProgramFiles(x86)}"

	15, 16 | foreach `
	{
		$A = $_; $paths | foreach `
		{
			if (Test-Path "$($_)$('\Microsoft Office\Office')$($A)$('\sppc*dll')") {$ohook = 1}
		}
	}

	"System", "SystemX86" | foreach `
	{
		$A = $_; "Office 15", "Office" | foreach `
		{
			$B = $_; $paths | foreach `
			{
				if (Test-Path "$($_)$('\Microsoft ')$($B)$('\root\vfs\')$($A)$('\sppc*dll')") {$ohook = 1}
			}
		}
	}

	if ($ohook -EQ 0) {
		return
	}

	& $isAll
	CONOUT "$line2"
	CONOUT "===                Office Ohook Status                   ==="
	CONOUT "$line2"
	$host.UI.WriteLine('Yellow', 'Black', "`r`nOhook for permanent Office activation is installed.`r`nYou can ignore the below mentioned Office activation status.")
	& $noAll
}

#region SSSS
function BoolToWStr($bVal)
{
	("TRUE", "FALSE")[!$bVal]
}

function InitializePInvoke($LaDll, $bOffice)
{
	$LaName = [IO.Path]::GetFileNameWithoutExtension($LaDll)
	$SLApp = $NT7 -Or $bOffice -Or ($LaName -EQ 'sppc' -And [Diagnostics.FileVersionInfo]::GetVersionInfo("$SysPath\sppc.dll").FilePrivatePart -GE 16501)
	$Win32 = $null

	$Marshal = [System.Runtime.InteropServices.Marshal]
	$Module = [AppDomain]::CurrentDomain.DefineDynamicAssembly(($LaName+"_Assembly"), 'Run').DefineDynamicModule(($LaName+"_Module"), $False)
	$Class = $Module.DefineType(($LaName+"_Methods"), 'Public, Abstract, Sealed, BeforeFieldInit', [Object], 0)

	$Class.DefinePInvokeMethod('SLClose', $LaDll, 22, 1, [Int32], @([IntPtr]), 1, 3).SetImplementationFlags(128)
	$Class.DefinePInvokeMethod('SLOpen', $LaDll, 22, 1, [Int32], @([IntPtr].MakeByRefType()), 1, 3).SetImplementationFlags(128)
	$Class.DefinePInvokeMethod('SLGenerateOfflineInstallationId', $LaDll, 22, 1, [Int32], @([IntPtr], [Guid].MakeByRefType(), [IntPtr].MakeByRefType()), 1, 3).SetImplementationFlags(128)
	$Class.DefinePInvokeMethod('SLGetSLIDList', $LaDll, 22, 1, [Int32], @([IntPtr], [UInt32], [Guid].MakeByRefType(), [UInt32], [UInt32].MakeByRefType(), [IntPtr].MakeByRefType()), 1, 3).SetImplementationFlags(128)
	$Class.DefinePInvokeMethod('SLGetLicensingStatusInformation', $LaDll, 22, 1, [Int32], @([IntPtr], [Guid].MakeByRefType(), [Guid].MakeByRefType(), [IntPtr], [UInt32].MakeByRefType(), [IntPtr].MakeByRefType()), 1, 3).SetImplementationFlags(128)
	$Class.DefinePInvokeMethod('SLGetPKeyInformation', $LaDll, 22, 1, [Int32], @([IntPtr], [Guid].MakeByRefType(), [String], [UInt32].MakeByRefType(), [UInt32].MakeByRefType(), [IntPtr].MakeByRefType()), 1, 3).SetImplementationFlags(128)
	$Class.DefinePInvokeMethod('SLGetProductSkuInformation', $LaDll, 22, 1, [Int32], @([IntPtr], [Guid].MakeByRefType(), [String], [UInt32].MakeByRefType(), [UInt32].MakeByRefType(), [IntPtr].MakeByRefType()), 1, 3).SetImplementationFlags(128)
	$Class.DefinePInvokeMethod('SLGetServiceInformation', $LaDll, 22, 1, [Int32], @([IntPtr], [String], [UInt32].MakeByRefType(), [UInt32].MakeByRefType(), [IntPtr].MakeByRefType()), 1, 3).SetImplementationFlags(128)
	if ($SLApp) {
		$Class.DefinePInvokeMethod('SLGetApplicationInformation', $LaDll, 22, 1, [Int32], @([IntPtr], [Guid].MakeByRefType(), [String], [UInt32].MakeByRefType(), [UInt32].MakeByRefType(), [IntPtr].MakeByRefType()), 1, 3).SetImplementationFlags(128)
	}
	if ($bOffice) {
		$Win32 = $Class.CreateType()
		return
	}
	if ($NT6) {
		$Class.DefinePInvokeMethod('SLGetWindowsInformation', 'slc.dll', 22, 1, [Int32], @([String], [UInt32].MakeByRefType(), [UInt32].MakeByRefType(), [IntPtr].MakeByRefType()), 1, 3).SetImplementationFlags(128)
		$Class.DefinePInvokeMethod('SLGetWindowsInformationDWORD', 'slc.dll', 22, 1, [Int32], @([String], [UInt32].MakeByRefType()), 1, 3).SetImplementationFlags(128)
		$Class.DefinePInvokeMethod('SLIsGenuineLocal', 'slwga.dll', 22, 1, [Int32], @([Guid].MakeByRefType(), [UInt32].MakeByRefType(), [IntPtr]), 1, 3).SetImplementationFlags(128)
	}
	if ($NT7) {
		$Class.DefinePInvokeMethod('SLIsWindowsGenuineLocal', 'slc.dll', 'Public, Static', 'Standard', [Int32], @([UInt32].MakeByRefType()), 'Winapi', 'Unicode').SetImplementationFlags('PreserveSig')
	}

	if ($DllSubscription) {
		$Class.DefinePInvokeMethod('ClipGetSubscriptionStatus', 'Clipc.dll', 22, 1, [Int32], @([IntPtr].MakeByRefType()), 1, 3).SetImplementationFlags(128)
		$Struct = $Class.DefineNestedType('SubStatus', 'NestedPublic, SequentialLayout, Sealed, BeforeFieldInit', [ValueType], 0)
		[void]$Struct.DefineField('dwEnabled', [UInt32], 'Public')
		[void]$Struct.DefineField('dwSku', [UInt32], 6)
		[void]$Struct.DefineField('dwState', [UInt32], 6)
		$SubStatus = $Struct.CreateType()
	}

	$Win32 = $Class.CreateType()
}

function SlGetInfoIID($SkuId)
{
	$bData = 0

	if ($Win32::SLGenerateOfflineInstallationId(
		$hSLC,
		[ref][Guid]$SkuId,
		[ref]$bData
	))
	{
		return $null
	}
	else
	{
		return $Marshal::PtrToStringUni($bData)
	}
}

function SlReturnData($hrRet, $tData, $cData, $bData)
{
	if ($hrRet -NE 0 -Or $cData -EQ 0)
	{
		return $null
	}
	if ($tData -EQ 1)
	{
		return $Marshal::PtrToStringUni($bData)
	}
	elseif ($tData -EQ 4)
	{
		return $Marshal::ReadInt32($bData)
	}
	elseif ($tData -EQ 3 -And $cData -EQ 8)
	{
		return $Marshal::ReadInt64($bData)
	}
	else
	{
		return $null
	}
}

function SlGetInfoPKey($PkeyId, $Value)
{
	$tData = 0
	$cData = 0
	$bData = 0

	$hrRet = $Win32::SLGetPKeyInformation(
		$hSLC,
		[ref][Guid]$PkeyId,
		$Value,
		[ref]$tData,
		[ref]$cData,
		[ref]$bData
	)

	return SlReturnData $hrRet $tData $cData $bData
}

function SlGetInfoSku($SkuId, $Value)
{
	$tData = 0
	$cData = 0
	$bData = 0

	$hrRet = $Win32::SLGetProductSkuInformation(
		$hSLC,
		[ref][Guid]$SkuId,
		$Value,
		[ref]$tData,
		[ref]$cData,
		[ref]$bData
	)

	return SlReturnData $hrRet $tData $cData $bData
}

function SlGetInfoApp($AppId, $Value)
{
	$tData = 0
	$cData = 0
	$bData = 0

	$hrRet = $Win32::SLGetApplicationInformation(
		$hSLC,
		[ref][Guid]$AppId,
		$Value,
		[ref]$tData,
		[ref]$cData,
		[ref]$bData
	)

	return SlReturnData $hrRet $tData $cData $bData
}

function SlGetInfoService($Value)
{
	$tData = 0
	$cData = 0
	$bData = 0

	$hrRet = $Win32::SLGetServiceInformation(
		$hSLC,
		$Value,
		[ref]$tData,
		[ref]$cData,
		[ref]$bData
	)

	return SlReturnData $hrRet $tData $cData $bData
}

function SlGetInfoSvcApp($strApp, $Value)
{
	if ($SLApp)
	{
		return SlGetInfoApp $strApp $Value
	}
	else
	{
		return SlGetInfoService $Value
	}
}

function SlGetInfoLicensing($AppId, $SkuId)
{
	$dwStatus = 0
	$dwGrace = 0
	$hrReason = 0
	$qwValidity = 0

	$cStatus = 0
	$pStatus = 0

	$hrRet = $Win32::SLGetLicensingStatusInformation(
		$hSLC,
		[ref][Guid]$AppId,
		[ref][Guid]$SkuId,
		0,
		[ref]$cStatus,
		[ref]$pStatus
	)

	if ($hrRet -NE 0 -Or $cStatus -EQ 0)
	{
		return
	}

	[IntPtr]$ppStatus = [Int64]$pStatus + [Int64]40 * ($cStatus - 1)
	$dwStatus = $Marshal::ReadInt32($ppStatus, 16)
	$dwGrace = $Marshal::ReadInt32($ppStatus, 20)
	$hrReason = $Marshal::ReadInt32($ppStatus, 28)
	$qwValidity = $Marshal::ReadInt64($ppStatus, 32)

	if ($dwStatus -EQ 3)
	{
		$dwStatus = 5
	}
	if ($dwStatus -EQ 2)
	{
		if ($hrReason -EQ 0x4004F00D)
		{
			$dwStatus = 3
		}
		elseif ($hrReason -EQ 0x4004F065)
		{
			$dwStatus = 4
		}
		elseif ($hrReason -EQ 0x4004FC06)
		{
			$dwStatus = 6
		}
	}

	return
}

function SlGetInfoSLID($AppId)
{
	$cReturnIds = 0
	$pReturnIds = 0

	$hrRet = $Win32::SLGetSLIDList(
		$hSLC,
		0,
		[ref][Guid]$AppId,
		1,
		[ref]$cReturnIds,
		[ref]$pReturnIds
	)

	if ($hrRet -NE 0 -Or $cReturnIds -EQ 0)
	{
		return
	}

	$a1List = @()
	$a2List = @()
	$a3List = @()
	$a4List = @()

	foreach ($i in 0..($cReturnIds - 1))
	{
		$bytes = New-Object byte[] 16
		$Marshal::Copy([Int64]$pReturnIds + [Int64]16 * $i, $bytes, 0, 16)
		$actid = ([Guid]$bytes).Guid
		$gPPK = SlGetInfoSku $actid "pkeyId"
		$gAdd = SlGetInfoSku $actid "DependsOn"
		if ($All.IsPresent) {
			if ($null -EQ $gPPK -And $null -NE $gAdd) { $a1List += @{id = $actid; pk = $null; ex = $true} }
			if ($null -EQ $gPPK -And $null -EQ $gAdd) { $a2List += @{id = $actid; pk = $null; ex = $false} }
		}
		if ($null -NE $gPPK -And $null -NE $gAdd) { $a3List += @{id = $actid; pk = $gPPK; ex = $true} }
		if ($null -NE $gPPK -And $null -EQ $gAdd) { $a4List += @{id = $actid; pk = $gPPK; ex = $false} }
	}

	return ($a1List + $a2List + $a3List + $a4List)
}

function DetectSubscription
{
	try
	{
		$objSvc = New-Object PSObject
		$wmiSvc = [wmisearcher]"SELECT SubscriptionType, SubscriptionStatus, SubscriptionEdition, SubscriptionExpiry FROM SoftwareLicensingService"
		$wmiSvc.Options.Rewindable = $false
		$wmiSvc.Get() | select -Expand Properties -EA 0 | foreach { $objSvc | Add-Member 8 $_.Name $_.Value }
		$wmiSvc.Dispose()
	}
	catch
	{
		return
	}

	if ($null -EQ $objSvc.SubscriptionType -Or $objSvc.SubscriptionType -EQ 120) {
		return
	}

	if ($objSvc.SubscriptionType -EQ 1) {
		$SubMsgType = "Device based"
	} else {
		$SubMsgType = "User based"
	}

	if ($objSvc.SubscriptionStatus -EQ 120) {
		$SubMsgStatus = "Expired"
	} elseif ($objSvc.SubscriptionStatus -EQ 100) {
		$SubMsgStatus = "Disabled"
	} elseif ($objSvc.SubscriptionStatus -EQ 1) {
		$SubMsgStatus = "Active"
	} else {
		$SubMsgStatus = "Not active"
	}

	$SubMsgExpiry = "Unknown"
	if ($objSvc.SubscriptionExpiry) {
		if ($objSvc.SubscriptionExpiry.Contains("unspecified") -EQ $false) {$SubMsgExpiry = $objSvc.SubscriptionExpiry}
	}

	$SubMsgEdition = "Unknown"
	if ($objSvc.SubscriptionEdition) {
		if ($objSvc.SubscriptionEdition.Contains("UNKNOWN") -EQ $false) {$SubMsgEdition = $objSvc.SubscriptionEdition}
	}

	CONOUT "`nSubscription information:"
	CONOUT "    Type   : $SubMsgType"
	CONOUT "    Status : $SubMsgStatus"
	CONOUT "    Edition: $SubMsgEdition"
	CONOUT "    Expiry : $SubMsgExpiry"
}

function DetectAdbaClient
{
	$propADBA | foreach { set $_ (SlGetInfoSku $licID $_) }
	DetectActType
	CONOUT "`nAD Activation client information:"
	CONOUT "    Object Name: $ADActivationObjectName"
	CONOUT "    Domain Name: $ADActivationObjectDN"
	CONOUT "    CSVLK Extended PID: $ADActivationCsvlkPID"
	CONOUT "    CSVLK Activation ID: $ADActivationCsvlkSkuID"
}

function DetectAvmClient
{
	$propAVMA | foreach { set $_ (SlGetInfoSku $licID $_) }
	CONOUT "`nAutomatic VM Activation client information:"
	if (-Not [String]::IsNullOrEmpty($InheritedActivationId)) {
		CONOUT "    Guest IAID: $InheritedActivationId"
	} else {
		CONOUT "    Guest IAID: Not Available"
	}
	if (-Not [String]::IsNullOrEmpty($InheritedActivationHostMachineName)) {
		CONOUT "    Host machine name: $InheritedActivationHostMachineName"
	} else {
		CONOUT "    Host machine name: Not Available"
	}
	if (-Not [String]::IsNullOrEmpty($InheritedActivationHostDigitalPid2)) {
		CONOUT "    Host Digital PID2: $InheritedActivationHostDigitalPid2"
	} else {
		CONOUT "    Host Digital PID2: Not Available"
	}
	if ($InheritedActivationActivationTime) {
		$IAAT = [DateTime]::FromFileTime($InheritedActivationActivationTime).ToString('yyyy-MM-dd hh:mm:ss tt')
		CONOUT "    Activation time: $IAAT"
	} else {
		CONOUT "    Activation time: Not Available"
	}
}

function DetectKmsHost
{
	$IsKeyManagementService = SlGetInfoSvcApp $strApp 'IsKeyManagementService'
	if (-Not $IsKeyManagementService) {
		return
	}

	if ($Vista -Or $NT5) {
		$regk = $SLKeyPath
	} elseif ($strSLP -EQ $oslp) {
		$regk = $OPKeyPath
	} else {
		$regk = $SPKeyPath
	}
	$KMSListening = strGetRegistry $regk "KeyManagementServiceListeningPort"
	$KMSPublishing = strGetRegistry $regk "DisableDnsPublishing"
	$KMSPriority = strGetRegistry $regk "EnableKmsLowPriority"

	if (-Not $KMSListening) {$KMSListening = 1688}
	if (-Not $KMSPublishing) {$KMSPublishing = "TRUE"} else {$KMSPublishing = BoolToWStr (!$KMSPublishing)}
	if (-Not $KMSPriority) {$KMSPriority = "FALSE"} else {$KMSPriority = BoolToWStr $KMSPriority}

	if ($KMSPublishing -EQ "TRUE") {$KMSPublishing = "Enabled"} else {$KMSPublishing = "Disabled"}
	if ($KMSPriority -EQ "TRUE") {$KMSPriority = "Low"} else {$KMSPriority = "Normal"}

	if ($SLApp)
	{
		$propKMSServer | foreach { set $_ (SlGetInfoApp $strApp $_) }
	}
	else
	{
		$propKMSServer | foreach { set $_ (SlGetInfoService $_) }
	}

	$KMSRequests = $KeyManagementServiceTotalRequests
	$NoRequests = ($null -EQ $KMSRequests) -Or ($KMSRequests -EQ -1) -Or ($KMSRequests -EQ 4294967295)

	CONOUT "`nKey Management Service host information:"
	CONOUT "    Current count: $KeyManagementServiceCurrentCount"
	CONOUT "    Listening on Port: $KMSListening"
	CONOUT "    DNS publishing: $KMSPublishing"
	CONOUT "    KMS priority: $KMSPriority"
	if ($NoRequests) {
		return
	}
	CONOUT "`nKey Management Service cumulative requests received from clients:"
	CONOUT "    Total: $KeyManagementServiceTotalRequests"
	CONOUT "    Failed: $KeyManagementServiceFailedRequests"
	CONOUT "    Unlicensed: $KeyManagementServiceUnlicensedRequests"
	CONOUT "    Licensed: $KeyManagementServiceLicensedRequests"
	CONOUT "    Initial grace period: $KeyManagementServiceOOBGraceRequests"
	CONOUT "    Expired or Hardware out of tolerance: $KeyManagementServiceOOTGraceRequests"
	CONOUT "    Non-genuine grace period: $KeyManagementServiceNonGenuineGraceRequests"
	if ($null -NE $KeyManagementServiceNotificationRequests) {CONOUT "    Notification: $KeyManagementServiceNotificationRequests"}
}

function DetectActType
{
	$VLType = strGetRegistry ($SPKeyPath + '\' + $strApp + '\' + $licID) "VLActivationType"
	if ($null -EQ $VLType) {$VLType = strGetRegistry ($SPKeyPath + '\' + $strApp) "VLActivationType"}
	if ($null -EQ $VLType) {$VLType = strGetRegistry ($SPKeyPath) "VLActivationType"}
	if ($null -EQ $VLType -Or $VLType -GT 3) {$VLType = 0}
	if ($null -NE $VLType) {CONOUT "Configured Activation Type: $($VLActTypes[$VLType])"}
}

function DetectKmsClient
{
	if ($win8) {DetectActType}
	CONOUT "`r"
	if ($LicenseStatus -NE 1) {
		CONOUT "Please activate the product in order to update KMS client information values."
		return
	}

	if ($NT7 -Or $strSLP -EQ $oslp) {
		$propKMSClient | foreach { set $_ (SlGetInfoSku $licID $_) }
		if ($strSLP -EQ $oslp) {$regk = $OPKeyPath} else {$regk = $SPKeyPath}
		$KMSCaching = strGetRegistry $regk "DisableKeyManagementServiceHostCaching"
		if (-Not $KMSCaching) {$KMSCaching = "TRUE"} else {$KMSCaching = BoolToWStr (!$KMSCaching)}
	}

	"ClientMachineID" | foreach { set $_ (SlGetInfoService $_) }

	if ($Vista) {
		$propKMSVista | foreach { set $_ (SlGetInfoService $_) }
		$KeyManagementServicePort = strGetRegistry $SLKeyPath "KeyManagementServicePort"
		$DiscoveredKeyManagementServiceName = strGetRegistry $NSKeyPath "DiscoveredKeyManagementServiceName"
		$DiscoveredKeyManagementServicePort = strGetRegistry $NSKeyPath "DiscoveredKeyManagementServicePort"
	}

	if ([String]::IsNullOrEmpty($KeyManagementServiceName)) {
		$KmsReg = $null
	} else {
		if (-Not $KeyManagementServicePort) {$KeyManagementServicePort = 1688}
		$KmsReg = "Registered KMS machine name: ${KeyManagementServiceName}:${KeyManagementServicePort}"
	}

	if ([String]::IsNullOrEmpty($DiscoveredKeyManagementServiceName)) {
		$KmsDns = "DNS auto-discovery: KMS name not available"
		if ($Vista -And -Not $Admin) {$KmsDns = "DNS auto-discovery: Run the script as administrator to retrieve info"}
	} else {
		if (-Not $DiscoveredKeyManagementServicePort) {$DiscoveredKeyManagementServicePort = 1688}
		$KmsDns = "KMS machine name from DNS: ${DiscoveredKeyManagementServiceName}:${DiscoveredKeyManagementServicePort}"
	}

	if ($null -NE $KMSCaching) {
		if ($KMSCaching -EQ "TRUE") {$KMSCaching = "Enabled"} else {$KMSCaching = "Disabled"}
	}

	if ($strSLP -EQ $wslp -And $NT9) {
		if ([String]::IsNullOrEmpty($DiscoveredKeyManagementServiceIpAddress)) {
			$DiscoveredKeyManagementServiceIpAddress = "not available"
		}
	}

	CONOUT "Key Management Service client information:"
	CONOUT "    Client Machine ID (CMID): $ClientMachineID"
	if ($null -EQ $KmsReg) {
		CONOUT "    $KmsDns"
		CONOUT "    Registered KMS machine name: KMS name not available"
	} else {
		CONOUT "    $KmsReg"
	}
	if ($null -NE $DiscoveredKeyManagementServiceIpAddress) {CONOUT "    KMS machine IP address: $DiscoveredKeyManagementServiceIpAddress"}
	CONOUT "    KMS machine extended PID: $CustomerPID"
	CONOUT "    Activation interval: $VLActivationInterval minutes"
	CONOUT "    Renewal interval: $VLRenewalInterval minutes"
	if ($null -NE $KMSCaching) {CONOUT "    KMS host caching: $KMSCaching"}
	if (-Not [String]::IsNullOrEmpty($KeyManagementServiceLookupDomain)) {CONOUT "    KMS SRV record lookup domain: $KeyManagementServiceLookupDomain"}
}

function GetResult($strSLP, $strApp, $entry)
{
	$licID = $entry.id
	$propPrd | foreach { set $_ (SlGetInfoSku $licID $_) }
	. SlGetInfoLicensing $strApp $licID
	$LicenseStatus = $dwStatus
	$LicReason = $hrReason
	$EvaluationEndDate = $qwValidity
	$gprMnt = $dwGrace

	$pkid = $entry.pk
	$isPPK = $null -NE $pkid

	$add_on = $Name.IndexOf("add-on for", 5)
	if ($add_on -NE -1) {
		$Name = $Name.Substring(0, $add_on + 7)
	}

	$licPHN = "empty"
	if ($Dlv -Or $All.IsPresent) {
		$licPHN = SlGetInfoSku $licID "msft:sl/EUL/PHONE/PUBLIC"
	}

	if ($LicenseStatus -EQ 0 -And !$isPPK) {
		& $isAll
		CONOUT "Name: $Name"
		CONOUT "Description: $Description"
		CONOUT "Activation ID: $licID"
		CONOUT "License Status: Unlicensed"
		if ($licPHN -NE "empty") {
			$gPHN = [String]::IsNullOrEmpty($licPHN) -NE $true
			CONOUT "Phone activatable: $($gPHN.ToString())"
		}
		return
	}

	$winID = ($strApp -EQ $winApp)
	$winPR = ($winID -And -Not $entry.ex)
	$Vista = ($winID -And $NT6 -And -Not $NT7)
	$NT5 = ($strSLP -EQ $wslp -And $winbuild -LT 6001)
	$win8 = ($strSLP -EQ $wslp -And $NT8)
	$reapp = ("Windows", "App")[!$winID]
	$prmnt = ("machine", "product")[!$winPR]

	if ($Description.Contains("VOLUME_KMSCLIENT")) {$cKmsClient = 1; $actTag = "Volume"}
	if ($Description.Contains("TIMEBASED_")) {$cTblClient = 1; $actTag = "Timebased"}
	if ($Description.Contains("VIRTUAL_MACHINE_ACTIVATION")) {$cAvmClient = 1; $actTag = "Automatic VM"}
	if ($null -EQ $cKmsClient -And $Description.Contains("VOLUME_KMS")) {$cKmsServer = 1}

	$gprDay = [Math]::Round($gprMnt/1440)
	$_xpr = ""
	$inGrace = $false
	if ($gprMnt -GT 0) {
		$_xpr = [DateTime]::Now.AddMinutes($gprMnt).ToString('yyyy-MM-dd hh:mm:ss tt')
		$inGrace = $true
	}

	$LicenseMsg = "Time remaining: $gprMnt minute(s) ($gprDay day(s))"
	if ($LicenseStatus -EQ 0) {
		$LicenseInf = "Unlicensed"
		$LicenseMsg = $null
	}
	if ($LicenseStatus -EQ 1) {
		$LicenseInf = "Licensed"
		if ($gprMnt -EQ 0) {
			$LicenseMsg = $null
			$ExpireMsg = "The $prmnt is permanently activated."
		} else {
			$LicenseMsg = "$actTag activation expiration: $gprMnt minute(s) ($gprDay day(s))"
			if ($inGrace) {$ExpireMsg = "$actTag activation will expire $_xpr"}
		}
	}
	if ($LicenseStatus -EQ 2) {
		$LicenseInf = "Initial grace period"
		if ($inGrace) {$ExpireMsg = "$LicenseInf ends $_xpr"}
	}
	if ($LicenseStatus -EQ 3) {
		$LicenseInf = "Additional grace period (KMS license expired or hardware out of tolerance)"
		if ($inGrace) {$ExpireMsg = "Additional grace period ends $_xpr"}
	}
	if ($LicenseStatus -EQ 4) {
		$LicenseInf = "Non-genuine grace period"
		if ($inGrace) {$ExpireMsg = "$LicenseInf ends $_xpr"}
	}
	if ($LicenseStatus -EQ 5 -And -Not $NT5) {
		$LicenseReason = '0x{0:X}' -f $LicReason
		$LicenseInf = "Notification"
		$LicenseMsg = "Notification Reason: $LicenseReason"
		if ($LicenseReason -EQ "0xC004F00F") {if ($null -NE $cKmsClient) {$LicenseMsg = $LicenseMsg + " (KMS license expired)."} else {$LicenseMsg = $LicenseMsg + " (hardware out of tolerance)."}}
		if ($LicenseReason -EQ "0xC004F200") {$LicenseMsg = $LicenseMsg + " (non-genuine)."}
		if ($LicenseReason -EQ "0xC004F009" -Or $LicenseReason -EQ "0xC004F064") {$LicenseMsg = $LicenseMsg + " (grace time expired)."}
	}
	if ($LicenseStatus -GT 5 -Or ($LicenseStatus -GT 4 -And $NT5)) {
		$LicenseInf = "Unknown"
		$LicenseMsg = $null
	}
	if ($LicenseStatus -EQ 6 -And -Not $Vista -And -Not $NT5) {
		$LicenseInf = "Extended grace period"
		if ($inGrace) {$ExpireMsg = "$LicenseInf ends $_xpr"}
	}

	if ($isPPK) {
		$propPkey | foreach { set $_ (SlGetInfoPKey $pkid $_) }
	}

	if ($winPR -And $isPPK -And -Not $NT8) {
		$uxd = SlGetInfoSku $licID 'UXDifferentiator'
		$script:primary += @{
			aid = $licID;
			ppk = $PartialProductKey;
			chn = $Channel;
			lst = $LicenseStatus;
			lcr = $LicReason;
			ged = $gprMnt;
			evl = $EvaluationEndDate;
			dff = $uxd
		}
	}

	if ($IID -And $isPPK) {
		$OfflineInstallationId = SlGetInfoIID $licID
	}

	if ($Dlv) {
		if ($win8)
		{
			$RemainingSkuReArmCount = SlGetInfoSku $licID 'RemainingRearmCount'
			$RemainingAppReArmCount = SlGetInfoApp $strApp 'RemainingRearmCount'
		}
		else
		{
			if (($winID -And $NT7) -Or $strSLP -EQ $oslp)
			{
				$RemainingSLReArmCount = SlGetInfoApp $strApp 'RemainingRearmCount'
			}
			else
			{
				$RemainingSLReArmCount = SlGetInfoService 'RearmCount'
			}
		}
		if ($null -EQ $TrustedTime)
		{
			$TrustedTime = SlGetInfoSvcApp $strApp 'TrustedTime'
		}
	}

	& $isAll
	CONOUT "Name: $Name"
	CONOUT "Description: $Description"
	CONOUT "Activation ID: $licID"
	if ($null -NE $DigitalPID) {CONOUT "Extended PID: $DigitalPID"}
	if ($null -NE $DigitalPID2 -And $Dlv) {CONOUT "Product ID: $DigitalPID2"}
	if ($null -NE $OfflineInstallationId -And $IID) {CONOUT "Installation ID: $OfflineInstallationId"}
	if ($null -NE $Channel) {CONOUT "Product Key Channel: $Channel"}
	if ($null -NE $PartialProductKey) {CONOUT "Partial Product Key: $PartialProductKey"}
	CONOUT "License Status: $LicenseInf"
	if ($null -NE $LicenseMsg) {CONOUT "$LicenseMsg"}
	if ($LicenseStatus -NE 0 -And $EvaluationEndDate) {
		$EED = [DateTime]::FromFileTimeUtc($EvaluationEndDate).ToString('yyyy-MM-dd hh:mm:ss tt')
		CONOUT "Evaluation End Date: $EED UTC"
	}
	if ($LicenseStatus -NE 1 -And $licPHN -NE "empty") {
		$gPHN = [String]::IsNullOrEmpty($licPHN) -NE $true
		CONOUT "Phone activatable: $($gPHN.ToString())"
	}
	if ($Dlv) {
		if ($null -NE $RemainingSLReArmCount) {
			CONOUT "Remaining $reapp rearm count: $RemainingSLReArmCount"
		}
		if ($null -NE $RemainingSkuReArmCount) {
			CONOUT "Remaining $reapp rearm count: $RemainingAppReArmCount"
			CONOUT "Remaining SKU rearm count: $RemainingSkuReArmCount"
		}
		if ($LicenseStatus -NE 0 -And $TrustedTime) {
			$TTD = [DateTime]::FromFileTime($TrustedTime).ToString('yyyy-MM-dd hh:mm:ss tt')
			CONOUT "Trusted time: $TTD"
		}
	}
	if (!$isPPK) {
		return
	}

	if ($win8 -And $VLActivationType -EQ 1) {
		DetectAdbaClient
		$cKmsClient = $null
	}

	if ($winID -And $null -NE $cAvmClient) {
		DetectAvmClient
	}

	$chkSub = ($winPR -And $isSub)

	$chkSLS = ($null -NE $cKmsClient -Or $null -NE $cKmsServer -Or $chkSub)

	if (!$chkSLS) {
		if ($null -NE $ExpireMsg) {CONOUT "`n    $ExpireMsg"}
		return
	}

	if ($null -NE $cKmsClient) {
		DetectKmsClient
	}

	if ($null -NE $cKmsServer) {
		if ($null -NE $ExpireMsg) {CONOUT "`n    $ExpireMsg"}
		DetectKmsHost
	} else {
		if ($null -NE $ExpireMsg) {CONOUT "`n    $ExpireMsg"}
	}

	if ($chkSub) {
		DetectSubscription
	}

}

function ParseList($strSLP, $strApp, $arrList)
{
	foreach ($entry in $arrList)
	{
		GetResult $strSLP $strApp $entry
		CONOUT "$line3"
		& $noAll
	}
}
#endregion

#region vNextDiag
if ($PSVersionTable.PSVersion.Major -Lt 3)
{
	function ConvertFrom-Json
	{
		[CmdletBinding()]
		Param(
			[Parameter(ValueFromPipeline=$true)][Object]$item
		)
		[void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
		$psjs = New-Object System.Web.Script.Serialization.JavaScriptSerializer
		Return ,$psjs.DeserializeObject($item)
	}
	function ConvertTo-Json
	{
		[CmdletBinding()]
		Param(
			[Parameter(ValueFromPipeline=$true)][Object]$item
		)
		[void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
		$psjs = New-Object System.Web.Script.Serialization.JavaScriptSerializer
		Return $psjs.Serialize($item)
	}
}

function PrintModePerPridFromRegistry
{
	$vNextRegkey = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\Licensing\LicensingNext"
	$vNextPrids = Get-Item -Path $vNextRegkey -ErrorAction SilentlyContinue | Select-Object -ExpandProperty 'property' -ErrorAction SilentlyContinue | Where-Object -FilterScript {$_.ToLower() -like "*retail" -or $_.ToLower() -like "*volume"}
	If ($null -Eq $vNextPrids)
	{
		CONOUT "`nNo registry keys found."
		Return
	}
	CONOUT "`r"
	$vNextPrids | ForEach `
	{
		$mode = (Get-ItemProperty -Path $vNextRegkey -Name $_).$_
		Switch ($mode)
		{
			2 { $mode = "vNext"; Break }
			3 { $mode = "Device"; Break }
			Default { $mode = "Legacy"; Break }
		}
		CONOUT "$_ = $mode"
	}
}

function PrintSharedComputerLicensing
{
	$scaRegKey = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
	$scaValue = Get-ItemProperty -Path $scaRegKey -ErrorAction SilentlyContinue | Select-Object -ExpandProperty "SharedComputerLicensing" -ErrorAction SilentlyContinue
	$scaRegKey2 = "HKLM:\SOFTWARE\Microsoft\Office\16.0\Common\Licensing"
	$scaValue2 = Get-ItemProperty -Path $scaRegKey2 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty "SharedComputerLicensing" -ErrorAction SilentlyContinue
	$scaPolicyKey = "HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Common\Licensing"
	$scaPolicyValue = Get-ItemProperty -Path $scaPolicyKey -ErrorAction SilentlyContinue | Select-Object -ExpandProperty "SharedComputerLicensing" -ErrorAction SilentlyContinue
	If ($null -Eq $scaValue -And $null -Eq $scaValue2 -And $null -Eq $scaPolicyValue)
	{
		CONOUT "`nNo registry keys found."
		Return
	}
	$scaModeValue = $scaValue -Or $scaValue2 -Or $scaPolicyValue
	If ($scaModeValue -Eq 0)
	{
		$scaMode = "Disabled"
	}
	If ($scaModeValue -Eq 1)
	{
		$scaMode = "Enabled"
	}
	CONOUT "`nStatus: $scaMode"
	CONOUT "`r"
	$tokenFiles = $null
	$tokenPath = "${env:LOCALAPPDATA}\Microsoft\Office\16.0\Licensing"
	If (Test-Path $tokenPath)
	{
		$tokenFiles = Get-ChildItem -Path $tokenPath -Filter "*authString*" -Recurse | Where-Object { !$_.PSIsContainer }
	}
	If ($null -Eq $tokenFiles -Or $tokenFiles.Length -Eq 0)
	{
		CONOUT "No tokens found."
		Return
	}
	$tokenFiles | ForEach `
	{
		$tokenParts = (Get-Content -Encoding Unicode -Path $_.FullName).Split('_')
		$output = New-Object PSObject
		$output | Add-Member 8 'ACID' $tokenParts[0];
		$output | Add-Member 8 'User' $tokenParts[3];
		$output | Add-Member 8 'NotBefore' $tokenParts[4];
		$output | Add-Member 8 'NotAfter' $tokenParts[5];
		Write-Output $output
	}
}

function PrintLicensesInformation
{
	Param(
		[ValidateSet("NUL", "Device")]
		[String]$mode
	)
	If ($mode -Eq "NUL")
	{
		$licensePath = "${env:LOCALAPPDATA}\Microsoft\Office\Licenses"
	}
	ElseIf ($mode -Eq "Device")
	{
		$licensePath = "${env:PROGRAMDATA}\Microsoft\Office\Licenses"
	}
	$licenseFiles = $null
	If (Test-Path $licensePath)
	{
		$licenseFiles = Get-ChildItem -Path $licensePath -Recurse | Where-Object { !$_.PSIsContainer }
	}
	If ($null -Eq $licenseFiles -Or $licenseFiles.Length -Eq 0)
	{
		CONOUT "`nNo licenses found."
		Return
	}
	$licenseFiles | ForEach `
	{
		$license = (Get-Content -Encoding Unicode $_.FullName | ConvertFrom-Json).License
		$decodedLicense = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($license)) | ConvertFrom-Json
		$licenseType = $decodedLicense.LicenseType
		If ($null -Ne $decodedLicense.ExpiresOn)
		{
			$expiry = [System.DateTime]::Parse($decodedLicense.ExpiresOn, $null, 'AdjustToUniversal')
		}
		Else
		{
			$expiry = New-Object System.DateTime
		}
		$licenseState = "Grace"
		If ((Get-Date) -Gt (Get-Date $decodedLicense.Metadata.NotAfter))
		{
			$licenseState = "RFM"
		}
		ElseIf ((Get-Date) -Lt (Get-Date $expiry))
		{
			$licenseState = "Licensed"
		}
		$output = New-Object PSObject
		$output | Add-Member 8 'File' $_.PSChildName;
		$output | Add-Member 8 'Version' $_.Directory.Name;
		$output | Add-Member 8 'Type' "User|${licenseType}";
		$output | Add-Member 8 'Product' $decodedLicense.ProductReleaseId;
		$output | Add-Member 8 'Acid' $decodedLicense.Acid;
		If ($mode -Eq "Device") { $output | Add-Member 8 'DeviceId' $decodedLicense.Metadata.DeviceId; }
		$output | Add-Member 8 'LicenseState' $licenseState;
		$output | Add-Member 8 'EntitlementStatus' $decodedLicense.Status;
		$output | Add-Member 8 'EntitlementExpiration' ("N/A", $decodedLicense.ExpiresOn)[!($null -eq $decodedLicense.ExpiresOn)];
		$output | Add-Member 8 'ReasonCode' ("N/A", $decodedLicense.ReasonCode)[!($null -eq $decodedLicense.ReasonCode)];
		$output | Add-Member 8 'NotBefore' $decodedLicense.Metadata.NotBefore;
		$output | Add-Member 8 'NotAfter' $decodedLicense.Metadata.NotAfter;
		$output | Add-Member 8 'NextRenewal' $decodedLicense.Metadata.RenewAfter;
		$output | Add-Member 8 'TenantId' ("N/A", $decodedLicense.Metadata.TenantId)[!($null -eq $decodedLicense.Metadata.TenantId)];
		#$output.PSObject.Properties | foreach { $ht = @{} } { $ht[$_.Name] = $_.Value } { $output = $ht | ConvertTo-Json }
		Write-Output $output
	}
}

function vNextDiagRun
{
	$fNUL = ([IO.Directory]::Exists("${env:LOCALAPPDATA}\Microsoft\Office\Licenses")) -and ([IO.Directory]::GetFiles("${env:LOCALAPPDATA}\Microsoft\Office\Licenses", "*", 1).Length -GT 0)
	$fDev = ([IO.Directory]::Exists("${env:PROGRAMDATA}\Microsoft\Office\Licenses")) -and ([IO.Directory]::GetFiles("${env:PROGRAMDATA}\Microsoft\Office\Licenses", "*", 1).Length -GT 0)
	$rPID = $null -NE (GP "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\Licensing\LicensingNext" -EA 0 | select -Expand 'property' -EA 0 | where -Filter {$_.ToLower() -like "*retail" -or $_.ToLower() -like "*volume"})
	$rSCA = $null -NE (GP "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" -EA 0 | select -Expand "SharedComputerLicensing" -EA 0)
	$rSCL = $null -NE (GP "HKLM:\SOFTWARE\Microsoft\Office\16.0\Common\Licensing" -EA 0 | select -Expand "SharedComputerLicensing" -EA 0)

	if (($fNUL -Or $fDev -Or $rPID -Or $rSCA -Or $rSCL) -EQ $false) {
		Return
	}

	& $isAll
	CONOUT "$line2"
	CONOUT "===                  Office vNext Status                 ==="
	CONOUT "$line2"
	CONOUT "`n========== Mode per ProductReleaseId =========="
	PrintModePerPridFromRegistry
	CONOUT "`n========== Shared Computer Licensing =========="
	PrintSharedComputerLicensing
	CONOUT "`n========== vNext licenses ==========="
	PrintLicensesInformation -Mode "NUL"
	CONOUT "`n========== Device licenses =========="
	PrintLicensesInformation -Mode "Device"
	CONOUT "$line3"
	CONOUT "`r"
}
#endregion

#region clic

<#
;;; Source: https://github.com/asdcorp/clic
;;; Powershell port: abbodi1406

Copyright 2023 asdcorp

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>

function InitializeDigitalLicenseCheck
{
	$CAB = [System.Reflection.Emit.CustomAttributeBuilder]

	$ICom = $Module.DefineType('EUM.IEUM', 'Public, Interface, Abstract, Import')
	$ICom.SetCustomAttribute($CAB::new([System.Runtime.InteropServices.ComImportAttribute].GetConstructor(@()), @()))
	$ICom.SetCustomAttribute($CAB::new([System.Runtime.InteropServices.GuidAttribute].GetConstructor(@([String])), @('F2DCB80D-0670-44BC-9002-CD18688730AF')))
	$ICom.SetCustomAttribute($CAB::new([System.Runtime.InteropServices.InterfaceTypeAttribute].GetConstructor(@([Int16])), @([Int16]1)))

	1..4 | % { [void]$ICom.DefineMethod('VF'+$_, 'Public, Virtual, HideBySig, NewSlot, Abstract', 'Standard, HasThis', [Void], @()) }
	[void]$ICom.DefineMethod('AcquireModernLicenseForWindows', 1478, 33, [Int32], @([Int32], [Int32].MakeByRefType()))

	$IEUM = $ICom.CreateType()
}

function PrintStateData
{
	$pwszStateData = 0
	$cbSize = 0

	if ($Win32::SLGetWindowsInformation(
		"Security-SPP-Action-StateData",
		[ref]$null,
		[ref]$cbSize,
		[ref]$pwszStateData
	)) {
		return $FALSE
	}

	[string[]]$pwszStateString = $Marshal::PtrToStringUni($pwszStateData) -replace ";", "`n    "
	CONOUT ("    $pwszStateString")

	$Marshal::FreeHGlobal($pwszStateData)
	return $TRUE
}

function PrintLastActivationHResult
{
	$pdwLastHResult = 0
	$cbSize = 0

	if ($Win32::SLGetWindowsInformation(
		"Security-SPP-LastWindowsActivationHResult",
		[ref]$null,
		[ref]$cbSize,
		[ref]$pdwLastHResult
	)) {
		return $FALSE
	}

	CONOUT ("    LastActivationHResult=0x{0:x8}" -f $Marshal::ReadInt32($pdwLastHResult))

	$Marshal::FreeHGlobal($pdwLastHResult)
	return $TRUE
}

function PrintLastActivationTime
{
	$pqwLastTime = 0
	$cbSize = 0

	if ($Win32::SLGetWindowsInformation(
		"Security-SPP-LastWindowsActivationTime",
		[ref]$null,
		[ref]$cbSize,
		[ref]$pqwLastTime
	)) {
		return $FALSE
	}

	$actTime = $Marshal::ReadInt64($pqwLastTime)
	if ($actTime -ne 0) {
		CONOUT ("    LastActivationTime={0}" -f [DateTime]::FromFileTimeUtc($actTime).ToString("yyyy/MM/dd:HH:mm:ss"))
	}

	$Marshal::FreeHGlobal($pqwLastTime)
	return $TRUE
}

function PrintIsWindowsGenuine
{
	$dwGenuine = 0

	if ($Win32::SLIsWindowsGenuineLocal([ref]$dwGenuine)) {
		return $FALSE
	}

	if ($dwGenuine -lt 5) {
		CONOUT ("    IsWindowsGenuine={0}" -f $ppwszGenuineStates[$dwGenuine])
	} else {
		CONOUT ("    IsWindowsGenuine={0}" -f $dwGenuine)
	}

	return $TRUE
}

function PrintDigitalLicenseStatus
{
	try {
		. InitializeDigitalLicenseCheck
		$ComObj = New-Object -Com EditionUpgradeManagerObj.EditionUpgradeManager
	} catch {
		return $FALSE
	}

	$parameters = 1, $null

	if ([EUM.IEUM].GetMethod("AcquireModernLicenseForWindows").Invoke($ComObj, $parameters)) {
		return $FALSE
	}

	$dwReturnCode = $parameters[1]
	[bool]$bDigitalLicense = $FALSE

	$bDigitalLicense = (($dwReturnCode -ge 0) -and ($dwReturnCode -ne 1))
	CONOUT ("    IsDigitalLicense={0}" -f (BoolToWStr $bDigitalLicense))

	return $TRUE
}

function PrintSubscriptionStatus
{
	$dwSupported = 0

	if ($winbuild -ge 15063) {
		$pwszPolicy = "ConsumeAddonPolicySet"
	} else {
		$pwszPolicy = "Allow-WindowsSubscription"
	}

	if ($Win32::SLGetWindowsInformationDWORD($pwszPolicy, [ref]$dwSupported)) {
		return $FALSE
	}

	CONOUT ("    SubscriptionSupportedEdition={0}" -f (BoolToWStr $dwSupported))

	$pStatus = $Marshal::AllocHGlobal($Marshal::SizeOf([Type]$SubStatus))
	if ($Win32::ClipGetSubscriptionStatus([ref]$pStatus)) {
		return $FALSE
	}

	$sStatus = [Activator]::CreateInstance($SubStatus)
	$sStatus = $Marshal::PtrToStructure($pStatus, [Type]$SubStatus)
	$Marshal::FreeHGlobal($pStatus)

	CONOUT ("    SubscriptionEnabled={0}" -f (BoolToWStr $sStatus.dwEnabled))

	if ($sStatus.dwEnabled -eq 0) {
		return $TRUE
	}

	CONOUT ("    SubscriptionSku={0}" -f $sStatus.dwSku)
	CONOUT ("    SubscriptionState={0}" -f $sStatus.dwState)

	return $TRUE
}

function ClicRun
{
	& $isAll
	CONOUT "Client Licensing Check information:"

	$null = PrintStateData
	$null = PrintLastActivationHResult
	$null = PrintLastActivationTime
	$null = PrintIsWindowsGenuine

	if ($DllDigital) {
		$null = PrintDigitalLicenseStatus
	}

	if ($DllSubscription) {
		$null = PrintSubscriptionStatus
	}

	CONOUT "$line3"
	& $noAll
}
#endregion

#region clc
function clcGetExpireKrn
{
	$tData = 0
	$cData = 0
	$bData = 0

	$hrRet = $Win32::SLGetWindowsInformation(
		"Kernel-ExpirationDate",
		[ref]$tData,
		[ref]$cData,
		[ref]$bData
	)

	if ($hrRet -Or !$cData -Or $tData -NE 3)
	{
		return $null
	}

	$year = $Marshal::ReadInt16($bData, 0)
	if ($year -EQ 0 -Or $year -EQ 1601)
	{
		$rData = $null
	}
	else
	{
		$rData = '{0}/{1}/{2}:{3}:{4}:{5}' -f $year, $Marshal::ReadInt16($bData, 2), $Marshal::ReadInt16($bData, 4), $Marshal::ReadInt16($bData, 6), $Marshal::ReadInt16($bData, 8), $Marshal::ReadInt16($bData, 10)
	}

	#$Marshal::FreeHGlobal($bData)
	return $rData
}

function clcGetExpireSys
{
	$kuser = $Marshal::ReadInt64((New-Object IntPtr(0x7FFE02C8)))

	if ($kuser -EQ 0)
	{
		return $null
	}

	$rData = [DateTime]::FromFileTimeUtc($kuser).ToString('yyyy/MM/dd:HH:mm:ss')
	return $rData
}

function clcGetLicensingState($dwState)
{
	if ($dwState -EQ 5) {
		$dwState = 3
	} elseif ($dwState -EQ 3 -Or $dwState -EQ 4 -Or $dwState -EQ 6) {
		$dwState = 2
	} elseif ($dwState -GT 6) {
		$dwState = 4
	}

	$rData = '{0}' -f $ppwszLicensingStates[$dwState]
	return $rData
}

function clcGetGenuineState($AppId)
{
	$dwGenuine = 0

	if ($NT7) {
		$hrRet = $Win32::SLIsWindowsGenuineLocal([ref]$dwGenuine)
	} else {
		$hrRet = $Win32::SLIsGenuineLocal([ref][Guid]$AppId, [ref]$dwGenuine, 0)
	}

	if ($hrRet)
	{
		$dwGenuine = 4
	}

	if ($dwGenuine -LT 5) {
		$rData = '{0}' -f $ppwszGenuineStates[$dwGenuine]
	} else {
		$rData = $dwGenuine
	}
	return $rData
}

function ClcRun
{
	$prs = $script:primary[0]
	if ($null -EQ $prs) {
		return
	}

	$lState = clcGetLicensingState $prs.lst
	$uState = clcGetGenuineState $winApp
	$TbbKrn = clcGetExpireKrn
	$TbbSys = clcGetExpireSys
	if ($null -NE $TbbKrn) {
		$ked = $TbbKrn
	} elseif ($null -NE $TbbSys) {
		$ked = $TbbSys
	}

	& $isAll
	CONOUT "Client Licensing Check information:"

	CONOUT ("    AppId={0}" -f $winApp)
	if ($prs.ged) { CONOUT ("    GraceEndDate={0}" -f ([DateTime]::UtcNow.AddMinutes($prs.ged).ToString('yyyy/MM/dd:HH:mm:ss'))) }
	if ($null -NE $ked) { CONOUT ("    KernelTimebombDate={0}" -f $ked) }
	CONOUT ("    LastConsumptionReason=0x{0:x8}" -f $prs.lcr)
	if ($prs.evl) { CONOUT ("    LicenseExpirationDate={0}" -f ([DateTime]::FromFileTimeUtc($prs.evl).ToString('yyyy/MM/dd:HH:mm:ss'))) }
	CONOUT ("    LicenseState={0}" -f $lState)
	CONOUT ("    PartialProductKey={0}" -f $prs.ppk)
	CONOUT ("    ProductKeyType={0}" -f $prs.chn)
	CONOUT ("    SkuId={0}" -f $prs.aid)
	CONOUT ("    uxDifferentiator={0}" -f $prs.dff)
	CONOUT ("    IsWindowsGenuine={0}" -f $uState)

	CONOUT "$line3"
	& $noAll
}
#endregion

$Host.UI.RawUI.WindowTitle = "Check Activation Status"

if ($All.IsPresent) {
	$B=$Host.UI.RawUI.BufferSize;$B.Height=3000;$Host.UI.RawUI.BufferSize=$B;
	if (!$Pass.IsPresent) {clear;}
}

$SysPath = "$env:SystemRoot\System32"
if (Test-Path "$env:SystemRoot\Sysnative\reg.exe") {
	$SysPath = "$env:SystemRoot\Sysnative"
}

$wslp = "SoftwareLicensingProduct"
$wsls = "SoftwareLicensingService"
$oslp = "OfficeSoftwareProtectionProduct"
$osls = "OfficeSoftwareProtectionService"
$winApp = "55c92734-d682-4d71-983e-d6ec3f16059f"
$o14App = "59a52881-a989-479d-af46-f275c6370663"
$o15App = "0ff1ce15-a989-479d-af46-f275c6370663"
$isSub = ($winbuild -GE 26000) -And (Select-String -Path "$SysPath\wbem\sppwmi.mof" -Encoding unicode -Pattern "SubscriptionType")
$DllDigital = ($winbuild -GE 14393) -And (Test-Path "$SysPath\EditionUpgradeManagerObj.dll")
$DllSubscription = ($winbuild -GE 14393) -And (Test-Path "$SysPath\Clipc.dll")
$VLActTypes = @("All", "AD", "KMS", "Token")
$OPKeyPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\OfficeSoftwareProtectionPlatform"
$SPKeyPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform"
$SLKeyPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SL"
$NSKeyPath = "HKEY_USERS\S-1-5-20\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SL"
$propPrd = 'Name', 'Description', 'TrustedTime', 'VLActivationType'
$propPkey = 'PartialProductKey', 'Channel', 'DigitalPID', 'DigitalPID2'
$propKMSServer = 'KeyManagementServiceCurrentCount', 'KeyManagementServiceTotalRequests', 'KeyManagementServiceFailedRequests', 'KeyManagementServiceUnlicensedRequests', 'KeyManagementServiceLicensedRequests', 'KeyManagementServiceOOBGraceRequests', 'KeyManagementServiceOOTGraceRequests', 'KeyManagementServiceNonGenuineGraceRequests', 'KeyManagementServiceNotificationRequests'
$propKMSClient = 'CustomerPID', 'KeyManagementServiceName', 'KeyManagementServicePort', 'DiscoveredKeyManagementServiceName', 'DiscoveredKeyManagementServicePort', 'DiscoveredKeyManagementServiceIpAddress', 'VLActivationInterval', 'VLRenewalInterval', 'KeyManagementServiceLookupDomain'
$propKMSVista  = 'CustomerPID', 'KeyManagementServiceName', 'VLActivationInterval', 'VLRenewalInterval'
$propADBA = 'ADActivationObjectName', 'ADActivationObjectDN', 'ADActivationCsvlkPID', 'ADActivationCsvlkSkuID'
$propAVMA = 'InheritedActivationId', 'InheritedActivationHostMachineName', 'InheritedActivationHostDigitalPid2', 'InheritedActivationActivationTime'
$script:primary = @()
$ppwszGenuineStates = @(
	"SL_GEN_STATE_IS_GENUINE",
	"SL_GEN_STATE_INVALID_LICENSE",
	"SL_GEN_STATE_TAMPERED",
	"SL_GEN_STATE_OFFLINE",
	"SL_GEN_STATE_LAST"
)
$ppwszLicensingStates = @(
	"SL_LICENSING_STATUS_UNLICENSED",
	"SL_LICENSING_STATUS_LICENSED",
	"SL_LICENSING_STATUS_IN_GRACE_PERIOD",
	"SL_LICENSING_STATUS_NOTIFICATION",
	"SL_LICENSING_STATUS_LAST"
)

'cW1nd0ws', 'c0ff1ce15', 'c0ff1ce14', 'ospp14', 'ospp15' | foreach {set $_ @()}

$offsvc = "osppsvc"
if ($NT7 -Or -Not $NT6) {$winsvc = "sppsvc"} else {$winsvc = "slsvc"}

try {gsv $winsvc -EA 1 | Out-Null; $WsppHook = 1} catch {$WsppHook = 0}
try {gsv $offsvc -EA 1 | Out-Null; $OsppHook = 1} catch {$OsppHook = 0}

if (Test-Path "$SysPath\sppc.dll") {
	$SLdll = 'sppc.dll'
} elseif (Test-Path "$SysPath\slc.dll") {
	$SLdll = 'slc.dll'
} else {
	$WsppHook = 0
}

if ($OsppHook -NE 0) {
	$OLdll = (strGetRegistry $OPKeyPath "Path") + 'osppc.dll'
	if (!(Test-Path "$OLdll")) {$OsppHook = 0}
}

if ($WsppHook -NE 0) {
	if ($NT6 -And -Not $NT7 -And -Not $Admin) {
		if ($null -EQ [Diagnostics.Process]::GetProcessesByName("$winsvc")[0].ProcessName) {$WsppHook = 0; CONOUT "`nError: failed to start $winsvc Service.`n"}
	} else {
		try {sasv $winsvc -EA 1} catch {$WsppHook = 0; CONOUT "`nError: failed to start $winsvc Service.`n"}
	}
}

if ($WsppHook -NE 0) {
	. InitializePInvoke $SLdll $false
	$hSLC = 0
	[void]$Win32::SLOpen([ref]$hSLC)

	$cW1nd0ws  = SlGetInfoSLID $winApp
	$c0ff1ce15 = SlGetInfoSLID $o15App
	$c0ff1ce14 = SlGetInfoSLID $o14App
}

if ($cW1nd0ws.Count -GT 0)
{
	echoWindows
	ParseList $wslp $winApp $cW1nd0ws
}
elseif ($NT6)
{
	echoWindows
	CONOUT "Error: product key not found.`n"
}

if ($NT6 -And -Not $NT8) {
	ClcRun
}

if ($NT8) {
	ClicRun
}

$doMSG = 1

if ($c0ff1ce15.Count -GT 0)
{
	CheckOhook
	echoOffice
	ParseList $wslp $o15App $c0ff1ce15
}

if ($c0ff1ce14.Count -GT 0)
{
	echoOffice
	ParseList $wslp $o14App $c0ff1ce14
}

if ($hSLC) {
	[void]$Win32::SLClose($hSLC)
}

if ($OsppHook -NE 0) {
	try {sasv $offsvc -EA 1} catch {$OsppHook = 0; CONOUT "`nError: failed to start $offsvc Service.`n"}
}

if ($OsppHook -NE 0) {
	. InitializePInvoke "$OLdll" $true
	$hSLC = 0
	[void]$Win32::SLOpen([ref]$hSLC)

	$ospp15 = SlGetInfoSLID $o15App
	$ospp14 = SlGetInfoSLID $o14App
}

if ($ospp15.Count -GT 0)
{
	echoOffice
	ParseList $oslp $o15App $ospp15
}

if ($ospp14.Count -GT 0)
{
	echoOffice
	ParseList $oslp $o14App $ospp14
}

if ($hSLC) {
	[void]$Win32::SLClose($hSLC)
}

if ($NT7) {
	vNextDiagRun
}

ReturnScript 0
:sppmgr:

####
$meread = ('
:readme:
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <title>KMS_VL_ALL_AIO</title>
    <style>
        #nav {
            position: absolute;
            top: 0;
            left: 0;
            bottom: 0;
            width: 220px;
            overflow: auto;
        }

        main {
            position: fixed;
            top: 0;
            left: 220px;
            right: 0;
            bottom: 0;
            overflow: auto;
        }

        .innertube {
            margin: 15px;
        }

        * html main {
            height: 100%;
            width: 100%;
        }

        td, h1, h2, h3, h4, h5, p, ul, ol, li {
            page-break-inside: avoid; 
        }
    </style>
  </head>
  <body>
    <main>
        <div class="innertube">

            <h1 id="Overview">KMS_VL_ALL_AIO - Smart Activation Script</h1>
    <ul>
      <li>PowerShell implementation of KMS_VL_ALL_AIO.cmd script, to automate the activation of supported Windows and Office products using local KMS server emulator or an external server.</li>
    </ul>
    <ul>
      <li>Designed to be unattended and smart enough not to override the permanent activation of products (Windows or Office),<br />
      only non-activated products will be KMS-activated (if supported).</li>
    </ul>
    <ul>
      <li>The ultimate feature of this solution when installed, will provide 24/7 activation, whenever the system itself requests it (renewal, reactivation, hardware change, Edition upgrade, new Office...), without needing interaction from the user.</li>
    </ul>
    <ul>
      <li>Some security programs will report infected files due to KMS emulating (see source code near the end),<br />
      this is false-positive, as long as you download the file from the trusted Home Page.</li>
    </ul>
    <ul>
      <li>Home Page:<br />
      <a href="https://forums.mydigitallife.net/posts/838808/" target="_blank">https://forums.mydigitallife.net/posts/838808/</a><br />
      Backup links:<br />
      <a href="https://pastebin.com/cpdmr6HZ" target="_blank">https://pastebin.com/cpdmr6HZ</a><br />
      <a href="https://rentry.co/KMS_VL_ALL" target="_blank">https://rentry.co/KMS_VL_ALL</a></li>
    </ul>
            <hr />
            <br />

            <h2 id="AIO">AIO vs. Traditional</h2>
    <p>The KMS_VL_ALL_AIO fork has these differences and extra features compared to the traditional KMS_VL_ALL:</p>
    <ul>
      <li>Portable all-in-one script, easier to move and distribute alone.</li>
    </ul>
    <ul>
      <li>All options and configurations are accessed via easy-to-use menu.</li>
    </ul>
    <ul>
      <li>Combine all the functions of the traditional scripts (Activate, AutoRenewal-Setup, Check-Activation-Status, setupcomplete).</li>
    </ul>
    <ul>
      <li>Required binary files are embedded in the script (including ReadMeAIO.html itself), using ascii encoder by AveYo.</li>
    </ul>
    <ul>
      <li>The needed files get extracted (decoded) later on-demand.</li>
    </ul>
    <ul>
      <li>Simple text colorization for some menu options (for easier differentiation).</li>
    </ul>
    <ul>
      <li>Auto administrator elevation request.</li>
    </ul>
            <hr />
            <br />

            <h2 id="How">How does it work?</h2>
    <ul>
      <li>Key Management Service (KMS) is a genuine activation method provided by Microsoft for volume licensing customers (organizations, schools or governments).<br />
      The machines in those environments (called KMS clients) activate via the environment KMS host server (authorized Microsoft''s licensing key), not via Microsoft activation servers.
      <div>For more info, see <a href="https://learn.microsoft.com/en-us/previous-versions/tn-archive/ee939272(v=technet.10)#kms-overview" target="_blank">here</a>.</div></li>
    </ul>
    <ul>
      <li>By design, the KMS activation period lasts up to <strong>180 Days</strong> (6 Months) at max, with the ability to renew and reinstate the period at any time.<br />
      With the proper auto renewal configuration, it will be a continuous activation (essentially permanent).</li>
    </ul>
    <ul>
      <li>KMS Emulators (server and client) are sophisticated tools based on the reversed engineered KMS protocol.<br />
      It mimics the KMS server/client communications, and provide a clean activation for the supported KMS clients, without altering or hacking any system files integrity.</li>
    </ul>
    <ul>
      <li>Updates for Windows or Office do not affect or block KMS activation, only a new KMS protocol version will not work with the local emulator.</li>
    </ul>
    <ul>
      <li>The mechanism of <strong>SppExtComObjHook</strong> makes it act as a ready-on-request KMS server, providing instant activation without external scheduled tasks or manual intervention.<br />
      Including auto renewal, auto activation of volume Office afterward, reactivation because of hardware change, date change, windows or office edition change... etc.
      <div>On Windows 7, later installed Office may require initiating the first activation vis OSPP.vbs or the script, or opening Office program.</div></li>
    </ul>
    <ul>
      <li>That feature makes use of the "Image File Execution Options" technique to work, programmed as an Application Verifier custom provider for the system file responsible for the KMS process.<br />
      Hence, OS itself handle the DLL injection, allowing the hook to intercept the KMS activation request and write the response on the fly.
      <div>On Windows 8.1 and later, it also handles the localhost restriction for KMS activation and redirects any local/private IP address as it were external (different stack).</div></li>
    </ul>
    <ul>
      <li>KMS_VL_ALL scripts make use of Windows Management Instrumentation <strong>WMI</strong> utilities, which query the properties and executes the methods of Windows and Office licensing classes,<br />
      providing a native activation processing, which is almost identical to the official VBScript tools slmgr.vbs and ospp.vbs, but in an automated way.</li>
    </ul>
    <ul>
      <li>The script make these changes to the system (if the emulator is used):
      <div>copy or link the file <code>"C:\Windows\System32\SppExtComObjHook.dll"</code><br />
      add the hook registry keys to <code>"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"</code><br />
      add osppsvc.exe keys to <code>"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\OfficeSoftwareProtectionPlatform"</code><br />
      create scheduled task <code>"\Microsoft\Windows\SoftwareProtectionPlatform\SvcTrigger"</code> (on Windows 8 and later)</div></li>
    </ul>
            <hr />
            <br />

            <h2 id="Supported">Supported Products</h2>
    <p>Volume-capable:</p>
    <ul>
      <li>Windows 11:<br />
      Enterprise, Enterprise LTSC, IoT Enterprise LTSC, Enterprise G, Education, Pro, Pro Workstation, Pro Education, Home, Home Single Language, Home China, SE (CloudEdition)</li><br />
      <li>Windows 10:<br />
      Enterprise, Enterprise LTSC/LTSB, IoT Enterprise LTSC (19044.2788 at least), Enterprise G, Education, Pro, Pro Workstation, Pro Education, Home, Home Single Language, Home China</li><br />
      <li>Windows 8.1:<br />
      Enterprise, Pro, Pro with Media Center, Core, Core Single Language, Core China, Pro for Students, Bing, Bing Single Language, Bing China, Embedded Industry Enterprise/Pro/Automotive</li><br />
      <li>Windows 8:<br />
      Enterprise, Pro, Pro with Media Center, Core, Core Single Language, Core China, Embedded Industry Enterprise/Pro</li><br />
      <li>Windows 10/11 on <strong>ARM64</strong> is supported. Windows 8/8.1/10/11 <strong>N editions</strong> variants are also supported (e.g. Pro N)</li><br />
      <li>Windows 7:<br />
      Enterprise /N/E, Professional /N/E, Embedded POSReady/ThinPC</li><br />
      <li>Windows Vista Service Pack 2:<br />
      Enterprise /N, Business /N</li><br />
      <li>Windows Server 2025/2022/2019/2016:<br />
      LTSC editions (Standard, Datacenter, Essentials, Cloud Storage, Azure Core, Datacenter Azure Edition, Server ARM64), Discontinued SAC editions (Standard ACor, Datacenter ACor)</li><br />
      <li>Windows Server 2012 R2:<br />
      Standard, Datacenter, Essentials, Cloud Storage</li><br />
      <li>Windows Server 2012:<br />
      Standard, Datacenter, Essentials, MultiPoint Standard, MultiPoint Premium</li><br />
      <li>Windows Server 2008 R2:<br />
      Standard, Datacenter, Enterprise, MultiPoint, Web, HPC Cluster</li><br />
      <li>Windows Server 2008 Service Pack 2:<br />
      Standard, Datacenter, Enterprise, Web, HPC Cluster, StandardV, DatacenterV, EnterpriseV</li><br />
      <li>Office Volume 2010 / 2013 / 2016 / 2019 / 2021 / 2024</li>
    </ul>
    <p>______________________________</p>
    <p>These editions are only KMS-activatable for <em>45</em> days at max:</p>
    <ul>
      <li>Windows 10/11 Home edition variants</li>
      <li>Windows 8.1 Core edition variants, Pro with Media Center, Pro Student</li>
    </ul>
    <p>These editions are only KMS-activatable for <em>30</em> days at max:</p>
    <ul>
      <li>Windows 8 Core edition variants, Pro with Media Center</li>
    </ul>
    <p>Windows 10/11 Enterprise multi-session:</p>
    <ul>
      <li>This edition is officially supported for Azure Virtual Desktop service</li>
      <li>The edition KMS activation may not work without AVD license</li>
      <li>For more info, see <a href="https://learn.microsoft.com/en-us/azure/virtual-desktop/windows-multisession-faq" target="_blank">here</a></li>
    </ul>
    <p>Notes:</p>
    <ul>
      <li>supported <u>Windows</u> products do not need volume conversion, only the GVLK (KMS key) is needed, which the script will install accordingly.</li>
      <li>KMS activation on Windows 7 has a limitation related to OEM Activation 2.0 and Windows marker. For more info, see <a href="https://support.microsoft.com/en-us/help/942962" target="_blank">here</a> and <a href="https://learn.microsoft.com/en-us/previous-versions/tn-archive/ff793426(v=technet.10)#activation-of-windows-oem-computers" target="_blank">here</a>. To verify the activation possibility before attempting, see <a href="https://forums.mydigitallife.net/posts/1553139/" target="_blank">this</a>.</li>
    </ul>
    <p>______________________________</p>
            <h3>Unsupported Products</h3>
    <ul>
      <li>Office MSI Retail 2010/2013, Office 2010 C2R Retail</li>
      <li>Office UWP (Windows 10/11 Apps)</li>
      <li>Windows editions which do not support KMS activation by design:<br />
      Windows Evaluation Editions<br />
      Windows 7 (Starter, HomeBasic, HomePremium, Ultimate)<br />
      Windows 10/11 (IoT Enterprise, Professional SingleLanguage, Professional China, Cloud "S"... etc)<br />
      Windows Server (Azure Stack HCI, Server Foundation, Storage Server, Home Server 2011... etc)</li>
    </ul>
    <p>______________________________</p>
            <h3>Office C2R =Your license isn''t genuine= notification banner</h3>
    <ul>
      <li>Office Click-to-Run builds (since February 2021) that are activated with KMS checks the existence of the KMS server name in the registry.</li>
      <li>If KMS server is not present, a banner is shown in Office programs notifying that "Office isn''t licensed properly", see <a href="https://i.imgur.com/gLFxssD.png" target="_blank">here</a>.</li>
      <li>Therefore in manual mode, <code>KeyManagementServiceName</code> value containing an internal private-network IP address <strong>172.16.0.2</strong> will be kept in the below registry keys:
      <div><code>HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform</code><br />
      <code>HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform</code></div></li>
      <li>This is perfectly fine to keep, and it does not affect Windows or Office activation.</li>
      <li>For more explanation, see <a href="https://massgrave.dev/office-license-is-not-genuine" target="_blank">here</a>.</li>
    </ul>
            <hr />
            <br />

            <h2 id="OfficeR2V">Office Retail to Volume</h2>
    <p>Office Click-to-Run Retail must be converted to Volume first before it can be activated with KMS</p>
    <p>whether these products are installed from ISO (e.g. ProPlus2019Retail.img) or using Office Deployment Tool.</p>
    <p><b>Starting version 36, the activation script implements automatic license conversion for Office C2R.</b></p>
    <p>Notes:</p>
    <ul>
      <li>Supported Click-to-Run products: Microsoft 365 Apps (Office 365), Office 2013 / 2016 / 2019 / 2021 / 2024</li>
      <li>Activated Office Retail or Subscription products will be skipped from conversion</li>
      <li>Office 365 itself does not have volume licenses, therefore it will be converted to Office Mondo licenses</li>
      <li>Windows 10/11: Office 2016 products will be converted with corresponding Office 2019 licenses (if RTM detected)</li>
      <li>Windows 8.1: Office 2016/2019 products will be converted with corresponding Office 2021 licenses (if RTM detected)</li>
      <li>Office Professional suite will be converted with Office Professional Plus licenses</li>
      <li>Office Home suites will be converted with Office Standard licenses</li>
      <li>Office 2013 products follow the same logic, but handled separately</li>
    </ul>
    <p>Alternatively, if the automatic conversion did not work, or if you prefer to use the standalone converter script:<br />
    <a href="https://forums.mydigitallife.net/posts/1150042/" target="_blank">Office-C2R-Retail2Volume</a></p>
    <p>You can also use other tools that can convert licensing:</p>
    <ul>
      <li><a href="http://otp.landian.vip/" target="_blank">Office Tool Plus</a></li>
      <li><a href="https://forums.mydigitallife.net/posts/1125229/" target="_blank">OfficeRTool</a></li>
    </ul>
            <hr />
            <br />

            <h1 id="Using">How To Use</h1>
    <ul>
      <li>Remove any other KMS solutions.</li>
    </ul>
    <ul>
      <li>Temporary suspend Antivirus realtime protection, or exclude the downloaded file and the extracted folder from scanning to avoid quarantine.</li>
    </ul>
    <ul>
      <li>If you are using <strong>Windows Defender</strong> on Windows 11/10/8.1, the script automatically adds an exclusion for <code>C:\Windows\System32\SppExtComObjHook.dll</code><br />
      therefore, <u>it''s best not to disable Windows Defender</u>, and instead exclude the downloaded file and the extracted folder before running the script(s).</li>
    </ul>
    <ul>
      <li>Extract the downloaded file contents to a simple path without special characters or long spaces.</li>
    </ul>
    <ul>
      <li>Administrator rights are required to run the script.</li>
    </ul>
    <ul>
      <li>KMS_VL_ALL_AIO offer 3 flavors of activation modes.</li>
    </ul>
    <p>You can start the script with any of these methods:</p>
    <ul>
      <li>Run Windows PowerShell as administrator, and execute <strong>KMS_VL_ALL_AIO.ps1</strong></li>
      <li>Right click on <strong>KMS_VL_ALL_AIO.ps1</strong> and choose "Run with PowerShell"</li>
      <li>Run the launcher batch script <strong>KMS_VL_ALL_AIO_run.cmd</strong> as adminstrator</li>
    </ul>
            <hr />
            <br />

            <h2 id="Modes">Activation Modes</h2>
            <br />
            <h3 id="ModesAut">Auto Renewal</h3>
    <p>Recommended mode, where you only need to install the activation emulator once. Afterward, the system itself handles and renew activation per schedule.</p>
    <p>To run this mode:</p>
    <ul>
      <li>from the menu, press <b>2</b> to <strong>Install Activation Auto-Renewal</strong></li>
    </ul>
    <p>If you use Antivirus software, make sure to exclude this file from real-time protection:<br /><code>C:\Windows\System32\SppExtComObjHook.dll</code></p>
    <p>If you later installed Volume Office product(s), it will be auto activated in this mode.</p>
    <p>Additionally, If you want to convert and activate Office C2R, renew the activation, or activate new products:</p>
    <ul>
      <li>from the menu, press <b>1</b> to <strong>Activate [Auto Renewal Mode]</strong></li>
    </ul>
    <p>On Windows 8 and later, the script <em>duplicate</em> inbox system scheduled task <code>SvcRestartTaskLogon</code> to <code>SvcTrigger</code><br />
    this is just a precaution step to insure that the auto renewal period is evaluated and respected, it''s not directly related to activation itself, and you can manually remove it.</p>
    <p>To remove this mode:</p>
    <ul>
      <li>from the menu, press <b>3</b> to <strong>Uninstall Completely</strong></li>
    </ul>
            <p>____________________________________________________________</p>
            <br />

            <h3 id="ModesMan">Manual</h3>
    <p>No remnants mode, where the activation is executed, and then any KMS emulator traces will be cleared from the system.</p>
    <p>To run this mode:</p>
    <ul>
      <li>make sure that auto renewal mode is not installed, or remove it</li>
      <li>from the menu, press <b>1</b> to <strong>Activate [Manual Mode]</strong></li>
    </ul>
    <p>You will have to run the script again to activate newly installed products (e.g. Office) or if Windows edition is switched.</p>
    <p>You will have to run the script again to activate before the KMS activation period expires.</p>
    <p>You can run and activate anytime during that period to renew the period to the max interval.</p>
    <p>If the script is accidentally terminated before it completes the process, run the script again, then:</p>
    <ul>
      <li>from the menu, press <b>3</b> to <strong>Uninstall Completely</strong></li>
    </ul>
            <p>____________________________________________________________</p>
            <br />

            <h3 id="ModesExt">External</h3>
    <p>Standalone mode, where you activate against trusted external KMS server, without using the local KMS emulator.</p>
    <p>The external server can be a web address, or a network IP address (local LAN or VM).</p>
    <p>To run this mode:</p>
    <ul>
      <li>from the menu, press letter <b>E</b> to <strong>Activate [External Mode]</strong></li>
      <li>input or paste the server address, then press Enter</li>
    </ul>
    <p>If you later installed Volume Office product(s), it will be auto activated if the external server is still connected.</p>
    <p>The used server address will be left registered in the system to allow activated products to auto renew against it,<br />
    if the server is no longer available, you will need to run the mode again with a new available server.</p>
    <p>If you want to clear the server registration and traces:</p>
    <ul>
      <li>from the menu, press <b>3</b> to <strong>Uninstall Completely</strong> (this will also clear KMS cache)</li>
    </ul>
            <hr />
            <br />

            <h2 id="OptConf">Configuration Options</h2>
            <br />
            <h3 id="ConfDbg">Enable Debug Mode</h3>
    <p>Debug Mode is not implemented yet.</p>
    <p>______________________________</p>

            <h3 id="ConfAct">Process Windows / Process Office</h3>
    <p>The script is set by default to process and try to activate both Windows and Office.</p>
    <p>However, if you want to turn OFF processing Windows <b>or</b> Office, for whatever reason:</p>
    <ul>
      <li>you afraid it may override permanent activation</li>
      <li>you want to speed up the operation (you have Windows or Office already permanently activated)</li>
      <li>you want to activate Windows or Office later on your terms</li>
    </ul>
    <p>To do that:</p>
    <ul>
      <li>from the menu, press <b>5</b> to change the state to <strong>Process Windows</strong> <b>[No]</b></li>
      <li>from the menu, press <b>6</b> to change the state to <strong>Process Office</strong> <b>[No]</b></li>
    </ul>
    <p>Notice:<br />
    this turn OFF is not very effective if Windows or Office installation is already Volume (GVLK installed),<br />
    because the system itself may try to reach and KMS activate the products, especially on Windows 8 and later.</p>
    <p>______________________________</p>

            <h3 id="ConfC2R">Convert Office C2R-R2V</h3>
    <p>The script is set by default to auto convert detected Office C2R Retail to Volume (except activated Retail products).</p>
    <p>However, if you prefer to turn OFF this function:</p>
    <ul>
      <li>from the menu, press <b>7</b> to change the state to <strong>Convert Office C2R-R2V</strong> <b>[No]</b></li>
    </ul>
    <p>______________________________</p>

            <h3 id="ConfOVR">Override Office C2R vNext</h3>
    <p>The script is set by default to override Office C2R vNext license (subscription or lifetime) or its residue.</p>
    <p>However, if you prefer to turn OFF this function:</p>
    <ul>
      <li>from the menu, press letter <b>V</b> to change the state to <strong>Override Office C2R vNext</strong> <b>[No]</b></li>
    </ul>
    <p>Notice:<br />
    If Office vNext license is detected, the option and state will be highlighted, to draw the user attention</p>
    <p>______________________________</p>

            <h3 id="ConfW10">Skip Windows 10/11 KMS 2038</h3>
    <p>The script is set by default to check and skip Windows activation if KMS 2038 is detected.</p>
    <p>However, if you want to revert to normal KMS activation:</p>
    <ul>
      <li>from the menu, press letter <b>X</b> to change the state to <strong>Skip Windows KMS38</strong> <b>[No]</b></li>
    </ul>
    <p>Notice:<br />
    On Windows 10/11, if <code>SkipKMS38</code> is ON (default), Windows will be processed and only checked, even if <code>Process Windows</code> is No</p>
    <p>______________________________</p>

            <h3 id="ConfDLL">Use Alternative DLL hook</h3>
    <p>The script is set by default to use Avrf-based DLL hook (except for Windows Vista).</p>
    <p>If you prefer to use alternative Debugger-based DLL hook:</p>
    <ul>
      <li>from the menu, press <b>9</b> to change the state to <strong>Use Alternative DLL hook</strong> <b>[Yes]</b></li>
      <li>then, run the desired activation option.</li>
    </ul>
    <p>Notice:<br />
    For AutoRenewal, you only need to enable the option once on installation.<br />
    to switch back to the original hook, you need to Uninstall, change the option to <b>[No]</b>, then Install AutoRenewal again.</p>
            <hr />
            <br />

            <h2 id="OptMisc">Miscellaneous Options</h2>
            <br />
            <h3 id="MiscChk">Check Activation Status</h3>
    <p>Display the licensing status of Microsoft Windows and Office.</p>
    <ul>
      <li>Robust replacement for the legacy [vbs]/[wmi] options</li>
      <li>For features and more info, check <a href="https://massgrave.dev/check_activation_status" target="_blank">here</a></li>
    </ul>
    <p>______________________________</p>

            <h3 id="MiscOEM">Create $OEM$ Folder</h3>
    <p>Create needed folder structure and scripts to use during Windows installation to preactivates the system.</p>
    <p>Afterwards, copy <code>$oem$</code> folder to <code>sources</code> folder in the installation media (ISO/USB).</p>
    <p>If you already use another <strong>setupcomplete.cmd</strong>, copy the 2nd and 3rd lines from the created script to your setupcomplete.cmd</p>
    <p>Notes:</p>
    <ul>
      <li>Created <strong>setupcomplete.cmd</strong> is set by default to execute <strong>KMS_VL_ALL_AIO.ps1</strong> in <em>Auto Renewal</em> mode.</li>
      <li>You can change the command line switches to other modes, and add any configuration switches too.</li>
      <li>Later, if you want to uninstall the project, use the menu option <strong>[3] Uninstall Completely</strong>.</li>
      <li>On Windows 8 and later, running setupcomplete.cmd is disabled if the default installed key for the edition is OEM Channel.</li>
    </ul>
    <p>______________________________</p>

            <h3 id="MiscRed">Read Me</h3>
    <p>Extract and open this ReadMeAIO.html.</p>
            <hr />
            <br />

            <h2 id="OptKMS">Advanced KMS Options</h2>
    <p>You can manually modify these KMS-related options by editing the script with Notepad before running.</p>
    <ul>
      <li>
        <strong>KMS_RenewalInterval</strong>
        <br />
        Set the interval for KMS auto renewal schedule for activated clients (default is 10080 = 7 days)<br />
        this only have much effect on Auto Renewal or External modes<br />
        allowed values in minutes: from 15 to 43200</li>
    </ul>
    <ul>
      <li>
        <strong>KMS_ActivationInterval</strong>
        <br />
        Set the interval for KMS reattempt schedule for unactivated clients (default is 120 = 2 hours)<br />
        this does not affect the overall KMS period (180 Days), or the renewal schedule<br />
        allowed values in minutes: from 15 to 43200</li>
    </ul>
    <ul>
      <li>
        <strong>KMS_HWID</strong>
        <br />
        Set the Hardware Hash for local KMS emulator server (only affect Windows 8.1/10)<br />
        <b>0x</b> prefix is mandatory</li>
    </ul>
    <ul>
      <li>
        <strong>KMS_Port</strong>
        <br />
        Set TCP port for KMS communications</li>
    </ul>
    <p>Tip:<br />
    Advanced users can also edit the script and change the default state of configuration options, or activation modes.
    However, command line switches take precedence over inner options.</p>
            <hr />
            <br />

            <h2 id="Switch">Command line Switches</h2>
    <p>You can use these switches with the powershell script <strong>KMS_VL_ALL_AIO.ps1</strong> or with the launcher batch script <strong>KMS_VL_ALL_AIO_run.cmd</strong></p>
    <p><strong>Activation switches:</strong></p>
    <ul>
      <li>Auto Renewal mode:<br /><code>/a</code></li>
    </ul>
    <ul>
      <li>Manual mode:<br /><code>/m</code></li>
    </ul>
    <ul>
      <li>External mode:<br /><code>/e pseudo.kms.server</code></li>
    </ul>
    <ul>
      <li>Uninstall and remove all:<br /><code>/r</code></li>
    </ul>
    <p><strong>Configuration switches:</strong></p>
    <ul>
      <li>Process Windows only:<br /><code>/w</code></li>
    </ul>
    <ul>
      <li>Process Office only:<br /><code>/o</code></li>
    </ul>
    <ul>
      <li>Turn OFF Office C2R-R2V conversion:<br /><code>/c</code></li>
    </ul>
    <ul>
      <li>Do not override Office C2R vNext:<br /><code>/v</code></li>
    </ul>
    <ul>
      <li>Do not skip Windows 10/11 KMS38:<br /><code>/x</code></li>
    </ul>
    <p><strong>Runtime switches:</strong> </p>
    <ul>
      <li>Silent run:<br /><code>/s</code></li>
    </ul>
    <ul>
      <li>Silent and create simple log:<br /><code>/s /L</code></li>
    </ul>
    <ul>
      <li>Use alternative Debugger-based DLL hook:<br /><code>/z</code></li>
    </ul>
    <ul>
      <li>Check Activation Status:<br /><code>/t</code></li>
    </ul>
    <p><strong>Rules:</strong></p>
    <ul>
      <li>All switches are case-insensitive, works in any order, but must be separated with spaces.</li>
    </ul>
    <ul>
      <li>You can specify Runtime and Configuration switches along with Activation switches.</li>
    </ul>
    <ul>
      <li>If External mode switch <code>/e</code> is specified without server address, it will be changed to Manual or Auto (depending on SppExtComObjHook.dll presence).</li>
    </ul>
    <ul>
      <li>If multiple Activation switches are specified together, the last one takes precedence.</li>
    </ul>
    <ul>
      <li>Uninstall switch <code>/r</code> always takes precedence over Activation switches</li>
    </ul>
    <ul>
      <li>If the Configuration switches are specified without other switches, they only change the corresponding state in Menu.</li>
    </ul>
    <ul>
      <li>If Process Windows/Office switches <code>/o /w</code> are specified together, the last one takes precedence.</li>
    </ul>
    <ul>
      <li>Log switch <code>/L</code> only works with Silent switch <code>/s</code></li>
    </ul>
    <ul>
      <li>If Silent switch <code>/s</code> and/or Debug switch <code>/d</code> are specified without Activation switches, the script will just run activation in Manual or Auto Renewal mode (depending on SppExtComObjHook.dll presence).</li>
    </ul>
    <p><strong>Examples:</strong></p>
    <pre>
<code>
Silent External activation:
KMS_VL_ALL_AIO_run.cmd /s /e pseudo.kms.server

Auto Renewal activation for Windows only:
KMS_VL_ALL_AIO.ps1 /o /w /a

Manual activation in silent mode, do not skip W10 KMS38:
KMS_VL_ALL_AIO.ps1 /m /x /s

Change config options in menu, Process Office only, do not convert C2R-R2V: 
KMS_VL_ALL_AIO.ps1 /o /c

Silent activation (Auto Renewal mode if already installed, otherwise Manual mode):
KMS_VL_ALL_AIO_run.cmd /s

Display activation status and exit:
KMS_VL_ALL_AIO.ps1 /t
</code>
    </pre>
    <p>
      <strong>Remarks:</strong>
    </p>
    <ul>
      <li>In general, powershell or batch scripts do not work well with unusual folder paths and files name, which contain non-ascii and unicode characters, long paths and spaces, or some of these special characters <code>`` ~ ; '' , ! @ % ^ &amp; ( ) [ ] { } + =</code></li>
    </ul>
    <ul>
      <li>By default, even explorer context menu option "Run with Powershell" will fail to execute on some of those paths.</li>
    </ul>
    <ul>
      <li>By default, even explorer context menu option "Run as administrator" will fail to execute on some of those paths.<br />
      In order to fix that, open command prompt as administrator, then copy/paste and execute these commands:</li>
    </ul>
    <pre>
<code>
set _r=^%SystemRoot^%
reg add HKLM\SOFTWARE\Classes\batfile\shell\runas\command /f /v "" /t REG_EXPAND_SZ /d "%_r%\System32\cmd.exe /C \"\"%1\" %*\""
reg add HKLM\SOFTWARE\Classes\cmdfile\shell\runas\command /f /v "" /t REG_EXPAND_SZ /d "%_r%\System32\cmd.exe /C \"\"%1\" %*\""
</code>
    </pre>
            <hr />
            <br />

            <h2 id="Debug">Troubleshooting</h2>
    <p>If the activation failed at first attempt:</p>
    <ul>
      <li>Run the script one more time.</li>
      <li>Reboot the system and try again.</li>
      <li>Verify that Antivirus software is not blocking <code>C:\Windows\SppExtComObjHook.dll</code></li>
      <li>Check System integrity, open command prompt as administrator, and execute these command respectively:<br />
      for Windows 11/10/8.1 only: <code>Dism /online /Cleanup-Image /RestoreHealth</code><br />
      then, for any OS: <code>sfc /scannow</code></li>
    </ul>
    <p>if Auto-Renewal is installed already, but the activation started to fail, run the installation again (option <b>2</b>), or Uninstall Completely then run the installation again.</p>
    <p>For Windows 7, if you have the errors described in <a href="https://support.microsoft.com/en-us/help/4487266" target="_blank">KB4487266</a>, execute the suggested fix.</p>
    <p>If you got Error <strong>0xC004F035</strong> on Windows 7/Vista, it means your Machine is not qualified for KMS activation. For more info, see <a href="https://support.microsoft.com/en-us/help/942962" target="_blank">here</a> and <a href="https://technet.microsoft.com/en-us/library/ff793426(v=ws.10).aspx#activation-of-windows-oem-computers" target="_blank">here</a>.</p>
    <p>If you got Error <strong>0x80040154</strong>, it is mostly related to misconfigured Windows 10/11 KMS38 activation, rearm the system and start over, or revert to Normal KMS.</p>
    <p>If you got Error <strong>0xC004E015</strong>, it is mostly related to misconfigured Office retail to volume conversion, try to reinstall system licenses:<br /><code>cscript //Nologo %SystemRoot%\System32\slmgr.vbs /rilc</code></p>
    <p>If you got one of these Errors on Windows Server, verify that the system is properly converted from Evaluation to Retail/Volume:<br /><strong>0xC004E016</strong> - <strong>0xC004F014</strong> - <strong>0xC004F034</strong></p>
    <p>If you have issues with Office activation, or got undesired or duplicate licenses (e.g. Office 2016 and 2019):</p>
    <ul>
      <li>Download Office Scrubber pack from <a href="https://forums.mydigitallife.net/posts/1466365/" target="_blank">here</a>.</li>
      <li>To get rid of any conflicted licenses, execute <strong>Remove all Licenses</strong> option, then you must start any Office program to repair the licensing.</li>
      <li>You may also try <strong>Uninstall all Keys</strong> option for similar manner.</li>
      <li>If you wish to remove Office and leftovers completely and start clean:<br />
      uninstall Office normally from Control Panel / Programs and Feature<br />
      then run <strong>Scrub ALL</strong> option<br />
      afterward, install new Office.</li>
    </ul>
    <p>Final tip, you may try to rebuild licensing Tokens.dat as suggested in <a href="https://support.microsoft.com/en-us/help/2736303" target="_blank">KB2736303</a> (this will require to repair Office afterward).</p>
            <hr />
            <br />

            <h2 id="Source">Source Code</h2>
            <br />
            <h3 id="srcAvrf">SppExtComObjHookAvrf</h3>
    <p>
      <a href="https://forums.mydigitallife.net/posts/1508167/" target="_blank">https://forums.mydigitallife.net/posts/1508167/</a>
      <br />
      <a href="https://app.box.com/s/mztbabp2n21vvjmk57cl1puel0t088bs" target="_blank">https://app.box.com/s/mztbabp2n21vvjmk57cl1puel0t088bs</a>
    </p>
    <h4 id="visual-studio">Visual Studio:</h4>
    <p>launch shortcut Developer Command Prompt for VS 2017 (or 2019)<br />
    execute:<br />
    <code>MSBuild SppExtComObjHook.sln /p:configuration="Release" /p:platform="Win32"</code><br />
    <code>MSBuild SppExtComObjHook.sln /p:configuration="Release" /p:platform="x64"</code></p>
    <h4 id="mingw-gcc">MinGW GCC:</h4>
    <p>download mingw-w64<br />
    <a href="https://sourceforge.net/projects/mingw-w64/files/i686-8.1.0-release-win32-sjlj-rt_v6-rev0.7z" target="_blank">Windows x86</a><br />
    <a href="https://sourceforge.net/projects/mingw-w64/files/x86_64-8.1.0-release-win32-sjlj-rt_v6-rev0.7z" target="_blank">Windows x64</a><br />
    both can compile 32-bit and 64-bit binaries<br />
    extract and place SppExtComObjHook folder inside mingw32 or mingw64 folder<br />
    run <code>_compile.cmd</code></p>
    <p>______________________________</p>

            <h3 id="srcDebg">SppExtComObjPatcher</h3>
    <h4 id="visual-studio-1">Visual Studio:</h4>
    <p>
      <a href="https://forums.mydigitallife.net/posts/1457558/" target="_blank">https://forums.mydigitallife.net/posts/1457558/</a>
      <br />
      <a href="https://app.box.com/s/mztbabp2n21vvjmk57cl1puel0t088bs" target="_blank">https://app.box.com/s/mztbabp2n21vvjmk57cl1puel0t088bs</a>
    </p>
    <h4 id="mingw-gcc-1">MinGW GCC:</h4>
    <p>
      <a href="https://forums.mydigitallife.net/posts/1462101/" target="_blank">https://forums.mydigitallife.net/posts/1462101/</a>
    </p>
            <hr />
            <br />

            <h2 id="Credits">Credits</h2>
    <p>
      <a href="https://forums.mydigitallife.net/posts/862774" target="_blank">qad</a> - SppExtComObjPatcher, IFEO Debugger.<br />
      <a href="https://forums.mydigitallife.net/posts/1508167/" target="_blank">namazso</a> - SppExtComObjHook, IFEO Avrf custom provider.<br />
      <a href="https://forums.mydigitallife.net/posts/1448556/" target="_blank">Mouri_Naruto</a> - SppExtComObjPatcher-DLL<br />
      <a href="https://forums.mydigitallife.net/posts/1462101/" target="_blank">os51</a> - SppExtComObjPatcher ported to MinGW GCC, Retail/MAK checks examples.<br />
      <a href="https://forums.mydigitallife.net/posts/309737/" target="_blank">MasterDisaster</a> - Original script, WMI methods.<br />
      <a href="https://forums.mydigitallife.net/members/1108726/" target="_blank">Windows_Addict</a> - Features suggestion, ideas, testing, and co-enhancing.<br />
      <a href="https://gist.github.com/ave9858/9fff6af726ba3ddc646285d1bbf37e71" target="_blank">ave9858</a> - CleanOffice.ps1<br />
      <a href="https://github.com/asdcorp/clic" target="_blank">asdcorp</a> - clic tool.<br />
      <a href="https://github.com/AveYo/Compressed2TXT" target="_blank">AveYo</a> - Compressed2TXT ascii encoder.<br />
      <a href="https://forums.mydigitallife.net/members/846864/" target="_blank">NormieLyfe</a> - GVLK categorize, Office checks help.<br />
      <a href="https://forums.mydigitallife.net/members/120394/" target="_blank">rpo</a>, <a href="https://forums.mydigitallife.net/members/2574/" target="_blank">mxman2k</a>, <a href="https://forums.mydigitallife.net/members/58504/" target="_blank">BAU</a>, <a href="https://forums.mydigitallife.net/members/presto1234.647219/" target="_blank">presto1234</a> - scripting suggestions.<br />
      <a href="https://forums.mydigitallife.net/members/80361/" target="_blank">Nucleus</a>, <a href="https://forums.mydigitallife.net/members/104688/" target="_blank">Enthousiast</a>, <a href="https://forums.mydigitallife.net/members/293479/" target="_blank">s1ave77</a>, <a href="https://forums.mydigitallife.net/members/325887/" target="_blank">l33tisw00t</a>, <a href="https://forums.mydigitallife.net/members/77147/" target="_blank">LostED</a>, <a href="https://forums.mydigitallife.net/members/1023044/" target="_blank">Sajjo</a> and MDL Community for interest, feedback, and assistance.</p>
    <p>
      <a href="https://forums.mydigitallife.net/posts/1343297/" target="_blank">abbodi1406</a> - KMS_VL_ALL author</p>

            <h2 id="acknow">Acknowledgements</h2>
    <p>
      <a href="https://forums.mydigitallife.net/forums/51/" target="_blank">MDL forums</a> - the home of the latest and current emulators.<br />
      <a href="https://forums.mydigitallife.net/posts/838505" target="_blank">mikmik38</a> - fixed reversed source of KMSv5 and KMSv6.<br />
      <a href="https://forums.mydigitallife.net/threads/41010/" target="_blank">CODYQX4</a> - easy to use KMSEmulator source.<br />
      <a href="https://forums.mydigitallife.net/threads/50234/" target="_blank">Hotbird64</a> - the resourceful vlmcsd tool, and KMSEmulator source development.<br />
      <a href="https://forums.mydigitallife.net/threads/50949/" target="_blank">cynecx</a> - SECO Injector bypass, SppExtComObj KMS functions.<br />
      <a href="https://forums.mydigitallife.net/posts/856978" target="_blank">deagles</a> - SppExtComObjHook Injector.<br />
      <a href="https://forums.mydigitallife.net/posts/839363" target="_blank">deagles</a> - KMSServerService.<br />
      <a href="https://forums.mydigitallife.net/posts/1475544/" target="_blank">ColdZero</a> - CZ VM System.<br />
      <a href="https://forums.mydigitallife.net/posts/1476097/" target="_blank">ColdZero</a> - KMS ePID Generator.<br />
      <a href="https://forums.mydigitallife.net/posts/838023" target="_blank">kelorgo</a>, <a href="http://forums.mydigitallife.net/posts/838114" target="_blank">bedrock</a> - TAP adapter TunMirror bypass.<br />
      <a href="https://forums.mydigitallife.net/posts/1259604/" target="_blank">mishamosherg</a> - WinDivert FakeClient bypass.<br />
      <a href="https://forums.mydigitallife.net/posts/860489" target="_blank">Duser</a> - KMS Emulator fork.<br />
      <a href="https://forums.mydigitallife.net/threads/67038/" target="_blank">Boops</a> - Tool Ghost KMS (TGK).<br />
      <a href="https://forums.mydigitallife.net/threads/74769/" target="_blank">hearywarlot</a> - Auto Elevate as admin.<br />
      <a href="https://forums.mydigitallife.net/threads/63471/" target="_blank">qewpal</a> - KMS-VL-ALL script.<br />
      ZWT, nosferati87, crony12, FreeStyler, Phazor - KMS Emulator development.</p>
        </div>
    </main>

    <nav id="nav">
        <div class="innertube">
            <a href="#Overview">Overview</a><br />
            <a href="#AIO">AIO vs. Traditional</a><br />
            <a href="#How">How does it work?</a><br />
            <a href="#Supported">Supported Products</a><br />
            <a href="#OfficeR2V">Office Retail to Volume</a><br />
            <a href="#Using">How To Use</a><br /><br />
            <a href="#Modes">Activation Modes</a><br />
            &nbsp;&nbsp;&nbsp;<a href="#ModesAut">Auto Renewal</a><br />
            &nbsp;&nbsp;&nbsp;<a href="#ModesMan">Manual</a><br />
            &nbsp;&nbsp;&nbsp;<a href="#ModesExt">External</a><br /><br />
            <a href="#OptConf">Configuration Options</a><br />
            &nbsp;&nbsp;&nbsp;<a href="#ConfDbg">Debug Mode</a><br />
            &nbsp;&nbsp;&nbsp;<a href="#ConfAct">Activation Choice</a><br />
            &nbsp;&nbsp;&nbsp;<a href="#ConfC2R">Office C2R-R2V</a><br />
            &nbsp;&nbsp;&nbsp;<a href="#ConfOVR">Office C2R vNext</a><br />
            &nbsp;&nbsp;&nbsp;<a href="#ConfW10">KMS38 Win 10/11</a><br />
            &nbsp;&nbsp;&nbsp;<a href="#ConfDLL">Alternative DLL</a><br /><br />
            <a href="#OptMisc">Miscellaneous Options</a><br />
            &nbsp;&nbsp;&nbsp;<a href="#MiscChk">Activation Status</a><br />
            &nbsp;&nbsp;&nbsp;<a href="#MiscOEM">$OEM$ Folder</a><br /><br />
            <a href="#OptKMS">Advanced KMS Options</a><br />
            <a href="#Switch">Command line Switches</a><br />
            <a href="#Debug">Troubleshooting</a><br /><br />
            <a href="#Source">Source Code</a><br />
            <a href="#Credits">Credits</a><br />
        </div>
    </nav>
  </body>
</html>
:readme:
');

####

$payload = ('
:niblld:
$k="``75/}.CdnGfi),`$mucVM{9DXToI?K;vt1hRl@yS0Aw%]N6z<~H->LrZ*gJ^bEQB&48eP+xp2!#|\=[UOF3q(asWjk_Y"; Add-Type -Ty @"
using System.IO;public class BAT91{public static void Dec(ref string[] f,int x,string fo,string key){unchecked{int n=0,c=255,q=0
,v=91,z=f[x].Length; byte[]b91=new byte[256]; while(c>0) b91[c--]=91; while(c<91) b91[key[c]]=(byte)c++; using (FileStream o=new
FileStream(fo,FileMode.Create)){for(int i=0;i!=z;i++){c=b91[f[x][i]]; if(c==91)continue; if(v==91){v=c;}else{v+=c*91;q|=v<<n;if(
(v&8191)>88){n+=13;}else{n+=14;}v=91;do{o.WriteByte((byte)q);q>>=8;n-=8;}while(n>7);}}if(v!=91)o.WriteByte((byte)(q|v<<n));} }}}
"@; function X([int]$x=1){[BAT91]::Dec([ref]$f,$x+1,$d,$k)}

:niblld:
::Y#B)f5``5Y`````Ym`l07```````y7``````````````````````````````````````5Y)```hjhQ/`??~A]0-PG3KK=mrAh6L[P!)n9MyH!2\SNJU<?2jib{g6)!@iW%
::;d+=WT\cHVdXQ)````````??lu;O&D@?L)d]*a1g&,XpWE\%uK[C,/?USVGb#%~e2yaf>|@9p*OV;-IqmIlS4@,o$WS`````````````````76nC``b/1`Xi?+-5``````
::``<PTi=-%7J6/`X```97``````(j,```y7````7`````u`4```y7``~```````767`````````97``y7``w3h`y7``{```u```7```76``J.``````Xi````````````Sz
::F`5Y5```````````````````````````````Fu``]m``Fu*```d`````````````````````````````````````````````````zD7`MX````````````````````````
::``````uutmrf;```g4.```1```uu``76````````````````Xi``P2{lvJ>n``761```5Y``5Y````G7````````````````}`76E>EBQ#o}``E}````{```u```_y````
::````````````y7``~1^vC4=H7`xh7```An``Xi````;```````````````5Y``#.``````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````^-/`uYH`z5@{,#<P.`-`R5YV````76YU.Mw{?^g(tXHAvtb[,ML4f+bSQlj```5YYU0,zVD>,!h@y>?1Q^#,HV%*m$\SSI{[%Q````=KQGvd6Fd3
::uV8p8Eev``*/kR}I4Gi|#wR)QLw}``kPgm~A8ADt>[|T-&SB)?Bl*/4G9={5````(6Dt.303NB]e#})SRJ0=@+3xC```l0\r5zmr04x}7uEl]J0K{=R55YHplM}4gLUH8X
::\RHZ)`V%-PK`97[GCUXinYI`T7````P27`d`K`{7gn-|Fud```(`a}l0C$5`m`^`]7<M?&2UG`H`v5``````````}`V`kn5`2M``7`Oi5Yf5IV5YN7XiX#d+MFGf$~_Wg$
::D=EN5lhP2=?[LE8Z+=B@zFzHzB!+HoP.1H<~EfX41c9m>n^nH/&f/._*eKN;Zh0KYWIzp1CR`(,Uz3q](3b/s&EHv`Z8(W}^cE;&9W.F,/Y4i0Ee`wU2fvmof[h^]6hTP=
::CUc]2bAMITD~H9TjT.jf4quyrm]+$,d,35>UQ=)tCS>#LJE\k$.O_~z*K7>6CKK(Icb$w0BnG^siE{l(@H^KBOW>y&Twj;jDTdBP\t?8A).d`14i_FrQsv[jTy(t(Ws&7*
::8e~)NP#]]7$D+t{NmDvrH(n>n0C!n2]A{*xrg},*[dh,NuraII<NkLD6hmTH~Cqf@UgkOSrfPx&,thPfprW>mL4-(2x~F-`)i]g!j=yup.H-ny(I;]3$(#^F>)ZlF!CQe~
::%jw]V^bK2jFc^z`xdzL(uNwwT6VSVY[2JZ`u>@!k.AZ!jq,>5;9KxVfS^~ghrH{VJs;U6U4A+4RrDi\x+X`)n%lr+&GIerK%69R@^FAzRD[,+4Z|V$^,QE;4VZ{4QTmThj
::j,|imc`X_KlclE)4hlFG%g4UB1@]w+BvyS[,gibef`r%(E0]7lXY*=|n$Z*f4;i#A7^k1US7tX|y%~}TP*2x?W$2b=QaUVV*1t|,bs6\1KOjfX}o)P|wS%CxH)vx4])Qff
::+~0UHav2wI|L4fRV\}!NWV`H9isTH}?.`f$t*DBq.6#_kvH_1Z=t&VD^M]V*8c6U~/H*i8)^{B,h<uo5]LmB*E&PL8V&(o%|;c5E.cX0P]T[\k1Uv}{6}Qs_SE0;`R%k)g
::H)g4[txQk)dfM0wD2C(kO*>VFmp]VB{;e6;-Ln2LV#Q6CY0h<~pqdc\diSt?lgU=tW;;l_D+hT?gLiZ-Cr/r\Z},uRfGva\[]Kd@.t\]JkH~Y*QH1$efh=jZPs~vqiljwe
::eZ$c<WO123W+9W@.B80ckQ#9c1|$nTM>/A{OBQ/Sl1%{0oLY@1r*VE{)!oAe<)8^eHewF$2EJQ(cR8FDw%!0N<5yRH70DN>b)H~zY?9!%VX]6zf3m8I}J<b+]-G~PlI>4Z
::5{H8tEospxH,hO)39XXKC11Yj|_m0i``[GD5``}```~=8%1;mS`roWtF~.0Hb0;kmi-Zrq}^Msrbv`P83~il08yFTHCxPk[wb2x$s=,S7/$.Je>l.\m2kIb@<|gkw4eLR%
::@&(E6Y{|OnnW)Qyoi<pYk5}u@O$I^lc1jr#n0V)^XUB%3p]v4yG?&mQ|oh&@2HEw5$Qc&lMk#$Rb!P86bZHZ0T!Zwez=H.hj3q*{CcPM^S)PpsZ.bRIrB?n+HkKxklG9AO
::m2H%Hr7C?B/j~>a<r>2SJale>v)ILHuNr8#p2J#k|A;WaLmKYBjE)]K5!Wo3HX|0SK$L/qEEc+.h;8E=ew%4;B>%hXVD3ao3`&<di~%r^*jZ16v]l0-6UU[NJ>^J*oz@<z
::;;}a5rqx3]sdPT%~wjqC|/<@f<OH(W(,>fw,)-NOYKu(N_L,_H}/)h@~#B]V{@7)Zzy~6<op@7_i|3y\t>1{0`2k!F(QMmVrD$Wq/LN0%oM>;!YVmc;O.&C~),W/by+DmX
::h\`HG8J$xNN=8%*=|(\oG~}^uh~K#e_i&yPJo_}_AmBoUp@~!qh#SxecbzHwH9IGJ+1H%/{I^\03obDj+>8MT.~r]>ey_dVb[iE-]Gy[.!X3*Xq-JEtk3l.%|9q.B^Y`q*
::^HhR`[VujlBI-;J(~v7#/+kx[||Dmf4-TDoeL#FUk\bj6Xt~#SwVb0AsU1WxTbgAMibre!6e*o]wFe.+T```5YG```/2kEhN]2f}``````rH\^_wX7&/765YRUV~hI?;5`
::````@abF5)[F&MHD4`WvaiB_+H`7``````BY(hu=vY>`%nl0<?+axeCI``````BS5WZLmf{@|5u`W5mwqv<^t`````76%_V$MoZP?Y}dMj#\>jIcsX``````UZV1*t,.sw
::U5$Y?f``,COI``````5YSAhPOqh[GJ%5P05`qfuHG```````o*0=rbtYz,60````V%mc````````fqt2gI*5.G.7LPv#f`k6\/``````76?A{9Q|b-\Xs}````mPe,d```
::````B$~x]T;`T`%n@a}8ba8VoV``````MX(Q&+df{@|5{`.ogM__IXm`````5Y\W]KQZ#U$Y{}!Ai5xkL%gG``````6_$+oN-5.G.7C`NIj,n9`{f`````76,,zAE|@0nY
::%5h,26@NW*cC``````Bp!SzqI7~}36.YW*V>D]8H}`````<PuP[]<(y7wG``_1``c6u7XiAf``%^5`<PL75Yml``<PV`<P]5``Tz/`&MK`<P!~``]</`pU_C``&0``#sf7
::<P1FE5N8rHDQdy;mA#E[Bvm9Y17```86zDCY9`8`</Qowr56)`````2i#FWH\oMz#Z332;t9``e)19x#abaA3$QfA+)n9M````q-yskTM)=Hou-0o7``5Y&pv.WA|$,f6F
::dro^eFphuAtzD*X2zv)BQLe3\Stmrf;`R>Qf33J;]c#FWH$```FuG8u+OSuAa/P1(-7MhV{}ou-02XC=w#id]8~```q-yskTLJ&#0$LA$z>r~+@5``i<,rpMTCMSWAw]Qf
::S+H<C```An-1GO0M|c3i/Se@&/>1a=``<P1FE5N80L1?{R%)?1?`l0-PT`C74nh[@aC6L`%54u,#ph)`g`````7,wr}6$`y`..`1C$~PK`57``9c^-~P,`z`f5uu7656i`
::H```6J&#($*AtmgG{2Od^{P#fyxo+```76r`{5}{44og)`Z`i7!n4476)`Z`R5````C$7`nYI`L5(d}L``}6I`L5(d}L``}6o`L5(d}L``.Y,`I7j/5I5Y56)`I7j/5I)K
::n6D`|`If115Y7`C`T`.7(d}L``}6o`V5zC<P76C`-`````RIL@HP{`}7CCE=)Kd`?`C7Vf[#@anY?```?/d?wrHPX`8`1}!A;o}6;`C7Vf[#@anY?`#`=}!AC$}6K`?7~n
::j\````5Yy`&7Z$*]<D)Y-`S5xch[Ti)`Z`*7tM,#og)`J`Z5.c3Q7`76y`&7Z$*]/Y.6]`*7ji``````````b7H,eI2Ui`A`*7ji*]og}`T`97YVpUogdYV`.7,GTg/Yn6
::D`|`{}L@76C`v`6`J7Fu^-7`,`E`|`{}ml76C`v`6`J7Fu^-7`,`E`|`{}ml76C`v`y`f5rczD/`cYV`.7!nTg/Yn6V`.7!nTg/Yn6V`.7!nTg/Yd```````^-,Ro7````
::K`````````````````````76i/9f````|5``zD5```DU``,#m```5```-^jK!$7po@7!;G@ANz5yuLlB#6r`AWv=dycF~n@bD)ln}x/XB5f-fzYfIf0_Gp41;77`H1IY5Y
::;Gm#.)``Pd~7`l<P[5J.q?aNW.Ph7`{`Jr3ur82276sm$Nm(\P=>D`44+RS!^Ab<Lf}`76*fq,o9J6nC``9$x9``Wv1)uY``TgUpSiA{``Wvbik57`zDR6[DDS``xh[T%F
::bPA~!XJR<pK7|<tC/`76Q}L-/Y4.fn``]m$}q~znijsH$th_4(pU0zJ7``|e4`7`7FTBl```PdwK0ldG1@$w`1kx`C>r99G_9-aHyCpD!gPhQ)A`Y-8E+Yr5[x,O;B<a7;
::mK(~+NT)kC````hG~79$V_zP07F`%RD7lV9J`/3M#x,O;qNw?0fCsg9tD%<bY_ed.65`q~~O*gSc5=LW-|k0++NnautC}xM+;`%Kg47Y`6vwYfwclCZ<H*o>VX_97Y7Y1e
::eL0Osm([ae`~``?.3VRVqgh0!6W\)Oed[65`nz(l&i|qCBJ,vgz\7YDiwc+Y?oz7XidoBQ;/P`)E-bOD)c4`{+`Hg-Zk{-u>@,{KL!dzJxT`1zy_R2b5mP<6iU@#YNkx$9
::u`)=?V=/>JL~A/fCmHP6hrR<p&ZW*B1JwT~4uvNg;b7Yhi</J.gm&_i((|{)\XK22_Yh/dXia5y9SVC~]Kgmi94EIWU/ZD7`@X93WhrP%Mmv(~G.q_DK</J.gm\94E9t=A
::._c-7Y+P/dXia5DeNmm.{Hl_!vQ<p&ZW1>&Nm(5ZG\kd@PX(*fC>\)itE0}cC`5YEw*E+6mcZLw,vKh#^Nrkhfpd![w,=-\/iW7`xh|x&W}cn5nY|O2v`Th>(b;)_WW_hf
::pd?e})=-blCZN3V/-EaCiP>me~f$]1_j4_7Y*T,>tl`dIlc/Ud+H;P7Y`6!]SY/>\)it.s9<hzH```^JkNxnA%ZxRJ{G``*]qy`HGadc5`9eR2@n`*N{M6E}=rB8]NV~?X
::x@@n_\)ocz&xR^rCsT;>TTX5ckhfpdk*U$M6We#Hn)F/mJfKyCJmS{GTbi+O&#<{``Pd7TXH3K*zKyZp8i[_DeN{M6i>\)gnWfm$>P9p>fN9!]y69JondgHkr.0h*]2KCX
::!|o#39nBWeGHg)oTM~K+BE6!_e3_}l{)EovB<]aEchrnatj0fahDk39u-/iD/`zDrnatpPYFZ>XT;>%R6_fqEy&h`Y7Ysm$Nm(CZ+RUC@xXx3PrqU{vN*i0```VC>nn(sj
::w&[D.o``l0T)il``5Yz}[&\jHw`P,N&*GqIk|eJ,1aI-%A,~L|6<rCmX|RIqed365`q~p6Zi_nct>W~OhfEH+Xt`z~H)T.k.SDW>!dg]A\f(YkFW;$*TS.KfKy@p3]WwjX
::C8pu./MH&RJR=3M=Us>W6NATDpqRprG@}+\RIB430ZGqw&]KRe7Y7Yuh$dLvkzG`Y|v=hpz1``FucEK\iR|xqt~N~ZmP5F-WmDozBT@GEBCgTx2#{Gky3x9J2v7*Hkr..9
::31Mi[9ekJ&AunYV=Ek\OahHaMt=9OdHzpbqK5R_xlX%&``Wv<d0nv9gdSM8P$K-5D`5Y!d6Nv#a6;22vZeXl_8f`76>WQNY~!O!;\nX&{zW\?R_!3tZV4$.`zDz<SBw<9u
::,)wIyrt+D.p4lHK(|(VH1X&?y3TBB$IF~~fA#4m+h60Bkhjp,CmHY?<d5dGpl*F!CyoA-pif9FzAsZI+;)vweUCctIn@EEo+6Bi=PulZ*BC~*T#uC~!sW;CXlGZ<rTf#}w
::T?/tpP*H,$hH9T>!)H}leRPa$tR_B[Y(&HhXJR!3WMr~{T@Xlc<k}O<cs>H{?b~i`HD0/iy3~8E{|u>hX50ZGqIkzUE{)E~iLsx1vfpdp<gx>#K#xnxI&TEqq-J,vaQhz4
::*E&_[(M=%z?,U,>.qZC`5Y)/@QKy@pxO#Gp<[j_b~i`HrhJ_BIG@EE;\$w@jPulZ*BsMkxcXke6y7tJ_-F[Vc|PYB#E{TupN++Mt9UrH+*E{.(w8FIl14x/3|,EVVl]Bw%
::7Y7YBIM=V<6!M!?tPulZ*B9t9e7Y`6wkPulZ*BsMkx}zY_7YPuLi<cW4#VVliC2slSjmr_7Y*T[Qn,vw4@Eu<_7Y#VVlJK2sx1vfpdpQ)z{!}w,N4@jm<_7YVX\RIBek}V
::t\BIVtV<>WQNT?yoe*7YzPJ,aN@m_n;}3PnzbLDR}`x&ZW*B6RY~4?<dSn8zATe,?B4kdSJ]Qsm=W%\1U,DN*t|C=G!>!TD/IB8kBX#2V~.XSfHl&lk50VgDq~0P&6!d[N
::.kMt[s.O#g)z4}!NwsPu2R!3sCs9Ca+4`fZme`*Yuv4}4n`*WjnW0B/m@E~iu7dir_BI@;QkLBRB;}udWNkah5@H2diRwsyV?xO6;c*~!diR.kMtt&z}=V,_Rr!^?jJJ!R
::xng^l}5GQyTkPuSrX4QmD5H;)>VHYg<i~c8&DS\1h@idT7tZ*BK$kxWg_e6y@pxO@nlDu;5GuEvw6hJ_BI;$L~}MgisDQrb!Eq;#CD1E~iLsx1/ixdZQ)z{!!;X5-yvfRn
::lDc|L/bR^XQr8zz}[&\jtq_e6y@paR%#j4qjzNqy#p^TzDkddDrwI}%}hYxLnigg|f5`M;Q|^L$>H`a+kdghUU-TunBn769J4#4r7YJ-o]n`1g7```M\!gnYI`iSvNH_81
::UU4.EC``Szw]n`ide4)C|Fu5Xi\3aAEF7YEJUf5`*HgOMLI`m7;G{#[o7`h_Z<`6un]rQlwBPKB_\^vKw.7`@X*\@XD(T`jirpT`eYn-__`6YUP`MXmYStNPpk|<xifqpC
::Msh`NKUUpKun!n76Tu0c5Yy8.s7Y\K].7`?V>7``[_3i$I,`-b2UNw__OAR6=,kn\uC~f<R^3p<G_9}`>/>1]}~XG7J.HTu5Xi*?Pk7YVdFX76{)In}xDbKoyB?j%7Tf[d
::|PsizDGcSwS#RoC`zp^cC`BDWi`Y6DgWh`DBTF!dSh,`._Yj`HLW~vkzc`Y|v=SdhKy.7`*$\153{H_?/iu%SH7`RCop-X*\TX,BT`%RL2Yft_7Y*~aizDL}``<P&}Jv~y
::|CbJ*.~XV|1mr[P`kg&PfH1uNc5YPO&#z67YJ-w]n`RVS~\KE8tG{#[o7`h_Z<`6un]r_m2zk.Xia588Q3>,/`>mWnV3a_7YMON7\<W\FP4vwBD>SQPh@_qXF.ywkvo_q~
::Qh[hOHRBZ3P`kgUpu&1uJc5YPO&#D]7YJ-_]n`>mL%wT2<WNKnHz-XV|1lx}/i5`!zIQ_z7X-`a+irDh~k7YMLFX76{)InHz%m._Yj`HLW~vkzG`LLG/MJQQlC`)!YnIWh
::O(nbyeR<l)25JCWDV6i*``[<uK;#$WFPxW*v)>lz*<qRjU!&%%nX2/2_6g.dXiloX<ZoD?55A7yzV~)Y/)ulvV}NNaW[#p{QD)x5V.|x3PLysauz>dH__Di$zDp-N}V>?J
::In$9EaS701im>fXjCd^;V%RC4T$zx<qfPe?9e$\1Rc9V+h)!DnYGssdL?iRYNE(%(~Du&UE_NDpU2DE#,H/.Wu(l$fWRw7OnWcb*^suLHp3[*}Dg*]@_#\h<p&ZW1TSyrP
::dS=e>C}xF[y7?iZv?FOUK-TH@z`/P}!G{9=pE_cj&`@@^elO;JGRT+BXjx6<{sSPK_m`GGLuxM[3<nra.O6B/O|kha=_/`o5MH#*8k;Q\@LT[!z%w2i5_XO>CcMFO/,RwT
::{gIs$EvDT3+mC>e65IfC0n8EK6y7#hlj|UvOhe^LSRWmO9=3c`]OY~UT<g7YFQ3<YmdGqH`Y6DP9Y_7Yw{P1Q_7YYO~#l`a+UEz_e_7Y>a3.Jk,$``pUoW9*huP_7YY]]_
::7YW\UEnHX/zDlm8{`Y7Y4EBn&1CI``;E4tN9R_7Y<u@```73{HpT-*7YzP63/=wiZ~a+J7Xi6oJrL}kfJ]u0T)Z)5Y9Je#JU7YOudG.!`Y7Y*\6K*(1,E#U3Gs7YDizIQG
::x`*$7`Q.N0~Jv_+6z(Ythwb#l`SzX4RuJ_7Y~yu(=tfC@^2&]j7)hcijefXj}6#&._$A*i31r.fD2```V-sc.hxCNg*o5f.__Yi$zDp-N}1&21xdJeK@Qsq_7Ye]_j9_7Y
::M+r+lugHk6PO4#@\7Yg.pnq~2T[B7Y6Dyw^|a]T?/tfC5d(u!hj]qy#p^TzDkd\fKb@tlBk5qtH_]9$=E]L.46>7>`R*8H!6UP5%)Sc-<Rq0U3=W7Y0n![o,rJ(g7YDicc
::$%INFs-wQN_!Yf(_7Y24_5s&ka2_NrMJV%P0C>3kM+Lpw72[2d4_`1d$U,ywxMl;1(.$gx3i[,Nwkv*W,6!3og8%Tm6+}`m24vmL_%4j7Y*T13/,5`1g]L7Ysv0+q0R`a+
::_d-Hav`YDi=P__7Y9*g?<_7YE#mH2Tpi7Y6DdlK}*9,whh$VRnW_`6EAO_7YYthw@Bl`SzX4Rul_7Y~yu(VlYXvBN7\<@t7@op5J35``;o{nSnk*AuPhRcf<cQ#zTRH`(X
::,>H`y7v{+_7YbR_5J.,7``@aB+||hG8zSbqXF.H.b]}`5Y5|_5J.%71f[A,L7`)ASH7`c#uM7YJ-zNn`RVS~\KhZmG.Y``]Phj|<xifq&dekh`NKUUpKcrqn76Tu0c5Y(j
::537Y\Kr.7`*$\1NPpk|<xifq!C0_h`NKUUpKcran76Tu0c5Yy8(F7Y\K*.7`gb.MY92_!XvZ;_Gp`6un]r(7wB+#}5sMgxpaF..whtc7\<5YVR=q|g9e)`Y-Il)`h6-@W_
::`6{`R`DBTF!dni2_DhfCV}PIW>}M)Nn`idi8Wn}5M5XidH1}zD41;s7Yy$p<5Y{)InHzx$._Yj`HLW~vkzG`Y|v=yp3d-bz7*e7T3UmF_Qbj;p8[0C``E}g@BQyu.^pz?G
::G`)K%ebgk4T?}KfC\GHz{b5IXE<vQKDX$E#QUs=j7Ygy+@fCqgIWU/kD7`}Xjclm[+FtKkK=BccEM!__~T^57`5Y-WQNIsn(Y]IkugCD3,~-N~FXJR?=<1eSC`7`VR)q^g
::3<4gH`}`h__Di$zDp-N}Ixj.XiiH1}zD[.ywv#~mC`it3c*J4_7YbR_5J.,7``@aB+m\RG8zSbqXF.H.Mld`5YTA_5J.%7U1=AUH7`2dNH?#s_`6r[P`kgT?z-c\2|J6C`
::u`ljhf`Y81UU4.fn``SzzNn`ide4)C?,{5XiW4aA<x7YEJii5`*HgO8|-_no%&}`7`aN8ag.~X$D|-u```}IjizD[.ywv#ORC`it3c5A&_7Y<CY5J.~y|CLJ%v[_/sDi.<
::R^wv=aN7\<+YMn81Jl``%xRJqi`YDiR_u`F4G\_qLaP{`YA8&P(>m$|<5Y&i|q^g8B)`DB2leZ1_7Y>Fk.Xi.\J,9oNPR}!CaN~jg.~XV|YhLW8tpPCaVtjj+YAM]xvg_5
::J.2Ih*[A`>7`2dNH}vs_`6#3P`%R<pZm]9H_6e{)Sn]r%)GS5Yn`idi83d>x95XiW4aA{+7YEJXi5`q~,hfCjg9iZx,OF..wttc7p<5YVR=q+gx-)`DB2l{1v_7Y-lk.Xi
::C~rx,OU/2_z_XJbe^LDR}`x&ZWUzo]n`|I-yd[mLJR%j|&Fk+Yno81eR``H1UR``|s^P7YEJ|f5`Z@````#VUIabT?Z-ADn}PI`r))Y5J.%71f[AmZ7`)ASH7`c#N_`YJ-
::l6n`A1>qNw__OAR6&vkn!G[1F~ghfCM}PIW>}M)Nn`idi8Wn}5M5XidH1}zDVfIa7Yy$p<5Y{)In}xx$._Yj`HLW~vQ<p&ZWFF/`F`r3uCO]``)`VfFlfelHW\?RdvZD6B
::`YzPG<W\?RdvZDvPY_xUmR}`x&ZWm?JKuH74LR@jWM!6$GqP?;nka76g5YpD~j`8`T``Tgy>ltNP>;F`%RGxMt?f=G.T>Q$,O4Y~/i!{]^&rDxUadEoA!4xOPdu*w66?i5
::Vc$`Tg&PbIPOKn-HC!/`xhq_60~/J.*EBNT3}L[T.dG```vCkX!To)5`76WLH&GH`JxOnBT$|I``^-1TU```POAgC`iJUD7`<P8S)6oizD~K[J``pUh4cK^.XiT$J;``Fu
::#Uo}%y>IIIfC#G~79b#d|9T?&<WN+Mx7\<8%Tm[+Ft?]K=!i``R^K$sxVA__7Yb8D)FC}xWAWk7YaHyFs_7YX=ZW`YDiha`Y7Y,OX=jF?Y$t&k{M9>I_7YKJ[vE8dGtM~-
::0E\1*qkkFP`rx8kh|xi5WP`Bm=kjal6B[2]1k%+s7YM+LXo#&Yt8yBhjn(^k28XPJ,1nm[n.P~aR342z{UC`Fu-R1Vp~qxvqtM6G{xWsu37Y{Hrg.dXi9t(lnX2bjzua7Y
::#51}q_!>nd/```O3O<K\iRGxwo!+l6BC&Vgkj}4_6g}dXih0]TbMF-I_7YJ|-_~9-Rvglf``gkc-Y_}ls_B5=2#xfA__7YqR.```._u.&_xfocpd2kZQ$,Lr/Ysmb9m(vC
::``c;3t\]~Z+N&V+)u-VH^@qCtCAo+_7Y;B6aJq7`x7dbNxp{[7.`cGW<+_7YfmDKXgri_naSNx%MS~O3o37Y0n$Xi$zD%B^|k6aRxa__7Y-WMf2_Th2X(~_9-RLD]BR%`Y
::6Dh#u\7YOuC~MHZnau5d/Tjx7>|b#T.6S{Gk7YjT<K%BixY_`6q~XPXlIz(_7YJE207YxUFTjj7Ya36q7Y=G`Hx_7Y(at7rh$V3\s_7YMG]R!\\t$V!ZU_7Y}M;NA\guC_
::7YVt-W$GqlMYv`xh766*nd-D76eR1oy7\<n_u.z~loqCi5RH)EiK#-N}JEx0~G#F7Yg.Uf.!W_`6(~688yeVO.N_7YJ|RgX=zR2Xx_7Y~yfCxgIWoqtC\gwTpf9_6g9tc9
::7YDi2_ThfCx5=2ATIV{Cz_7YhIYCZ<3f``f`8[k%``~`,wI~aRra&n{b.M|!7YKo,BY_zP/HeV./]KJE7J7YxUFTOj7Ya3Y-7Y52-~7```GSt_Eq.c5R5TQ}u~GtQ.w_N<
::U_X#</J.&49)\GAo+_7Y;q2_xfocu#c.``;_no7Y<ckN1z(lqRc~k_`6%B5```H_r5U_R.br3~@_#\r>!276smb9m(L}``Czz3<h2dHzb&&}07F~<R<in`(tF;,w``1`!A
::?/,.``.`f-R6^`<P``TC6,(qGyPiH_7YDb#dx27Y|<WNW.g!g_7YF[*H]zj_7Y(|]XPj7Y]KFQP`qH__7Y7>Vtm<`)D5Wp^TzDkdjSzx<cnEBW1EuGCV5Yd\%mf5.`^Bnv
::UUOHk]i/``5BZPe`4`r8%`O+oizD76j9FQ!7NXH```Q_?z`A56%7\<````>dPr>`y7KY``<Puxe`%Rj2P`{+2_NiCdXict_HtCt)Cc>`iNizy`s5J.MjX%C`itUPIkY-%l
::o`h6\Gq_7YNw<jhfl_noKmn_u.B_6_!vQzH`Y|v=QVCD}`#&CDM#!b[_/l}Ru6%7|5,#8@J9^f5`}Y{qnL=X76K=Q/~```,wYDoBu`ljhft_]`CdXiZLAX*\LX-7;2#au`
::BDOA`YDirOh`Y-vz?Yu.-[v!``|sB^7YsvFQX+jgPLyu;)TgY~S-}Ru6%7|5WvlBk5{Jq?1(VrtKt.7`*B1d.7``-|QFuxe`]O2_#ja7~g5Yvvx/h1i}L`5```4vFQPd{`
::gnl/f5=2knHQUiRO>`eYsb3_xU2_6_!vb8pI76sm$NJ9Pd5`5`Wmm.#A^$Q9dR|@l*b._5J.mVm$B<5YK=Q/~```,w8ryaw6%7\<<C_5J.?Tj.XiG2(izDZeC87J7`*3oo
::7YuQ*.BQ;/M`jbbBf2m8jJ7`*35o7Y7YGpwx3i-qN#%7h*MAf`O.Xi.o.*b._5J.}F<?b-N7\<pKnL=X76K=Q/~```,wlo4}Q<5YN}^eG\mR}`x&ZWltlBk51&![T5op``
::Zy5=!hh`1`Vf95hz(izD76%)5(xau`u`*?bgBf5`cl8$f5``db*+0yo9}`vqku#U!X^v*V76(jh#7Y7Y<c-qN#h2Mr$C)K6T<.y*dzQ`s5J.wrG\EqP06TTcJ#s5LmYk*H
::Y-{)=uf~V~~O![h5p<``(B5=c5,#($,xP`%R&Tibk#_]@|MFh`NKmgxc_5J..[w`/```Vnd+v>76ombk8poq\6*./`@aP{Uup~MHA_hf\#xp7Y)#vU2_>)sN>Dx7\<VGF[
::d8Ub7`*3Q97YuQPhV<W\)ON#&)^+he^L0Osm$Nm(Lny.Wz5Y<P4Ectq<Wmf~3~^)9JF.,tEkVGkiwT/bP!Tku`41X5op``Rh}I(izDfp,w9/zsu`0ie?3u``zDVc9h_```
::Ph@_N?(aW_#+N89j7Y)GHQX)3qr`eY=ZF_xU2_}laNW.*.uXjc&2i1bf.\v=yp+B@ttImY#df9T?0<XJ__N6n$zDRBUUf(,G{`KKWXq~ZU@)1g,=5`ZD_N1z(l89rMND4A
::Z./8dzc<>Ra3M}wizDE}TvzPW_B5=2lXV|XR$pW5%D3z5Y#[jCopUPI&a5J.f(N98{V=h_m5AiwTwhx.mGMTXx^g6B?jlX#%``Wvh_[*mC5R)1``fx>#M+GXtofCuiJGr6
::.MI9wTi0fCWgO(?```uz,Gkm5YCvq~s_oqtC\g&PeZ1Gc#hy7`~ENDuXjc[.ywzn/iG5)p&V1g/|5`/t_N1z(l&i|q7cCD*.6QhyBDbg.`CBj_B5=2lX*\/R)N5$]*Q|h6
::%{i`fRq_R.br2zcQd+Tk?0s8VbPY]8f`fRq_R.br2zcQt+TkQhx8Nm~-{H5JGR1#zPqN_Gd~>i``xhzo/t3GXvQ[{)5$./RzW_O1IgPhtCA`DBo<u5.`Ux069fm7``M>(u
::~l_.Xia54{&3`D/`TF.X/`1gg8__Dif7c`ljFs.0OS7`2de25}zDIBQ3gm*cH_YPn$zDRB0pZm%AV|7`KZAC8zaxsP-)o```,t/=2dH4wTP<LR(@Dh,```Lm|A(~</UxFD
::;BE|nka7tg5YN}H6FL{)tZ?BxJgmquhG~7cbsvf5f`\2Y%vw9h&0<6[s76op%Ov?41?fTn)izx-K,C!GG)8t-```L}<PI;,LR#k?``Pd{xSi(mC~`Y,yTfC`ljhfci5}b&
::h1E/2_,y(GC`BD>~C`KKu#_q9_U/.X7`}XZ+&2i1bf.\v=ypo<m5WhX?__$\=R4RrxQiIBqsXu\9n```x.7Y*I^|%m|Y5`Eqf`]BqslXe<``AnSBZ>2I76sm$Nm(?tx.y^
::&r%7WmWFY~r)5RO_$tEk!dODbDLmrjY-FQ&515rDZ#O?|C_C~7-XSU5h(7p27Y%#Bl$xeg+[!```Ph&ko+bK~;F!c`5YQn,CpG#fIswsxUJ,#\tYj.``3Qw<PY(u7y;o~/
::fw``xhJx(4odh#Ni``|ej&@l&CTgY~/i!{y^ow5G~ueNraLm&_TBw%x65)_Nl|yV_j85``{)MiU$16k\;B;j<=`Y%__Dn$zDh3t}xZ*1zwLza{puS~M}rhICi5IeAu5$S~
::yzP5.*vP|@rx1]Tm[+FtKkK=&B{)Hmk%Y~~X/O[_$tj%&}sj<~~XC?FCHz]E/M!]&lp5eRYCr5gx5$S~n<KNWUh```+!scCU74^_;bx6z.RB6a+t.sUE`PL```f(Ykpa;$
::#5fk=hQ_XgsNRox7\<N??R>Iyo|CWC@xu*G>/a@A`=6aH+VtR_\Uo5)}rhs.tC~7jT7_yBd(guT`5Y7)bKL.+1QP08891FtVg]21}K{n0nC<XxKB|(/%`=OB^C$tIjC_c-
::B_!XaN~j#zNS7`^-AuM0NPR}dSFWTB+h6zn2zP-a%XAQ``j\=&Joiol*@2nl316hfCSnlT#Vml2^N[9$[x7YXgm)vDGc&_7Y`6xnPh6zW\v_&3Vd``yhY=4B$C)K6TMovy
::Y~~Xd\>C{xkx_k;B?jwBd!M}PI4r-w[N+Xg@3#CbW9Tk)#]PB)F`%R^X!4(k!UWMx65)_N<3Dj>+j.A|B]lRyBs5V>#O9aDPTFtq2TmHFejkO6qw#x_kJ5Nw=1ka#J;DOu
::YmK%#pl,zDkdnP/mDF5```nnHzl*zUnX>7%7&[i59}1~JQ7Rx3j\FAQzc`Y|v=yplH#de[2_r`U5J.nka7Ig5YqRra3R9$xV./wKFQa}{`D$AaE.I.``R^#&|f=D7`|xpa
::;I-7wZL|h#mb7`h_Z<7YMn%nB/4b4_#$^PoizDHy&H~OJ|h#2b7`h_Z<7Ylk%n9`/d%n8fZm&_lHfoATLQhRljgrN6=f\&&6A[_\wJA`7`bVeI]B4kvZmGUV5YaN8a`6~X
::\OjRwTeUsa%G3<|<Ed0(Ch5i=+TO3LyGXY5Y;G-|;#{)\X0Sr@O\``&_#+7Y@P)v[h0O7cW_VyNetdG3bEE6p^NaT[BS`)`C}*<#50GAlpdCH3_QTFeGRBNaGSYkWDy7\<
::/Mr7n`4ku.7Y9`~/J.>`Sm[+FtKk7SUsBDuV5`5Y6gnRei-mgfl.Jdm7pfXm$5H9zvj/d]7QMd$W`15,Iq749X-|8S{ldbA[s<)KAr(RW3`Y`6dXc7J.m7L|%mV5.`$5vH
::=x<#zPnY1`RYWNB.x7\<#dnilyL@fCsgPhUGA`NK[h?>E}oyo&[t,GAoa_7Y;qNw__a70g5YaN~jC/7Y)Yx7\<VGSm[+Ou@d{`ljv/>g5YaNOUx7\<ArG.f`4kE7?K76aN
::a<x7\<Arw.f`n```````````````````````````````````````````````````````````````````````````86``J.kn``u`````````````````````````<P$``7
::*>[G$+/`[,7```</Wv``|5zD.7!n<Py7Xi````Bp-`865`i`5Y``OGr35Y&.76````?&X5J.{`k```}`>0<P/`s6``5```J.iGzDF`O/``1`Sz/`m`@}5`n```5YRV76x7
::]m``y7Xi~`V5r31`y7````2>C`{K<P5`zD``~/H;``(5zD````-|$7|5f`N```5`yoxh5`0X``7```&MB}XiA`s7``u`{+/Yd`)}7`}```xhjV76O/``76U.XiY|7`}```
::``````````````````````````````````````O&``3/``xh7```hy7`Nn``5Y7```7y7`cG``zD/```;#5`2M``5Y/```g!5`c9``76d```#r.`c6````n```@L.`#.``
::5Y/```?t.`#.``5Y/```3;.`#.``5Y/```NK.`#.``5Y/```Y-.`#.``5Y/```d?.`#.``5Y/```Qo.`#.``5Y/```TT.`#.``5Y/```u~.`#.``5Y/```UD.`#.``5Y/`
::``h6.`gn``5Y/```w9.`gn``5Y/```-%.`0i``5Y/```P0.`0i``5Y/```vS.`0i``5Y/```}{.`0i``5Y/```a@.`D$``5Y/```^V.`D$``5Y/```9c.`.c``5Y/```<l
::.`OM``5Y/```fR.`OM``5Y/```\m.`OM``5Y/```,w.`BD````}```41.`KK````.```rH.`6o``5Y}```pz.`6o``5Y}```j].`6o``5Y}```````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::````````````````````````````````````````````````````````````````````````````````````````````````````````````<P>/``hT7``4A`zDv$``an
::.`;o!7``]J``kA{`zDVd``~-5`y7q```A$``@).`}L#7``aJ``P*{`<PXd``CZ5`NEq`<Pd;``/tf`Fu^/``6I7`l0w`TgL$``Eu.`|5\75Yy^``Jx{`J.Kd``sr5`(X(`
::``````qz5```````````MI7```{`````````````````````````1~5`=K3`76JK``.cf`Wvr/``|T7`h[A`Xil$``ef.`Yq!7``BJ``\<{`Tg{d``w>5`11q`zD`;``c;
::f`pUb/``TI7``1w`Xi-$``Pm.`NE|7``I^``r8{`3QId``6r5`a}(`5Y*$``Jc.`Wv\7``>^``````fe56Tlz)p=~+Qx\cegIQDRHG-nX=LvN8CG@?CTWR/`P2@0{f@FWT
::[BB#}m9A1E>nwZh\rM#F7`bmtoi-|o~IP1Z[cMrMZLQ~DAHAnG``t7BCwF&;%{TBx}MR%)/1o`<7BCwFCWicuCpH,`Fu&DqAzIV1O3VF?8??g?dyq{HD1`n)L[{2-5f8=H
::%How;m+.*p^v?8J`Xi77Z#pH/yTms|Rbw\\c.^%HKlT7q-UZ0M|cQd%Q|So7``=7mJHZA+aTZ4JdI.#s@0e1zq],19NLH!m0\yLraxGML4t8RQ{A|5c6!3(;=c#F($*Atm
::gGd|~vnY/}KTCM)^CQ+T{m~G$3DW[bO&w}*\E-{f7z3xZ4jzRQwoa/FG,G~PJce9VQ|SRyd=K2uLC4b9WHdy*AE[92E55Yy`n)>1zq],he&&}(blnI/15rULk,x#@(\S``
::ti0?8G/[u3{5tMo>pH;uUR~GXiFu]{UH#}$`]mpUkwHZM1(x@5GY/`Tmi1hUevd6C`~vD4.+v.5Yd`~vD4QLf.``G`6MI{^L[}``.`]w6B?^JE~0``+`98m+ou\S$Vq\K`
::xhzDv2oM9Mg```<P]+3xEB~=<D5YszpH]S}l.Y5YszpHrAqR}67`U/;fX==L|{``$`Uv-q3xbc_p#}|5Mj.to=J,[BZ```````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::````````````````````````````````````5`,#````<RDCR><iq^f9nO~/|t%;4*pswJRtgt(!X]R=+[t6{o29%a{<yvh7``zD``(X````i<vVxg5.Q~5VMGP#I-H<tO
::i?5yDIBtenn3>VZ^~Mj5K|;Gb|6J?ce#c!AyP;_B=|Z,|VJE5y61AJwZ^\J8)U8KP}7S{R=.X=,3CM8BGgD9Zs^Z<UJ_TfRRWHZ0.<CXAKP,_MX!jSP35lM*231ThVb6J?
::/wv^;Ve7dor{8|]^&;mV;fZq/t7qo>&!%w(Q(~a]*<!{%=JFtQw|~*Da}N~sUj2!T%K+]n)Wy3V9PO#no5[+^f9sgLd4IC[?2%@!uwDTcoN9`q4?Y<t7!*1WGQ_%+bS-h]
::Y=L[DT{o+9/a`]!.YC(fvja+PN;>z-uNpa;-hY~|9i<P``KN``pUwn?+bd!Iu>=IMljm3S_4`3(crr%x^DX;Yn_2N@_XW07?{@(M8pI6<,mV%*6arr<AiGG#o6t.VCn?4@
::fTMu<H.@AVrJ`i-7!>9G5|GrrPdX$!)yl?&N)fv5EVtbWoKl>shGD\RBy>nX9?[y]hN.>g3xnMo&3gM$Zs*G}[4=BkgY0<yM~8,=DsM7pG6U!ky(D>(}R0G6!7E1]<#M8+
::{m%N+XYZqOti/=lR^?+w4e2a.!l@G9kUT/JR%|*f_aX>I*##t.|%^!C*,/Mp-9<q@tcYgtS-K]L=~#Zg{pB9>(OSm```|5``4```L}v%>XNnsP&/S12iX}.R-5=93.,<Cc
::^ze,wor+-nz+TnY+IRI}tR=}iA$B$<McP<vodtnzbn?xp$S1}Xt}2RAnEx5Rc<wcxH}0p-ZXxn$pJ9oj!i@}MlOiCdS#V5Qc]>xL%pG7On72NKfLLY{5``````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````
:niblld:
::Y#B)f5``5Y`````Ym`l07```````y7``````````````````````````````````````5Y)```hjhQ/`??~A]0-PG3KK=mrAh6L[P!)n9MyH!2\SNJU<?2jib{g6)!@iW%
::;d+=WT\cHVdXQ)````````#H>u;Ogi@?\XY%*a|-&,)jqE\%yo[Cj.oU4{8J#%KBpyafO#@9bnUVK.W3mIlS4@b<_sS`````````````````76nC``_c@`*i;E1m``````
::``pUTiE-O5J6/`t```97``````,Gm```y7``````T`````4```y7``~```````767`````````y7``y7``~}y`y7``D```u```````u`````````4```````4`````````
::``Xi````````````j\.7``.`````````````y7``+}````````````<P7`0?``76D.``97``````````````````````````````````````````````````T`<PC`````
::````````````````````````pU08;Of.``Fu&5``zD``5Ym```u`````````````````5`<P<Xic.<7```1}````f```)```MX````````````````4```9rM>IHTR``xw
::````f5``|5````G```````````````zD``vp,AORK[T`pU}```<P7`5Y````t/````````````````n`|57```````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````76gf``,#/`l0?/``q%``Tnu`zDM,``Y55`p$e```%I``K)}`Anr7``3m7`y7V`zDUC``T4}`|5U`76vK``iOV`xhZ/``{v7`wr\```<d``++5`xh
::E7``Gt``ffi```v/``~B``~1D```EC``E@7`&(6`5Y;,``SU5`|e/7``?r``j\i`|59}``yh5`E)~```Zn``T4}`<PC776cp``(jy`76pn``){/`AnQ7``o@``;H,`5Yt/
::``D=``u~?`zD@,``\0/`A!M7``Jr``E=,`\<7.``^R5`/dJ`76H{``rHG`3Q>5``MW``(XS`<Ppf``0[/`;oB7``A]``cQm`76PC``SW7`(X&`76YI``x3d`uF!5``Jm7`
::CUt`)Koi``n!}`)Ky75Yy6``_xV`TgQ.``#55`,#=```0i``4f}`3QB7``1z``mbu`xhxC``0d5`sHP`76C?``nAn`]m`/``RV7`h,R`l0\)``s#}`@aZ776L,7``4y`76
::W)``vB}`V%&75YK`974nuFzDd`,`z`@}_yxh/`````#76BZ#ou\SxCTZJpd3c&]e#}c0vmBd````````QJtMBgo8Em\S7V>[j=vT)8o8}?7y%)oZP!(7````(6X=#3,rS4
::`GIQblj`zD608CTZJpd3uV8p8E)`;o&SYDZ2{[*>.r]8Yz7u}]gX>rJpzvC```````5YYU#do8h8iSi0Mz/1U3GMGcNB7```UZw,<g#F*S&XzIarF3Gd.MZ```````C>2S
::CS{m4GA<bx.Mo`pUJcr=H,~A8AX=)=AvyMU}IHiS````8,Fpk<Cy6A+[@+3x/G``A5{{<P7`n6*`$5^VP27`````````{{<P7`n6*`$5^VP27`76w`%5&M/d/Yd`;`P`F}
::vSV%/6T`m7``````````````````J.^-``````im7`.7``76/`u`````^-y`xh````.7,G``````X,``)```/dA@^5#uu9J\=l@Vf+{3AFTr@W{C13.>Jdl9MVp0CqZ$9d
::2d&NSLTQPvB|[de)NzuZiLp2ySeW&ODMu=Xqd?WMYY?pUj|Z8f}?S8k^PfkgH2rTN2O7a?jq89KVb#%lF,.n)yyF/|qNY;c;i-*6q&t6K|.T(IzKB/6PC2|2;0;dKQu1\I
::5.B=;z-)O.5?Ta]2X^@V%|Owiaml$W*{QIyyv}2m6?.N_Q]oViP1Z^Ka0dPv}?C;W$*f!g{S%=67LPd;0>jp!_5wYNuBo2%wtff0Gq`ku,>}~Pz>J0>+wqLlN;02@9nHup
::<Xi{Po;V]LC6#4d)-BL^Sbumt({5.^>PceJY=#8+C2vU4=g#9f.%dHK5=-mvadfTr;K#o1V\J}FW8u)>klHIQTCE$%p^83a&C;on0A.B+u@Vt1fLb<RR\&g&oeDn{Lp.ld
::|\uRA_~iZ]m*]kY1hJ-C%vrntLX3xDcWqU[Q}#`si/*se_+J7F`~d(iWD;0-2cwdbo~[|;/5W3i=(5;/5G4B.)F8;~6b5Hhu/fQ(klRV2tvZL1\((r$,l5P)DW49(=fEQ#
::E?X=KX-R-d9H<*%+`2dvh[7no`FdT9Qj1.=5jyJ5quIxmqJcFD>{l4|ue_1@%|3]qL$^Hpo1K;=aeUM*uw=w2KWVJ\9LP,Q(4RIKu<zM?0k*[n<{Sib[jQnspEkjjAuw3<
::pMFI,,Y-(CZBM}gK8IxTHL0#IAoNPc)*J5TjKZnEG]{)iN193Z_lAuwX$DlUs=mOSJMtAXy#Nc}Ua?jyIm!IA!8O_q3=@tUp<|S\jU;I^#tAP;QPZ(7^dSpA/@vLt9CAV-
::U7WHEc1}UdHsvC/dXkTl{r/X|@4+!t@L{-w@!cSnw?VGt(iO$(!|9(,fIcbqS#xv^_vZX;9Ju}r.M9XT&|w6@$4?U||\q=R6s_v^/!t/qNE>un[9^h6pBL9{s7z~X)]67J
::-[>I}0YmJG3cpK0>voo,9yp~bBRF59us#=9tO^|B#~gqX|vm|A2vfn*rw\[3&^opG]vb2M3|z}$7n%/tvQ\y/O1%(G!rzoi4w$cqx+k{p/]U1}*RtN;ut&<lpFqQF=Y707
::``Dzo`76``5YvkGa($H(RA-_#kcXuCj}````gWtDdM$\dIyF$;Q`wwpdXp=A#p<ni~%j4(or~;[&?=5CKf9])2nE;LWr?#7b{j3SAmxap@|tj`0^+c$qX1\-{}z73iu4<<
::J$HLPS!l9l8#NLk%PFz,qt#ElV2BgKf]xgnM^=GgBp+L2qDbwJi7[5LS)S8d)02s_lcDlO~QwqT+WU~46k/#yDL~fhe{?5iaVdFrya&<J$mFiRCT,xnUGIQiKIi8w+~sD1
::<$XV4W?qm,f>msT#{\BtEDa2#&~qDGG[C*m}DxEXrKn^JB459%D3Z@(=|[XxDFA/#k6xC*Y2nvA)\h~%#0l7;(~Pm5l6@_]I~-S)7g/Co?ied1>GLs+tan|,xO^?Xm}gyn
::wM*[B*D%#rN{3<kobBqj;ZOMV)z%-,c2(#UZ.~vC*,jG.ig.(<cJZt1o0387nFXuT64tz8jXShXg[6BX*H%SjQK<y}yZ6TdmLtitk7?.!B_tep}?7kp282P!SAJIeTI$Ss
::V~vaU.Nt|iGaoqLhSo+I,?{1[zom[>f,IB;q?|Fn!RP?8;Y4t9mT=PkrPPi%)+P>2tU&]X#}V6\\iOR@sMOn,<WRJ=)cye<a{<tMkdij.yF}q\J0ZcAhRgFSX4_]V}QM4^
::~5t3H6)kGF6~kY=h>FY/v,M8|#L+42AweG}J%![N-RU{ksS)F\Nju5*+}```<l6\uDPl.5``````#xy;Y{J`a`J.Xi*4>OZ>vL``````gkm8zoM{A!J.u`DvNos_WOD```
::``5Ytg]n}MZPo`9}&Mx,ljRh/,``````tM7]K2d.fVy7n`]7r{%ET|m`````<PeNGdgJ#U,6}dMj#\>jIcsX``````UZV1*t,.swU5$Y?f``,COI``````5YSAhPOqh[GJ
::%5P05`qfuHG```````o*0=rbtYz,60````V%mc````````fqt2gI*5.G.7LPv#f`k6\/``````76?A{9Q|b-\Xs}````mPe,d```````B$~x]T;`T`%n@a}8ba8VoV````
::``MX(Q&+df{@|5{`.ogM__IXm`````5Y\W]KQZ#U$Y{}!Ai5xkL%gG``````6_$+oN-5.G.7C`NIj,n9`{f`````76,,zAE|@0nY%5h,26@NW*cC``````Bp!SzqI7~}36
::.YW*V>D]8H}`````<PuP[]<(``````````y0,`uFz`zDcQ7`CSd`^-U7``di7`RY)```?/``&0``}{g`76j}``gEn`l0g```q*``]</`Tgjn``R>Qf33KVW4K^IQ&X*AP1
::Qasw.```|5}Yn`]`07C$E)phC`o`````````FuG8u+hu0S0].fCrULd`i<,rpMh?%H~IA2L;AFo\C```````76&pv.WA,A+ryskTd```An-1GO.o|Bp#!(&%3$Qfi<,rpM
::jo%HEl<Z0=DUaT=c##7`````R>Qf33J;]c#FWH$```FuG8u+OSuAa/P1(-7MhV{}ou-02XC=w#id]8~```q-yskTLJ&#0$LA$z>r~+@5``````xhuAtz9f{2/o)82F0$LA
::,7````````q-yskTBb&#0$LA$z>r~+@5``````xhuAtz+[{2Q,fcD>$Q,`44ph$Y~`u5tM*]Ti,`g`n5@{9H7`d`````````5IFuGY$`y`..`1C$~PK`57``````J..Y)`
::*`55Ful07`C`X`d7``````pU*leZuU33h\/J`ZHE)S/lSK5~````JyC$}6K`M7Fnj\Fu.Y)`z`@}_yxh/`````````7,76<D,`I7j/5I5Y<D,`I7j/5I5Y~P)`I7j/5I5Y
::56,`I7j/5I5Y56)`I7j/5I)Kn6D`|`If115Y7`C`T`.7(d}L``}6o`V5zC<P76C`-`````````3Q.6S`\74u/dogmY^`R5.c,#TimY*`S5``````xhiYS`\74uy7ph)`^`
::K5+{Sz56uYL`A5tME)~P,`^`{5}{j\Ti)`Z`````RIL@HP{`}7Md/2pUd6-`g5.c3QTiG`*`-5xcvp~PuY~`R5``+L,#.6w`n5E)11TiG`R`````````3Q.6S`\74uzDTi
::G`R`n5zC<P5Y/`?`;7j/5I5Y/YC`L`^5(d}L``/`,`,7-fbt)K5`)`-`L}V%C$7`C`o`I5G9?&Tg}`T`G7IVpUog}`T`G7IVpUog}`T`G7IVpUog}`T`G7IVpUog}`T`G7
::IVpUog}`T`G7IVpU7```````4)#&(7````d`````````````````````*i;E1m````4```;o````Lf``MX5`76``76qp@.-&]S.4ZMWJhk}Z3bqlJ(MP>6a[,]X@8)#&(7
::;dK5V.OJ<R?KQ`s&TK@7QA`>\r#6`Jr/tY[xIFT5``BVGX<c``%eW```e|YY;@``=KN5aS[_rmF5``S5````K5;}/Q;))>ro5x07~CK<BJT+S7o~?X$vXb>;NiF7=/mz*<
::O#-FP|`ng#7YEot}>#8S~7QJ7)j@dvyo@Vj_9RLi``a52<MQ}```EZ_75YhA~a@+>7``QJ_nq,o9H6nC``9$*X``Wv.,li7`zD/^[DLN``3Q4T@K5`76l,46O(``5Y=TGt
::*b[)AoCM``AnUf/`SiWV``WvUfO<sM4J{j)yzWxN.```4VMoTc``ibp/``Xi_~rD8ifqi60*<E])_~LD8iaaXr6xDO%bg?~DI`W_g0e.``%7h*q-*oRC<i}>\)</Iuu```
::S$GTSY*bGT(PU#h~#6A7``76=TG>|5mzS_`6\Uy7``sdBP=T7>]<k~n)9}tGhTIg.,1Yn+8_`y$oZDrOb-*oRC<i}>+)>ja7c6``s#I-4>n+45ag}@7Y6DK5@H[J$GyYn+
::t`%KrJ7YDimzy^s#U4Zi--7YDiBH;g3k7Y]VeRti*5^o2)M/1```ag/*`Y6D1GHTGbOm5}+o]1mKsd-<3JYHE3_D[/4vF4kV`@BVV)Ou``U5p/``Tg_~<?qAlr*o=)g}An
::,{%CG2R$e|*/;)p.W_+t_uK5o}y^/Y.D-^m5Bb&PyzqKq/.G/`^-?7H{Iifom$4G[#^gN&&i@}`Go~T)9+O-@pyiOm7i_~#TS)~oGsO~M_``R^bcZ7CVC@S)zorclFsv/(
::d`P238&PGFc;=r!`~H5Z*oRC(2*jeddk7`pzA!qP,6#f4Jfh%b(Iy6sNp6l7``sdcTqu4VR~g@MZ3utGhT]rsvaFd`/d%nR.LOc/a-sM#J,AZ70o&)M#R<7!`@.,dHU5fI
::HG1i{LN{jhdmJ;!b+-W6azeD#X5```sdqGGh4n``QJ^7@o6=+tA{sdt-6x5$g<H.?l.`5YVW}v7E`v7E`v8;pWpM^)``J.=0ZoKlc/rr|@#JfhP13```>&N{kUa@o!2tWf
::Uh6&eR#7Nh(X%1qKNk]VkAOmv{{mpTDN_>wjz^L/j@[!g/l_t>./#J;J|<$70?+Ru>Cg\J^qcYNT;)6n]D9G!A&wn!6xFWki_~OTxO4#Zs7Y.$^#_qEDXJa>\3aA\k7Y7I
::9ea#*HN&5Fl(ljZHDk7Yv>CF#5NRd```tGG54J<%46>27`5Y6xH)QFZ.Jr=5sd&k\<D9%Rx.;]pZT!Mc.S6rW3;NvN67LowsY5c>r3Y.u)}d&wazQ<s}.```sdY26xv)m^
::Zo9e(#Cz%sO~6j``^58.Z7t.shc/efx0^58.Z7l.l%W+Yi>7YA|7``QJ%8`y%xPt593(P!NTq,zr@7+toc(6z_y^56uy#kJ~YNe/la#^8Vd3=o`MwY$7I00Jrg<plCr7Q`
::dz7_,ZBHn)jvefiOO<3m3M_~>N67zoi<6xH5Q`;)o9x6x)0]67Bo|5``,#8D``$Z;jzP&,2-}7ah?M``zD-g#gz&eRx[wf_~io`B!5]&}%Om-nkPx_U#Tg]V}NyaPq^.lo
::+RYrgpRCJ9{+e.PtDVd8!`=XO<!`17oH86Nk@Dx6=)y7``o.OM\X6r|YOKvW]aY5(uJKH.R%sX(6z_y^\52T>.L0W+Ii>7Q<~nS7a]/`5YdX\+a@,_X]@)b_7Y6WQi]BD#
::9GVV&wDW^kUHE`V6YXpU^.|6\XB-+a\<h6(i~DUD+Rm><rZnl(>/,AJN67gfR`j+Yix7&Js},5mzu<U#Te]K%f7YXgBHk)Q)``;oxO`R6&qVk)F0ED+tz%YeVF6g(7\q&+
::`@(#V~9L>m?i/Cp.fI3G4-5~8-?ts@m(UDXJ)ZBn7^o+uy<p2toAr0/E`v7E`v`m+t003(,-=TfX`y4P*/>_^-V=z^\$j@[!g/Ckz>&.|Jeq%b/fyXDNo>i9U`sdLH_hZ.
::a@SUPtGc(6z_4J<Dj@nk=aZdtGndQJ\Ou6BH)`gb{d5I600/9dFaKV{>d{+tGw1Ghg=sG.``QJ9uBbZ7ZoKIc>sMWs`.``QJ?vj@o!+t3AAvj26xtJV0``FuJKso]1Dkwr
::ct#JN?9fV7``0b+Xt/Ru)```G_vo]1H/IAEzM{S[gi{mqTe!UFV-Sf\!(Y6xQgS$@od>0+W.NVfRl(Mt-aPtJcsdHesi3mF52ICG-~IS)p4Je7,-v.Y5;7?i1YPdZf1`hp
::Yi@a\<qD(itoR%(XBDj.Tio9`)?.<pW+Yi)5OJ\5`y/2+=)&&0N&=yyRgb@X}@xOvKvL&)-pS3ST+tBw&wX?Frw94`^5|IE`7uc9%RliY<pDefh6O<YX?/FDu6J.^fXcB-
::w9+`wgYXO/FDY<An0>V)&^}/j@Yjw]q#tQMn+J7{46&/7`5Y0*V|8F^.V%a+ZfDBF<rD1};.Jn;7B-+a`~(DE`Tio9zRtiY<a+Yis7E<G6cF^.vo?6di9cb5CSNO^.n7=X
::$51YSCZfTBO<rDU5;.JntoK5c_`~c9`)+.Y<~ns#Is7Yb)oKy#+=JA%#6&1Sl(IZJmu62PIi!a|5`XE`Dco9XXo.itW+YiJ7b5K}cFY.+Y(i4CY<`nZfXc4-rDn){mvNa+
::6i1Y4n^f1`\X$51YvCZfTBO<rD|5;.Jn1pYi+aY5YD(i2hQoAQ7Y7Y|5f9ji?.zpW+Ii)5Q<67E`5,c9`)e.u6#.^f`CB-YX>OY.`z\Xk+t>8X7YDi_~A)s}sdCooiOmN-
::hoiIB5sdHT]r.,G/BoyV(#u~tCrQ;))>ro5xe`o~$z=K,OH6)TQ6]b)tiKD);>NeH^QTj@Is{rM;V/IB=T)Y%Vs3Om<o9t)2JgVC7```ZGgTS)J7NVr3&VjhAoKlMdK50H
::L`Dz1Yh6Tzj.PYDz1Y&>#i\sY59/Yih.0i2c#6j.kidzGy[=+=>VC?]4IiVitg!Vhyg+_-4-#J@C*/$7OlsOL_=s|5A$0{h.Ai>0efOP>l^5ai+I,<9#IixJtjw9x6K+Qo
::e!LkTL6xgg]b>IKoqA;>*o[)g}N{,{l>G2pR\s|5toZbZ7xR+R9>C`?#YitiLgrD[o(.(%67JzY.B58.DGqDY<Y-/X]&y%^=b3^.<DD)LoCB=T`Ss@mSy6[#76N&N{jha@
::!]SYJ3Y.Q.?#Ii*7wgYX[o3.(%(XBD\sY5c/Vl`!+TXJKK]&%ij23F^.M%SzZfggF<rDK};.|.;7l>+aY5(DE`Aio9XXtiY<7xYij7E<zzS7_~9XsKm6xcAQrDtih.c69#
::Iis7wgrD{}qDY<<PIiJ7wgYXm/?.#.toefR`1pYi!aY5`X(iNRUD+RKK{L^ij29F^.M%zz-fY-O<YXX/?.Y51pYiw7Q<`T(i;tR%`TpD#2`@Om^no~]X=K<#h6)TRRS$l%
::m/QdK5V.eJe6>feI)(7A__J-dX!gIi_~,o+R<D_```sdm-6xg)U.yw+DaRqG4_7YOmiG+?a_6D~C<a|d``CLt}``l0n)M6````cHi7#JbcZ7/V<_OAR6[Dhy``766x{%W7
::``0de43dhyqz#O7Y7^U9P1OW7Y(K3/Y+5`~~x>#JbcZ7yoTlc/+-9tXz(_Di_~n)U#Bp!`<DvGj+[Nun9j0z]7``x87```QJt_@QloZm97i`zD8i|q66[xAph_7Y+tDV#l
::|_`6.,`Rwm``a@(I@`#@+p2t.s+^g.~XV|)/_~O5U/``U$00!me|!~/x7Y7Ie]k%v(7Y=J2d%%.`Xi)>x)p$7?N-7T%n>7``kg_}w$_AqDzHM>~p@C!kA8&P(C`!9>LpRC
::*ifcCwjD+RNmj```OzcQy5tGei1j7Y`y_!Bv$_7YN&w,{Y{LYY>v``SDM>LpRCbifcCw_D+RT\W```OzcQy5tGOa;j7Y`y_!XP)_7YN&w,wi0$W7pt7`sc<_hVsd3T;&_}
::j@H1SYs@_Ay6F#rj#6+JtC#$6hql`VsdvH)TYDS$x@pDC)\.azdX|+a@sh1`0b7uaN7Yv>F5]7E)iCgoZml&f`zDXJ;>a54{Ri]BD+=_6Dsd~H5+j_Dio~zr+/``}2m5``
::&M}C*D````ZT>`%b(I(P<H3_81UU4.{C``XilBt>%`5Y0X*\_`BHg0rk7YN&)@NkH_7YfI`+U;``r#]>P|w,{Y{Lw,%g0bLdZt7Yv>LpRC4}0H?iC$aROM*.~XV|j5_~C6
::e/``U$00!me|2/cP7YEoGS%{Xq7Y=J2dDI.`Xi)>x)p$7?c>~plCj29Go~g)vo;GZdkg_}Di.<cQeP)4N&w,{Y8;0lK^a@W7;K7`;o%7O[4-9t>^a_Di_~xTr$Y_J-NT.>
::|5o~F<B/``|<(#\r#6eJl,3SRoZme%f`zD8i|q*6[xcbo_7YPtCV|Fx_`6OmR~YvfI66R;``6H3_ZHNT9>oyx+Pt)nP-%V-RO]rno;9G!{p-&r|JQT%b(ISYU5F.``pUed
::uJ7`scFSy68_$9Na,$5~XisG[#|<$b_5xbj@GxN=mcL6=zdX|+a@6=PtSVtGcTE-iOe```;_U0$G``R)rTruK%?ODj^0++C6gLo.^kH~`)|5N5_s%O?q+6sU9Goc)4#2`@
::`VRc-TFo\#c/EnNT%5`_7,\5ZDX\%ewg2Y{sSPK_m`GG-5iC)+i<9JTz)zLg.7^iWpHrGA}@o9>F5,.XUog.`|wsgP,UWcw$H1qD=Kv=|Y=Kj3#6;E?t^30oVl351G|>rs
::7Y1r````>&yj?vj@6=Ety66R/6r6R)oK&Y>xPK!.9eT;I]!z`Yb)F0Zo9e@zV78J!`2.}63_K)oK&Yt8j@L2O?(_7YN&2lKnY_7YRy|z2-V=z^PS&@Z7G/[2wrM#|Jl^tg
::-a9G89aY!5.```72W@L2.B$6Mdf6j+Xi]Dro^]QDB[N&2lNkW_7Yhy4+?!7Y=J?vj@A22)4TD5%VUSg}>9,wmoD)LoSzNT9>m/_~~)}dK5;}%ga7(q&+`@qKd8#6QJ^BZ7
::topJV/XQcl6gei2-Lihy@Tn!7Y@h5```[#dJ@&eROm;]Z7s<G`$7L?Hit7\,+h!```c;EyV1`YoVEl.?)(RrW_xU79jiF0U3=a7Yv>W4#J4tM+Z`0${Yj+Xi]DroL;QDB[
::N&!F4V8P@o*E?#c/#.M`K5<HdX&5@uZT<=P#|n/G6x%5`_7,\5ZD\<15qH\mp44N*kk_76lVg3\m#M[3,$*D4`jv)s26K$b>K_ha@7>*fsnzTH@z*7?i1`UEM%(~cu&UE_
::NDxhf!&Mk~H,7?Dz+Crg2YvbLgB7b@G2i5_XO>CcMFO/,RG2mZGA}@&m)T}S`q(+!=jW]n_W7Yb)SxEoQk(+/1`Y`6OmWnMvY_6DsdOk7[|5n>&MK}[#yz]VWW-|]f_~Fd
::D)FljcQJ#Aj@fqnb{9sdHToiOm2HhoPtDfhg%V-Rr7Am,hNG`V~CHT07.,)-Q.fIWf_ucleJ*B&)k~zDXJvne[NTBUTG_~ui0j1_S[9GS7Vgl```GoknHQ.-k~^TS),5Ph
::2zT`76A+H|$7_~PT;2]wG```F~D%|I^-Pr+`K52fr8L)F0U39q7Y=G25>+H|d5BHa68.;/````_~eT|~vnYQJrXi%cz7DGW%IqK-NTh)JKF3&37Y#5T.Z8-5-#p47```QJ
::,AZ7lo!JV/!-LpyC*i2-<ifsmc7ZzHNTv)/Cs5fIcGB-7/?}.,?.qDwXHi$XNV?H3mLf_~-4Pag3ku#UD[Abn],o#Ps\B66x@JJB7YXgVsV~,/2ni9j3M+9Gs9{jI-n+|X
::a@@_3q(#9*XU>_7Y-0k.1EV;gHi#r6]5^.4.|XD#7SCcj@[mi8Up1E9#7Sb-FNna+4Q/0n?#/LE;AFuQF,0wkvnMM7``zDzCB6NT,>f5_~A)s}sdCooiOmN-ho9Goc#6WV
::#J)AZ7vopJV/B-~pyCH7j$vvS8O#K=tCwh5```[#Q&S&qRFE^%Z77~&DK5t*dXB5b?.?gm&zs_J-6xp,)>h?yV(#N^LopzQ7k@A!DGW%IqWf=TC5ka0.yya!Lp7Y=J9uj@
::A\.B$6Mdf6j+Xi]DroL;QDB[N&2l`K!_7YPt3cVg(_7Yfh)yV[+dsDsd-HgL|,$66X2)!T^RM#ZYD><rt6$+7Yvz+h5fi>W4p5y5yoZ7iX)`p_JT-g17t3\J9u+[nk7Y(K
::~Gf)`Y.$^#*oStI)Zcjc[JM%j@%qnbK9sdHToiOm)-hoPtWfhg%V-Rr7Am,hNOmcV>~plC?i}>|)XbuvhQ]&rwg}@fyozm=9wrD=0@3_DimzizrDsd?-6xIg>75Yvy}82M
::1```QJsF%b&Pu&=K$mu~`Y.$3aU3TA7Yv>,t&Pc`J.L1)```6czo4```@aMZ3utG8z)Gp_A8&PSiKu``zD+Rki2```OzcQk7tGg#js7Y`y_!i0Ak7Y9LYYsT``=KHZyh5Z
::1)}>x)S$z}m>V=b]qcJ.5YqXF..w=X+R*Bp```OzcQk7tGg#as7Y`y_!i0Sk7Y9LYY2T``[#~Zyh5ZeCF0ro9eNDn}PI/)OmX6h)``0b&Pu&=K$m1~`Y.$3aU3DS7Yv>,t
::`~c`766xsP^bT?.G=n*D<PNTQqf```;_81[hNf]M````Su_rw)lB6aU$8cwK]&_6dH``QJ+Y[^BJKvT}Y_iKxO4#x|`Yb)lB6afI66wT``SDM>V=b]0dOra$PtzY,)``0b
::&P0|=K$mj]`Y.$3aU3=@7Yv>V=b].,zgG)``+Tj_!TD)^ou4RROmdH#h9Goc36NWSQ;)}>2)BDC)^oEKhE41s@u(9G!{W-7t9lG9\/rozm;VOl9Hn+LYb-6xL)?B?j+t-W
::CH4`7`5YtqWiITCD)C/G|576YX//^o2ITf&-BnfJ!Yh6[x^@975Ysv+L.`XilBOPh`76BHK>#j7Ye;UUrt0bLd!V7Y/LwjaA6B7YEoLmN@n`|5IuC```xr+)1```Mjf!An
::BH1X>H3_81UU4.)$``XilBENh`5Y0X*\_`BHc=2j7Yz&N@xQ,_7YfIzYPi``!@+phy|CM>~pRC]i]BV~?`5Y6xQi#-!)1`?b}X<jOAR6[Dm]``766xXH%7``0de43dhyyx
::X!7Y7^U9`_sq7Y(K3/Md5`wrctg@BVy/roTlc/g~x>#J}MKtS/y7<Pjgs5p5D+5```sd3U=.``8;UUrt0bLdGM7Y/LwjaAvQ7YEoLmron`zD+R{6\|{){nz,)XRH_Pjgs5
::H8(ilB}a1`5Y0X*\_`BHBrxj7Yz&N@z-f_7YfIzYHi``a@T?uu7?R~A%#JN?Di.<R^7CsdRix.``8;UUrt0bLdlc7Y/LwjaAPE7YEoLmB$n`zD+R{6\|J,@}0H?ixhXJvw
::.```Q_1uauD.PG````Mn`!9>V=g@0dOr{$Pt`+4D``=KR6[^BJKvVB__iKxO4#uQ`Yb)lBD#fIzYKi``Mi*oGSqu8/sIfdOm+D1i``0b&P0|=K$mN1`Y.$3aU3}v7Yv>V=
::#h.,`RKi``Mi*oGS*c8/sI%dOm6i9i``0b&P0|=K$m?;`Y.$3aU3z;7Yv>V=Ml.,+Dci``+Tj_}@S)Lo14lOOm5}eo_ZxIsdJfxQKwZr7!+TC)Lo>0eJ*B,5mz1)}dPd|H
::6xx2R7``OmkfOzcQ;5tG_Dms7Y%bx}H)7Y=#_g`Yb)?BNKt`Xi,8T```YR7>y7``<P\@rPhyeChgR)_Nun]r*9PtzYni``0b&P0|=K$m7;`Yb)]BDc8_6Dt8~_`6.,zg}i
::``a@(Iy6{|K-WM_Nun]rg5O}``5YG}`@goIlc/U->rH8zilBO/t`5Y0X*\R7BH0%rj7YP|R5z-7Ya3sI7Yv>LpRC&i?B93v`xh(#|<#Om>LplC*i2-,cNG`VV>~plC?i}>
::|)F4O#K=*B(moiJKEoFGp`_~y@xO[_Oaod``%V/0BVECc```]&!FiO*7``gk]+~$``yxgo!JV/?GYX&J,AZ7lo&)@pR<zH)T,>;J1vp/nvhQMdrw67``wxXi8Kj5)dV|[O
::qs7[>jGyGkW%zSG]nRh$y9XMDDW%zSS%3s7[](u+Ht=%zSSA80j)47AOPw3o5CD#)L})M6gbW7rm7Y<~~pRC<d^#_uCI0dhg)LTuwi}>2)5IWfN0<olC[3=5``E)R~f$hy
::1)1i7`zDj3!`sNB.3```_~-o?5``hyeCOUPhB_M`<P=Th>C$``P29GBHn)R[%mgz5`</DHzig}0Hf$zDS)eom/``^-LpSCx7``R^}M35*```l0n)M6H.``gkj`.d``]&4T
::{Y5`<PTB+h9}{`)K*()uk@A\PtCVSEX```_~%_a7IK``=Kw$#`}`5YbcHo````CL_,07Q`;)n!E3QNYX}`5YOmf~2oV9y,``|5XJwgC`IK?.~/``-f$1?&i`J.,xR>5`76
::A[X6Mn``f$E<[7``UD(ATv(d.TeJ]<A7k/4TC)4oMd``^-gpSC#7``[_;j87``Om3>uK7`5YeDrX}`76j]lp~hgqmc7ZzHNTv)/Cs5fI3GB-5~KHO7j$_;*BX#O-f~%17Y
::Di%6Z5c```3moP_~F?xOV>*olC^ViC33Ea7Yv>*olC*i]B6aA4|_7Y>VT%BV<.*.j`%O!pEtc_Yi`T]rYX1~?i$GRDXjACNT])X%e7kG/c0/kY(K%b|YU#s*6NNk7Yj@$p
::BD.Ot7Mr\JP%@#^NshxOm>gpRC0i3aO3|~``;o|Jc/hH5x^.ji{>x)UDuxY_J-[xsP35F.``Xi$7pTS)-owsU/<Z``Ag%{]R(#/IG7)2]&#68P````=xXHNTy6s@UoPjsz
::_I``I|d/#6[x_Pj@<pPt-W%m!@5`86>2$```+twwsd(kU/fZ``QJ}MVu``Xi{>p)</Vu]```]P2hS`76BHk)=<``zDxOO>W4zrOmd.+oN[mKsdJfxQ-%)b_DZqmc~CHTE-
::ytnmJ;!b+-W6az=Tr>-|7YKohim+}`<P27VFi`</^-{)YVRc@?}xa#uW4rLi/7<P``-X``76t(k43dyyCf=<|@_J4t%bT?EkAx^I``E{kdeH=T.>y70Rk_6DWd`*(tv5``
::QJqKZ7hoiS,O%mI15`\<^AA8+.I3cw)RaR6K/```BHc)jjhq7YNwku]BXb7`5Y[xnC]9oa7YT;da8.mi``f`(Olj$t}=``zDW/-F_JyiyyPic7``s#UEg?Ck7Y)_PIgm5S
::``;oXJe#[W`Yb)]BnB``5Y[x>Kkkgk7Y(K$mF/``^-D=CIz-\_7Y9GgctG>TpJulE#*o]1_joW7YH^Y}]RA\Pt3cSE#_`6Ome{!4}```QJjIj@L22)aY9c<DaR7/NV3s-|
::;Nb59Gcc[6#X2<)5/```sd)6L/``e|o,au^#roWGs#UE+h.@V`766x_i.```1G7TIgZow$8e7Tlgn```s3dsi2@]Iwn/5```-T````69WVrou\oCtH)\TE<i@iroiS;y``
::zDLR6K/```NPq_6DWdRH=TG></BHn)+2%mFT5`^-9tT+6?\RV#yyeCgP||{)_i{>x)/XO!Y_)#NTt){>p)PXsOdcPh(fV`<PNTt){>p)UDaR5/]VRR=k_Y1C``A%QJ.MoA
::h=n(g@``r37`x7Tg(TQwA1%d4VO.L```e|/mC)]B<zcr[k7YB?l^#dKV``Xi]B$Lhy|Cz#y+`YOu{CL```R)c+c;f$%.gXD)/I.7``wr#d#J7)9}_~|6sNTjp`zD=xm6[x
::%`N&XlOmIked?f7`UD2ld```BVU~&oGSYN~m2```_~-7$```BVLCD```Azhv``@aU/(H``QJ_}j@}*(P9```#7^n=```\sNia71mA1As8\_r6}^$#7@f^```6&X(3FtEA.
::>`,$MY.,nYSm``3QF^L/B5``5`crq```k_wq7YY_>{x2V%Vchy5CUh||4TM6/```~C7Tb.2XF_7YIP=KM~|YV;\n#`d```.,5~?ix_*_7Y9LJ6?Y{d-R-5``7QWcw$H1qD
::=Kv=|Y=Kj3#6Kmg}@fPo1H7|paN&SSOmTfOzzN*iR```0bLdna`Yv>W4__v}~75Y+YnoOAhu``}+-}Y```-|6}J9F-````P9fyL2XuSZ.`|5``5Y#i)>7,~```QJ>w&25`
::XiF0ZopJV/>r9tE=\_Dio~^3}5``}5}```.,N-?iFQk~n`zDD)zo?<)TO2V%S9zm7~.```0b^9I(`Yv>D=QJ7YDiUQB_6DsdcTKV3mdGo~n)~/Wd@HNT.>{}_~\TC)~o86
::6xP_uG_~T)^.sd3TB)Om)-uK9GocWe?H)T,>iO0oVl35sd|H6xg)fcCw]Xeg$q4V\*Hv````hL%V\*_t``76EY9<NTCLf5``Xi2^WBD`Tgvuhyqzum``aNX%P`zDR6e\#T
::&i0bx}h&``r3587Yv>ctw9i`76,x+2V%1dhyc74_7Yksyz7YEo_Z(#s*g.|J,AZ7lo&)@pR<?VeJ*BVlJ9pb````OmLZFIU$8cX-9<NTCLf5``Xi2^w9D`Tg!VPt=`BH|3
::[7``FQ@Kn`C$00~XR)|J.M4g5`y7Gn1```PhZHu`76n+c`i7#JtCVl&+hy4+P_7YjAe67YEo]1(#u~*BeJyz7Z7!9G!{>rBniZo3=g?d``*?m?GLp1#-ctZUf`^-Cf>|0^
::wo2)X/)```S$=7iQ``,wH%bdUCB0g/``^WtPJ]W`76?Y9LR5;v``QJtC-lroiSfq7YJ-[/[_6D_~eTHiQK_s-0`V`Go;9G!{e-&rfJdI%bx}|_7Y=#B_Y_#5JK*o]1NDA@
::-1UU[jp^f9{`76AVi2Q+a$``8[+-@|M*f`)KC>#i)>7,~```QJ}M5^5`Xi2^S$9`5YB5[mw$x};b``scgTHi}XFV`@R)2-l$>`)y[=2tSV8/sIzi0dTZX9&$Mj}`Tg*}IA
::60Q/``A4&JtdSZ5`,#pJwo2)X/)```S$=7Z^``,wBD8?$<w`zDD.i7#JtC-lroiSVq7YJ-Cg=_6D_~^?XJc>lomd7_3ZZo2)qK^gOP)TfRZ$zo#rzLSQcl6gei2-Tt5(V[
::}```*bl%roxO~rK$YJR_R6_~V.xOLi6&*MSV3ayi!tMi&3?<A+D|h}OzL^?nIAZ)>/``4veJGwO<5`-|gbwo2)X/)```S$=7Og``,w.XxOsh_svlg}cPc%(D$/5`L@xO8Z
::|@#J?vE#U3k[7Yv>W46rZozPs*v`xhrPEQM|A$|6G```hyc7~_7Yks[%7YC?oFV/*rwjz^3#Z7!IkGqKv=#6OJdI`yL2pJV/y_ZHdX=R^3_DDk!vX4#2#JlCw$;KshC).c
::KL+)qIT24v*BO#K=bV|fCI````1GN<UJj%Gy/|Etii]r&rYJ8=ki_~e+I|h(MXl)0dOr7XU$zV<%{L).X?``r8;Ls@Z7S67```LFPP#C``@ug3b{``d?(AT|q~N&eqU9Y]
::9k7Y>}2\*+NTw>_.``Xi]B#A7Y6D;0T_`6d,)-au&tDV~C3T.d3m[M_~|TC)^ot>6xe_uGmzm<+-CPM\CQWc7ZZo2)X;l6}+)Ty6(b1vp/(;EE|AeJ*B7SJ9C-````4V?.
::8oPkI|^gz&SDQ.JKmX9eA7WdS*6xhR,y/%a@xO]K0MPJl,b!AoMqTb}`dbzdIATCo/``np#cOm%gau``5Yd*R1|`76kpa@+X/XADc>3<E_&Lj]I5``,y_!!twcsdreK@Jh
::x_7YPt^C`@7_O~2A``knHQZ<_~F)Nm``zDaR?g`Y`6Jh]k7Y$IWff6>&2ld,)-PM!tGc~C3T]r\mZ{_AqDW#ir9L39M6Mi*o&)7tYeVFNifNyEi1ql`Vsd=2)TfRZ$zo#r
::zLSQcl6gei2-Tt5(FM}```*bL0QoXJ9Z./rgkjR6k~CKXJLi>&X(OmU}f?S&[5/z8;0l/sS$of3H``,wJ$F#c/=Y7```LFeD9C``@ug3/u``d?(AT|q~N&eqU9`_bj7Y>}
::2\&+NTw>/d``Xi]BM%7Y6D`$9_`6d,)-PM2t3c~C3T]r3m-no~~)/I(dR*6xp,N-?i|<(#u~LdxQ-%42\1AG`V~CcTAzc?>qkDP/`vEE|AeJEB[)JoulXu``zDXJ9>D=_8
::ZozP_\?`xhwT|XsOwi\ss5``^-9J^d3aroJEw.q_7YU/b0``0]CVk0/chya!bG``l<iZ9t,Od`Fu~AZ.Y4Wc(TxOcZA%_J4tzPd7K`Tg&P2Xs#;_z&1_BL35a_7Y`6&w}K
::5&iU-6k~qX9##(v&Djv{0bT?0kAxMM``{)\\H|XPIViC{TkG#O}}a?35BVuq|_iBl5``&t00(dV9k38U,CcTE;>HIz./LktaYv(74=JAu*l)rg2Y\N2g(##,!47Y7Y,Zgp
::28kk=5``Xi]B=EX_6DHC!w+g/=~C,FT`5Y[x~eB374jXWMC`;oHiF_9L9JWi?BjW7k2AmJtUSfZU2f{m}@LRE_;LUBIioK7YPZU#FWL&SWBVTqEo7Da#;_P|^^{_M)1G``
::fCsoqi}UI>X68^ie`y,_t>fMWd!w%WviehroiSP9joC```_~N@+RE_e|2/HI7YC?Dj7|9*M}7```&t.s%mFE7`</Jk{+!```6#K-P|2/DI7Y7I(AYNPSr`zDR6t@[Jv_3U
::WA2tHctGhB7q7Y`yJ!FQ-^C`C$00H}NVs_R[[~_~&TaR(Z7_7YOm[jed<|``pzcQCXK5iKa{Vc3aroJE(<3_XgNT+_j`^}``a54{&)Haw53qV|K-P|2/sX7Y7I(AYNu<L`
::zDR6{r[Jv_pPM7Eto_*HP|SZeF`Y-X?F_{<c``Q#W@+?R}``;&BN4V*7!47Y7Yc%rhH5BVuq|_QnD5``HzP8tGXnR^5J2@x+kGoOoqh6[x~eNP3lo`76k~a}+Ry@`N0k7)
::2@{2V>?#l6V0-*l2D6={1Q,VWd!wGG>5iCijMoaR#=wk`6bV4DD~%8F#3/-a``^-a54{@i]BIkH_6DtG|P%q7Y`_y=7Y(K3/O(``;_1(NTAZrf/`Xi]B4\Lm4U%mE-7`wr
::ct[ymO5`02i[__7YoG@a~6````BHj%F#M*J-,xP[3W7Y7Ya#Xg{dYwl(;_KWi2.```````Xi~C$jH^Dxw$vw@oS)UG=|SCju0RUURy#7]raC_J@CRY&<OD`y*|9GH__qL+
::6xr)_ap_DZ5{K5\H[x~eNP.0T`xh4P+=salUN&_y^}fDmz!5-1}ZV=CFlDs3>+hyv||#z.``^-C~_)77````````Hb{d4oM.gLgpRYtG1iQJ?}6nBHJ{(KHZ>H,x]9zP=5
::T`5Y[xCN}85q7`}`QJ.Ma]*```@aU/Fh``kg?vD.$8``$?Pp``76h.muv{g52e#g8[kG_~j%(#^~y?NTh)+>T~`)+d3(6-[xek\W7Y~/>8x6WLli%976BHJ@)W7Yju{T7>
::5Ik~Z|&gC`;o5CP-ctRDUE&th.plg{6c``})zo!An)kU)```\<<olC3.}>x);cD)cWnb7`,G9WiT.>y7_~H{jNdI<```%6Qx.`5Yj]lp_D=/J\he,\tRR))>ro5xe`o~$z
::=K,OH6)TQ6Rp0oVl35sdt-=TV_)ysa<=C!v>C=>8Y)^#a5B;%D``zDnWX>jQYJw{]P3/X`xh4Px=mCP(3*NTeia@k\B;%D``zDnWT>%a7^TjPY0*82<%(#PtHc3(0-NT_c
::JKVV|TxOm>c0=Je7KQeI8$h*.>Lp@C>iF0ro?Fc/`@JHNT;>m/jWMoD)^oSzNT;)2-<ifsmcV>~plC8;}mvvPt!{K5V.8J?vk}7`Xi]B6aFQX>.`xhaR;KR)|J.Mv_ed-&
::``pzKN%R#```a@tlqD/YBHOYa@T?WDaRGL5_7Y>jV```~~|@GJ3#Z78_g0k7``%7)U)5x5/6g;`R)5``a@tlqD/YBHOYa@T?WDaR{l5_7Y[mPrT~~)tp%mdl7`6wDHf`*]
::t```pzJx+xq~ZB;RBd0O|+%MV-S3sQqR{,zg55``a@tlqD/YBHOYa@T?WDaRsu5_7Y[mPrT~~)tp%mwh7`</DHKH!dulb+A;=+*eClc8f9}nm@n(%R7`zDHiZoF`c;HZCz
::6xBg0bLd.L`Yyzs8````A,c/8.``<P%mst7`</DH^dOmy/loc5(_7YJ-Sf%U(Yx[`T`)`C7~67sdTHSfh)uXK+fI66g/``[#~ZosU/{v``knK))>2)\XHi-6VFZQe}zP_H
::9`767!3uu`f5uCeIzDT`|5^,``yL}`ggz7zDepM%$6n75nR^11/dn`qYr/)K/*2USa?5*]qI.Y?Kf7qfn+<P2`V`.7Cne^?&.6lY/`RYV$Xi\AG`fzW5vpq|7`HgH`!nJb
::V%h,u`Q7)/@aZB7`+Dy`a}pC76mlA`@}P9XiVl$`fzB}vpL}/`(-37h7VR``)b{`x7]CzD0$*PLP4`AnfIFu~PF`An9;``L;G`CzF5<P@}\Uy`N777]676X#h`&/@fTgKV
::C`0X}Co.M<5`Hg(`!nSIzD^@u`M<q$$DyafYmKS7H;EE/YX#~`&/;{>*@0)6gDB.)KZcf`kDR/H;+=ya,6`7a`hi76Z@u`36A}nn^5/`=D?7G9#x5YypN`T6x)xhKV%`n)
::jixhfeHPMYb`D5F`Xih,,`BzFIFu;=V`Bg<CeI~D}`=U6`=79,{}d$``SaW7*].3)YL7t/J.5%&M?g9`p`g5sc/d``voT`m/$#56xh``fY=5Tg#r5`Ng|`/ddX5YUKc6)6
::=5Tg,G/`]in7550i``=57`c6YGxh`JT6a7_,8,qQZD8`/`4`$czDe)]`+7k)Pdd$*P?i[5vp$S\U0`L7di933QLDH`{6kGpUYg{6L7mi933QLDH`/`4`wKzD2`X`+`#5<M
::q%~Pf6P`Z5ycH;Xi)`y7&f5Y~1HPm`>`f`````````````````````````````````````````````````````````````````````````````````````````````````
::````````````````````````````````````````````````````````````````````````````````````````````````````````````86``J.kn``u```````````
::``````````````<P$``7*>[G$+/`[,7```</Wv``````xH``~```7656)`````vpc`Fu````````````zDUf``/```/d3Q``````6G7`.7``5Y.Y$`````r3c`Fu``````
::``````765i``/```/d3Q``````6G7`.7``76/`m`````J.@`xh````````````76DD``C```C$xh7`````YV5`f5``5Y/`m`````Fu@`xh````````````76yD``C```C$
::xh7`````YV5`f5````C`o`````)K@`xh````````````5Yoi``/```/d3Q``````6G7`.7``5Y}Yf`````;oV`Fu````````````zD1i``/```/d3Q``````6G7`.7``76
::}`M`````<P@`xh``````````````0i``/```/d3Q``````6G7`.7``76/`m`````@a@`xh````````````5Yri``/```/d3Q``````6G7`.7``5Y}Yf`````\<V`Fu````
::````````zD8i``/```/d3Q``````6G7`.7``76/`m`````zDy`xh``````````````Fi``/```)K````````6J5`~`````B55Y7```````````````````````````````
::````````````````````````````````````xh)`An````i```s7``5Ym55Y7```f5``<P````ox``~```,#````,```;o)`An````$```%5````$55Y7```^5``@a````
::++``~```5Y````n```AnC`{}````7```g```<P57767```1```&M````F1``T```J.``5Y/```-|.`{}````7```g```zDC7767```1```&M````41``T```J.``5Y/```
::P2.`{}````7```g```7677767```1```&M````5R``T```J.``5Y/```a+.`{}````7```g```zD.7767```~```&M````11``T```An``5Y/```gk.`{}````5```g```
::zD}7767```4```&M````yh``T```Xi``5Y/```fe.`{}````5```g```<P/7767```F```&M````u1``T```C$``5Y/```?&.`{}````/```g```76/7767```97``l0``
::``Ie``~```l0````d```xhi`An````d```97````G55Y7```y7``76````fe``~```Tg````f```Xi)`An````G```r7````i55Y7```r7``^-````<P``~```^-````G`
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````|+``````r3?}``````pzT```````}x``````MjK}``````&>T```````cx``
::````r3;}``````QJT`````5Y1x``````3Qv}``````ZBT```````~x``````vpt}``````OPT`````5Y8x``````5Yu5``````4A)`````5YaR``````feu5``````SS)`
::````5YkR``````gku5``````P0)`````765p``````3QR}````````````````fR``````````zD(R````C`````````````````````````|+``````r3?}``````pzT`
::``````}x``````MjK}``````&>T```````cx``````r3;}``````QJT`````5Y1x``````3Qv}``````ZBT```````~x``````vpt}``````OPT`````5Y8x``````5Yu5
::``````4A)`````5YaR``````feu5``````SS)`````5YkR``````gku5``````P0)`````765p``````3QR}``````````````zD?`n).f/|$n?c^L4/9Aa/t=@+3xZ42#
::r!i0z)<G?`Fum6!37,ZMBLRH@v!>P1H+<\|B4eoum`fe&DqAzIV1O3^FH&beQE;;(>oZP!``-fwrw,LJ&#7~iS*/4G9={5nTFu(IFI/}\n,=R55Yd/KTd4G8^H7XEZ2=#3
::,rS4>`|5h,Fp@baA<>K[?2vv)8j7SH{A>Z,f``~uMdo=NLD4BKqH/yTm&K;2FTI{#s*P3A_$P1u(YF%{``3;S$~BO$|S?]i1rapU1Y!3(;=c#F!b{A;]>1<+?M=B]eQ!sA
::+>-Pl7{TvbBLou1;2ZP1s=NLD4-`k1S$~Bj$]SYcxt9=dMUbPK3EElwrX6#3`n/M4egmaAgXyt/O<Pn`HpqW+4X8NbXRVm&KD=gWPMK^y!rA3$Qf``*7BCwF(;=c#FNbXR
::Vm&KD=f4|Bx9WHdy*A/`kkl0P[)=;M=c44i-fSLA#nX=5Y<P33lM9Mg`3Q76F[iS=SZGgGK`$`.Q%S@](1o`,`.Q%SGzQf``m`.Q%Svm9f``V`YSLAXm4G``f`WqkRrIDt
::CO``67FFg5)8o8J!HhT75Y/Y^L>S%S97``````````````````````````````````````````````````````````````````````````````````````5Y``J.``5YEK
::hHHl{```x7``l```%5Hooxn$!Db55T^R.d6g55^cvBH~IKRzJiEnoTm$hX{dZE,Jnd2gK}alLK>~0K<<p{#3Ix9$sX!iP.q6)diJ/deJWDL/*KF~QtYU!z;$gTDc+-y+md
::yJ;G7=MOr/+K5-|AfB!7@$co|9;j3`*/[K|-,<eD|zA$ro7```````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````
:niblld:
::Y#B)f5``5Y`````Ym`l07```````y7``````````````````````````````````````5Y)```hjhQ/`??~A]0-PG3KK=mrAh6L[P!)n9MyH!2\SNJU<?2jib{g6)!@iW%
::;d+=WT\cHVdXQ)````````#H>u;Ogi@?\XY%*a|-&,)jqE\%yo[Cj.oU4{8J#%KBpyafO#@9bnUVK.W3mIlS4@b<_sS`````````````````76nC``9;y`!!F2q5``````
::``pUTiE-O5J6/`h```97``````a+$```y7``````T`````4```y7``~`4`````767`5```````r7``y7``^IM`y7``D```u```````u`````````4```````4`````````
::``Xi````````````j\97``.`````````````y7``d/``````````````7`8,``zDL5``K```````````````````````````````````````````````````d`3Q7`````
::````````````````````````44hQv%o7``(X8```|5``Xi}```}```````````````5Y``Fu3-IHTR````n7````/```/```$C````````````````u```K,KlvJ>n``Af
::````g```1```Fu7```````````````|5``.8oQfSEG/`UZ````zD``Xi````F`````````````````7`*i````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````Xi?75Y-`LfMj$`,#K6*d.7}`-|oi77I57`0bto]`])``x6iOJD]/``T/0ixh3`zD+`{}l0f`;oED/5F45`Gs~DS`bt``\d{+}6kd``)5LazD/55Y
::07WIWv<`TgB`cCimC`Sz}6E`^p``US^-GY_n``~CGs5Y,776A5VS``?`,#NYA/F~/`]O<DS`~A``[hJx$`V.``m<5`<PE`76SK``.7n`uFTi..r75`m/4MX`CX``Xd\O7`
::(55Y|`2d_yh`)Kd`g`;G5`P0|5i`\X``,.pU<PY.``><5`wrx```D$``wy}`C$27``E-``RI{`<PSC``#uDZ<DP776D5@1``````````J`%5ycvp56$`I`77rc3Q56,```
::``MdsxvT)8o8}?7y%)oZP!Os9MeevQev````````^-l[Bzd3EBo8.!uA!yvd6Fd3uV/^UH.yq{Bd````*/kRuJ>1b[5@G8ZL=/``kPOI7y%)oZP!!)[B-`Xix4W7;u[SyI
::V1O3sdC4$qw}MR%)/1o`````````(6Dt.303NB]e#})SRJ0=@+3xC```l0\r5zmr04x}7uEl]J0K{=R5``````A~{A6Rpt^[0MGcNBM5``C>H!1VmZB*axY+H&X8OSVRWR
::/```&M(I8XzIarF3Gd.Mv!``<MP27`d`K`{7gn-|Fud`````````FF5Y/`uY*`$5^VP27`76w`%5&M/d/Yd`;`P`F}vSV%/6T`m7``````````````````J.^-``````ji
::7`.7``76/`u`````l0@`xh````.7,G``````U)``)```/dA@^5#uu9J\=l@Vf+{3AFTr@W{C13.>Jdl9MVp0CqZ$9d2d&NSLTQPvB|[de)NzuZiLp2ySeW&ODMu=Xqd?WM
::YY?pUj|Z8f}?S8k^PfkgH2rTN2O7a?jq89KVb#%lF,.n)yyF/|qNY;c;i-*6q&t6K|.T(IzKB/6PC2|2;0;dKQu1\I5.B=;z-)O.5?Ta]2X^@V%|Owiaml$W*{QIyyv}2m
::6?.N_Q]oViP1Z^Ka0dPv}?C;W$*f!g{S%=67LPd;0>jp!_5wYNuBo2%wtff0Gq`ku,>}~Pz>J0>+wqLlN;02@9nHup<Xi{Po;V]LC6#4d)-BL^Sbumt({5.^>PceJY=#8+
::C2vU4=g#9f.%dHK5=-mvadfTr;K#o1V\J}FW8u)>klHIQTCE$%p^83a&C;on0A.B+u@Vt1fLb<RR\&g&oeDn{Lp.ld|\uRA_~iZ]m*]kY1hJ-C%vrntLX3xDcWqU[Q}#`s
::i/*se_+J7F`~d(iWD;0-2cwdbo~[|;/5W3i=(5;/5G4B.)F8;~6b5Hhu/fQ(klRV2tvZL1\((r$,l5P)DW49(=fEQ#E?X=KX-R-d9H<*%+`2dvh[7no`FdT9Qj1.=5jyJ5
::quIxmqJcFD>{l4|ue_1@%|3]qL$^Hpo1K;=aeUM*uw=w2KWVJ\9LP,Q(4RIKu<zM?0k*[n<{Sib[jQnspEkjjAuw3<pMFI,,Y-(CZBM}gK8IxTHL0#IAoNPc)*J5TjKZnE
::G]{)iN193Z_lAuwX$DlUs=mOSJMtAXy#Nc}Ua?jyIm!IA!8O_q3=@tUp<|S\jU;I^#tAP;QPZ(7^dSpA/@vLt9CAV-U7WHEc1}UdHsvC/dXkTl{r/X|@4+!t@L{-w@!cSn
::w?VGt(iO$(!|9(,fIcbqS#xv^_vZX;9Ju}r.M9XT&|w6@$4?U||\q=R6s_v^/!t/qNE>un[9^h6pBL9{s7z~X)]67J-[>I}0YmJG3cpK0>voo,9yp~bBRF59us#=9tO^|B
::#~gqX|vm|A2vfn*rw\[3&^opG]vb2M3|z}$7n%/tvQ\y/O1%(G!rzoi4w$cqx+k{p/]U1}*RtN;ut&<lpFqQF=Y707``Dzo`76``5YvkGa($H(RA-_#kcXuCj}````gWtD
::dM$\dIyF$;Q`wwpdXp=A#p<ni~%j4(or~;[&?=5CKf9])2nE;LWr?#7b{j3SAmxap@|tj`0^+c$qX1\-{}z73iu4<<J$HLPS!l9l8#NLk%PFz,qt#ElV2BgKf]xgnM^=Gg
::Bp+L2qDbwJi7[5LS)S8d)02s_lcDlO~QwqT+WU~46k/#yDL~fhe{?5iaVdFrya&<J$mFiRCT,xnUGIQiKIi8w+~sD1<$XV4W?qm,f>msT#{\BtEDa2#&~qDGG[C*m}DxEX
::rKn^JB459%D3Z@(=|[XxDFA/#k6xC*Y2nvA)\h~%#0l7;(~Pm5l6@_]I~-S)7g/Co?ied1>GLs+tan|,xO^?Xm}gynwM*[B*D%#rN{3<kobBqj;ZOMV)z%-,c2(#UZ.~vC
::*,jG.ig.(<cJZt1o0387nFXuT64tz8jXShXg[6BX*H%SjQK<y}yZ6TdmLtitk7?.!B_tep}?7kp282P!SAJIeTI$SsV~vaU.Nt|iGaoqLhSo+I,?{1[zom[>f,IB;q?|Fn
::!RP?8;Y4t9mT=PkrPPi%)+P>2tU&]X#}V6\\iOR@sMOn,<WRJ=)cye<a{<tMkdij.yF}q\J0ZcAhRgFSX4_]V}QM4^~5t3H6)kGF6~kY=h>FY/v,M8|#L+42AweG}J%![N
::-RU{ksS)F\Nju5*+}```<l6\uDPl.5``````#xy;Y{J`a`J.Xi*4>OZ>vL``````gkm8zoM{A!J.u`DvNos_WOD`````5Ytg]n}MZPo`9}&Mx,ljRh/,``````tM7]K2d.
::fVy7n`]7r{%ET|m`````<PeNGdgJ#U,6}dMj#\>jIcsX``````UZV1*t,.swU5$Y?f``,COI``````5YSAhPOqh[GJ%5P05`qfuHG```````o*0=rbtYz,60````V%mc``
::``````fqt2gI*5.G.7LPv#f`k6\/``````76?A{9Q|b-\Xs}````mPe,d```````B$~x]T;`T`%n@a}8ba8VoV``````MX(Q&+df{@|5{`.ogM__IXm`````5Y\W]KQZ#U
::$Y{}!Ai5xkL%gG``````6_$+oN-5.G.7C`NIj,n9`{f`````76,,zAE|@0nY%5h,26@NW*cC``````Bp!SzqI7~}36.YW*V>D]8H}`````<PuP[]<(``````````y0,`uF
::z`zDcQ7`CSd`^-U7``di7`RY)```?/``&0``}{g`76j}``gEn`l0g```q*``]</`Tgjn``R>Qf33KVW4K^IQ&X*AP1Qasw.```|5}Yn`]`07C$E)phC`o`````````FuG8
::u+hu0S0].fCrULd`i<,rpMh?%H~IA2L;AFo\C```````76&pv.WA,A+ryskTd```An-1GO.o|Bp#!(&%3$Qfi<,rpMjo%HEl<Z0=DUaT=c##7`````R>Qf33J;]c#FWH$`
::``FuG8u+OSuAa/P1(-7MhV{}ou-02XC=w#id]8~```q-yskTLJ&#0$LA$z>r~+@5``````xhuAtz9f{2/o)82F0$LA,7````````q-yskTBb&#0$LA$z>r~+@5``````xh
::uAtz+[{2Q,fcD>$Q,`44ph$Y~`u5tM*]Ti,`g`n5@{9H7`d`````````5IFuGY$`y`..`1C$~PK`57``````J..Y)`*`55Ful07`C`X`d7``````pU*leZuU33h\/J`ZHE
::)S/lSK5~````JyC$}6K`M7Fnj\Fu.Y)`z`@}_yxh/`````````7,76<D,`I7j/5I5Y<D,`I7j/5I5Y~P)`I7j/5I5Y56,`I7j/5I5Y56)`I7j/5I)Kn6D`|`If115Y7`C`
::T`.7(d}L``}6o`V5zC<P76C`-`````````3Q.6S`\74u/dogmY^`R5.c,#TimY*`S5``````xhiYS`\74uy7ph)`^`K5+{Sz56uYL`A5tME)~P,`^`{5}{j\Ti)`Z`````
::RIL@HP{`}7Md/2pUd6-`g5.c3QTiG`*`-5xcvp~PuY~`R5``+L,#.6w`n5E)11TiG`R`````````3Q.6S`\74uzDTiG`R`n5zC<P5Y/`?`;7j/5I5Y/YC`L`^5(d}L``/`
::,`,7-fbt)K5`)`-`L}V%C$7`C`o`I5G9?&Tg}`T`G7IVpUog}`T`G7IVpUog}`T`G7IVpUog}`T`G7IVpUog}`T`G7IVpUog}`T`G7IVpU7```````h8_nh`````}```r7
::``^-I7``%T``J.``^-zz3q/I>Q;Q89F-,%Pg.Za(4Laj*#|sBelESMR)6sRjKNVj|Z*_7`C{8YH;qX76J6C`2b[DXi5+7`&/.`<PoiIY5-_5){7`riyX7`<8T`)K27``{)
::U5`>pCzD6/``x7f`76oX76].c6ItA776Nqq*EKPN0ih7sUR\````PjA(8&v1voI_Q71ZY&BJ|NCYmjV0Bb{izD5C``uF26=.dW7`J85d&JZN6G)^[DH;mS0iQ6Si!b*3K#
::IzTjE]jNXiy$``,Gn?/2rDKN4}P7-|NKzDbIY#}^KCZz`<y`p$jjC$i}RTTL!z2BsJ5Y%k{6HEnd7`8ilC,8bX5YPo^7!SP.zDFoJggKRX@tH_C`W_{6;\X%``MS``]m)f
::}LHz/`$z9/~F$!WDGQ[.[dPN568hu$s~]d)K\#i`vS7<b._~``^H9`5^K7``hw``#s)`76c2)<ngf`L@j$Tg__CYvWG.76o/``qYz`os]VgkX).6q~#n)nB`G`RC<I/2rD
::KN4}A`oykATg`L_5Y-yPEDL5u`TLDpJ.Qa8`c/``7,^.diAJf`\]].Tig$5(=eDpJ.5siY&GcX(X5`zDCJ@gDj5V)K<;.`394`rB&x7`|xb_ky]qtieU~7Y-Z```/TY_+w
::kq}I9gIV}D!k~;Z_FXhTucji<NIgkN,YvWV|Xgd_Sm1q?o}Ljk#}MW,l}If_j6Z{pbtJ{%yh15````{`5YAX~`(I16>;IdzD[{T`7y@Wb@OH!0J,9m}LJ-``Suf`db(di<
::ru{`x3v5Iiq```vBB`L;0n76M&j_F;*/mX4N/6;w4`zDGL)YO_7`o\%7``L>{%6onTC$UPDj1WMi&6E_Cs8&@7\<>/``AT!`bjfiG6B+d`W$e5^.f6gkyG.`<P^g<Duik.
::jiU9G6V5``7y``C$$6gkyGN`;[x7``{)+`=k%.TiQOA7Xl``}LC`76K5*PbEi5*]?```zV}`Tg</``AT[7os=9t/W6*nY-|5--8K``]m*c}L>adY1D>c(Xf`zDOz*nY-|5
::--e#t`0_d`\<HDDDH=!9tJ]_UDe5[PPE7```wsO=SyQ4E--k1/BVky1o^_n`;ayUt;wD76s#m`q|>.-DKbIghs!6mC0k\59wl7mK!/7`X2~`5|mcTglP.`&]+.zD_aPI1T
::h7hK1jC$P/si(X~C``rO%m<bZWK#Omjh-x%.tX~OaQW$O7@Bqz9l#CC7mthXv&!j9Yo\w}``w+n6q;w.lXZ[7Y1,25pgY```CC&6cbJ]nnLe`YOuoD{}VJi6y2$/BTM\s_
::WbB/BRv6$`wyS+\<{gp$m.N5)K4?/dse//kg*$,6eq!.Y-6```T_8`\rVX(Xf!-DglUPr;f3%gu)e70b5V;KzLEC8;4tC$Eo.CObdK}LlaC$=1d/TguZ]m%}sh(XEVgDhn
::16Z;=9</s`SaEy0*C$zyv/F$G?^-y&5/W;huvo5Jz7U=}`C$Xm~~h)T`7yx{?t#vr.%FG5J.dn7`Uzr$5SeNVY})_JpbZMzDqpjuyL%.oi;OP4W$H?^-FzE7Adh71Ko+<z
::_b?rQJ-FpYr,.`/2M}XiKS`Y_|F.J.h^/`_;9R(X>+76\xZiji;RzDy)SOAZEozD@n.`ldc?}LMsPI1Tyu/I~j1`y}``5|qfpznCU`U$c?nLFzE70de,to5Jf6e~!CQJ*#
::(DY;*I=K`m~~h)VT<b?yn4-KG)e|^776[&)5RVO7vB7H.7,s7z=<=c7Yi^7`C$hQ|{bMbPq~f`76Gby`AdV,;ozy=6_b7rQJQ&XXhTK~=KdDI594zn6#aE)K6P}6vWokXg
::u$0`W;ru/I<RG`hTw~7;c=M6u)$T0b3CLD8_uKvwY/Ii5u``YVwsCb2_U~Z8;C~FPN4X>e!r7;IP6gE!Wbtb-fhr%3PaJkRaPVV_/`3#h7,K4jy7RZ.75ISdf5PTbX=VYh
::zDTP%n6#fi76_P=hq|[sb@RuyKJ,t75B87/`T*?<Qy}$DYg4G`p$XdXip}{i%FwnC$OY/Ysdpx`McZe6@\}`5I.3jhvOS0jb~A_Qer``Fnth`S8]o.O7ca`MJC``vx4.3;
::}@sh(```&i&6$bQ]a}>9G`}LC.LDMP2U;wp776,2h`A{U7H+(K,6O_M`o\^.U)Z.5`p$H5Ii4Ul0uky_iKbU/d=1@`)Kf8~DDoq7os;CZz?zw77kA75YWEi5TF{7`BWg7Y
::6qR7oKFj[G)k16zEHz``1B_5Y-Wf~D/>]`SNym}LJ-E)nN.7TgCKJ.}D-`db\Gb<?zG`p$kLC$7EK/F$@I^-E|7/W;7uvo<Rz7e~EC5^Q&CY`ET,<bAS*D*#d)x;bBf$Kb
::/CU$&o}L(sV`e~SC/^Le0YcJmT0b8}LD%UX}zp#5_h)l___|&`7ts$7`BRjukgF9c6g~SiY-LE)K5L]`0_2`}tQp``)kG`bq~G5Y/xi5l&x51gCKFuvf=`)K`>-DY;SI7;
::#T/6u)fT<baR*D*#})8;!LC$.~@`s;7u/Ic)\`hTK~7;$x%gu)fT0b}),KnC\`U$<onLlxb70dV,toh{~`z_rPT\8n,6R-[_F;#5}+t7)`q|@7`BIKd`DWK6>EL;``8iE7
::<b/iEDALJCx;!LXi>p/C3b51E-/x7/0dD,5I;k97V~^CQJx&(DY;~I=K=t^gY$X,<bTu&DnC\`F$NI^-/x7/W;.uvovyz7e~^C5^$NqYU$T,<b8}LD5C\`U$LInLlxb70d
::V,toj%f692cXaXd8CY`ET,<b!S*D*#d)x;.4f$>p/CU$@I}Lt3.7RCv,;o<R<z_bdrQJNepYhG7`~~#5_hQ`/`9w(h(Xt{IYx_-Pbqld5Y&3@`wLFXU<g{=6e~ZCQJ9*XX
::Y;zI=K)tl6u)E7<b/i!DH##`ObV1CLXwb70dI,}I&R=6e~NCBJTB-DhT;/=K)t^gY$T,0bTu&DG>\`F$P58.JFb7wLG+\<2y~`#TM/=KH1^gY$M,0b+)&DnC\`F$P58.oF
::V`_b7r5^m80Yu)$T<bol9KG>d)8;l>C$.~y`0d[)}I&R\`hTK~=KtW7YlgE7<b/iaDW|JCx;!LXi|3/C3b51E-/x7/0d_)GK;kt/V~ECQJ;*(DY;HI=Kg?^gY$X,<bgu&D
::nC\`F$jo^-/x7/W;!mvow{z7fknR(X&37Y^02}=K|9t/PWj!hbhD8.&6]a&q.KEM7K}`jjN7<1qj4`Xw[DH;fc``w})`7wc`}L9/5Yx*~`5|GcTggLF_cqD`vBpJAnCV=m
::/2IXV6O_V6~E%d%zdwf6xdif1~T<BP!b<unFTC\`F$NI^-lxb7W;.uvo<R<ze~gCBJge7Y)k5+^\uG``^7/`=}D}C$B,XiCVi5}Ls/vC/G&6$bQ&`NhT?/=K3=cPY$X,0b
::(mBhnCd)e|@7#h[~5`%qi5}L*6/Y|Th`6#SJ)K~fciqp~5SRIb9`e_yY~EZm``egb7<bN`5RF_l0m]e5Lg/xV`_b/r5^1B0YcJ$T<b>m&DVn__s$Nn)KxmzDJ,*o}L/xV`
::_b|L5^1B0YcJGT<b>m&Dt3%dQ;o.&2j_,5FAu$}LL7)YO_M`o\~m``hK!`F$x5J.Ndb7AdV,;oL/<z_b7rQJTBpYu)r7<b/izD~K!`ObkvCL6db70dQ)}I&R=6e~1CBJTB
::-DhTm/=K)t^gY$c,0bti&D?;A`(9T$}LJ-E)=1Q7Tg1Cf692B`ji$x%gu)b70b});K6dJC8;!Lti?$@`wLR7\<RCG`Y;lI7;$xM6cJnT<bnS9KG>})8;!LC$?$@`0dV,}I
::+/\`hTc~=KxDogAEF`=ka7DRH+7`&/Q)5I;k``GTu/=K+P%g`Ec,0bti;K6dJCx;U-ti.~y`AdQ);o<R<z_b+LQJl6pYH_*nY--fhr%3_|[|;0KinjM`MPZ]y?|_``N&7`
::^-\dlK`Y0ne|-.zD/W[5wy25Kg-k7Yrf;`-|/_7Yw._uC)cuDL9G(_ArYf76G>9u2]5`0mZ67`C,``5^/`Tgn+c56oy7Ip.OC`#xC`zDv=<XDod`b&p_6DOX]r<o.H.,&w
::Y_1,+5Tgold}Wfr./2dk7Y(fwi}T[]fYSC``<b7`C$7+7`|7c6ItdL``7?n`bt?`5Y^B.<N-$`oy~_`6P<PM}>nniI5pj_8I6.zD>pVn391n}L&`5Y~CUPr;P`Tg{`{j\V
::[7zD`G``u~(wHF9f5YE^7YPau/MI(P@><oTW7Y23/`]d=(1pIj/690DC5I=]ldi,hY#b/`)KC)``F$``5IIi$D15/`IV>`)K|```;c7`5^|eTgh7C`btI`5Y7Jd<N-u`oy
::~_`6P<pI}>nniI?]j_8I6.zD`Oi`jfIs1prDKN4}!5~F;V``)|``;o4=c$$/7`MMY_|<No_;c/,>)T@^7YmTt`2bEN)KKCQu!k``C$C6gkyGh7tKp_+zn]z/~F>N_DK*3|
::EKf94u(!V2BbbUgDRkN3[|*.Xi=V``vC4O.27Y}7Z{46dbzN4`3=7YPa-5zDt|7YRjr7},8P&opJkj`6qs7`+~[0cFM`yhQ})`z$7`C$;`5YK52nji^.diu7M`$ZI`5Y\b
::}<N-$`oy~_`6P<au}>PdiIg}j_8I6.zDKb$n39mi}L,W7Y=9qDn~&ju`[)``7;/`)K`z/`J/RYItmK``=|``;ozqc$a3``MMY_|<NoDvc/i>)Tx*7YmTt`2bY|xDV+X`SN
::P54gMsPI9w``5Iz7768/``5||5--G+``n!)`}LV```=I``z$4uC$167`aLC`zDzKHXDon`b&p_6DOX@^<oF~.,TU__1,+5TgzadYN-^%cFIi$D15@7os$G``Cy``E)h(GL
::rz``gZ`Y(+P)Y$Z7>oC)i!7YnJm`3;vDC$m~vn@N``}L~DKN4}&6ubFNl+aErv7;9DmRWY]a&q0Dh7K_+sSy#5J.)d``F~W$~F]N``+/n`5qw.tX`OP`RCRYIt<`zDtB_5
::Y-%IN+o\f`7x.zJ.QznY]bNVhOu!5`2mY_F;PUnct3!.b]o.&2PsRjKNVj|Z*_7`V~5`xh;K;gG#m`3;\5)KyONrW$P<J.f6gkSZ7`5IcNfYw,xP{;d(u#qCCL8l#dXis*
::8`]?J}t>,;W=i&s/pUXO7Yzqq*EKPN0ih7sUR\+)``FG;74CcGUU[sC74T]7V%RT[5]lK7G9}O5Y%d{`3,rnpUdCGOR;1-@q7t5zJ(BTtwK97`\=?>O[n^XKPKq@aS/WQH
::cSDy[^I]sx+\55D[l{nF#2+[fu?o;wcpmAhLs1r8-s,8_Ov>|[AW31S(vzB?LkR-&{%ORMbN9x&f;7BC^5[lNPK_{i````{D?U]\Im0bmgzDZkfj[|*.Xi237Yu92Yk<ak
::``|1}`7;mdcxG\ju(|S^Q}Fy.`>/hT{+mIJ.TLYUsU6(7Y]B[.ji#CzD#1C=Y-`iBz6d}`XdF$Sz.^5`!z]&SO7,9i+K__ky#9t/AX`YArqfBzE%7Y8Iz.tXfH``F$hT{+
::kt7`@X{C>0HCy7C,TjP4lk`6Sy,`J;;k+h7WPI_;8`5IJKR5GTU7>0x;76&iRS=MT~#5cd7YNGw.tX)]7Y1,27B.}<eI0tc`5IFmrA$v%`NK5Vb.t;/65^l/@7~y7YD?Vj
::XH-kiY*huQ5^%NB+[7[PPE7```ws6qSyQ4E--k1/&&Z]R?|_``GT7Y%OdCl<~!m`3;>/hiNqNrW$P`$tI)5Y{IIZQ06v76&i}/!4T/86H>^kR[V_zP}Cd`Dqe}<PG97`l+
::{cml~$y68xunqSy/TgI$n}wMidpUqsc58yT}@aU5/zfu]8,wPk97#/&6ubkq7Y_IUPr;NizDam.tY-<bJ.VLf`idO#h<dLaNkTU_FQGkh,X2&6cb)C76{InC>06v76&i./
::!4T/86H>^kR[V_zP_jyiO>g.h[Uth`Yk~99cs=5YSSQ60?Fi<PBOtF%M}NIpBcI=OCIH=qp4/`gV=?E{a2;VIE/>F[DWtCl=Glz?-V?QNQN/[^r]_xnta3OC7-=q*[Zjh?
::_f/AH\cRe7G5UW{a)9*sIp~[;jPf@w$/aSD$<P<N5sl4&NGxI#!6PZf9aqXjGY*)b)Q89+5Y1x$/aSngl0p](i[^jCT\p.d`_oDT;wtLWl9T1.}8d|@,G&Vo%[6(tCk[R.
::eI`e`6EPju(|+k7Y)qNrjb07C$6TF/RCAd{+5;7`@X+=Q0zCg.R$`Y_V$dcxrd7`x;)|H<,^5`!zR)iOd,|5)I*a%0PW7YnW4Qtb$itK+q^dp|.Krn+PDj1WrDVKNPK_{i
::````{D]U]\Im0bPUv0Rkd`xJ25KgJl/YW{46dbzN``VJQD\$Q@76XXf``T,`.t#Qi/irC`db``TgDI``x7f`76XXX6].Qi4m8]1`s`SaEyO776~qNrW$!7KBLT``wL-V1O
::YE5Y&i}/!4T/86H>^kR[V_zP=UNrjb@_`6+th`ITh`L@r,.6oQQD!b\C@+Yn7`x;K|h<+x5`!zV)iOd,|5)I<a%02W7Y5!QD!bqfBz7i`Y8IJ/Tib;`YD?Y7^-+.``j|#e
::;J-N_DK*lLEKf94u(!V2BbbUgDRkfj[|*.Xi4WE.%q_7}LMkS7DWn.^-]n``a```<b{`zD-;#!i>FD\<i7``DYu6#b=j7Yj|rD(|x`C$qJ*]Uwq7\<UKV6BZV`CL9dr.6Q
::Y__VXd~DRDcKvwjjXgFUfbW$A_`60Dh`N5S`dbW$fZS,h_|Mz/~Dw#/`@L5`}LVkvC>>V`L@@K76@)>_|M$/K+6X7`q|#/J.@P``+^a`jiCW`6CNKi^yt/Y^WFCYZCn`}L
::r&``g(@hEKIP6gE!cItb-fhrr```xh<;y?f_W`A(yU1;wD76~!Si2b7iBzqnFu8Fx`C$$xbbUwq7\<UKV6BZV`CL9dr.6QY__Vx_6DtmGb6ox/ZR(qNrjbR`}LLRH\KEa`
::kgSv?iB^CY5^_7@7~y7YP},`}L/QUC\r&6ubkD76yXU7>0x;76&i)![MT~#5cd7YNGw.tX\v`Y1,e5Bg,X7YacOSxr$E7;;b&6ub)C76{InC>06v76&i./!4T/86H>^kR[
::V_zPfLC`<Olu\<go7Y6L&6ubkD76[tg0_i5;TiR$9`D$8J8},$U_sH&_+h0aPIY|@_zP\bs7d8c6LmGC76{I2=&0p;764gn/!4T/86}|Ekh1V_zP/_m}tyQ4CL[jT/Sd;7
::sBWki]UtuQQJ^N}Ymj4QBb{izD5Cn`p|7YQ-(sG`\y7`pUEmpgG#m`3;>.-DMWE.%qY_g.sA``gZ`YqXP)v$Z7LoC)IQ7YnJm`3;a~Ri+7@a2|f5C$y`5Yi.``5|qf-D@`
::{j\V@}zDq/``I-!NHF9f5YE^7YN#u/KI(P@><o+q7Y23/`]dZ_1pIj.6_?>c(X$`zDT/``5qf5=K)YgkyG67TgW7``,oxPosf.76E^7YN#u/vI(P@><oEq7Y23/`]d_`hp
::Ij}61D``5^[9</bzah#b|5--G+}`n!}`769Z)<N-$`oy~_`6><D%}>nniIQyq_8I6.zD#@zn39mi}LO`5YtGk.jiU9&/t57`z$y7Ip}R``}@C`5IG```S,``Xdmi}LBP``
::%I7`pUTb!gg)}`==3_Di3iiRx)~T~C9KY_QCR7)KTj}6N-UzcFIi$D15+7os$G``>$``G9h(GLrz``gZ`YqXP)Y$Z7LoC)zb7YnJm`3;j?C$m~vn@N``}L~DKN4}&6ubFN
::P+-e+7osIP6gE!Aytb-fhrr```xh<;@?f_W`>e!r=K%P![eWm`6o6.IiO_5dRqYj^-MxzD@qY]vo5_4`Qj67Gs&DzD8gO`~1}`5YXT``#k@7GsoDRYK|)7~1L.^D`O``(d
::.`zD^ggD-.t`2bb.Tgn+G76oy7Ipen``-f=O.2K_7YZH$`oy~_`6><Nn}>nniIep3_8I6.zD}/in397`eL#P5Y~C``5|7`)K.OA7+)4`rB3<5`n+``@a2MlK\#7`SSj_g.
::j-R^RCT)o~AL`Yt~B`H;L0<6RzO`=kN-oi*7``ly``5Iz0768/UPr;^.diu71`$ZG`5Y9Zf<N-$`oy~_`6><g@}>nniI<<3_8I6.zD#@Sn391nnLMsH`C{``5^1C;ow`Sa
::Eygn76+C``-fC.C2]{``K?7YjghC=L#62)}>8#7Y-#d`W$)f4->aGY1D``5^[9,6M<5`z$y7Ip!D}`}@5`<Pf?>XDod`b&p_6D2Xe4<o.H.,M,j_1,+5Tg@V9}Wfr./2t`
::76~ChY!$(fUz%`{j\VQ7zDR/``I-)zHF9f5YE^7YN#u/1I(P@><o437Y23/`]dX5hpIj}6_?``5^O9.6g~BP#b8`)K)YgkyG)`,#D576~C``/dM`)KFUX`jf~`,#q```IC
::ru\]w7Tguq7YOAK+-CN0UJJc(jzPjj``O7G5osX$~6h7|Uv\EN)K4Y7`aL5`<P<KLXDon`b&p_6D2XD+<o.H.,`WW_1,+5TgzaGYN-UzcFIi$D15+7os$G``>$``G9h(GL
::rz``gZ`YqXP)Y$Z7LoC)e*7YnJm`3;j?C$m~vn@N``}L~DKN4}&6ubFN!x-e!r7;IP6gE!Aytb-fhrr```xh<;y?f_W`A(q*1;wD76vv``V%+~c$7Yi`4Nl7)K5_4`1B7Y
::jgf.76E^7YN#u/nIy6@><o?37Y23/`]d4O1p0`|etGT`7;5`)K^```J}si(Xoi$D15c`IV9```4;;}jf;`-|/_7YG.!Md)NmDLcsP_ArYf76ZKIc2]4uC$|ONrwye54g/6
::gkyG)`,#D576~C``/dM`)KFUi`jfL`,#q```ICQu\]w7Tguq7YOA?X>CUhUJJc!jzPjj``O7}7osx@~6p5``z$y7Ip.ONrVIVjoHVkq7Vw<;^Twa|er9x$8^-N/Ymjw-Qb
::{izD8_?}x3>.zDKb5`$rl7,K,`56K5e0jiX$76oJKf){?WMKGtz.d*3=G$E3/`)nY_|<+DOlV~5`Xi;KKgAEEf){DwMK|=j`2(c!.LHWc`\y[0~FnN.Y.rU}^%5gzD\ot5
::ve+uXiLJ-`,nRYItl```h7uC\]{`5YXX/6].Wg(Xoi$DUT7`^-Sp,K*x4.zp``C$wap7RCRYItHDMjfX7`^-Q3,KV+2`SN7`}L|a.YtG//jix`TgA+aG6oy7Ip1$``vCOD
::/2jk``NYL7bj|5--W,56QZw.0XD6R`,sT7Tg>/``nTunosd$/6!`SaQqw.;ih/}`+`;>(Xi,Ci};L`.89w6KnC[~e|P/}/<~U`WfC;/2[```Y^Q.Y-Apop1KR`mhF$}LtT
::;K.,kbvp=bzLH>BD)b27``})o7bjXD<DB`{jtW|<^.Z_-cB&V}/2jk^z4/Q6%t]N{esErv=K;D06G36S0bDi9XNk85e|*.Xi.j[5W$e5pgBaC7RC@7$K%_f5`E&`-;^j7Y
::nJw5,8(fLD(PpMzp<zXiT$``vCq;/2%jh,P/c6ItY]97}*M`3~A```<zNYeu!`5^=9<6#6ah#b|5--e#pMzpl/fRnMZ7`Tx<J.qs8`rj7DQJzN97#kYf=KoDO/=]s5P0I/
::5YK|^)#;D,KBga8`c/B`Z;+[7YjKa5Y-,VzDG3`Y6ZU/XiYE``VI~Nwr;jC$P/si(X@^``N^_5Y-G6TgA+356oF)h5[UP`FK9_zPjj%5c/shpm27``})P/bjb.Tg!+356o
::y7Ip;2e`pY4Yr;fc76Q,$5bjA```<zKYeu5Dd?C`zD%6G7bj|5--8K``E)#b}L~67`4GV+aX%N``s`SaEy{`5YXXD6euc.5IB]nnO7[D*;^.diAJ``;or;d$.z9`z{F+\<
::XjIVP/c6It^]BCw(3f7;6D%zkF6S<b$itK+q^dp|.KJn+PDj1W/bpZVkq7VW,lto%_C`W_GRYg%Pn6eWm`6o>.-D.~5`qwl7)K$_y7i]46nbBNy7RTk.nA;CNg/<}`p${`
::5YXXD6*hT/(XgD76i.[DZ;|9V6!`SaQq)`zDMY5YaY!.Y-FW7Y/C}`XdJM^-$d``u~W$~FJD76i.Ziji|9V6!`SaEy>/C$$i~/jGg`TgXoCzfnu`db[9d6M<i)Y-$q7Y{/
::``pzDpJ.Qaz7l>AkzP$^}`(I{`,82>zDh#<`2(F6.d%0``DWePoxKi``I~B/Y-(fUzNIj_8I5`zDxaw`|n&6cbaS7Y]}9Bkid$C6>Ok_ArXPoKe+.S6oj?KiFCh`RC.`zD
::^ggDhnUPr;^.diAJs$Y-3C{+zK``E)#b}L5X5`XfCAjXJ]BCO7*PbEY9D6%^iYV^cToirje/+)M<5&IY5Yk$q_OuY9I6#6v%W~=5C!d7}`Xdok`66L#!i>R7hKo)5Y{InC
::>06v76&i./!4T/86H>^kR[V_zPW~5`,n`d[<{T@@wjpPoxLP``8i``V%jXC$}75`z{h7hKzrn`GTM`>jA```<zNY].c6It`_qD.K`73QW4``2;X`+LP<+.<z4).V1`5Ig]
::$Y~!;}Y-yo6+>#t`@Nuk`6)d``u~W$~FJD76i.16ki|9,6!`SaEy`K?iKR~Df|P<x.[az7RCF+\<O07Yt~5`Xi;K;gu}n`5qw.HikUNrW$4`rBr/``nT]dosKizDL<!.Y-
::(*ZDo3w76oy7IpmH5`,nz;=<8h36+^S`pL5D5677}`2bG5)$TR7`VIOX\<tja`Z7XTjilp7YUd``</%.Ti;Oe/+)_,b.bIY_u;`d/2C;{`&D16r;4m76Q,$5bjA```<zKY
::eu5Dd?C`zD%6G7bj|5--8K``E)#b}LoR7`4G&6(X%N``s`SaEy{`5YXXD6euc.5IMK)Y#6sU#b|5--8K``E)#b}L/+f`XfARWXJ]AnO7*PbE|9t/PWA.<bDitX6s*`0_?p
::nLVkq7Vw<;ETwa|eG_b--;ZMx@}d7`5Y[\MrAi``zD)o;cNv}Qjc|<sU(Nc^A(t`Y-fio6TDnnOMs`zDxu``C}(75IGK5YBI``</{`}Lr-y7_}A`)KgiWDGk$UMFf5``9`
::``XG7`)K2]fY5-ahY-wj7Y{/``x7+<J.5s9}FK-_zP6r``P5``7;PUIMt3!.b]o.&2PsBOSyQ4E--k1/BV=Gvp=_^NO=&`jitD5Y}q4.q|>.ZDPW]nwy!51g-k}dNLb7Tg
::kj7YzG|-$TS```!K)5\]w.lXXYgkyG;7dbcF``)T``,#5/fTH#}`Iu{5)KA7``rHit~Fd?``-g``z$l/Xi=3Q-W$)fb-ks7Yovgg;~+```L)//bjjfWz!pMK(|%.lXr`n`
::J}9/(Xoi$DUTg7jihu76h7``<bd`zD|s7Y/4R`mTfK5YT)``;oy71iZLa_OFx5TgzaphP&h7lKgjrcg{4YZ;U9&/1<u6#bo.--6ktnB|t0C$Vj8ClyQ4CL[jdCSd;7sBWk
::\]UtG5uF(NvPA(t`Y-)i76}q4.q|v}76}W5`(d7`zDi)SCGTM`,8pC5Y^@<7(9<7)KyV#Yfg4Yr;;CZz4<C`p$}`5YIXo6Gi9/(Xoi$D15n`^V\5TgPPXXzp+W7Yp@]7(9
::``}LYg``Do``/dn```f6kn3#YWzPLk``O7[DZ;=9</W6[Uv\PU`c+qX`0_/boHFUg]SG````{DbUeWMaBb{izD5C``#sx65ClV/YLI&`H;j$``M$.`\m)f.L,WvoDWyY~E
::rD``8i``V%%zd$165`MD%C\<-DKN4}{`oyu```,/_`aezDC$;`5YaY#`6oy7IpVg5`Wf``5I;```B.``E)4`a<7#Y_ejB`H;|9</W6[Uv\PU`ct3%dQ;o.&2I```,##e8^
::qN5Y})``L@%7.)<o7`(Wh7)Kj%``T{$`?&O$uK\#7`0_2`}t?K``0XS)os7Dm/HN?ibqi55Y<h7`)n``5IwEk.C_S)Gsm`5Y=5``vCfRW<IpY_ejB`H;|997W6[Uv\PU`c
::]6]aBy````Fk=9ZU#e8^qN5Y~!m`3;}`5Y-D;GA$wk+hIN``W6ah#bo.--G+/`E}5`76wX=)V~{`TA{d``2-a5\]w776gIz70_-`db3K@6fg4Yr;;CZzj^UhtZiI-DB```
::3bZ]JTske6w.Q6%t(NvPA(t`Y-_f76@-}`vS67zD~7``=E0i7TA$zDHT,`IV,IuKs\5`\m8/.LML``k~=T~F/NvCd_ZDo\-/``-_qQvW~`zD.`5YZ{``/dn```f6G9^B|W
::zPLk``O7UP-;>fdi_W&utb-fhrr```xh<;h?f_W`>e!r=KR_H6>>.z0bP_WDRkfj[|*.XiNq[5+)+5fBezCY]b{YxdId/6.Jah@2d}@n7dV`OJ|`Ct9;n`GThY@2X}@n7d
::f`OJ|`dt,;n`GTUPpLMn!uQ,@`8o^7DR(Ih`RCR7dtxlmPngr7Qoi,{}]1a5jiY9Wz]UwavjSo^-5C``?&P65CjZ.Q(fw`~FzN``c)m`,GM.76*6/`(dOz/2Kof5!f-`db
::{L1gkN#hEq+d5Y0o-7SN+5EgL-E)r9!`)Kn?HD.KA`6#TyzDi>/`ldx7zD5sph_;h7lK1j]mP/&6cbb\7YmT``@aq5,KV+L`SN``}LLDKN4}``5^o`5Y=5``vCiO`~$^Y_
::ejB`H;|9</!*cYq;N.<XxFaQW$P5egpaPI]dBYIt(N/+-e!r7;IP6gE!V2tb-fhrr```xh<;R?f_W`Ndyz=KyN-6RZyz0bPUv0Rkd`xJx<^.qsd$u{u/t>DI/dW4[.(X_]
::O/Ud3UbatKXiFb#h3~b/<DH#ZP4FM5V}S/G`sKy`HmL$CY.Jah@2n}@n7dV`OJ|`Ct9;n`GThY@2w}@n7dV`U)5`76wX=)W@6VhOw$zDe9t`2bSC5Y2,5`mM4`,#wbBDW_
::G6X\uG``O-G/=k6.?X)ivom]!`Tg&H``Cf16Z;U9&/1<u6#bqfBz][__8I``C$d5``w6``Xi^.W~39Z_ArCi76_P%03;N.]XxFfbW$P54g/sPI[7BYIt(N/+aErv7;9D&R
::WY]aBy````Fk7wUtuQQJ^NUY$-XA0b]UqDq!}7!kRaEMV_/`,sqX\<$kk`GT16pL[-XiFb-D3~^/<DH#kQ4F/5V}z/G`sK0Y~mg$CY.Ju6@2T}@n7df`OJ|`dt,;n`GTUP
::pLMn!uQ,@`8o^7DR(Ih`RCR7dtxlmPngr7Qoi,{}]1a5jiY9Wz]UwavjSo^-5C``?&P65CjZ.Q(fw`~FzN``VJ$`,G/.76>o%70_2`Yv6p``0XC)os;C1~&5i`p$BVn$oq
::Q-%q2`}t#-``0X;5ostK76x_L`itz576IF7`TAh7@KAjuuhG4YZ;|9&/5ws_Arn```rzVY].^}~Fd`zD$7|Uv\``)Kz}``qY``Xi^.&HkFL_ArCi76Uad`39e54gPsh1Y|
::h7RK4jp$#c&6ubi9$D>_k.ji%P7RIU3I<bbUDKt3ZlQ;o.&2PsO=SyQ4E--kG`1D`IBJ[]T7-9z/Gs%PQUeWm`6o<-Ii23mK1A1CE)6LC$O04i\<jjPdt9xPIO&gzDP;gP
::xdKd/6.Ju6@2A}@n=CV`OJ|`dt,;n`GTUPpLMn!u5$@`8o^7DR(Ih`RCR7dtxlmPngr7QoR```*dB)<pkJx}Eo7`qwl7)Kr~``5Zu`?&U$uKNDquvWI5760o-7SN+5EgL-
::E)r9@`)KYc``}-sU#bafWzB+MKq;w.lXq#Y_1,``}L/7``eD``^-|5voT@!_e2~.zD`ONr%qP5pg>sjvP&h7hKgjC$a`BPbE%P7RIUO`=k;0i$Bs_$=$^5[lFjA(8&v1vo
::I_Q71ZY&BJ|NCYmj&uBb{izD8_35+@}`5YIXi6].siuF<N1`t5``7y%-Ii{YgkyGC9/2.k7Y71_U.TgD76i.hKkiY9}6T)``V%nLd$16e`RCRYIt8V76yXd`7;t`Xi-{<D
::=T5`76;?BCC{8YZ;Ym%z-R``V%t/C$}75`XG9@/20g~`Z7*PbE\5``53w7zpz/pR&Y7Ye/NX(<{gJ.m.E`dbO,%gmt|U@IvMzD[67`ld5`76IXf6].AR(Xoi$Dg^``/dVM
::zDau``G9``}Le`76!B.`IV2M,KV+?}6oy7IpG/``LRf`-|J.#9b?K+UV-C%~@ifR0G$/K+f~NR<e>jXga5Hr15eYm=I5uuF-`Y(+&,&iGTci-^;D/60m)`7yli)KdG$;,3
::}`}L)k16a~j7~F8_.Y/bE`CfxQXi2A*.nWj`$t4x7`PfY_pb|CSz8N?`)=Y576a5``p=5`5I|O5YK@``Mj>zjto$0`jfF+\<-DKN8H#9d?b)BCnok_pbjm9H7)_h|bdnZD
::2<Y_s$u`zD|y/`d8``5^>`Tg.Q}`t(Y}J.c}``I-F-pyYkCYJJ47bjqfLD@`{j\V9jIV*-eIvf|_Cb5kf6hP36ibHl.[5!>`!b)GwxTp__WbgGXi!v``jdu`]KZlg\VTt+
::OVC;MHwN?ibq>/rL3XW_s$9,jt5/*e)@Fv}LHY5Y^!Vj7;#$36!`o}zpz7$Rp3KV+)mGKB3s9`N-``pU;Kvgh7|Uv\uu5YF5``-f~l/2T65Yi.fckid$,6!`SaQqm`J.Ec
::O5`i^7Tge```L)A}bjb.Tg2XRo6o</Ii{Ygkuk/`a+(ILXXoK`H;n```rzLYeu1`5^#$x6!`o}6oy7Ipci``_Hb/3#9Z``0X``@a$$mKn5}`7w[78.*DC7RCRYIt@75YX>
::kP`k*/5Ya5``-f~l/2T65Yi.[DZ;d$,6!`SaQqm`J.EcndXDG`)KxNBC2oT`5|o{)K,>!5,yasmRJ$i`$rAYrm<|5YQ7/`p$}`5YIXf6].AR(Xoi$Dg^``/d6VzDau``G9
::``}Le`76mJ.`IV2M,KV+?}6oy7IpG/``LRf`-|J.#9b?K+UV-C%~@ifR0G$/K+f~9X<e>jXga5Hr15eYm=f5p$ic7`TgFl#g)Fv/.8%5zD^#7Yi=SzI,)q7Y-m#6bC;@j_
::QCOdhpd`$DUTF.jisE1Vg)``V%t&C$fOP`)nF+=<-DKN8H~f~F=75`0t1`5qG`C$OzE)an_Nt>u*yz/_V6rEj=5YR-`YF;n`.hz}76.W5`oriJJ.]Hw6~m<;{}HU(5EVc`
::fe(>/64Fa7IR^ojv{);XXb$H_y&jw5\<k<``0X``5|{`)K3\C`&t/`<PM)b\VTw/os|9,6!`SaEyAar@ci%rE{*_iKdIjvfCp7hK}b4`ni(_pbB`5Y\sC`Jc/`<P<`zD&v
::``5qr576V=C`&tpi<\d2f6].AR(Xoi$DUTqf-^;C1~-JY_F;c$?<ZKp69!dGUD@Pe4uk._iK\$``_/fYDbYboyfJS6AZHbtx{DE-;w!zvIWiY_%dgCaE3kcYN-1,~F^gTd
::=;*P#dX`feVC5Y}w5`orqKJ.&r96<m%mO/q?(5EVc```,/;`MD[uvpRj.7c/LB(Xoi$DUT7`7;DDLD-+Jf6o+uIi_5``-fDc/2Ij.7c/c6ItRlzD59/`7;qf$Kl7u`zVG/
::76tWC71.QN#[6s``IIDD^^z_?gyr`KM;xN,Ks\*`oQ|`/td;Nr(p-`Fub/o<#)9`Y5pQC$oqM`lMFX/2wKG6H>B`nA`P76oJ7Y9B=5EI5C``G9-~}Lu6gkukyz\<#_T-Z8
::;C~FPN4X>e!r7;IP6gE!Wbtb-fhrr`0?9I-```o#!GP`B3/Y0Dh7K_iFSy#5J.z7``VfyH~Fl```ICV`(99o^.f6gkyG7`<P^irDhn2nji/`TgPPZ/6oy7Ip?6JP(}j_g.
::K6L+RCr./22```L)B5bj.`)K4z``lyOX\<]i5Yq`|Uv\n```6~4`c/f`h0_9oggN}`F4ii6;j@-`z5Y_|<bD^Rc/!5~Fl```ICt7=k5`C$1X``&Vsi(XP.76q`|Uv\</;_
::I#0`!Squ~$,gXiM?n`)Kc```U9t7F4B5)K~$}X=TW)^-Fs7Y5M1`cT^k<DDo``,#Q3,KV}``zVh`}L6ju`{d}`7;|5--Z6/6=G`KC$S/tbp|O`/t=.``u)``/da3<D$|/`
::x;LRXb]Vi`Q<`YqX;i#cZ7@7osc```G/Q`{P``5I%i76tGZiji!dzDw`SaEys7Q_b3M`e_V/\<IG``DI7`<>.`76Kq65m(2`.tdkg`o?;}EVL,76g)``L@w7d$fOm`jfRY
::It/`zDXWw-tbhD8.&6]aByn`5YNzD6].h6ft*}xhd/4.PXuS0loi+.9F15J.4-7`~DJ6_yp@@,9YYDU-U/pUo/sUDp^*=`j7NX[PeC?tbmWf-ju`BC?%_xF9;l!bo9zp>;
::LjDpW7l0bz%0)F|?S`Y6PiQD&>f6YDF-5*n`KE,9`FsfwVb-)bisgT9YYDO-p]K```````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````8```#hC`Xi``````````````````````````Rf_yph#`OA^53Qg7````.`D`````zDR`xh````.7!n``````f)``)`````````````m/}`.7``5Y
::5`i`````Xic`Fu````g`-5````5Y}/``/`````````````D57`T```Tg76.`````^-n`An````$`E`````<P~75Y7`````````````Zz``)```)K<P5`````;o}`{}````
::d`v`````Xip`<P``````````````zX``C```C$xh7`````E)5`f5````C`o`````Ful`xh``````````````=i``/```/d3Q``````vC7`.7``5Y}Yf`````44c`Fu````
::``````````j.5Y7```</Wv``````u~``~```Xi56G`````,#c`Fu````````````76Yi``/```/d3Q``````vC7`.7``76/`m`````,#l`xh````````````5Y9)``/```
::/d3Q``````vC7`.7``5Y}Yf`````Mjc`Fu````````````76S)``/```/d3Q``````vC7`.7``76/`m`````Xi@`xh````````````5YE)``/```)K````````N)/`~```
::5YJ55Y7```````````````````````````````````````````````````````````````````An)`An````i```s7````i55Y7```f5``<P````&P``~```,#````,```
::``C`{}````d```97``76G55Y7```^5``@a````mP``~```5Y````n```#s.`{}````7```g```76`7767```1```&M````n1``T```J.``5Y/```3Q.`{}````7```g```
::5Y<`xh````n```a}````_d``C```y7``<P7```-|5`f5``5Y````K```Xi6`xh````n```a}````Kn``C```y7``<P7```,#5`f5``5Y````K```5YX`Fu````C```%5``
::``W/``/```.7``pU````6w7`.7``5Y````$```zDX`Fu````n```%5````d}``/```y7``pU````Ol7`.7``5Y````$```XiX`Fu````f```%5````a/``/```x7``pU``
::``ml7`.7``767```K```Xiz`xh````K```a}````nn``C```a}``<P7```Jx5`f5``76/```g```zD57767```y7``76````~4``~```Tg````f```j\i`An````G```r7
::``5YC55Y7```r7``^-````s8``~```^-````G`````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::````````````````````````````````````````````````````````````````````````````````````````````````````````````CF``````r3`.``````pzK`
::``````?F``````Mj7.``````&>K```````AF``````r35.``````QJK`````5Y*F``````3Q/.``````ZBK```````2F``````vp}.``````OPK`````5YkF``````5Y~5
::``````4A$`````5Y-A``````fe~5``````SS$`````5YZA``````gk~5``````P0$`````76o3``````3Qd.````````````````P0``````````zDHA````d`````````
::````````````````CF``````r3`.``````pzK```````?F``````Mj7.``````&>K```````AF``````r35.``````QJK`````5Y*F``````3Q/.``````ZBK```````2F
::``````vp}.``````OPK`````5YkF``````5Y~5``````4A$`````5Y-A``````fe~5``````SS$`````5YZA``````gk~5``````P0$`````76o3``````3Qd.````````
::``````76?`n).f/|$n?c^L4/9Aa/t=@+3xZ42#r!i0z)<G?`&Mm6!37,ZMBLRH@v!>P1H+<\|B4eoum`76&DqAzIV1O3^FH&beQE;;(>oZP!``^fwrw,LJ&#7~iS*/4G9=
::{5TTFu(IFI/}\n,=R576dCg~)ScATG/z?M-&Z#ou\S)7tiwrw,LJ&#/Ic0$mvt6F[dJcFpMSZA``o8=K/la;W=eTLM)^CQ+T{m~G$3pUyY!3j;]8v=k2sA``Y^=K/l+;J[
::ZWD4,O2UQ`L#=bQlr2L;wF^Wi87<*Sbls%v*F3],d`@7{TvbBLou1;2ZP1s=NLD4-`-1S$~Bj$]SYcxt9=dMUbPK3EElTgX6#3`n/M4egmaAgXyt/O,#n`HpqW+4X8NbXR
::Vm&KD=gWPMK^y!rA3$Qf``g7BCwF(;=c#FNbXRVm&KD=f4|Bx9WHdy*A/`;_l0P[)=;M=c44i-fSLA#nX=5Y<P33lM9Mg`3Q76F[iS=SZGgGK`$`.Q%S@](1o`,`.Q%SGz
::Qf``m`.Q%Svm9f``V`YSLAXm4G``f`WqkRrIDtCO``67FFg5)8o8J!HhT75Y/Y^L>S%S97````````````````````````````````````````````````````````````
::``````````````````````````5Y``J.``5Y>KL~M;{```f5``l```%5Hooxn$!Db55T^R.d6g55^cvBH~IKRzJiEnoTm$hX{dZE,Jnd2gK}alLK>~0K<<p{#3Ix9$sX!i
::P.q6)diJ/deJWDL/*KF~QtYU!z;$gTDc+-y+mdyJ;G7=MOr/+K5-|AfB!7@$co|9;j3`*/[K|-,<eD|zA$ro7`````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::````````````````````````````````````````````````````````````````````````````````````````````````````````
:niblld:
::Y#B)f5``5Y`````Ym`l07```````y7````````````````````````````````````````$```hjhQ/`??~A]0-PG3KK=mrAh6L[P!)n9MyH!2\SNJU<?2jib{g6)!@iW%
::;d+=WT\cHVdXQ)````````Xp>%~]9^G[V@Z#4ef;-SJlA%E[-$/r[i9BT0od$[2E8=KDb~T^%o}S\Z;TdEbl~4h!mJ/vMJT1V@Z#7m_D)uf&!@-b#H[E-ty&.`````````
::````````)Kx`76w`5`p53^L`````````a}Y-bm>PUG5Y``5Yn```````ft````5```.7````76``5```}`767```````{}````````5Y/```5```````7`/d``Xi``y7``
::``4```}```````}```Tgd`)K7```x]``/d````````````````````````````````T`<P9```0s``[G``````````````````````````````````````````````````
::.7``!`````````````````````````````5Y439<]{``@aH.``5Y````u```1`````````````````}`76HT;lvJ>n``dJ````T```s7``Xi7```````````````J.``nA
::Kt[3)5``|5)```)K``<P````o7````````````````}`76o)=c4eh}``\/````T```u```76````````````````y75Yu`````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::````````````````````Pd7TAz^cZ73/,heCHnMrAT7>WUwO,<<P(([ed(lCZ7OW1)Ix3QLoRCy[B]V|JC]7wr7!`@`V7Z7!`@<syQ<s*T7>%R~P^Jx#wbK+0]-UR])=;o
::5C1i<olCHm5~Nni`I0q~u)Ix>B4QuXc7/>+)ro0dm$D`O[#dcT-~lCZ7jc7P2kV~K+Ak!uK%(#V2y|7bC~rT.>^Re;y6{)zo3.]WK@et|#;hxwq3Ci*T%UAHNn?eOnm$&.
::c{C(4~Q.|X/*~w`T)5qiqz+)u=ld_uwXRC}S4~Q.V2m+k&w-uXV7syt+u`_r7!`@`V7Z7!`@`Vx%1v2)c/#d11KH^c*zq~`)s+#JCi*TEu5~T}H-|O\\v&TF,A*zq~u)s+
::V~K+x3co({Lq|xHX=q+Nqjo+q*!)Mt,sV~?XA]N.&td.(gc/P(0i;zW.*zzw@0<HKn)(.uLXTgY~S-E|l2w.#x,O.B+kwrG\R#````*y@K}6I`\teW]s+h~/T`NK[hP9]B
::4k7;}6I`sO,G2l5YaN8a+hUGT`NK[hR!xxWTQk21Z|l0cEW\U_edr67`!zR^y5_M5`<P_q.c&VWvQ}Q_.F`6su.7\<+Y=,knL.~-t`?,]PpkFQy7)`gn/iB`{1;G;_Z<7Y
::i6f5J.Yt%BX4QmH7H;)>#K2BQdI```KNP_gm=emc?w)bn2;BRjn(4_%m%Y7`!zR^[I(~H.hE-bD7(U-`]ONws_a7(h5Y&ifqqaP{YvZyLWEBc\_qs_U/<P``@X*\Uh}jMq
::cDbCPh@_sv4`/`)Ax<>{y1NPhjFQ|5)`ljXJbeQm=`NE=T>dK])>_.mCyJ//b3t6R!ayVVzN`u}d//e-T`h6|YAz,b_5_&h%(#.BS6.d\5knzDY-</mG5DXjnDnEbB#-W.
::gm)ekdLQF5_DNP9j~`%RGxrrYs4z`cNa,$ob@a+)yHI5z.\e6]*%$vIlZiqi9tD%Wmihp.j6WNwaC7\<tC;R(#E;?J^5=9WU}},,vzEN))4/I-|Y-z,b_5;>Sm[+#Bc\kB
::~s*To(b#)+DDxo4`\5yG>M|@b>K_ha@7>*|s*HvbCR>Xxx,+BT]0uC)zGGO!){y}+9.Oz/f%=u6S[4Y~S-E|n@UZJ,K1?B4kU}ZD4`qt\?nn7fssTHI%G=Dt}AS_cja_/Y
::,zZx]5`_K)dh)s#d01hPK__N<PCX!RDz6N$C-Q;N(~cu&UE_NDpU!PE#{VGg0W*HvbfZ\!u{2PY5Pc3l5fDR<mC~oVmh<d-@y9PFJc8.T~~OKJtwE.c6{}s**]Bk#\r>.S
::zx63/6C`A1^#O3rs7YD\+a6T@J2!7YKo_^7YzPK@n}__7Y+]CYC`>m0GYo`Y7YI-Y.aNF```yh;n-H<,7YDixA`Y7YYd1*XKI`iO5wyj7Yrv1Htu7y5Ym\UEg?B_7Y0nV`
::``\3aAFj7Y{HpTj~7YxU9o,#``wTAJ5P7Y+h$V}eY_7Y\e`J[_Ge?J4#>F7YOudGR7`Y7YYd1*i`,`La<8%k7YiEbB1ywTHrG\[Od~wxSUs%WUm`ZyGk;FMX28mi{N>7``
::+{x2V%}?36S)GA$WU/.x``}Xjch#iw}t%W9*g?r_7Y(aU3{j7Y#5?}L8SV[/q~2TX17Y6Ddl>miGq3`Y7Y*\6K4s}MiRwTnKbP,6|sZQ$,>n/Ysmb9ZK#B+RW.#&._j%IB
::vj,il7)/i7ww=V,/l7GU<B8{C~ZxRJJU7Y+hGw)rI-/H`Y`6++ZU)j%#M=QkU9N9J_7YfOsi&\\xn_ah|~!Us+9T<s#5X)=..w$t+k7S;g0**\}O<?1&Xg@nZ<l*(\Uhh=
::>`L#HDAs~vkzG`KLSQK$ks0s7Y{HB!F<)`BD^m7YFQ=z>+V5J.Wt$V;0W_`6]]F_7Y(A]8nk7Y*TbuiGqH__7YI-DcSW-|A]J!`g8_7YRQA_7YkyA\}<%}Xij&5w_a7Y9v
::IlZi$Xi7e$\1]BsU1HJqQ&E8c\?YX=IjSQ?w?z#<qf|d{i$%zExnl7M0<d1nNH_&7Y`6++gn>]Iqhht]l{}EwTng.dym-`<Pu~S#/mQGIb%a_y|C##=s7Y]E_gwT]<WNW.
::Phg]T`9c-RQ]qy#pl,zDkddDrw!I>qB@````,Z}id~ri``zDrnhZaRram=E](m(9318hw_%m%Y7`!zR^<K(~H.Eb8gH`n`;_Z<7Y+-f5J.%7Tf6^owq_/szPn$~`kg&P}F
::#;(~h.q_3im?Q_.F`6X%.7\<+Y&vkn!G[1F~`#cnoqZaP{`Yj`]nzDp^vjy;||_q[_U/&P``eQVGay#pl,zDkddDrwmtu?g@@?&tQ_`oATW_c5}bW_zP!D0\_tqcJ/&3Vx
::7YM}C%ddRMy/<~o+_RdB@d7y2VCmtyyo<dY&P*U_7Y&}*HTXiL-_N6*nzDp-N}1I80kddDrw,tZyP_Xui9n```IBRjmLJRa3m=@_-Wf9,N\?/ikCop$Fx0>`n`</sIC/nX
::>/h}F`]OedP<7`nz(l,G``76@GXQ.\{)OXNP.d~`kg&Pm&sRp3$w1mk0L})K76aN8a+hUGT`NK[h5A]B4kr8WNq3sLzD``Ph&ksvr7C`id]rhX~yfCOg%v[_/szP6m~`kg
::&PEAQL-_Z<[_/szPn$~`kg&P}F$v(~o.q_<cm?Q_.F`6X%.7\<+Y&vkn!G[1F~}#`iXqZaP{j_j`wnzDp^2kZIaN~j+hwnT`Y-7Dz|{O2_#+`6>D.7\<YmD=#p^TzDkd\f
::b$\1r}``<P&}kc_SfCCb\76TY,iH{HW_a7|h5Y&ifq\0cEW\U_ed;67`!zR^YPi(A&<66!#^Pky;||_qs_U/&P``eQVGay#p{QD)lnqGO]``f`Vf#YP5767`~)N}2\>B/m
::jXNPR}/T_jkW7YNw-mx/6KFQ*+7>F(bk7YJIN}dbD)17N.765`cr4Ph7<P``TCD5qq]jhfpd3z!A;a7Y_qvjhfpd3z!A+O7Y}h^TzDkd\fEbvy@czvLm&_X3kuqRYvE/2_
::+P?}XiVK@_Du`C``db[)1vFQ#9)`gnocKvnpjT5>3y#p{QD)x54?*$\1JK{HvhGwIk0PJ6)UiRJ!V9(jRd``d\%mc./`cGH54E6?kbZ7lC``5YZfAi$p67``5^FmdqEq0P
::w6\$AiK<Q7``u~vF}`5Y_}Iy<PlVf$``|5{/{`6o\iw```ddcK76.J6K7`zD(~c.Nbsv</C`&]qy#p{QD)17M-N```b8U=3d]U;hfW7Y^tPujRNb`Y7Y.M+^7YKoJ|7YxU
::IId_7YaH#)U_7YY9[_7Y,C(H#)U_7Y[Usxw>s_7Y=t$V&ha_7Y%{]Rvwyoo7TCo`<PQSct^]T`DB4k#dix7Y|<c\uQ|x$```gm]?7Yg.q_<ceUU@37``rHeJj_7YmWP{4k
::V]Gxtt.sheQmD5H;)>B6U^c`5Y@tZyGkdScPHi$=_%YmZgk?hoPiWk7YTxcO855Y5`v@%xaU,5J.gmj*7YR0?$._C]Gxdtt!UEX=5S2X(_7Yf(#9)`+@fCdQq|]X3j7Y<~
::}lJ|Cb%j#xTB#-N}wyPijk7Y9$*2a_7YZm&_afF5w_2d]ewT><sO`/pz6(`YzP$o!@,,]k7YTxpa,CU3Ya7Y=G#pJ_7Y6BSH`Y6DN|k_7YLW&#7Y+hRW@a%jssas7YaH!6
::9J[gwjaA}(7Y{Hh+|Oe#507YOuC~@zV<9)+YP5767`H)c$@g5YeR*@x7|5n_u.<~@oYCi5@HKEiK#-N}JEfA~G_F7Yg.mi2Rk_`6(~r83yeVF-N_7YJ|RgX=MleZ\_7Y<y
::fCpgKWTyxV./17#<aRLj__`6._C]wTiioc#dv#]X_j7Y%m?0,,jk7YSb#d|9,Nb<aR#nY_`64g1r7Y+h|C@nZ<}+c;H#Z3?v``Q_Ht1Nq/S37YqX*qH|qRd`5YW\U_Nwtj
::JV9t7`zDq/^[7YqXNP2.XgriUoA%=u6S1tN}dbD)17I7``7`}F1g$`C$5Yd.>|7`f5Tgd+,6K,D5!A5_1_7YxvPsj_7Ysmb9m(N}``Czz3<h2dHzb&&}07F~<R<in`(t)o
::q/XW7YqX]B+@`Y6DH_Z<!AN_7Y{H*R-ROlUZDR}``!nEbB#-H}#BBLI`rE_]~Zs_U/=+``nbsv))C`>mC~gy]atG$59}wTEJs+C`ZD^#k_6g?}XiloE~+Y[Dyo5`3Q{)%E
::]R&PBD3Z,`c6WN^3C7\<tC\g&PSi_G7`WvfCD\9c[h1gl^C`ZDNP\s~`%RGxV$Aa-/.1``Pd}xgx?#,5J.A7?HHiI5gGzDIqH|&)JXR6[D%^7`3Q{)%E]R&P/X)9,`c6j_
::B5=2lX$D.ci7``RB4kuz<iIRI5*GzDIqH|&)JXR6[Dk~7`3Q{)%E]R&P/X_v,`c6j_B5=2lX$D>0}7``RB4kuz<iIR?<(GzDIqH|&)JXR6[D]07`3Q{)%E]R&P/X@,$`c6
::j_B5=2lX$DCBk```ct1NnXx.,c,7B}Xi$WoqtC\g&PSi`E``WvfCD\9c[h~gieC`ZD_N1z(l&idi?jA```ZmcPHiF5LndX;5J.nk,Wu~yKUU4.J?``]mC~gygnauo#RI/`
::KgNDuXjc[.H.22V`5Y!dZhp.A7I}}Ru7|5._C]GxV$Aa[5m)``Pd}x#VK}%n^@db7`$KXgri_na5p5S{n`76!dZhp.A7I}.Om7|5._C]GxV$Aa[5yf``Pd}x#VK}%n^@pB
::7`$KXgri_na5p5sjC`76!dZhp.A7I}?6$7|5._C]GxV$Aa[5{G``Pd}x#VK}%n^@jb7`$KXgri_na5p5_iC`76!dZhp.A7I}?6u7|5._C]GxV$Aa[5Zd``Pd}x#VK}%n^@
::EE7`$KXgri_na5p5sj}`76!dZhp.A7I}-gu7|5._C]GxV$00iDPhe6T`DB4k>*d```wszan+tkEoX5yGKNs&5`<Pq~#Q3<PYdzHmK`RYj_B5=2lX$D;#K```ct1NnXx.,c
::,78}Xi$WoqtC\g&PSi3c``WvfCD\9c[h~g+2C`ZD_N1z(l&idiq5i```ZmcPHiF5LndXv5J.nk,Wu~yKUU5AE}ShPkYNO5d7|5#}mmCjOv]`4Hr6N{,5``eR@jt5}XL+L}
::mM76-|Cb@oX<+YZ<^VE]<e6```ct1NnXx.,c,7p}Xi$WoqtC\g&PEAPR@jt5}XL+L}UM76-|Cb@oX<+YWw%xpa&}nzi<$Gsy5Y-|Cb@oX<+Y=,e&b]3ak_NiK}XiMMEEVU
::DP]VzoEJ``WvC%Q2`Y7Ysv0iC`mb@iar}#qtqQgpU<6k]P07H`%R@jf9t```FF`Omz}3=#I-YQ6>sv0iC`mbNiar}#(=PdpQ*Ys\#aU/W+``bVVl4q3j&|{6@5O&Ka*f;B
::4k]1gR*aIj~6Nft2.qa.``F~Qh^WLz%MO_P.$5J.Hz0gv7``xh[/ZVK@=GlB2k;VxP28nghj``3Qqqv_]gcdFQUD)`KK#D7&CgjTA/ze^```;bgxp,S~{Hz?fC!5^h^5<w
::__7Yj+l+[5[a7Yg.AU,w0ja7]R5Y==rc1wjkG2AiF*7`xh@jU2T-ni?jP_7Y!.$/Si5Z7Y6D&]$9[.~```Phe6T`gg*6bl)DgyLP1Z$G$76E=P/Khy0osv``WvfCD\uB&V
::K}%nW~ToeM,`c6WN^3C7\<tC\g&P(C[==ePhe6T`DB?j$Zd```wsFUdXtkO@#xkvC%P95`<Pq~#Q3<PYdzzn?`RYWN^3C7\<tC\g&P6kPO`Y_DgnzDfC&6kf``76@mR|M*
::K0dXq/o#@72NPR@jt5}XL+L}|V76-|%mh./`$5=2lX*\`lwkFQUD)`KK_D7&CgjTA/o#+7ah0m``Wv-Oq~#Q3<PYdz_XK`RYWN^3C7\<tC\g&P!XtZ[ePhe6T`DB?j$Zm`
::``wsFUdX~sO@#x]nFN>fPr3_7Y(asqf1fCD\9c[h~gU#C`ZDNP\s~`%RGxV$00\DeW8Qsv0iC`>m\9.3/```Re8MI#3kMGwci510vW6uC~gygnauo#=K/`KgPh(%T`9c-R
::Gde4cduzO\%m8./`Z|4-k2~3iEoA7=+Rp35/NxJi5Cj~<RhrrC0B@l;)TgY~/i!{Z^ow&V>m(9T?P\aRIbf.,k7Yo5[HVJJRp3=39xpa;B?jgm\9hG}x9$o7P_7YXEcDsl
::ze{)Z5enXM76-RnO=3%zaMjUdsQ|t6C/PhQ)T`Y-{)OQ}/2nm7{)+gV7\<~OU=C`4kj`*nzDQy<pZm{%V|wn9`f5#}>df0888_7YXgcJ$WP{]JkHY_Di(0q~$U{)xX]B_Q
::(4*;$E6_U/Y+``%xD3toh.vpTNSnMTrxb#juDSd`XiY~*RIKpfH2*?k\``TbW\ZhV7(6+RjUe0i`pf~I*?j\``d$=gN5J.m7WNo=+h;NT`9c-R(]qy#p{QD)x58!*bL/;B
::8k<=gRp32V?kr}%nEvLmt_{8[7|5nXIq2_6g?}XiloX<+Y=,wx#u./yzw^@KQ_u?.`Xjzfrs?g]Vd`RV5nMK76d\%m_./`^BnvUUaVRB(sGSuD?,Y_7YlDIIbDFQ4_%m#.
::/`$5=24u6S*%$vIlSioC}`<PyQ9tEkin(f4```q|]Xmj7YoVS<aR@jbVNb._k63u76&i|qLVCD!5$-e_+PI}XiZ^*bzR%BljY_6DH_]`K}XiloX<~OzP_\~`ji<nGH==iB
::KU.+ds]gHdf(hN7YzP7D@p.N/NF4Bjq~|-WZ?YY&@lWcTgY~y.!{07``qR@j<11N|5``db#dcP7Y|<aRra/^C`PrI7\<._k63u76&i|q}VCD=u((s~;F=_7YBG7~`TZ5hA
::ht,,Zk7Yn97(bt?Gp27Ynm^v/Xrk2!3~TX})RCGTkn8,Lr5`s1^yujFt?]K=Ai``,G}xmFpaHD``zD]BljY_6DhGHz9$r`0dq_Yuf5J.%7U1c5p<16Y1%BljY_6Dp|#sP{
::Ek_YgnzDp-N}MnN}O>IH76smb9m(]i``rHeJ=_7YIw%h07``_rt1?q2_YhD}Xi9t`k`Y+h61nka7@R5Y<is7pz0[K`h60,;`6#]XIa7Yrvnka7wR5Y<i9{9t1N4gh)4`11
::]Bm(k_6Dh#}```[_PD{}Xia52<^T5`76}MZhVt^`MX|_%X[5{`BDNH7YzPJ,i#&M=7h65`=egT.`Dvh]\XS6*IofzDrHuK76v$1g5Y@{^k7Ygx|a{rg{76LL=f?<n$zDj]
::?_7Y#RSjypk5n+</J..oF_7Y{H\$zD1nMK76PO5JV=1NPgi=7YDik{6GKo&DmFQ/J.DV`6~j+h8`)`ljz}^e?9R$r`PhNmT`RYWN)b.7\<lItqed<<7`;tSG.\v=hp>77`
::xhq_3i]PW+(`%Rra1&O1h_6YX}Xi$WU/C+``_nHQsq2_!X!u8```%BljY_7Y6gPh0zT`6#]Xmj7Ysvnka7RR5YeR6pC7\<#dcP7YKo0a$`c6j_&5=2@X*\$JjzKa7Y=#ee
::/`KgYN#E<d]rg5(Ak%//``9J1P4LDR5`x&rwWmu-2zk^;fO3K7|5n_j`JnzDmm3zcQPnFv__7Y<W>*f`n`4vG+t6</J.Tg`#.}2?.`+```pUedRz7`&_-Jv$]E5YaNLiqz
::F5v`h6LD``pU5]%`fRq_za,5J.Zm`pu~u>Hr?YKhC+8Pe/J.<P{/m`itUPq~+aP{pku.4_-J}L-_Z<[_DKB/J.gqdcC`FtKkTku`m\IkpD$bt_,-mzB6%dXizDOg<WmPf`
::n`=^F_zai5J.&$EN9`Xbq/O3U7\<W\)Oed`~7`;t}m00Vc=T=E$|p/J.WW*k7Y.IfmzD!asc.h]+-_Z<[_+-B/J.Jqdc5`FtKkX]2?.`}`3tvfMQ&\SX6|I3edRz7`C{\U
::-dXi%4*h];7`;E1[]Pb.H`jiSt%7O[V#J.``TgKWU/.x``}XM`loX<?Y>N)EsvNNf`&]yEt+}`6yu(5(f99`u`Hyvw1gf?1(>5]T5(96{v76?*S_YP<nzDp^gks`kgZn>`
::VdO;76v$wE5Yv$%E5Yv$]E5Yuk6EPh8`9`LaMrt/)K6TD1NPR}*E+6-__D2$zD[.yw=pw`O;76VfcAgDfmzDf-d{LP-dXidoU_zai5J.&$EN9`XbCXbyrh.`(lYqyu;)Tg
::Y~N4+RW.B@L8H}~-7`c\5B]aa`4`@{%}459v765Y%)5(k]9`u`*?4_`OX}Xil;;_%`NKV<O|mPf`^|WhrP8vaNxnIWU/vK7`-Q;/l`jbbB#-H}5(f99`u`m2Y~?zm\*H$B
::gu4)C~MH26-Rra\@L~2dGgz15(P`!AlG/i/`Izu$wE5YV-`/v@NT<FB59v76IfN_YP<nzDp^gks`kgvubkV/r3xcSD|k^?J3r[7Y7YGpgx*#q0W_#+N8?F7Y7YI>]P|A~`
::%RrPZ<d\_qEaP{Ekk6*;76<i_nUFCQ;.~yu(8~}RsUU7|5eI-yvwF4XJJn\3!6j%giwTQhVCRC}xL8H}<.7`c\5Bl}TgQI5qF7\<xnE!8_`OX}Xil;;_%`NK?}y;#_7YFQ
::4_+^%j__yO`__a7Y>}2\iRq_<c]Pk5FQ_.9`gnoc[ej&yF=O(oi`wrp,,w9tx.3YmXH;c`db2+c/c`}`5Y+YAMH6o.o5=+FtKkK=/R6TBhRc<~,FzP)/h0F_`Bi5J.nka7
::fR5Y-Rp3s5p5\95`76ajH`r8Q)f~3~2T@37Y+h[hJ(ab)tdt`[QSw0MbsvQGC`XlcE&PY8xO,/M#@_*f[..wPt|Cm%R1sZ#d(flyuKqP-_]`X}Xiv5^VKVG/,Kmka7}R5Y
::-|%m55/`cGHzDbW\Sh-7mka75R5YeR!3o%[6*f[.yw`h/i#5#I%x}de4A-E=&8OlgkZQ;.~yu(tZG\i(&n0m},C~Ge]*5`jc+hfW7>f.O_7YF..w$tfC#5l}.+LXAa_-``
::zDJOMn6HNP|@QQ$,O4Y~y.!{07``d\i(cLZ{g|7}-77`TgjzKa7Yjgv5[_Yui5J.gm1N7YFQDu.__YZnzDx.k`tO^5J.nka7zR5Y<i!ia5~{#ku.B_+PX}Xia5H8ub2Ued
::Vz7`q~4Tz\7Y+hUUw/xxMHLW4Bkn)K6T<.y*`HU6N}7Q.\CDUqe~d`LE?whEpj|O`dopTxyOD*`k7YpifqQ#/mJJw$``]mm.f<R^t+#J=3aA=```qRzomWU/D+``|x^g|b
::wT|zc\2|80hEn_u.gvFQ9c)`D$00.nPh4MT`Y-{)OQdFNw[_a7mR5Y&ifqhQEBsv>dC`>mx/(3_/``Q_}l`6+MC7\<B=^?WcXhm&;#f7``-|`YP{3_j`HnzD%B4knkhfj_
::_DNnzD]PP3*Ecu)`ljyW_qr_#qW\U_edi<7`x2FtKkK=BccE9=;Bek[B+RaCr5!VB)f}<~H)JR%#$trW?\|9vw3_a7MR5Y{)!57YP{x2V%2RgmFWCH1!7```r8WN6nC7\<
::+YAMd*pgc-e_H)bL&7Phr@T`DBd(JF$-)w?ja7cR5YQ8v_N6HnzDSqed/<7`q~H+_R34$wq_hi)5J.%71f@@m01EsvnnC`>m6juh;I80kd\frw./``Z$\153{HGP1Z;__D
::-nzDfC@z`YhfFlfe^E#d*87Y6Dxi6k7Yqd7`5YG\%mj//`?\9|]Xmj7Y(@nF7`$KFQ(X)`zp1vR6]4wxfAa_7Ypj\KN59tRq`YDi1vFQ]m)`D$00Cr?WU/~+``%x&Nqy#p
::{QD)x58!)E!o53sv1k(+d`n(4_%m<//`2dSh1k4.[d``eIr}?976aN7=C7\<>bMYC`)`L@qDZ7````4vTIfC`YYP>nzDfCC<Q^HU-_Z<wVcs``*$n_k6`c76&ifqkzT%;`
::h6w0;`+aU/f+``nbsvJ.C`id]rj9Fo&;Z^ld?$n__YLnzDfCf<Cbl~*_;WU/K+``|x<#;q2_PDo}XiKWU/~+``.+\#}6(7pj=#+5V=lNL`|55YI`#BWNzrC7|5n__Y>nzD
::xympAsMs[_=6*nzD``````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````<P!X``/<n`V%Y5``B.7`gkh```k.``ef5`|eP`76rX``gAn`Fuk5``F}7`ZBh`5Y(.``iG5`p$P```````Tn5`BS4`<PBD``UCn`,#=5``.77`a@1`76
::yi``6.}`/d075Y!6``qIu`J.P.``Q/5`oy8`<P5X``rcn`\<F5``l57`iO1`76Li``Wf}`y7w75Y%z``\<u`pU|.``zC5`Wve`zD1X``j?n`C$a5``Q/7`3;h`<Pei``Om
::}`a+%7``````g`}`NEy75YM6``J.u`3Q^.``N`7`_.1`76Ti``nk/```4`<PND``9_d`\<#5``x_``]Ot`<PVi``Kk/`````xhP]T[\k1Uv}{6}Qs_SE0;`R%k)gH)g4[t
::xQk)dfM0wD2C(kO*>VFmp]VB{;e6;-Ln2LV#Q6CY0h<~pqdc\diSt?lgU=tW;;l_D+hT?gLiZ-Cr/r\Z},uRfGva\[]Kd@.t\]JkH~Y*QH1$efh=jZPs~vqiljweeZ$c<W
::O123W+9W@.B80ckQ#9c1|$nTM>/A{OBQ/Sl1%{0oLY@1r*VE{)!oAe<)8^eHewF$2EJQ(cR8FDw%!0N<5yRH70DN>b)H~zY?9!%VX]6zf3m8I}J<b+]-G~PlI>4Z5{H8tE
::ospxH,hO)39XXKC11Yj|_mX#d+MFGf$~_Wg$D=EN5lhP2=?[LE8Z+=B@zFzHzB!+HoP.1H<~EfX41c9m>n^nH/&f/._*eKN;Zh0KYWIzp1CR`(,Uz3q](3b/s&EHv`Z8(W
::}^cE;&9W.F,/Y4i0Ee`wU2fvmof[h^]6hTP=CUc]2bAMITD~H9TjT.jf4quyrm]+$,d,35>UQ=)tCS>#LJE\k$.O_~z*K7>6CKK(Icb$w0BnG^siE{l(@H^KBOW>y&TwFD
::``&MN}``n```/&As4^v=_mHqQpCi=nKO````=K9KxVfS^~ghrH{VJs;U6U4A+4RrDi\x+X`)n%lr+&GIerK%69R@^FAzRD[,+4Z|V$^,QE;4VZ{4QTmThjj,|imc`X_Klc
::lE)4hlFG%g4UB1@]w+BvyS[,gibef`r%(E0]7lXY*=|n$Z*f4;i#A7^k1US7tX|y%~}TP*2x?W$2b=QaUVV*1t|,bs6\1KOjfX}o)P|wS%CxH)vx4])Qff+~0UHav2wI|L
::4fRV\}!NWV`H9isTH}?.`f$t*DBq.6#_kvH_1Z=t&VD^M]V*8c6U~/H*i8)^{B,h<uo5]LmB*E&PL8V&(o%|;c5E.c+uXI!bS%i<FB!l7CDYm^=)q>L_.q__vRHLsqB{{U
::u|YshIiG/6`,TOG<3|$2k^=L#%$nt-}<DA]>^@a$,Y#4d)-BL^Sbumt({5.^>PceJY=#8+C2vU4=g#9f.%dHK5=-mvadfTr;K#o1V\J}FW8u)>klHIQTCE$%p^83a&C;on
::0A.B+u@Vt1fLb<RR\&g&oeDn{Lp.ld|\uRA_~iZ]m*]kY1UR.rYl4TgH/y>McU{A)\!/.s|t$NhG7kK~$SFUJ=KRFdc9i2(y[)cVY3}c\u2TF\a%w1y]n+Ak}%*q`-.8w+
::~sD1<$XV4W?qm,f>/_om1C2i&DN7/r&0n^|cWxw]k>o.eCdpP0zbZWDPt9mT=PkrPPi%)+P>2t9^WovEg@58uRTpo(rBjPyS2N*lQV]n_QrArs-ogs6VENiQu,Ghh(PqgD
::iq0}jeWirm0s%~xM\N(M6}q^;ZOMV)z%-,c2(#UZ.~[#.(i155zHr$VIj1\~3jx4?=5CKf9])2nE;LWr?#VgQ[43]?.IpcXf[&<n)}n6lN@AjvgLZIidNW52+4qL&RTcws
::VV^s0ay.uu&.q9Bg;IV+FTrx-0ce{gBEVZlt;b>el#HGv(}KtlO/#C_}H-#5jX*##EQ)8AQ/(&Nuy0o=Npa`v>ml3Q3GNps}aGKvk}]a6~j}+uRi)I*L||4f{\csmV(H^x
::\G1;T7QApDd_.sDTN6[UK(qwaJ}T/|ruob@hY.f\;\`Lct(#@&Y^m=C=tk~mopZiE[VnW;}%XWpUeG7m$f|<S^&sJQy>R*{07c9>.z&Q]#X7olREiv7|E=+R(|_X[#czs8
::ztm*W5JBsZEjK.wA7J2d)D&cz#&csp-C$=mW,yA}@cO,U$RHG```/2kEhN]2f}````zDiMJ7````[7``zDc0fxu,b$7```766&SZ````A!````)EP)__k0i`````u~<7.`
::``l0C```]<87cPQIJ7````J.%hq```5Y>```V%^C<jlZXD````)K9_&d````.G``5Y8%2-QC3D}`````aEN4````8[c```*{``I)Pr``````f~n5/```h[=```WZ``Dp!R
::5`````CC@x)```xhR/``````2?,5``````TT<d>```76>```kTMm44VFf`````76;25}````!a``````pUROz5``````9miu````An````J-m}~;hD/`````Zp*u7```UZ
::7```f-90s_rzv`````j\#Cf```pU)```y8CzRN?e#}````pUxn37````T5``76J>`2T.7-5`````#791````{@````?csX\GV*c`````u~H//```&M/````F,V*hbEZ7``
::``)K&A>```<PV##&g86~]p3Crj_~i{kr0$=_xNhISC8cfJ&{[A_D*H%SjQK<y}yZ6TdmLtSB;(LrMUTj*XBZ_/>]~Vwm!HfO=N.D(CLX++-\v[\`{}oy)Kn6D`|`{}oy)K
::n6D`|`{}Ol)Kn6D`|`{}_y)Kn6D`|`{}ml)Kn6D`|`Ifbt)K/6^`77An<P``/`)`6`J7Fuwr/Y$YV`.7,G^-7`````j`g}BSXi-P?`K7ff``V%/6o`i79GJx)KnY)`~`$5
::Fu````760`D5scQJph$Y-`G7Ana+xhC`````WCP2xhd6L`u5xcvp``}6T`c7````V%/6o`i79GJx)KnY)`~`$5}{````760`D5scQJph$Y-`G7AnvpXiC`````WCP2xhd6
::L`u5xcvp``.Y)`L`````QJJ.nY?`G7xGE=``````````?d>*xh}`9`j`U5=KC$}Y,YS`K5ycvp2UmYJ`A5sc,#56,Y]`K5tM^-2UmYb`~5J.&M56f`z`]7L{vp<DuY-`S5
::@{Wvog)`J`~5%Vfe~P,`z`*7mMSz2U$Y-`4`$C[#<Pd6-`4`CC@a)Kd6H`L5@{QJ2U,`*`4`WCpUzDn6L`A5tMP27`76V`~5uu}Lxh$```b7H,eI2U,YR`@5L{3QTi)`^`
::K5<M447`76y`&7Z$*]TifYH`-5%Vj\Ti)`^`K5<M44TiG`*`-5xcvp~PuY~`R5````Wv~DM`(`u}=KC$}6?`f7%f{+<Pd6@`S5@{}L<D$`b`)5YV``3Q.6S`\74uXi2U)Y
::@`67````WvarQ[Px/G_4yHiS````R^5<SH5y8>Lrys(7````Tz+r33(O*cNB7`S$[HQ~DAHAGZ5|aT~V%*e3]S0]b1%Q````=KQGtKb[=LS4`G!(]SuJ>1b[<,zVD>,!h@
::j```5YYU.Mw{?^g(+T;m0=9`^-l[Bzd3EBo8.!uAum/`=KQGT#ys?Mq)o^huXRzITh(-qFbc^L7```QJtMzg#F*S&X!yFGv2BvUgSBx}````{Ti8n![!jR6Rpt^[0MGcNB
::7`8,Fpk<Cy6A+[@+3xUn``P7Z$zD7`C60`w77,eI~P.`R`Q7h,````<P{`F`</2?J./6V`(`55(Xxh}YG```S5ycSzph)`*`n5%V<P2Ui`^`u5&M````zDG`T7G.5IFun6
::6`|`ffy8``zD)`-`S5uu7656i`~`559c``zDuY^`S5rc3Q56mYo`G7nn}L/Yn6-`````c;76/`uYR`^5@{{}2UmYZ`P79cdb~PdY-`^5xc````<PK`97[GFFxhn6H`77xc
::pUog)`````?dpU5YHDc`;7Vfi<@ad6Z`P79cdb/Y.6*`A5|V4476)`Z`R5````````5YfOhLC```L@````X7``2bv`zDQn``````KN5%XG````g```````````````````
::````````````````;_7Y`6````qIm`|5``5Y````n```TgB5``}W``wrv`5Ya/``hq7```eIs}STrJA#j=Y)4VzebS;uUR~GTg^TNcgLIQMRHABdsH_XS,zD``?&``pU08
::;Of.``Tgx`76y%``nnBL?-|)rA/`````.7``!```o,KlvJ>nRy````XiH```n5``T)QBQ#o}``#s``p$``pU2ckzhu)`)K&5``X7``nnT>IHTRH#p*EpHwC```7s7`G9``
::<P_@(/P1roG7````Qs7`/d``<P_@(/P1roi7````3s7`Xi7`<P_@(/P1ro,7````._7`kg}`<P_@(/P1roc7````765`@a}`<P{lvJ>n``76%d``//``uu~Z,f````Yqd`
::``````````$5}`3QC7``mN``````````76)<``_.)`zD6.``````````pUY.``767```````````````````````76Z<``}}c`@a_.``hi5`MjP```si``w9}`*]N7``u<
::``93u`xhs.``xG5`mlP```=i``DV}`H;]7``````.hn`44\5``xY``8,u`TgB.``f55`[#4`5Yyi``6.}`/d075Y!6``qIu`J.P.``Q/5`oy8`<P5X``rcn`\<F5``l57`
::iO1`76Li``Wf}`y7w75Y%z``\<u`pU|.``zC5`Wve`zD1X``j?n`C$a5``Q/7`3;h`<Pei``Om}`a+%7``````g`}`NEy75YM6``J.u`3Q^.``N`7`_.1`76Ti``nk/```
::4`<PND``9_d`\<#5``x_``]Ot`<PVi``Kk/`````zDe7Tm)[/OE55Y%/~vD4QLf.``fd>?TR%)-Px5]w6B?^JE~0``hoyhl]Dt{=crD4z=.3>A```E[wHZPnyskVd`(j1i
::)cD>7`\&l[iSWA?E~G11Yu`9Wp,!sAvk)f``x/UvwFo3rM``J?u4[&JE~0```AyhZIi1XS,7NEl[iS)S6A/`xhx4X=NFc<f{^-`OkR8ZD*K`xhOPW(.Mb{WpWy$`P}syWA
::LIDtCO``G[?(0,]{3-pH,`V%3U*leZuU33h\/J`ZHE)S/lSK5~``]*sHeTJ^D>m-ElnI/1)*o\=B]`,#TY/|zv[bO&%H,0D2,f12qT~&^L7`QJTi4m<0]R}[axl0N60Lf.
::VAEG0=c38;icg`@adz#p^HQl<>K[?2yMJ^[&@?4%``y8Dv!>P1H+R5f8+#MSaA``-^c;RJ{;,3Bvn{Pe5.``j5lbaA|bC*t2aT,$PeJELAT7>*sHeTJ^D>m-El*/4G9=[d
::}`vp00#c<c/SWA@>L[]F``gTl^eTM)&LUH$`Sz.67yd}bnv2Uzi8kzSH5y8>LrysGd.Mv!~PxY0LOS9w3>arF3Uzi8kzy}5Y2/lbaA<>K[_64Ti8I!C.5Yk/lbaAuJLr33
::L5().ZE()Y(d&/9Aa/t=?l[;m9^```<YB@;m>n,@URzVh!f.7[x4.tO3ssi8i^g(fSK]br;2BTd`e`|$$tx!KV]8~=w}VAEG0=c3vTZMg`^-_6`\C.Ql%)Sd%F[dbcG98D
::JltEi11bH,[Bm>7`^5i9VQ|S<>K[?2yMn6@7woQlvJ(n?Ujxh&AB&Sbc?A>nc3BW%{``E)6J&#}/ny8G2GK2Uzi8kzy}h6zr51K2%5An~D!(jR>ZE[?l[;m9Y17`nn~D!(
::jR>ZE[?luLi8p#=/u~An/[u39<GcD>5Q$Y,n/m9A1E>n7z3xZ4LdI.5Ys7//nyIz>[axGM?{Tg!huAa/P1HgqWNBI!=(f`db!huAa/P1WJh\rMBL4/9Aa/\n``vuCv%FBv
::)c/GIQblo+}6O5P7=cPKn?Ql;)/`$D8Mqn[~or]8]eQETKw]Dt$3~576Ad)2hTIZSHwp3xC`443uG8u+g?JlXmd=t2OsyMBL?-uYm7wo4%6J2KU3MdI{dX2ITRV7XMi<,r
::pM?,#}c0<J);Rs``<Mi<,rpMh?%H~IA2L;AFo\C`sH3uG8u+i-*l~JL[@sMdI{L`,#$6&pv.WA_$9fS+H<,bUpHEmYc7wo4%6JOK,3!TGc.<56IY&pv.WAR>St[39<fB3g
::ogIY&pv.WA|$+ryskTd`QJ3uG8u+F(*l[>>rJpr\C`+L3uG8u+RQpSe>Qf33``.ci<,rpM}5gm?w!>0=DUaT=c##=/``G7wo4%6J<K$3#,*4)u4mcYb/Ob1@kbarys<dC4
::BL}/xv``EK=K#{_Ct2K4|B&d.a)YK/Ob1@6RK[t22;t9y7<pkDVI<HN18x.M``````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````|55`zDOl``4`````````````````````````76````-f``5Ye7``````Rf_yph#`OA#7.c4456$Y*`@5````````
::````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````^-~DT`
::M7!nCU,#C`````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::````````````*/fRl0.Y$Y*`@5````````````````````````````````````````````````````````````````````````````````````````````````````````
::````````````````````````````^-~DT`M7!nCU,#C```````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````*/fRl0.Y$Y*`@5``````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````^-~DT`M7!nCU,#C`````````````````````````````````````````````````````
::````````````````````````````````````````````````````````````````````````````````*/fRl0.Y$Y*`@5````````````````````````````````````
::````````````````````````````````````````````````````````````````````````````````````````````````5Yr5J.2\7`P,0`4`````j\7`D}b`86j,76
::``````?7|5M(``d${`1`````Yq``BJ;`OP$dzD``````b`eY0fzDT).`n`````+{76E=$`OM^/Xi````5Y;`UD%fzDWV.`n`````+{7693$`0i&/Xi````5Y;`RYD.Xixb
::5`}```````````````````````GA5YEK_&9hir[f5ciP7hE86)d>/`1NC0-A,wZnObA93*Mm^5FLK`DBok5n7X3O^/C|+\MJ]NtC<5J.tWHhDSzu_,+6=;3UD&wctA5Ywx
::#bk<QJh5Uw5&K{q.9lVr/`;y8Ab|JkOoOZ^<xI+pUV+xK`1```````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::5Y``a+``TgScrHRy[6*+prDpZDZu-`%,Bc&>{*D5J+qn@2A1+CT8n!e@^T-M!DC@HV_^Dwh+AJzGx=A=3O}Z=H4S$A=r#D&,JMCPhkxk*AUZWUv5}o7s%!40s<.Iak`pkM
::Cp$hZnT7m*L3WDLGv{$-wwIBm=B[g5w9E38TdT*Jp*$WuE=hsgy-D]z=&=09{op9wa=<Ewilk*\jQ##^KC5KMN{al~}85$XDKke[wV~;Vix_G_d`u`76I```76b5/]>Xzr
::G+J.LZe%2IKRF}U<[3y,lcgH8AgE[Rpn@ptX5)0caIRlo,7Dq.9<2c+L<B;Q`&jn+2-RT%W0/??@%{x|(-o5?V*gT/qh2>MZB#v-)z3og}k@1IW05!r^^VXb)tY#aR%GF\
::=+3mNBo!)Shl;VCOl5mM]&nbmI%JgZj=(\U!ap\HrSm0{6#Dc3hM.8o!>z[>8G([2(T%}GF}G0*]/F.R4,bMoP_k1j1;UZ[UYYCd78932M*+zGAqi&aGNOfCFr.G6!O0XH
::)y]l65`{dpmD?Gp+}*0FQ,~9zc-!IA@LYbz%~<V{82?R`f5lif/3%V?+Ltd.QA6*ja!E?@l{o#M-!-o7Xf.q{Kp><cm-hwGQp0_)GoU{s=LOgRK7<*daM]b}.s#?6%np=9
::McE5K93FY9~,N|+*/WB^@oN/y-V]x\2+I=%@P9)a,N2kN;(*Kjk+sDsiY?(]y3rIm~z@CD8WG4+3XVngQkbOOnqj--yNbs4JC?IooD<k*Uqd@7``Tg``BC``<PH}l@G9MF
::$co5{V\*OWbP,ziG/#KNojvO>}L@BD,5!DI5;VLg\5oKE+mGy#]<m9L`?5yVwJTiM$mzXGu|$ZC```````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::````````````````````````````````````````````````````````````
:niblld:
::Y#B)f5``5Y`````Ym`l07```````y7````````````````````````````````````````,```hjhQ/`??~A]0-PG3KK=mrAh6L[P!)n9MyH!2\SNJU<?2jib{g6)!@iW%
::;d+=WT\cHVdXQ)````````.+>Eqq)qo=#l/9lwdW)SAF(}`8/]d4jro-}?~eS2batx%uoULdXktR)r,a!~F[cB*2C%yx&!nt#l/9d;ZGBtqc<fi`````````+~``#ru/Xi
::I%G^7`````````cYZD6i%5$`a```h,``````Mj)7``Xi``````f5````Xi``76``Fu````````~`````````76``76``````76``O/``J.``````Xi````````5Y``````
::5Y````````````n```{}9`Tg5```UK7`C$````````````^-u`zDc`````````````%5``D```G.f`pU``````````````````````````````````````````````````
::Xi``E)``````````````````````````````/<QlrJ/`5YPg````}```[7``J.````````````````y7``985-DRn}/`y8?```Xi``<P7```z`````````````````7`Xi
::3-IHTR``5Y97````/```/```zC````````````````u```>TQll]Pn``k`````K```n```Tg````````````````y75Yu`````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::````````````````````^->o#JzRlY)TdXS$L0k4O#K=2zdX}+Ii_~,oHiy#56NTH)Rc;pMXC```1nX5ro.T^k#JdLt}``@aO~hP``lXV|V._~n)tCtG7TIgf!=no~`)}2
::Bp!`7`BHute}``vyx.@_GCAn``a5~{@(C```^-;jL8Ri)>x)p$7?`ZA%rxp__Yyn``a5H8]i)>x)p$7?N-7T%n>7``kg_}w$_AqDzHM>~p@C!keOBu``[.yw]rTMsdcToi
::0dOrT5FQ^|i`zDD)~oZzA+D|iR(#FQO\i`zDD)gou4RROmdH#hPtDfOU%V-R}Nrn_~ETC)6i{L+)@1s@m(/XHipD76=Ty6a@shn`k@,=PtH_-6G.``pUyV#UZo,$&n``pU
::edC%7`pzR^$dsdcT6mBV5~-DMZBc~C7TCL1>Z7}`BVwXrV``?b}X<ja7Gh``&ifq\6NT.>db5V8TC)Loxcj@.,N-?iIyRv\<sM__G(/55Y+Y=,_rw))>x)MX{R)q~aO~08
::``QJ^cZ7Ao2ITf3l7_O~z8``wx;))>2)?XHi?RkV`@R)yT)Xo,``5YlC`)p`BV^~QoWXQD!O|2`@4qe```-fJGR^#d~KC`|5n>``$5s3M+9Gi]Iqj9`@~X``76/=d6BHRo
::Z}``UK@`\<<DWNm>,bt66*gr2DSXHiyR]&DSOmMGBHn)vo>0h```Q_c=c}``V>%)Q)OumXvDd>67UDK`p_rf5DXj$-dXZ+xy`!$ZO#K=dz6xA)Rc*oKlc/#6}}7```FQBU
::i`wrYsSL;$u+w.8h)+Gn[#\635!5lCc`W+Ti_Nvzx<qfX>lorr8}7Z7!2taA.@#]NTn$^@4PJTVX#`\5*P-g9CNTGr1a\NDi@a@gv&UU.76R{2mZGA36DHWU1)D5)XCX>H
::Q<~pox7_pMmzY,qf^<zH)T,>RY6x{n7@(TIl)@(dFGssdL?iRYJ.8}2GEt<0S_cja_/YlVg3\m#M[3,$*D4`jv)s26K$b>K_ha@7>*fsnzTH@z*7?i1`UEM%(~cu&UE_ND
::xhf!&Mk~H,7?Dz+Crg2YvbLgB7b@G2i5_XO>CcMFO/,RG2mZGA}@&m)T}S`q(+DGfD>froa_7Yj@H1qD,c7ZzH)T,>RY)To>]O0oVl35sd!H6x@)]B6E>`5Y6/7YDiBHB6
::H}``y?````OmWn|G`Y6DsdNH+$7YDi_~PTI&7YJ-6xy)3aU3na7Yv>T%W5g}P9,w\TxO&#lU7Yb)F0U3|a7Yv>sM|J.MNNC`Xi)>2)/XD)^oDzdXnz0m#EY_6D~CHT07.,
::)-Q.%XHi$X]&DSOmMGBH@i-}``6h#_7YP||fE!``SU}```[#irz_Q_7Yj@L26h|_7YN&cyOmiGNlY_6DsdNHCT7YDimz^<[#8[mKuyOmWn!OY_6DsdNH;P`YDi_~\TaRNr
::f7``sdHT%nOm)-PM9GocqeJ?<_7Yw$H1qD=Kj3|Y=Krj#6Aiei2-LiEt}`_~th=AWdQNnyOmeNbORj^0j@Q.+N>7``+{x2V%z;&tGctG$c[_0oY7``0dDg5}PtZVsdLHR@
::`YDi_~PTaJ7YxUDD1nDg.iyy^CB-W4_JQT9fUk7Y7|8>z&DSVpW_7Y^]YXH+dLrGS5````sdHT%nOm)-PMPtWff6%V-Rr7qy`!+TD)u>5~%7.,Z}to<z,5~Cb5wiei2-Li
::DGbTWd?-NTv[Rj#A6ryaaqe|){L)qhbo18k[8-\3ss5k7YC?sAi9sd1*6xhJD<7YiK+RfZ&sCeN)3aU3&s7Y#5~.S8Hi_a2_9G-V,wP0?L/=eg5Vh,+RC}sI2~/=)YFNGa
::+45}aj%06_>1A+8_1*={VQeP4BBG````/IB5sdHT%nOm2HPMPtDff6]&39wis@Gxm/#\_r9LTuwiS$_Ay6bdK5V.&Jvy6e6k7Y(KEyRW5`^-sM|Jw{Y]]k7YR0````a@L2
::Bv^_7YN&2lGH=_7YPt3c+es_7YU9j@l|s}0`$7pTT[`Y7YmFv_5Xb#Pt3c,j(_`6OmWnT&k_6DsdEH[xY+n5``OmdHauPtDfN0%V-R2]z9tk7Y7VsdvH)TPiS$x@BDC)cc
::azdX?7Rcg.j`%O!p+tA{sde_Y5ggWito|fs9XjeB?0#7R*F~[eLw}+_u*]BVe~auPt$V];`Y`6g}entol1QDm|]VIat_L.+IkGqK=r!`U#UEPfO.``e|U$8P8rsG1`wb(I
::SYM*b_7Y!.xi````BHu)9}sd(kU/TE``QJ,AZ70oIlV/F->oyC2i2-pDNG`V7ZN&-R.,3/vo<zj+O-@pyig}D}1YOm<Gmz>XZPuWN&]jn7S7}```@V#Un7zG``<P2T*o.T
::J]TAH```Q_BrL/``%7Tf(-LpRC>i{>+)Z$7?c><oRCMdX5Q8)`5`[_{e275Y+Y>58J^cZ7vTFo>#K-N&eqsvYC.`/d]r{$PteCUh||w,%g2-!)1`Gyx+Qd``5Ysv?d.`/d
::]rg5O}``5YG}`@goIlc/p->r~{bkM){$``a@(I(P[K4>L<knp_eO,$``a@_A(PxOm>LplC&i2-pDNG`V-^%Vrw*iRceI#)c/e-;b|J|W}Cz6R```kny)iDbo*S`QWn8```
::y8n```QJcezn$8/9-~=&TSQng}NnBHn)}d~C7Tn$>Mk_7Y9+%7``zDS)-oCz6xe_M)r$``a@GxE=mc7ZzH)T,>eY)To>.7o~g)voO-Lp\J*Bj}mzgXrP{Q9Hn+.X!hrP9G
::an~`+tiM~CHz7^~O}88.1```AT0D7J}=Xu7M.Y``(iIT.o{R)qw66xpCMC8.hyc7.-``aNndq`zDTAH```_x`)\5``76E#,6P|J,=!`kedG{7`pzKNiOA```a@T?4TaRwg
::yVRl.,5~f$&)V/n`hy@T\H``LKGz7sO~V*``lXV|t-_~p6qK(~9H6xQi\@+ph?Xi``fI5C*DPh(%M`)K[hrts@T?OlaRdByVlF^V[bQ_utS/``%7p1#-V=|Uf![rk~BTxO
::q_YP|C``a5~{%ilBgPyy|C$58Tb.FuF0Q85```[_b;475Y+YWw3[````Q8Ol\H6xaD%bUp$VaNo+=```_~[`%bUp$VaN8)[```_~1XqK4>L<knp_M)6,``*bH1y6pOO>W4
::IHOmd.8oN[.Isd,UtRR))>ro5xD+O-@pZng}D}.Yvyj@+jc5S{``76LHM>f~oH~Fd7``/dX5s_Jav/``%72[4-LpRC;c3a,H~_sz4I``&ifq}B?```WvpP)4N&w,4DAbUp
::2X6H3_1cEC``sM#J,AZ7yo&)#2R<7!_J2YL&5qFF/`F`r3uCO]``)`8[OlG9B^m5j@v#+tKA$}3_7Y3mzn_~*?XJ@|9v7YoV7ZWo~7(hB`C$5Y3d+2d`f5Tg|P,6A[6xK)
::iC{qw|7Y[ZBn#JTXof>W7Y(Kd8#6QJ3#Z7gv9G!{\d6TQJtqj@++ZD+RfZsM__G(47``g}xGBHmT}```OmV{!4@```[_s<475Y0%j@_A(PaO6o]&Tu8Pa@Gx>jmcV>~plC
::?i}>|)F4O#K=jBT`sdk*A`sd6-6x@)e#(5`gn7``hyqCt_*KpC``e|_,8i{>p)*iS)H~}```(XlV3PIi>72j&kq.c```]&T`~Ck<G```{9L|762@{K``3Q_6AC7`nTR>5`
::76!dM>n`E)(.9```Ph!]V`76NT,>|5_~~)tCK5;}+QWc)y-[iI}nh>3Mq<ei&-8a5`pU^.tosO`C`Y`6775`76rDX/&o1H7|pak.V6rDq5;.zoW+IiJ7B<67cF^.e`ai&o
::e%Sz%gj.Aiw9MX[hY<SCpf`Caug}>j^.P6F#Tgk.AiSDMXvo$d_\Iiw7E<+)E`5,o9`)8.u6#.Bf7>B-rDX/h.`/x2Iiw74<+)Z3Y.e6UKnz`4&i\i{>p)Qox.J>Y4zz7Y
::Di;4`Y6DtGhTb.BVc>c#``5Y{$7YDi(R)@S)BoL}``wrWu#JqK*7I```W4ssA37YaH+6[#q-y%!AO{``R^lf0b9Ly6C```Om|n_~r_Ax,I``8.%=7```BHF)56``zDXJF_
::N6<C``]&4TM6)```tGhTE-iOrd``gkeO`,``*b}*y6X```Om[M_~7zs#X3m>6x[NZr7!+TC)Lo=KcEF7j$_;*BX#O-gpACuk7YEouliL``WvDYBHz)})zo*\6x<MiCEomL
::#RqNh```w9``{`r8e.3aroKlc/E>|@Y_=I*75Y.FFa*oKlc/o#Jp7YoV3aA~Zx)```BVe~auhyeCB3Ph`MV`3Q-54V{C>```||})t#]e_k7YKJuG`xH^.MKV``E)O.L```
::r&qR7#F_7Yhy,,A```0bg?eDIt7YJ-[x\65```tGMT3s!s7YEoZXqK!8(<r6Eu]G_~PT+77Y)#[xODFa*o]1k%Ts7Y=JN?`yJ!WWsk7Y=3QJs}@,Pj``T`L{3ilBVfe`5Y
::[xEiGympfI|Dsdf_U/t-``QJqKZ7yoiS]?``zD7%`YJ-=T7>hQR;Mt?V1GcTn$4V5~=AhyeCf6YeYk7Y)ymphy0dgPe|o,+kM)6)``Gymphy0dUhe|w,t#s@++bjszaT``
::9JQ-9tT+Yh^bpH@}``eIgm)Rp{#n``^-*olCqg8%7Y+hPiG7``<iZ$%VDF7,1Y[lC`,#%BIi{>p)PXD)c>C~Y_kZH75YiO@f``Xie#,d+t6s%m;c5`^-V=}=``76[x\65`
::76iOrd``gk%X?)``a@x+Ptx,9K.```%6m<V`5Yj]lp_D=/J\heaVLT|s``4`r3LK``zWXgj_*kXgM7>`UMv[Y_`6}5W_`6`V*@0oulOA``;o+R45`#}PN7p.}`hh7`76g}
::]7^q|DS)zoL+=Ty>[G``Xi}>+)UDGq7YJ-,x+2An%6m<$`5Y8}7Z7!fI)ne.KL})jhS$e;y6NLSQsX6gO7}mBv9G!{HrBn8^0^~,W_6g`/``Pt,s%m2,5`6wm```QosAA7
::tGhB;d``]&,3+(q0DTz[vXad2kO~q<``lX$D;#B7``!@mphy@TS;``[#~Z+haju`)KUU4.qL``/d3aroJEeff`zD+RF_f>W.``a52<*cT`76BVM.vT{9(#9*P|2/U^``Ag
::OezPR4h`XiVe5E`vW6\G``5Y%7l7HFC`5Yk~QTaR~OO```_~]_a7*X``&idiI%r```&thctG9R?d``]&;3sv@u}`/d9j0zGG``(XZmqK$mj65`^-\3__B@%75Y+Y[Dq-7`
::zD6xv)]B%n]`5YNT+_eOBi``[.H.vVT```[mBnBH#@!/``PtQs%mSC5`</Jk{+G}``kg!d%bLdP97`;o(AYNlCe`zDR6[DE@7`zD6xv)]BuDA`5YNT+_]+Li``[.H.~E9`
::``[mBnBH6g0/``PtQs%m^}5`</JkMXE/``kg!d%bLdTM7`;o(AYNA08`zDR6[DSD7`zD6xv)]B=e0`5YNT+_{J%i``[.H.ddV```[mBnBHBrS/``PtQs%mU55`</Jk{+5/
::``kg!d%bLdN{7`;o(AYN6!4`zDR6[D?j``zD6xv)]BZ}A`5YNT+_k61i``[.H.~E$```[mBnBHU.R/``PtQs%md75`</JkMX05``kg!d%bLdDM7`;o(AYN~m4`zDR6[D.#
::``zD6xv)]B6m0`5YNT+_8RDi``[.H.vVi```[mBnBH}/S/``PtQs%m;_7`</Jk{+|7``kg!d%bLdxM7`;o(AYNr~&`zDR6GpU_nS@75Y~Ob@8_C9s_Q5v(7YK.I=s3A}``
::eIZmqK$m^L5`^-\3__0ol75Y+Y[Dt]``<P6xv)]B[<S`5YNT+_eO.i``[.H.y[C```3mBnBH#@A/``PtQs%mSW7`</JkMX.7``R^!d%bLdVu7`;o(AYNp6B`zDR68v#T(i
::Fa`YO-+5``}x?#V~lur```2thctG9RUC``]&;3sv&O/`/de4R};yqZP6\3)w?5``R^!d%bLdQV7`;o(AYN9FQ`zDR6|,y^!d%bLdET7`;o(AYN.4Q`zDR6w4l^!d%bLdIc
::7`;o(AYNF<Q`zDR6]K$v``@a47``3Q~ksvg=/`]mp{k~UeXk!zTHg-<DD>=KYPGO^5<_N```_ZC]-_7Y7YkZt75Y~Ob@fx(NKJDzz_H`8G1igdr./8^qDk0T]9``{)l7k9
::``5YC9s_Q5d!7YK.2r^qsj0T@9``{)CA/@`Va[!9Vk$d/cADnY%)Q)k6M+K.vf8_utE5``}xp(`v7E%k2u#M[32n!AV/BVpU`O>aYYOe(aDT9efOG5jwwx3^}o``{}qN,w
::wjAx,9``{)Kzms)P=k8%>2`YPa,XV=u+7d@u8_iBJ5``}x?#V~vPZT]5`_n7USy6%vJ9RRBJGD``{}9Po./(a_7Y/=xz4.TU7YDi?P?qisU/=w``ATZ5)>ij~h*0Q#Lcr3
::@Chy7=FGaDDN/`<Py\[DOi7Y`6,_I%ggpk7YZifm``76t(9_2z-}``Q_|3r5``}x?#V~vPZT]5`_n7USy6%vJ9lOD}LUF~N.t7V(^?X```Ry8GP]?```;oGSqK$m?M5`$Z
::A%LT7Y8R9f``[.ywk@)g7YDOi.``C~=Pb5``<P~fkNtzJW7Y^5-mwx`bK,``IV3aroJEtiG`zD+RF_]`H5``%7O[@_9Rn.``C~=P%.``<P~fkNtz`37Y^5-m}+Z.=1$?{9
::qK$mI{5`^-V=__cbX75Y+Y_WO_)YJ`<PTBA]`V7ZJN|#&h*0Q#Lcr3@CuA7=FGxPUWYQlOju]%raVr.`5Y3mpnBH|3h/``Ptrs%m8x7`</h1C>HO@OeddF``F~c.<j````
::IaQ_Qf3c7Yu9lO9};P^quyxOu>9t+dV`766xP_8RqG``[.yw`yfU1_DOj}``C~=P%.``<P~fkNtz`37Y^5#I}+|GO0*.H8XkKZA%#JKv}K}`XilBW_#@w5``%71f|6wj7Y
::f`g`<PTBv&<]jt7E`vEhKJDzz_H`8G1igdy.U4;o2)c/`z,tn6zRa@GTy6F#d8!`d)!-lop-j]lp_D=/J\heaV`@R)}>2)mbG\W6]d`E?t^30oKl4o9>1pGt``76NTdVRc
::88u```QJ.Mmfa]F_7Y,6\|^^.V]B+NLmNftGTwuxYks@L2LmaVQ2U_`6JH|33IiS0v(_)#%B}UxT7?|J$#q~-NNTo\SXG`{})>tW@K5`UD_DINRz*oU<sv*M/`XiJE4\}x
::T;V/NVlFFm,&<i|`pUed\\``;oX_7Y7Y7Y7YWiMCV6KW6Dsdas\J`/j@A2i23#psP|^^*)qh*orEJMtGoWY_][u75Y}MOY$XV083h.T,QQ>>``aN1~ct`<N9.rbeVI5`UD
::}dd[7`44`9<ChTzEJcZ72oIl-KV~#6S^#dj>}`y7~hq~w?Wff6XHg-<D!r+).G``5Yl/1oh.WvJkef~Im]$$7`nTo>h,e;qDhuu```/>+)>ja7~V``[#C{\Yd```#7^nD`
::``\sNia71mA1As8\_r9LTuwiS$mSy6=Kj3#6;E?t^30oVlypw_\|SZ?W``QJn2j@6=+]JD>0h```;oA&+IsdskO~]@``lX$DXb7YN?-gSc5=@7]wj@#_hy&XN0``=Kk!u6
::[xs<g7``g}Wf_~N_szXV``[#irs54{Ki^#O3*a7YW\=P6xQq=5``gkeO.G``a@H1@`s@mSqDO#j3|YO#u~tCxQ-%Wy`!+TC)Loc6)To>]O0oul8-``zDS)zo~An)t#zD``
::Xi}>+)X/+R?>*oRC7,iCC?Klc/p-<oRCMdX5s_O-.5``%7O[;5Do]r-|#FedXp``sc|TS)~oIV8.J.8K*/FQm?C`Wv-W%mOH7`f5D7@{OU[/``NE5l2]y6ODB,LplCt(T1
::AqSOM/87``k1WCLc!h4V3>-D5`Xi_~7zs#X3m>6x[NZr_~YSrO4DDLB$|I0$m($C``QoYGtof-N7}Y``zDC)zo5|[x(D0bGTy6W#TByV!h.,5~?ihy@Tso``aNu<6`zDR6
::13.XQ>Qo``]m$-hoIlc/p-Ak`%7e7U7aio!Dm>9[`%7e7U7aio{-{a;6,x!2An%6m<c`5Y8}3Wf```m./@`Vj@fx$IRC%^Mdrwm/``YRh6zD``XiMCtifI5C9K||w,8P0b
::GT@`_@,=MZ3u~C7TE-svSp5`/de4?GMFV/=`PZc;M~!`O#irf/;gsv;7/`NEFhrP*/ocr7``<\_r9LTu4DS$_A(PbdaY*<R`5YbC}```tGhT%n[m1%+pFQWZ.`,#,n``zD
::S)~owsO~ch``R^.MPt}`]m?GmzPdc;q/aV5`^-gpSCm/``QJRCZ78_R#C5``hybigPn`zDTAcC1`~~i7#JRCZ7ho|JM/r7``[#Xz.```[_aM37``<=xidiB@,```Pt1)gP
::n`5YBHwa&}``Vlc/y_P|2/IH``,Js)+[V_7YZ?ypm7``1G+.lG``]&4TM6c```tG9R$C``%K@O}7Sd5YHwdbC`YqB```\<W4{T;>y7xAY_6DsdZoqu5`<P[xIgv5``[mV{
::!]SY0bLdRn7`r3]q7Yv>LpSC$C``R^#dFgC`TgHe7YKoaRN7o75YA.````BHCsb}``Pt87Wd@HNTy>9H``Tg527YKo.OQYhy}n4-b3t6DNj@SHSYc`76sv`L5`Fu{>O)))
::``sc0?xOic6&K{=)F08h,5;dK5V.&JalzPJi9`76_~Z*]VsdSHdXnz`}p_]$[7``+TWN6{N`5YZooFc/MQMdrwd/``QJsFzPxdg`5YNTA)U.ywyja7|$``{)O_6Y=7``>`
::iN[I{9qK=r!`#u8```Faj_Ajs7``9eqK=r!`sN]z]```BHc=G/``hyeC*DPhR[f`760X*\57BHNif/``hyeC*DPhv#f`760XV|lY6xRJq(``XiF0ro?FM/r7``=Ku~;)``
::|e?H)T,>RY)T9>eY)To>\O0oVl#IsdW*NTg)JKgo[I(K/^[D]X``76[xi6H7``Om8jed\E``pzcQkGJ(j_7Y<We$d```wMf+pnT5``,#iq55kp7`1```@aU/-K``R^9uw$
::_AqD[K2{H>/`^-,t6G;`766xh)}>\)fRaRw!x`76~Y``pUedlb``;o2)c/a-5~_nHQd@c,mp7```BVMoX)``a@GTqD9|9*9L})%gGympPt5CgP]&cyOm/Go~`)tp%mZS/`
::^-LplC*i)>#)?XD)^opzdXZ+sy`!`@qKd8#6?mg}@fhoQ|(#]se;0l@RAb5|eZ}RqdD7``r3^zn+DT~5``-|Z3ed}*``;o&$^R$`dbt}tGg#(G``]&63sv}L5`/de41f>z
::e`BHI#/.``gu?k7YN&YY?A``=KN5i7ww;iF0*oe]YNK\c7``sdHT%ng}^nwh,5;dK5V.C+KS%5``XiRcnwKX{R)q3sO~(I``QJtdN)d`-|t5_~JDaRTj{776svM<5`/de4
::xiV>qK~GzN/`86}}u```FQ*/.`zD.On`>`j@GxK=mcsdNHdXnz`}p_?B+}```@M#U-@p!-<W%WC```]&DSw/AbUpUqU#3/E~/`^-FCr8Fk8R>C``S$=7;x7`,w|n|p/0``
::<P{Q9Hn+V`D7``P2eaj`P0``N}m>lop-8}j@L29Gocn4_sB>&\``Old?s@m(UD+R(_GC]G``x><X*\U,b}R87`!A}XH?9%97``wK{Lv<nO``r82k8RyC``a@x}`+7`;o&$
::j/$`zDt7sL9LR5(U``knK)2-<iAG`VV>~plC@1s@m(#r3usd<-6xA)fcCw$Xeg$q\>sYrS``M*x-l;os?`zDrCLF96JM``f-4_`O>7``i2jDT0``!1Q-A|NO?`)K!6?Y&!
::QJfhj@L2FQSv,`zDD)LoCzdXnzsy`!`@(#V~9L$$ku/C~n$IRC%^JlhENKlpkD%XHi(g5=eM?```c;qPm>NT!-a@+j+tDfe.;&dM4D,y_A(PI|rj!`?|4p#608!ifcCwHX
::eg$qkzd*&7055Y,X0$ofy87`,wYja7))``=KQ/^A/`IqCz6xFPs3Qp9G1Nla26CnY_zP_~|SxOF>|@ZxlJHqY_KoxOjhPh,Nn`Fu#UhEa@9L(P}```d,0HPM2t$VHCDo%n
::3m*ro~~)~/sdV*dMM6]P9*L`5YdXrX^3_D[/J\hes&tR`Vj@fxfIdd6r7/T}d,c/9;\BuvEE|AeJ*BEyJ9BE7```4V?.4oPkU#kBv&794)3ap.!tzf{Zwj4.U}AbUpQs[K
::/^Vr4JfWK!C`-|3Fed?z``;o&$BZ,`db954UO_7Y3ml8_~BT+R;n-H4Ia_`6rP%MU#A$|6G```$IWfUhl&K@d,)-f$2tHcsdNH)T9>uFedyg7`;o&)KvYeVFxuKwpyro2)
::X;l6}+)Ty6(b1vp/(;jbcl6gei2-3@5(9{,```*bWhQoD)@ol&DWOm)-U5PtAN(d3T[<3m)-Nn!tWf*Dr&Qc%gg!Ao2Ip1F-l;L[I`)K,$LFo73V``((x_+PR7``i2jDxy
::``Ifp-sMNn7_\nmzKa.U9#b~7YBM)>1?{9`|UEM=ssS47YEo]1x2%maW``OlfeSn3m=->P``76o~1)^.WdY2)T;>8,k~G@C)^oCz6x!,2Hf$fIDf*DPhnbo`76dXtJ^3_D
::[/4vF4UFSQ8}7Z7!PtocHC0zl^`)ul`vb8P.W6<dtmg}@fuzaiL}``xhS)=D6&mi[mM9k~|X[#kBz&*MRV3aZn!tMiQ3RzA+D|<5,{N/b}``?zsNq#;```,{B.b}``g2(j
::Ka7Y8^U9uy|xPtIW9*`PBW7Yo5qq{RD)Bo</``wr~pyCcc3a`?pJV/[6>o|J^BZ7Ro]1f)^oGsO~h2``QJtC#$6hfsP.CPM\CQWc`Gv?Y`76hA$K1.JHF<A6mXH;c`db}x
::A$MY}```0dTZ(7hyy6,<)7SRR)}>2)ZDC)goIRhENKlpkD%XHiyR>&O]3mEf_~;jAx(G``s#UEc6NT8_]+Y}``a@p3U$Aa[5/}``t>b3?}-|Aio~I+s#s*Y9s_7Y%b&PSi
::Q,``zDS)+n|@lX$D;#u```W+~7``^-NTZmC{$7N_a7?f``&i|qn4DDB)(U_q0X8?\qcx=T.>\m!4}```[J3Kj@_!FQfR/`Mjsz~G``[#Bp!`<D1G-7BJ7)uya2Pt%W%mc\
::``\<>oRCwc{>x)%ID){>wj__M9r`76g}di_~rD8i|qg~dX{;J#pzcQIiM7``<P}5i7#J,AZ7woIlV/W-lorrj]lp_D{k#\_rzH)T,>RY)To>]O0oVl35sdVP?```wr0DtG
::)60n``%VOy#79e;o(A(#TgF(!_7YF..wHnr_Q_zip(G}`@go!JV/3dKHNT,>f5mz$5F\_r9LTuwi\/%6*<c`5Y05````sdRP,q#lO5E77`5Y=TG>ml+pFQ[G/`L@U|F-gp
::RC!k%X2}``0bLd=[``;o.T8P%m([``</PI9COm3jed]l``pzR^Kx]>+hf9C`76NThJg37YOu00e77&Zx;))>O)vC``;oQ)?H``Mjmc7ZzH)T,>RY)T;>kg0oKl4oG>1pH0
::``Fu!hBVj6JG``8JCpO4Sa)49L9JF,iCw~kt3XL~c*NTJJN[`YKo8ifq>6[xsmD*r```V=xF+YVrknJuWnbp``5Y[xo*zPLf)`5Y[x]9\@+pfI5CP-@V!hBV\3Jo9eqKV~
::!`7?c>lo@CK`%VQc8PpUuTqDv7``An=n*D@aU/Sc``lX*\TOedF1``u~w{e{\dGWY_cb<`76+YL<B1-```aN!dT`<P$E(H+U``766xp1zPv=i`Tgc[/lUS````O0U3J```
::QJ}MO%M27Ya7cn``[#~Z>H[xKfzPt_f`5Y6x<9zPl[i`5Y6xp1zPO#i`xhT?@_0Tvn``scsdvH)TPiS$x@BDC)cc{Lc9r7!/mzZ55!S~K$gx~)/Cf(O4Sa#J+_vDP0Y0z7
::FQ+=5`zDD)?>3<7YTCD5qqxXS)-onAn)M697``Xi^#W_iBk`5Y+Y4\Cf9>V^Pc&t5C9KR)sT{/]PAzi`5YNTg)iCHT1&oft_hBs7``aS[_G(]```sdjkU/+m``QJqKZ7ho
::(AYNF<9`zDR6t@(T37a@J!FQox5`WvccsdHTn$Om2HYvPtDfgP]&39%gs@Gx</#\_r7!#J)AZ7vopJV/9QMdrwt/``QJn22TOHACaN`t9```_~FTHi`YnoknHQLyP_A,c/
::]0}```BHu)\5sdOkO~_$``vW6i]B3lo`5Y=T.>fqedpt``pzcQt+\r#6|TC5H#vo|Jc/e-W4__JPw`76+Y_W#J9uzP%Af`xhmpyyx,gP}`zDsd75UJ6!;)_~4_mcsdvH)T
::YDS$x@pDC)|D{L+)@1s@m(jiXJgA7Yw.P2Y%d[FQc65`zDD);>a5p5D+/```tGB0l}``Ph&D.`J.L1<P``YR7>Sz````R)|JU9%bEmlC````3mwjedGK``;oHz(KR6[D_;
::``<P6xR)}>2)fRaRulH```_~!TxOF_9RZ7``a5~{qi]B<ZD`pUedeo``;o/TqK$mmy7`;_g#g7``8;[hpK0$H1y6M|7>HplCXdX5VV|TC)^o866x+_M)@/``a@p3U$aukt
::,bkNOmrjedeo``;o|Jc/U-V=__jGy```sd(kU/u,``5f,>2b+XM%CCKzC}zD``@V!hOm0G_~N_Ax*C``[#s*+h<Z}`76NT9>_yx+Pt)nYQ]&N{%gs@Gx(jBa8I`Z``````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::````````````````````````````````````````````````````````````````````````````````````````````I-6```````[S7`````l0}n``````%e6```````
::-S7`````765n``````Tg6```````9S7`````Xijd``````i<6```````jy7`````zDYd``````oy6```````Jy7`````l0kd``````d?6```````````````76k/``````
::/j9`````5YUQ``````FuO/``````m/D```````5B``````|5F/``````PdD`````5YuB``````r3F/``````N)D`````5YvB``````vp3/``````4uD`````5YNB``````
::44q/``````zDD`````5Y^B``````\<(/``````qID```````!B``````\<a/``````~1D`````5YWB``````zDs/``````JyD```````i&``````XiW/``````QwD`````
::``D&``````r3W/``````CzD`````5Yh&``````3Qj/``````|-D`````5Y<&````````````````$%.`````<PUv``````!Aa7``````zWf`````76^Q``````l0[/````
::``1F9```````>Q``````xh\/``````h[9`````5Y%Q``````V%=/``````e|9```````hQ``````,#\/``````l29`````5YoQ````````````````5Y``Mju```1$``w.
::7`!Al`5YeK``>X5`eI#```6J``@L}`vpJ7``sH5`r3V`TgUC``}{f`XiU```f$``!A{`76x7``sJ``,#3`5Yg/``y;7`<P!7``s$``{N.`TgVd``#Q``CzD```l$``E@7`
::btz`5Y[K``FF5`eI.7``6o7`</)`,#?}``K).`5YT`pUiG``kTf`pU)7``$y``h,w`5Y15``t=``,#3`76HG``#w/`xhg/``YS``Zz$`76N$``y#7`C$B`5Y`;``93/`#s
::R7``$I7`<Pm`TgeC``U$.`wr=`<Ps?``HQ{`pUN/``rX7`j\q`76V$``ji.`<P^/``xJ``(2{`zDZ$``CZ5`;_(```M;``zD.```j`5Y{;``l0.`9H(7``YI7`X\9`762d
::``fV.`^-k`zD2t``[#{`Tgk/``ZS7`11(`5Y/n``<O5`xh\7``w1``Fgi`76Kd``FA7`CUz```J$``&(5`t>/7``J^``V|i`)K9}``ZZ5`]m~`5Yrn``*M.`3QC776sx``
::vpw`<PPn``r,/`)K=7``rl``fq)`pU1d``?*7`Tk>```l$``SD/`eYL`5YJ$``yo/`)Ku7``j^``oy,`vp2}```g5`*]Z`76hM``76f`)KS55YMO``</%```````````4n
::/aj,Y&^d@,{@Oa6Ww(&mAFTq8qNam^\3m{O$[U#W7|/M@87VmIQf/{fps6_x\nc<a/p%m/~~)_^B*I<iyVhO3mVIip9&3nM}P^Z}QwLaLw@yJWd-brvW83lE|Nm?J$gKn5
::!5g*)JtyeDML[,Aqqy%(BDkNu|7@Q7%P\on}s*\QDl12ffYY^OC~hix@3w,;o[Y/y5NHcdhlvC;/;Z&RQEZ%p!!]M4Kv8$MSMJ$]dW=~414L/<y^UVk%cqLBIU\$%!e&JX
::?6<fTvtEwGp4Z*YxWl3#H(i2}]ccx!AXgMZXm=rhd}=m3r&%]mewJKP*>fMP4aA11rZ#R5[Ze>}hH\(Tt*MT~vHs=!.xM^y^aKit+k^;/8W1QKStq-3.B@%K/c^&[=P~`[
::^R_^;V!OO/IDp!6UxsK@X#B9WsJ.91Buxt7mt]<hp(wgCH&,}9w4YI),MLM_qb]rqA!},Q&5RZ%)ol5~];[_wKAR-Nr^1AS[LRVA;#~fSfjz)@_]et_mVJL*W4[%vifb3|
::vhM;QR{@a0@q+6!X*_[3EVhNzb[8\,07``Dzo`76``5YvkGa($H(RA-_#kcXuCj}````ALb&B+^^(MG5hb)7PNoN(H}oBZejWiYGYXzR3^krh]TLgb,ofF~^Iuyo(+hX-I
::u!<>]Cs=<I3o,1aAoFM0+c`JM|L|LF%AI2XmnMOi!bB(u\=vIH?w(xNC1C0Exhna*ds?^E!U$4V5}@mp0L!sh6mPn%RYm$9?C>`/N|_4HNEj\{Z*i3$&mm9T{UAZ-~+_b3
::lbb49->Q34\J(M{0^doztcCe;NBj|pf|v7C3*6*-i@^#EJRbCXu+`l,m=<t*^-ehF~&h}VDEt<ILmaq>_F.9jPw|^v2|pd(q\F}O#c~wLd9jjWy\9/KGBx6d,<1^~$NL?.
::@KfM9Sx62hH$epNFq_z{6DntbFP8u->4}w7_Z>I<pU+o\4IO9W!BP$eF4*HTnlpg.fFJmZD2HPy[/Cot?|8|rdQwiz5;!UGUK6=#8+C2vU4=g#9f.%dHK5=-mvadfTr;K#
::o1V\J}FW8u)>klHIQTCE$%p^83a&C;on0A.B+u@Vt1fLb<RR\&g&oeDn{Lp.ld|\uRA_~iZ]m*]kY1UR.rYl4TgH/y>McU{A)\!/.s|t$NhG7kK~$SFUJ=KRFdc9i2(y[)
::cVY3}c\u2TF\a%w1y]n+Ak}%*q`-.8w+~sD1<$XV4W?qm,f>/_om1C2i&DN7/r&0n^|cWxw]k>o.eCdpP0zbZWDPt9mT=PkrPPi%)+P>2t9^WovEg@58uRTpo(rBjPyS2N
::*lQV]n_QrArs-ogs6VENiQu,Ghh(PqgDiq0}jeWirm0s%~xM\N(M6}q^;ZOMV)z%-,c2(#UZ.~[#.(i155zHr$VIj1\~3jx4?=5CKf9])2nE;LWr?#VgQ[43]?.IpcXf[&
::<n)}n6lN@AjvgLZIidNW52+4qL&RTcwsVV^s0ay.uu&.q9Bg;IV+FTrx-0ce{gBEVZlt;b>el#HGv(}KtlO/#C_}H-#5jX*##EQ)8AQ/(&Nuy0o=Npa`v>ml3Q3GNps}aG
::Kvk}]a6~j}+uRi)I*L||4f{\csmV(H^x\G1;T7QApDd_.sDTN6[UK(qwaJ}T/|ruob@hY.f\;\`Lct(#@&Y^m=C=tk~mopZiE[VnW;}%XWpUeG7m$f|<S^&sJQy>R*{07c
::9>.z&Q]#X7olREiv7|E=+R(|_X[#czs8ztm*W5JBsZEjK.wA7J2d)D&cz#&csp-C$=mW,yA}@cO,U$RHG```/2kEhN]2f}````zDiMJ7````[7``zDc0fxu,b$7```766&
::SZ````A!````)EP)__k0i`````u~<7.```l0C```]<87cPQIJ7````J.%hq```5Y>```V%^C<jlZXD````)K9_&d````.G``5Y8%2-QC3D}`````aEN4````8[c```*{``
::I)Pr``````f~n5/```h[=```WZ``Dp!R5`````CC@x)```xhR/``````2?,5``````TT<d>```76>```kTMm44VFf`````76;25}````!a``````pUROz5``````9miu``
::``An````J-m}~;hD/`````Zp*u7```UZ7```f-90s_rzv`````j\#Cf```pU)```y8CzRN?e#}````pUxn37````T5``76J>`2T.7-5`````#791````{@````?csX\GV*
::c`````u~H//```&M/````F,V*hbEZ7````)K&A>```<PV##&g86~]p3Crj_~i{kr0$=_xNhISC8cfJ&{[A_D*H%SjQK<y}yZ6TdmLtSB;(LrMUTj*XBZ_/>]~Vwm!HfO=N
::.D(CLX++-\v[7```````)K5`)`r`,.\mC$7`nYI`L5(d}L``}6o`L5(d}L``.Y,`I7j/5I5Y56)`I7j/5I)Kn6D`|`If115Y7`C`T`.7(d}L``}6o`V5zC<P76C`-`````
::````l0C6L`S5rcfe2UuYJ```WCP2xhd6L`u5xcvp``}6T`.7````V%/6o`i79GJx)KnY)`~`$5sc````760`D5scQJph$Y-`G7Ana+<PC`````WCP2xhd6L`u5xcvp``}6
::T`X7````V%/6o`i79GJx)KnY)`~`V59c````760`D5scQJph$Y-`G7Anvp76C`````Md{+pUC`o`{7rG````xh)Y0`H7p$11Tin`w`<7uuIVTimYH`z5<MP22U,`>`-5uu
::11Ti,`*`V5<Mh[ph$`u`87p$l0phfY^`z5}{}L~P,`^`37xcvpphuYL`A5tMl0TiiYZ`)5fV}L7`}Yc`$76G/2``<Dc`;7FnJx)Kd`;`$7xGh[``~PM`97Vf[#@anY?`T7
::``````)K/6J`55zCP27```````?/d?wrHPX`x`!},wxhHDT`o79GCUpUC```````c,IVph)Y<`07yc,#Ti,`b`)5@{QJ2U,`*`*7tM,#og)`J`Z5.c3Q7`````\`l/c;Mj
::/6{`f7QG/2l0n6~`R5=)4456uY-`z5+{Sz56,```b7H,eI2Ui`@`(7=)J.7`````````\&FpfQfSV>.}9=R5````/]>ner>,i8UpGaf```Xi24Opi-DuUR~G``````S$[H
::Q~DAHAGZ5|aT~V%*e3]S0]b1%Q````````Xix41/,!KlHAGZhFr\E$kp,!h@}I4Gi|#whm````MdsxvT)8o8.!uAumBd``(6+r5|aT~V%*ZoQlf776YU#do8h8gm2SSJpt
::{=L^=c|zUHfSf7````````MdsxKV19=He3]SYR(n12Gd.MZ```76Hp)no8h8iSCS{m4GA<bx.M``````0?P>a.,|YF]82zpHec``A~{AUgD#ys?M[iT^k2sA-/~G?```<P
::Tl&G51;2aTOgSB<SC`G9phf`A`x73,|5<DiYw`77jiFu56G`````````eI7`.`{`O`q55Iwr/6i`+`t/eI``<PmYH`)5yc442U,YL`%54u,#ph)`g`````````)K/6J`o7
::zCP2ph,YV`~51u``````5YT`G7QG44``.Yi`~`559c````````X7Ifh[zDC`?`c7N}mlpU/6-`^5xc``````````\7&M<Pogn`E`-52ifeogmY0`$5^V44Tg)`E`{5````
::````76J`%5&MP2~PuYH`77xcpUog)`````?dpU5YHDc`;7Vfi<@ad6Z`P79cdb/Y.6*`A5|V4476)`Z`R5````````5YiOhLC```L@````t7``DvA`<P7i``````865%XG
::````g`````````````````6J6K1/J.``\/.`44hQv%~)*Z?`````Xi``E)``11|Tic.<UJC`````\.``$C``uuN)>nH+``[Gc`pUC7``,>vt[3)5``Pg``w9``l0/f6+un
::@CXql-ZR)7``Tg3```w```5+vt[3)5``Mb``ld``l03n6+unC`|5U7``m```o,KlvJ>nTl````<Pa`5Y7```\ovt[3^TYn````YV9```G`5Yk#\d]8m>I5````(0.`(XG`
::76k#\d]8m>R5``````/`pU.`<P{lvJ>n``5Y]}``J7``nno!C.````~DS7)K(27`DKr`</mc76h>c6i`0776d?5`|-d777li5YBJCY*DS7)K$Z``Sa.7G9m(5Y{#T`^5+m
::uuldn`s6k5dbK=7`6gH`ldR~V%rc{`V5bC^-Zc}`.XI7ml#x5Y%pa`v`B.zDZcC`WDY7)K!T7`Ap8`X`T}5YK=5`Ag3`J.7l11{}}`H687BC}}}`7XS/11qI}YT#+`}}EX
::p${}}`H6F5xhMd!USa.7G9bm/Y{#1`^5amuuBCd`[6DRwrL}T`5/TnAn%576*]N`w.\;2Ul`y`RYK7.G=Exh>P;`i7A`J.Zz7`\.Vf|5f55YV%A`o.mc<Pgc?6c5nud?ph
::gPx`F5[7YR7`?#;7[GqQ``SauY>`q7K)&(xhd65`1`V$5YZc.`/X^7xhI57`%pF`v/PXuuvCd`#6zI^-rHV`7/vCPd%576eI)`1~An563u``|UC7V%n`G`>P``VYk}XiZc
::2`qD\T;o-DMYLP7`VYS7xh!n~PKgp7L@L}V`j5$C{}%576)K1`</g$76>;G`36F5TgMd|UIg4`/dqR5Ycl$YJD4.,#&pbP}7&d>*UZ>P@Y07=`YM<P_XHYa7_,8,qQZD8`
::/`4`go<PNzHYa7_,Vf2UZPJ`15;cf55Yml1`@}tvKN!Uc`&`H5|V~~3uqQF`PdKA76J@T`WzF)o.@0GY?Y`7k`WM<P^3B`55D9l0c`d`)65`RYV$Xi\A,`fz1}vpq|5`Hg
::3`!nvEV%E)$`r7=*Xi$G0`5Ch,]ma}5Yxh1`{}=V5Y2$C`/Xk7xh5-y0````````````767Y7Yt```Xi=$``5```1```J.````9J5`11a```=$``yo/`&([7````a6l1ra
::0ML4&9\I%oS]wZwp3xC`A+0Mh&Fpb$.y(85`0v``````````zDFv``YVn`76+/``````````j\k/``pY``YV9```````````;wi```y7``````````````````````````
::``@a`n``````!!6```````xS7`````,#/n``````?&6```````SS7```````7}``````>2D```````E&``````Fu`}``````mPD```````s&``````)KY/``````3QD```
::``5Yp&``````L@_/````````````````2t``````fea7``````r_f`````5Yjv``````;os7``````f5i`````76CB``````xhF/``````;GD`````5Y{B``````&M3/``
::````D$D`````5YRB``````Mj3/``````mMD`````5YHB````````j7``````})i`````76BB``````vp(/``````=KD`````5YUB``````vpa/``````shD```````YB``
::````3Qs/``````l0D```````,&``````L@W/``````X]D`````5Yo&``````Fuj/``````?<D```````S&``````|5k/``````{LD```````````````gk(7``````]jf`
::````76&Q``````<P[/``````fq9```````gQ``````;o[/``````]O9```````XQ``````<P=/``````N=9`````5YAQ``````;o=/``````,#9```````vQ``````3Q\/
::``````zp9```````````````5Yg@StaxGrd`|5D#=Bv!%H$`dbjhDAwA\nGs%aY8o!lS%S975YEYyBbSDRwJptv2&X+QJ`FuF6FH\S<0Hk)f``3)~1J[V576ddYSLA]];f
::?`],J[nO,ryMnZWy$`j\#U^l3>{[?`Mj3Dv2oM9Mg`^--6E#3EElUg56N/6MI{^L[}``5dYSLA&GcZK`n$_[,3/oi{``u{8QFHvQH0%k)f[#wao{kplS%S97zDu3]Mf{t8
::yHiS``L1kTRJ=;M3Bv9MSL+mowwJ9|<>67766/lbaA}]vto=_lzV^L&$%S|85`AA3uXGv2NLD4BKbSE%~JStRbw\\c``EVQJkzcuCSl]Pn*]A0#c,X!(jR>Z,f92)5d`11
::<0f88#w}VAEG0=c3\;D4spv.5YXn/m9A1E>n>gqW]82Hf.5Yld(baAb/,f[~x,ZMJ```4P{20Mg{jpk2sA<>K[?2yMGY+7&;]8~eQE)SgX>rJpzv6i``r,6J&#*$LAtm.*
::RUz55Yg/j;]8v=k2sA``F)(X*ZLr{=eTtVQLIHUI2C>1AFHMGcNBC.E)8MqnA<\,)8X8i-B@;m>no`<P+P{2-5f8=HF<?l;mE[K`,#xP{20M%8UpRQH0cA<=NQ@aY`egIQ
::DR-ZSHD2,od`11JDtVQLIHCV0cTZc3-5$WR1~msAk%L[C|#wC4b9\IEl1JHDe`|$$tx!KV]8~=w}VAEG0=c3vTZMg`l0Y6`\C.Ql%)Sd%F[dbceI8DJltEi11bH,[Bm>7`
::m/i9VQ|S<>K[?2yMGY&`R>St[3eTr46B[EfSBZa2r[)5?{Bef.5YV/lbaAo+TGA<WT\cegIQDRG7dll^zv\cg`JXC$PeJELA8ZSHD2,oRm``rXC$PeJELA8ZSH/|lMN8]`
::7/2i4evQwowA\nv2Tg57,^/-?w\R+.X=;MV)E`l0X6,O^HIKw]Dt$3~5!A{}IQDRtmdLRUKv?8_17`,w{}IQDRtm+;s=WT=cegIQDRG7zDi}~Lf{c\IHxT;mStra^-e6WP
::k2B;2>StZp``m>sHeTM)v^OSi0mmdLRUKv?8J`3Qu),{.~/Vs0#nX=``tMi<,rpMjo%HEl<Z0=DUaT=c##ogKY&pv.WA[$9fS+H<,bUpHEmYV7wo4%6JjKCO&,N8wLv.``
::{7wo4%6J=;U32;t9Uzou%S``+n>Xr2FG,~GM]{Pev.MRpX/`8[An-1GO0M|c3i/Se@&/>1a=^-$6&pv.WA*/,ff~^T)cJ.!huAtz+[1F[d]8#i/Se@C$rP1FE5]{SLOI4%
::6J/`[#An-1GOsw#cao!2Kl!y/`l2An-1GOBv@4Opv.WA``~n>Xr2FG/z#dE8qpMSi0]J(n(3(7``-`R>Qf33J;I{kp,uHIA2HD\7s;c&Y|jI4%x//112~zRm``v$0by*N/
::Ql$1ytU~5%C6K/Ob1@6RK[t22;t9y7<pkDVI<HN18x.M``````````````````````````````````````````````````````````````````````````````````0i``
::y7D5``}`````````````````````````|5````E```j\G`````5Y;``5c,4M~)C6~`S5rcfeog,```````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````Md{+pUC`o`{7rG``````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````zD)Y~`S5rcfeog,`````````````````````
::````````````````````````````````````````````````````````````````````````````````````````````````````````````````Md{+pUC`o`{7rG````
::````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````zD
::)Y~`S5rcfeog,`````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::````````````````Md{+pUC`o`{7rG````````````````````````````````````````````````````````````````````````````````````````````````````
::````````````````````````````````zD)Y~`S5rcfeog,```````````````````````````````````````````````````````````````````````````````````
::````````````````````````````````````````````````````````````~?``C```3Q87<P````^qf`{}````````````TgA/767```G90`An````-R7`~`````````
::````$ZM`{}````~{7`T```Tgk/5Y7`````````````,*``)```pUw/767```h[D`An````````````zD3C5Y7```ml0`An````207`~`````````````$ZM`{}````F{7`
::T```zDn}5Y7`````````````,*``)```pU%/767```l0X`An````````````zD3C5Y7```\<0`An````/]7`~`````````````$ZM`{}````;97`T```xh9}5Y7```````
::``````,*``)```pU]/767```_yT`An````````````zD3C5Y7```db0`An````3H7`~```````````````````````````````xh=`Fu````uLYm;r!FMoX}2up\(Si/6c
::7`T```MjXec!>|lR0b2s<]UE-f$CB7<P````l<Wy\4#r8ucKw4i1Y9G5}2}`.7``zDr9lnLZi}72WUk|9j#mRHN,``/```PdVb[iE-]Gy[.!X3*Xq-tVM`{}``5Yls^CI7
::UlaYXaDz%,L&W~<,``/`````````````````````````````````````````````````````````````````````~`76.```-f$s4gZ/|Kz-vN{`$)Md&J*iL/MR*/FK/>
::-~_hKTw$Jovo5TyX9d3JG,~m%6J~kK2>FZ#3|z6$5I;Ks<S+Xdi^imfh4ib~i;Gr5`````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::`````````````````````````````
:niblld:
::Y#B)f5``5Y`````Ym`l07```````y7````````````````````````````````````````,```hjhQ/`??~A]0-PG3KK=mrAh6L[P!)n9MyH!2\SNJU<?2jib{g6)!@iW%
::;d+=WT\cHVdXQ)````````y)3<o1@qF=IL8bCuVwAS7*XTtLZ{94Z[)J*IK*i[}|_|YEb?)\]Wx@};=^LqY=@&-$S;IwX!&tIL8bd;ZGBt,IU;i`````````+~``#ro/xh
::I%G^7`````````cYZD6i%5$`G7``;o``````XiL5``zD``````{}````zD``5Y``Fu76``````.7|5``````76}```5```````7`Pd``Xi``````zD``````````7`````
::``7```````````u```pU~`zD.```[./`)K````````````Xiw`76D`````````````J.``N```t(X`pU``````````````````````````````````````````````````
::)K``;o``````````````````````````````}}12,od```h67```n```@}``Xi````````````````|5``AA/f6+unC`}L-```)K``zD/```c7````````````````}`76
::<Xic.<7```W}````$```)```)K````````````````4```{nQL~(jR``O/````|5``y7``769```````````````76``#.````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::````````````````````76.KgMlWi`MPZ]y?|_``GT7`^-mb)K`Y0ne|-.zD/W[5wy25Kg|`*]&V~`5^}`Tgo7``zVDpJ.f6gkyG67Tg~/``@}]07)v_TgJJ``;o{FC$OF
::P`l>``5I,`zDk/$`z$y7Ip.O5`}@S`,#27``})v5bjyh)K!5``TLe5Bg(.``|7c6IteM``-g``;oMlC$fOi`]UN)}LQjp$DIB`Z;d`Tg)T``x;``}LLDKN4}C`L@i7zDT/
::``~~G`C$wadY].n`L@3```7/c`jfRYItbk<DP5.`?&A```<zVYGi``5^J.diczah!$PUnc+qX`0_/boHFUg]SG````{DbUeWj!Bb{izD~K``E)!$}L7YG5cwl7,K5_y7DI
::5Yc^WuzDT/``5q``C$HaH`c/c6It!h``-g``vpy7M)kUm`jf.`zDJirD#uk.jiG`Tgv5``<&%5C$C6gkyGL`,#x7``})}`\]4uC$OF?gW$P5Bg^`5Y~C7`7;7`)KKYgkyG
::)`,#D576~C``/dM`)KFUi`jfu`,#27``})+`\]y7Ip.Om`jf{`,#27``})w7bj7`)K)YgkyGh7tKp_+zr{pb;J{%yh?hzD+L}/zDi^Fm=4F$zD1K67y[J7UD<$;_cQ*_+h
::#Ug]SG````F```8/zwXl07C$%7)YO>q`kg|-4V>i;_eM8k`6$6]aBy````</``8;e-7)%izD4iF`qZXdXia5I;j}!U46)x7Yh5;7sBC```P2%ODjPUD0Rkd`+)f`76XX&6
::1D&`H;KizDL<ah#bqf~D@`{jtW5`}LIku`GTt+xdNv764kO5P0Q@^-s;\x(G~t5Y9^7YYbZ]^Tske6w.Q6%tN_(fKaq*1;wD76.J``;o{FG$!s/`_;4`5IB]BCO7k.ji^.
::di.V``<b<.TiR~wa?dIkIVPz5^srW7\<N@u`R;$7=)?L9M!E_`&Mvj6D,kk,B|uiU5UPDj=Vc/76s}BYQ7?58Mk]T`*pu`q^@V&PZwd`Yp%5V%kD7`7|~`2?raI-!c4;wM
::POL|NMy>PZ]/@aK!k3gS<8,w>F.@>vl-_M~\M4-{{pz[PHXK{_ozxSh9iQpOL7%Mp]b\@t.5PZ1-=ql_=riQ5iAw{-o%DxH-/8Bs=9*s?p%[Q6d`{6]a&qK_hat```5Y0`
::2?`id6s9^5y,En5Ya*&.soA8,w(T[5Gw?7G9S_68_Oh`2?eM<Pg7f`%|;9)FCY7`&~;p7*;3%;$?GnqS%c>QpO}}%4q%[x)M3#91=MCF[yRjB$OTwwF77XA<j!*{.Fd{1|
::K>O[%klfsD3+z?1{>QIMU%\,IN$p>za3&Z9D$FwXpk*(Vi+0_WGTB,^JQ8W_yJ]J=#[[4IuK>=obaSFs8QAH##[^R](\Kj5{c1O9*Oo*#-=}7i+0A7v`=`sUR\*k8U&```
::xh<;y?f_W`A(yU1;wD76.J``;o<7y)bs/`]dh71K1jh,)k3_+hd;fY+=}`z$w.tXiv7Y1,e5Bg9&7YQCh7tK6F7Yjn&6ubJ]ldi,j_OuDm.6Pt?`D$MkzP=UNrwy<_`66a
::PI9w!_zPtjh,P/WDaXt37YD(@hEKIP6gE!cItb-fhrr```xh<;y?f_W`A(yU1;wD76.J``;o<7y)bs/`]d36[<tjh,J8O_+hd;|Y+=}`z$w.tX917Y1,e5Bg,*7Yach7tK
::Tjp$Y$O_+hJ]BCzL__OuDm.6n1?`D$MkzPVK7Y1,e5BgMr7Yach7tKTjC$i]U_+hqN/+aErv7;9DmRWY]a&q.KgMlW|/hyVj=Z*_7`W@8YH;4mTg+!Si2bii76*#tgSLvV
::zDJi.`7JC`~mqv>7>I/`H;``)K-n``qY5`Xi\-wgRzSos~afG6%`{j\Vy`Tg1jh,P/B`Z;oa7Y=6ah#bkk7Y_@%7D$&776uRe`RCh7tK0e7YM{Bi(XJ]BClx__Ou<$.6r#
::___VkdzD7X``x;VjXHVkq7Vw<;^Twa|e4}````ig90+q^de|RaEMV_/`3#l7$Kg&76V146dbi#7`^67`p$``C$lC``w69O+m$)fYYf``</w.lX-J7YUle54ggDh`G?|_+h
::/;fY+NRgEqbj6D+PMK(|%_7YUNe`k}=`)Kq;VV[I4k^07d.6Fgd`p$.`C$lWQ)G,y`,#!g5Y@)>_|M$/K+6X7`q|#/J.@P``+^a`jiCW`6CNKi^yt/Y^WFCYZCn`}Lr&``
::g(@hEKIP6gE!cItb-fhr%3*F[||uXiK_>kSy#5J.=jS7DW-_zP(/``EE5B`)|9&/1<ah#bTW7Y_@``Xde5Bg9t7YQCh7tKMB7Yv/&6ub}U7Y_I8Gw^p$TLu<ah#b,W7Y]$
::,`7x21J.fX7Ye/h7tKNb7Yv/&6ubH\7Y]}UPr;2$66vvj_ArPU`c+qX`0_/boHFUg]u]<;y?f_W`A(@h1;wD76~!m`ld6.oi)qP`,sY];oGKt`C_=.]OTDVYw(viq|^776
::qA^)||k)vBga8`c/&6cb8j7YPEU.ji5y76r#Y__V5dzDjt7`@LFkFuJa-;]dOX\<,65`WIk.jiMYTgA+356oF)o5[UP`l>a_zP965Yi.Ziji|9O/VJ``;o{FG$hYgkQ8Z]
::bTf_j6Z{x$vJ{%yh15``5Y.KgMlWi`MPZ]@?|_``GT1`7;7YQD*#0`Tuf`76XXC61D&`H;XDVY@qvi3;5`0mZ67`C,``5^/`Tgn+356oy7Ip-g/`I5.`zD^g-DP5+7osq9
::d67.``z$7`C$=PzDJ/RYItmK``-g``;o8JC$fOm`8N``5I4]/do/UPr;^.diu7C`,G{`5YXXu6].!5~FM`zDBH_5Y-afUzuz``Xd4`rBzn``5Z7`7;5`764C``J/r./2vi
::``NT7`^-(<,KB`{j\V_,}L?K``k~5`Xi|.Igp5``z$y7Ip.ONrVIVj?HVkdY1Dx$vJ{%yh#*(+]a%P,UeWm`6o}`}LXT7`\&%`3Q&m``i34.q|4)ttBOn7Xl4`}L9ju`GT
::)27M`P76&2`YArb.Tg!+Z/6ow.tX?$``vCLj/2rDKN[[!9tJ]_UDe5[PPE#Zl&~~``76[\MrAi``zD)o;cNv}Qjcx$8^-N6YeWW?Bb{izDH#?}zp7Y1i)iR7hyd7S$<-n5
::ALl7,KDo}`Do1`7;`gzD^K``#s+`\<__/`|Q16H;7D}6k=ah2b%55YK$``vCLj/2Rj``6du`5|&><D@`{j\Vf`76XXC6_?5Yc^WuzDT/``5q``C$Ha8`c/c6ItP4``-g``
::;o{FC$fOM`{PJJ\<@`76tG``5|OGTgA+juq;y7Ip?6}`I5.`zD^g-DP5.z7;q9d67.``<br7=K)YgkyG97Tg~/``nTj/osv_Tgr.``z$%.Ii|g``J/RYItmK``-g``;o8J
::C$fOm`8N``5I4]/do/[DZ;^.diu7C`,G{`5YXXu6].!5~FM`zDBH_5Y-afWzuz``Xd4`rBzn``5Z7`7;5`764C``J/@n/2vi``NT7`^-(<)KB`{j\Vmi}LQD``k~5`Xi|.
::?gh7|Uv\(*)KcX7`\mf`76XXG6Gi``5^J.diczah!$PUAc+q^dp|.KHn+PDj1W/b=Z*_Fj8&@7\<>/``nT[7oszP76G#m`3;>.-D%7@a2|f5C$y`5Yi.``5|qf~D@`{j\V
::F`Tg~/``nT-5os\eTgcHah#b(fpzf`{j\VT`Tg6}5Y~C``/dM`)KFUi`jf{`,#27``})w7bj7`)K)YgkyGh7tKp_+zr{pb;J{%yh15````6.-D)i</%1e5Kgi6``DW~Pox
::9}``%```p|7`Tgljf5P/B`>;3F7YW<ah2bqf86+qW_M}o.&2I```J.4YH;&`DK\P7`q|GYH~]n``a```<b5`zDxa9}Y|N_zPljf5X2<_+hV%yh#*lL1;IP76mjMaBb{izD
::_34.3;cGC$yW/`9wJi\<>/``nT39osU9t/s`SaEy{`5YXX&61DA6rm+-76i.}~ji|9t/s`SaQql/BR1iZ7`TVjXHVkdY1Dx$vJ{%yh15``5Y.KEMV_+sSy#5J.7k7`+~A`
::TA9DVYB+rDq;1~Xip@5`qWu7Tg>/``nT={osR,/6!`SaQqw.Tih/}`+`<b(Xi,Ci};>`.8FA6K*#=~e|>/}/TyU`Wf5;/2E/``*?1ijiO-H-~b)d.8z$)Kb#b/~1{`5YXX
::96fg*7~F,?XY77|Uv\PUnct3%dQ;o.&2PsKsSyQ4E-j_cuw8Z];o|_``UJ16H;oD-Yw(rD3;z.Zi;m[G+)0oXH2J*7uWGYHEFs7Y0X7`bjqfcX9;u`!SP<J.pJ``fgJ7uF
::6j7Y]}k.ji|9H6%^`YArYfpDo3d`4~865&Ea9}l>]_zPVZu`c`6.2>idzD9?n`7,f`76XX&6euA`AA=9H6~!m`3;y7Ip1$``vCLj/27RGYi.Paki|9&/s`SaEy{`5YXX&6
::eu2/5IB]fY#6BP#b|5--G+ju(|Rad$q_l1XlQ4CL[jT/Sd;7sBC```P2WbBbbUgD$a0`y_#5\.^_Q`U=&`jiXDVYnC.`#(p5Tgfk\5Y|l7mKI_|5+~>cuF^)WD.}n`H;A`
::``<zh7%h4`5IMK}Y#6+cY-|5--=i``TTy7C$wa8`j3O_+hFD76yXG5nA3```7/P5aey7C$8a8`c/72(Xoi$D15{`,8W*~D;xOn6on_7YM65`,n]C\<6jT`GTw5nAi$56?X
::Y_Ar(f.XSYq`)A\_zPtj@}c/Tq(XLq7Y_I)wjixCp-m5n`z$w.tXMC7Yh^BzJ.?Y5YaYah#bVs7YJ+juq;5IXi_b__1,x7}Lt{C7,s}6H~+.7`0X7`,#Sp)Kn5}`7w7,J.
::_uc`V~S`Gs3```7/P5(94`rBhj~`Z7y$_i!,d6t\W_Ar`g^Dg+.6V^%.?iQO0}+)P<^.3T7YQC.`zDJi[Dhnu`5|(fgD(Pjuq;y7Ip1$``vCLj/2T65Yi.Ziji|9I6~!(5
::Y-|5--*Y5`,n<|=<IZJ.~Vsi(X5N}Y=~>{Y-a*^D#7`Y8I`KC$S/3`+``Dd?j;5YgN$`5I}`5YIX&6eu%`AA=9o6~!m`3;y7IpG/``-fLj/27RGYi.Xdji|9O/s`SaEy}`
::5YIX&6eu2/5IB]V5Z7UPZ;^.diczah#bPUmK2_8-zpdKC$6W|/@q/b?HFUg]SG````F`)KKDb.(M9776a5~/E|usriju``[7``5^d`5Yy07Y*T%_`62Ug]SG````P_w.mj
::4Qbb{izDo3juq|BPKisb``%qi`uFR156fkM`>jC`76VFP`)Ah7U<jj7Yv/S`Gs7`Tg)k*4&|uiU5UPDj1W/b+ZVkq7VW,lto%_@5*8;CuF(NvPA(t`Y-n```rz;78Nl7)K
::.`76^![DH;lDRYkWju3;y7IpG/``-f@d}2Ij``%`|Uv\n```&~!ARC7`<Pbg=Dhnu`5|}d7X(Pw7zp17)KTW``,2v`5ITi$D15[/L@u```,/&5aey7C$\DUGRCtX\<-DKN
::4}Hd,#1```ICl.\]\5)Kb6b.+)BzJ.f6gkyG(Mdb8```L)pfbjb.Tgo7C66ot/Ii{YgkyGi{<P3Qd`dX``@ambMKn5}`7wx7b._uC7RCRYIt,e/`Hi``V%Z|G$}75`z{@+
::q<6r~`Z7*PbE$#7`p.``G9Kq.LHY5Yi.fBjiR,,6!`SaEy>076F5``-fmW/2T65Yi.a4YiR,,6!`SaEyvS76F5``-fmW/2T65Yi.#3YiR,,6!`SaEyGy76F5``-fmW/2T6
::5Yi.U-jiR,,6!`SaEyOl76F5``-fmW/2T65Yi.GckiR,,6!`SaEy^R76F5``-fmW/2T65Yi.]ijiR,,6!`SaEyyh76F5``-fmW/2T65Yi.hY#bBCLD@`{j\VnuzDA7``I-
::d]~FJD76i.DYY-BCLD@`{j\VS$zDA7``I-d]~FJD76i.1KjiR,,6!`SaEy*?76F5``-fmW/2T65Yi.PPjiR,,6!`SaEy!T76F5``-fmW/2T65Yi.NgkiR,,6!`SaEy>X76
::F5``-fmW/2T65Yi.[.jiR,,6!`SaEyvD76F5``-fmW/2T65Yi.NgjiR,,6!`SaEyG976F5``-fmW/2T65Yi.[.kiR,,6!`SaEyfV76F5``-fmW/2T65Yi.YUjiR,,6!`Sa
::EyFu76F5``-fmW/2T65Yi.]ikiR,,6!`SaEyr7TgF5``-fp7}2rDKNt*#9\mf^HYLmBDlIg2zD[s``x75`76IXB6eu1`5^G$r<#6HnY-|5--G+c`L}5`76IXB6eu1`5^G$
::Q6#6HnY-|5--r`n`I57`<Pbg=Dhnu`5|}dGX(PT}6oy7IpHid`I57`<Pbg=Dhnu`5|}d^D(PT}6oy7Ip.O``Z^R`5I9)76yX``@a$${KB`{jtWP`Tg4```L)pfbjb.Tgo7
::[A6ot/Ii{YgkyG)`-|Y$76ER}`/dn```rzt7%h4`5IMKV5Z7ncji^.diczd`,G}`5YIXB6eu1`5^G$Q<#6HnY-|5--r`7`I57`<Pbg=Dhnu`5|}dWD(PT}6oy7Ip!Dd`Z^
::S`5I^,76yX``@a$${KB`{j\V9ji&&z@zIG7N+t*/5Y{IG`lIz$K+Vu5`_6^`TgH95Y!Bd`7;N_7YB.``G9H/CLu6gkyGg]L=tXM+bH7POmgg|5Ao``lIEbzD-D``x75`76
::IXe6].c6It@6HYx)o.k/}qeP2dAgV^-TXifn``qY``pU;KAgh7|Uv\w[``[5OX,@sj`M8Ln5UY.PFm*i\5Ao``lI$yzD2d``x75`76IXe6].c6It?T/`liw.>ZB3/=4Klr
::_7ddfRu/-DG;]CJ.ok-;Uzl7RK3kp$;sF7a+o}``|17`<b`776uWNr4~254g1Dd`fnV`dbu```,/O5(94`rBFYQDXKzhh,+Dpzp[y`Y5u`zD|s-;gFrC\<Ct``DI``@az$
::{KB`{j\V9ji&&z@zIG7N+tMX^.F-``pL[>76I%5`~~>.UDzsfb&/25+gN-f`N55k~;f#CYJ6z_F;H|zD<X/`ld5`76IXe6].c6It@6UM5?DD^^/|aJKiDYWz}`CBeZn`zK
::46ubLN/d2o}`/d)iBzG(rDyL3%XiSg|__|XTJ.kQ(_6qs$\<s5}`0X``@a$${KB`{j\V9ji&&z@zIG7N+tMX^.F-``pLt;56ti.`z$~`zDS7``I-d]~FJD76i.GcjiR,,6
::t\C`z$y5)K)YgkyGN`-|1```ICP.=k}5)K)YgkE{g]btVI}7KBeYpLXr76}=sU!$n75Y=5``-fmW/2T65Yi.96kiR,,6!`SaEyf5TgF5``-fp7}26S5Yq`|Uv\UU^PRCb<
::_7/WUh3/{Kf|bCJ.[Nd`gv7`C$u```,/&5aey7C$\Dr}RC1+\<-DKN4}1`oyu```,/O5SNV7C$C6gkyGL/<PeY9$5?DD^^G|T6hgT0k/yo{+1C76V^j)Xi&_V`k}r`5IB7
::``hi``V%Z|G$}75`z{^RY<6r~`Z7*PbE$G76Hi``V%ddf$D\7`J/RYIt@6HYx)o.k/7.Tgx;`$1~KiVRWw,`<Odn\<47``eD``@ambMKn5}`7wx7!._uC7RCRYIteM5YHi
::``V%ddf$6W7`J/RYIt@6HYx)o.k/h.Tgx;`$1~KiVRWwc`<ONG\<]TEunX7`C$u```,/&5aey7C$\D]5RC1+\<-DKN4}I`oyu```,/O5SN%7C$C6gkyGO`xh]X76yXqf,M
::1#.BSJ+uk/$${+1C76V^=;XihM/`@4m7vpW[``g(@hEKyDIgH36S<b$itK+q^dp|.KQn+PDj1WrDVKoE`v<q`@`VdE`vs```5Y.KLMlW|/Rq?pB-*_Xq8&@7\<__1`|xt`
::2bfiG6m7}`Xd9ob.]I`Y0A)F\<__>}$)Xy(XYNGY0<*nY-qfBz~Uk_e27#C$C/``-fODV~a```}K)b/>>nTg+u.*]x^UFuDM!t)@Vg}L|l(YmJc6~mT/5YI`2UKyF)ltV/
::W;R55`76IXM6_?{6~mXi$DUTT.AAfczD4\m`ld``C$(z+$|C1X\<[;0#%-``pU|.0gh7|Uv\<h,KKCFu8Fr;d$ym3uFA?sQ)I,``_/fYDb/|&lz,7w<Zn```rz]7MDh7=<
::DIh,./LB(XCNCYh7|Uv\ti``;qC`v.6N@=IB76!v&`nA1#.BSJ(},8.q)x3#J5r[1WCy=O5`=?c}vpfG5Y[tCS/)7;76LE{7.8`gzD)C``fe4`;~+```L)iibj;}``l`}`
::lS&35S*]AnO7*PbE6DG6ZWj!tb$itK+q^dp|.Krn+PDj1W%eNc?i%9xh<;@?f_W`>e!r=K%PQUeWm`6o{`5YrTB$C{&`H;XDVYsm``x;,`}L)5``,o89osKizD>5-nY-qf
::/<%`{jtWZxJ.-.``D@6Y&VPy764kt7P0JW6D7E253o{`5Y6Tg`GT``@a(<{K&6#K%x}`5YNo%Rc/c6ItCd5Y4zu6#bqfBzkW`Ye2/`zDS7``I-Zz~Fd=Sdt}4`5|qfBz%`
::{jvwVjXH-k1/4&v1/Iskt<4/Q6%t]NaesErv=K6DzzWWA.0b{izD5Cy7z$`KXiC/``-fr}/2}_y7Ot46nbLNy7~$k.jiq9d65-B/Y-5`)KKYgkyGo7dbajC6%k3`]Ol,``
::>C``G94B.Lu6gkyG7`<P^iUDhnf`7;t`Xi*```J}>c(Xoi$DUT``@aSpVK>3d`&/4`rBp`zDHTC`IVZvTg-C``ox/)J.7R``eV(}~FfKldK;/~/Wos`6c?f`~1``C$-_&Y
::fkVXjX-N_DK*lLEKf94u(!%ODjDiXXNk85e|*.Xi7/4`J/`dvpx```e5+4.>G```MLnY1D8YH;a9.60>l}Y-W*~D#7``zV4`rB_jC6%k7`]O^-c,B67`p$``C$|7``d>!5
::~FQV``-$d`]mJ7fRni,KE{I`TgTZ``AP7YOucQzDXWA.<bDiXXo3!.b]o.&2ci!nDW7U7a`%7exe7a`%7e7UiD|<sU`6Y5F(3f=KwD76})|57;`gzD)C``G9mG}Lqj\5P&
::OX\<*jT`/fRdji.`TgL`{j\V|u}LL.``N5Zzs39}``%```p|7`Tg4```L)bibjafHDG7u`zVe5Bgi6gkQ8Z]5IY__.C{yziO9%yh#*lL1;IP76__*n<#PUHDRkd`+)5`76
::IX{6eu8.5IE]$Y!```zV4`rBp```L)Dfbjh1TgPPc56oy7IpG/``KNUDh~+```L)iibjG```$>g!l>|5\<lifYK5Zi_i^.di0)``V%4)C$<FP`)AZ5<Pu`768/Zi_iYy``
::D`{j\V}})KCd``+{&D(XJ]<D.K``@au/C?;xjuq;5`C$H`5YU=j_Ou-,Tg^C;J/;yh)KKp/`TLa)J.>-``6<``pUE.{Z%^fO1G2CzDpg`Y8I4uC$$/``#9*iy~@`0LtGm`
::7;4C<DP>`Y8I4uC$#Re`FK=_zP>/``7Qku7)!,d6s#/`<b;GF5|ONrW$1n}LX!7Y0AU`aX}|5YLKY__Vn```rz}Y].n5~FIi$D15``7;PUmK2_?}<p|uC$!sHC=$^5[l6`
::``gk7Y7YcC1`````xh*.UP=_^NO=&`jic```,/_`0_p5Tgi6gk(th7tK,`76yX``@amb$KB`{jvwVjXH[jA7(f;7sBC```Xi``V%nLG$hY*]yG````{DbUH_!.z#PUHDRk
::d`+)f`76TXhz_?&`H;^.di(!m`q|B7Tg./``-f+0/2rDKN8H``pU;Kvgh7|Uv\``)KNf``qY``pU\-AgcHu6#bS7ogn+N76oy7IpG/``-f)O/2SifYK5k.ji^.di0)``Mj
::y7\,h/``-frF/2Iju`Z7*PbE^.76D)``Mjy7[,h/``-frF/2Iju`Z7*PbEi5``7+juq;P/76kUNrwyVj}Lj_ki)A<;JTwa|er9x$4^-N6YIU3I0bBh#DRkfj[|*.XiT$``
::X\l6\<w_``)^[DH;oDRY$aju3;Z.BDAjG$W$@/zD~7``qfCB9TS```!K`C\]w.lXXYgkyGh7db/|7Yt~5`xh.C,H.JG`L1g}Tg@p5`,ns`,#x776yXM`.8n```>z4Y].c6
::Itl```_7=e~o}`5YoX46]./ouFU]nni,[DZ;F9</t54`7y[oXi{YgkyG]C\<T+``P5``7;)`76=5``y8FDN~{g``HT6]osa9{}L>QD|bsf/<lxMK(|w.lX`OhpW$4`rB\_
::}ztZY&/^^NtXsErv7;9D<RWY]a&q.KgMlWi`MPZ]S?|_``QEt`2biiG6+qC`\mt5zD$d``}{4P/TG?zDHTD`IVo;uKKC.`(m5`76oX16].c6Iti!&DW_n`^qs}5Ya5``,G
::Y.}2gr}`Z7[DZ;^.diu7}`vZy7)KOhJixJMW`6lVxY].``5^D$76#G``</{`5YXXwzGiB`Z;|9&/s`SaQqRa6nlWi`8N<;^Twa|er9pb8^qNvPA(t`Y-A```J~.hRC3`~F
::%N``VJi`$Zk/76./``,Gk]/2rDKN8H.o~Fb)5Y&5n`p$}`5YoXx6].S`osG$56!`SaEyx7TgF5``,G#n}2X`.6i.``7;}LzD@`{jtW+7^-m`5Yk$``/dA```<zk5jfh7tK
::>DKN[[#e;J%N_P[7[PPE7```wsikSyVj=Z*_7`V~5`Xi.C,H.JG`L1>.zD?$5`?<e`,#$!BDDo{`bj$/K+t7/`ld5`76oX16].c6Iti!&DW_n`^qi55YpN5`)n``5If#k.
::C_<)Gsi`5Yn$``vC=m.2IjC$P/c6It(N/+?*F;EKf94uu7``76.KEMV_>kSy#5J.)d``u~efHF<N``s`SaEyY5Tg)$``nAl6d~VZ76dHT`L@}@1gg).`bt^$n$$/7`jd7`
::zDbgQDP5*PbEL,ob~N}`;w>/~K2@<739``}L2_}zr{pb;J{%yh15``5Y.KgMlWi`MPZ]S?|_``UJt`2b)iG6/y.`vS|7zD$d``}{4P/TG?zDHTu`IVo;uK;>/`\mz}.Lnx
::``k~``Tgv#tgh7|Uv\~AuKND5`m]~`TguZl6O_w`o\,5``9```,2``)Kx7``})3obj(fUz_PrDq;y7IpX_m}tyyn}LqjT/Sd;7sBWkKAUtuQQJ^NUYG36S0bBNUD!pbK8;
::ON<iV_+sSy#5J.XWi5Jcu}vpYj/dG*r7Qoi,</]1a5jiY9Wz[!wavjSo^-s;(QAT=zXi23!hUBf7f<xz}Y]bV`pdId/6.Jah@2i}@n=CV`OJ|`Ct9;n`GThY@2N}@n7dV`
::OJ|`dt,;n`GTUPpL?n!u5$@`8o{`5YKT~uwbz&1O<KzDfQt`2bti5Y{W/`mM;7Tg5JR6O_MYK\5M``U.}/=kL7ZR&Y7`Uz``Tgv#tgh7|Uv\FAuKND5`m]67zDtVmYfgF`
::kgH|769JC`p$]j7Y5Fu#jbe5|gBaph]dh7lKQ+`Yt~``Tg;KtgRz$7bj|5--r```TZ7`)Kb]<DDo7`^-Q3vKi#tgq;N.*XxF-PW$P5pgWajv_;h7tKTjp$P/c6It(Nl+u!
::`[7;;DBg]\Im<big<c]6]aBy````FkKAUtuQQJ^NUYG3{7>jBNUD!pbK8;ON<iV_+sSy#5J.XWi5Jcu}vpYj/dG*r7Qoi,</]1a5jiY9WzE\wavjm$^-s;(QAT=zXi23!h
::UBf7f<8zCY]bV`pdId/6.Jah@2i}@n7dV`OJ|`Ct9;n`GThY@2N}@n7dV`U)f`76{T~u\r6VhOf?zD?^t`2b]d5YfL5`mM=`,#f!BDW_ZDK\Ii``U.``IVsj}Lu6gkyGd-
::/2Ko``@.G`H;}a7Y/p8-q;%.>X1OP4W$e5+gXhY_QC``5I<```o+X`(9f`76XX8z90&6Mb[]Ani,UPZ;F9O/.~0g#bqfpz%`{jvwVjoHqkmYUNLc/^-N_DK*3|QKf94u(!
::s$BbbUgD$aA,e|[Q@i6kl`4N`Lho4js/G]\GuF(N_eA(t`Y-Di~Di\Jf6ok?Xia3mK1A1CE)6LC$O04i\<jjPdt9pPIOBi<DP;gPxdKd/6.Ju6@2%}@n7df`OJ|`dt,;n`
::GTUPpLXn!uQ,@`8o^7DR(Ih`RCR7dtslmPngr7Qoi,{}]1a5jiY9WzI3wavjSo^-~K``E)2Yd~b?H\%-A`TAoD5YkW4.ld6.76k|/`(dK</2Ko]m!fZ`dbXb1gkN#hEqwn
::5Ya5``,Gk]/2rDKN8H.o~Fb)5Y4<n`p$,yC$z/.`jjb}\<vy``0X#_OuF9L}x~Si|b(fi<_P%0yL)q7Y7/``,G$w/2~rd6].c6It/`zDAM``</k?C$y$``vCk].2L_``0D
::[D*;W9{}_LsU!$WfWznpju(|w.&X\UfbW$4`rB`Yu`u(q*EKyDIgH36S<b$itK+q^dp|.Kxn+PDj1W/b4ZVkq7VW,lto%_@5Z{`I&J[]k7-9(}Gs%P6UeWm`6o<-;iQOi`
::WfR7.thX/6]b{YxdId/6.Jah@2G}@n7df`OJ|`Ct9;n`GThY@2%}@n=CV`OJ|`dt,;n`GTUPpLXn!u5$@`8o^7DR(Ih`RCR7dtslmPngr7Qo27``<?Aa7>Wo~G\#}`Iu25
::Tgd_S7[73`,#*?``XJq.bj$/hxt7}`ld5`76oX16].c6Iti!&DW_n`^qu/5YGMY_OFe5|gUapheVh7lKTj]m#c_k+h5`zD/V``</8uC$y$``vCZH.2qjrc6yB`*;a9}}L>
::BP!$sfUzB+tg@dw.lXXYgkQ8Z]^T%_y<G]Lc/^-N_DK*3|QKf94uu7````5`/2@ysdMWV6~E~m``8i^5,8XK5JXd9H]x#7C$yDjv(tA`TgUKy6dHC`L@^.76L/``</``C$
::(Ug]u]<;R?f_W`>e!r=KRP*6((L7>jPUD0Rkd`TFp5Ig<7``rHmM~F*N``W6G`\]y7IpG/``,GR6/2gr56].c6ItbN``IhI`btT{C$Eo``eWd.vpIj]mRZY_+he4``D)~`
::L10d76Gd~`RC]Xlt=```yJ8Gbj&C)KB`{j\Vq5)KWX.YV1+i&mj;zD.K;`?&T```H}``=E7`Tg*```AD84m][7zD]z>Y1Dsi(XP.768/n`5|qfUz%`{j\Vh\}Lu6gkyGzh
::/20`76+fn`5|4C~Dg+MKq;y7IpxOM`qwOX\<4=o6Giu`5^|9&/s`SaQqg{=5x$Y_Ym9*AzmLY_h5}`5IG```.```3bZ]^T^_G6fgY&/^^NtXsErv7;9D&RWY]a&q.KgMlW
::|/hyVj=Z*_7`V~5`XiiCb<t\m`q|o`C$L/``\zDDd?5==5~7[DZ;.k7Y[Y7`L}Z}J.ajTigFUm\<|P7Yf,``C$S`TgPPjuyLRa6nlW|/@q/boHFUg]SG````{DbUH_!.z#
::PUHDRkd`+)25TgdG``MWP`]O~D``U.``IVuZ}L5Xu`Adsi(X5`zD$7|Uv\n```>zo7MD}}}L9ju`Z7*PbEc```EYosJc7`zD},FDP54`Y-|5--Z6/`L}5`76oXt6].B`Z;
::^.diu7}`,G}`5YoXK6].``5^^.di@.7YAr4`76p```;c7`5^#9t//WA.<bDiXXo3%dQ;o.&2PsikSyVj^Z*_7`rjWi(XY]DYy_J-S$a3HD}qviq|\)Xi$/``@{*i6~XjC$
::g{7`5^V!7Y\`5`vS_,^.So``){5d~Fb.``&7``z$w.tXgX``zC7`zDbgBDP5[Dji^.diAJVdY-DDzDKC``IV-~.L,WS7,s``5I?`zD\^m`!kE5)K<7``ly``5Ii`zDL<u6
::#b``)KKYgkyGT`-|1```VCN5\]y7Ip.Ol`,r7`)K1```VCo/\]{aC$oYgkyGJ_Cb8```@)*dbjmlTg{`{jvwf%}Le?``T~``Tgv#hgRz{7bj|5--W,7`d?n`}L9jh,KA7`
::C$c```G/Z7(9!u}Lt`5YV`|Uv\n```>z@Y].V}~FB]VY!`SaEy}`5YoX<6].V}~FIi$DUT``,#SpcKV+*`(94`rBp```@)Nnbjqf,Kz`{jtW/b+ZVkq7VW,lto%_@5*8;C
::uF(NJeA(t`Y-n```>zaYO_jgpU>N``[kUMMj,iG60_P)gk``C$>D``&V7`5^J.di;|m`q|KGXi1R``&/``5IU7``hi$`z$`KXiC/``,GZH/2Rju`Z7hY#b|5--nXd`n!C`
::76n5``#x``,#o```8}``rH*.~F^)ldY/m`H;AU)KM7``XdE^.LSi``|7c6It]N``3=7`,G]]n$}7``qYX?~FIi$DUTwuos|9t/s`SaEyOmn$%OP`RCh71K>DKN4}>_W\D5
::76yX``,#SpcKV+rDq;y7Ip.ONrVIVj?HX_MYfgY&/^^NtXsErv7;9D&RWY]aBy````Fki]UtuQQJ^NUYH_9$z#PUHDRkd`+)5`76oX%6*h46dbC`zD]Y``Xd4`rBWk``d_
::>`DBC75Yf```MW7`C$>0-D8gO`~1}`5YoXz6Gisi(XJ]BC)^``7;|5--nX}`rH.`76n5``#x``,#cr{K@zS[~ok!Ii{YgkyGu`-|j]HD?^7`7;]dzD)Cs/=kw.TikUNrW$
::4`rBvg7Ycz``Tg\-lgRzah#b|5--G+rDyLRad$q_.ITF?pnLVkq7Vw<;bTwa|e4}````ig,0+q^de|dKXiK_+sSy#5J.z7``rHKK~Fe]1`^7``z$?m5Y4/``|7c6It]N``
::E?S`bt}`5YoXE6UN7`Tgcus*!`SaEy}`5YoX~6908`ji(5zDQ}<P7;o\xUo7``zVe5Bgi6gkSZl7)Kvx7`NT``,#Q3$K6/``5WvWBMF0@jJch71KTjh,P/c6It?g``Hi``
::L@SzJ,h/``,GlS/2rDKN8H``TgE.LZw,``L@J7n$hYgkyGo7Tgx```@)=nbjsf76B}``7w7`}LrjC$Y$``5^/`Tgn+juq;y7Ip!W/`Y|p`,#R```VCc/=k``C$56gkyG7`
::zD^iPD-.k.ji|9O/s`SaEy}`5YoX<6].4YZ;^.diAJO`r[L7XiKWIjv55`76oXL61D``C^}`Tg!+rDq;w.tXXYgkyG7`zD^ixDP5UPr;^.dicz0g!$PUnc$a0`SNQ4CL[j
::Q}Sd;7sB!5V5d_|<m`1```O.+5(9y7AR,`````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::````````````````````````````````````````````````````````````l0VG``````GrL```````=J7`````)K9G``````*]L```````6J7`````76MG``````yhL`
::``````Rg7`````pUcG``````gTL```````ag7`````XiuG``````C$L```````*g7`````)K$G````````````````G#``````44w}``````IRo```````%2``````,#%}
::``````l0o`````5Y*2``````Tg]}``````NNo`````5Yx2``````V%N}``````yHo`````5Y(2``````&M6}``````vZo`````5Yd!``````zDz}``````Xbo`````5Y{!
::``````|5<}```````4o`````5Y@!``````|5~}``````Gxo```````~!``````@a~}``````-|o```````B!``````dbH}``````SUo`````5Y|!``````l0-}``````%q
::o```````j!``````;o>}``````ljo```````````````[G{5``````}E)`````7692``````5Y{5``````^^)`````5YLl``````(X{5``````;J)```````@l````````
::f7``````(?C`````<PNl``````a+M5``````$Z)`````5Y0l``````V%M5``````=L)`````````````````n`,#c61/ji5`mlHDE`[o``bmSzGYI/``)5LaXiq`76p`^f
::9Hf`^-n`v7bt7`bt<Dv`&m``Qcvp}6.}``c/aaTg/75YW`Tu]m)`J.c6.}im/`SzTi77g!``#rTil`^G``VC]O<D65``f7%%TgJ`zDS`?.btd`Xizn``os``,#.7``]i``
::M/fRED35``?D+=,#3`zD.7>?&M9`J.$YB7WB5`<Pi5``Wv``+{T`5Yj7``@z7`9HD`76.c``r35`q%J.D`a1``gTT`<Pu}``(5y8zDC776a`gfQJT`)KiYk`I-7`j]J.i`
::8c``!}%R56%}``Z7%%<Pi7``;+``IV,```o}``(\``cQ~`76+G``1nC`,#D77687`NXi^`Tg)`E5NKd`xhI}``?(``[#~`76bf``TC%V!U45``h<7`;ot`,#T6C}``````
::``xhP]T[\k1Uv}{6}Qs_SE0;`R%k)gH)g4[txQk)dfM0wD2C(kO*>VFmp]VB{;e6;-Ln2LV#Q6CY0h<~pqdc\diSt?lgU=tW;;l_D+hT?gLiZ-Cr/r\Z},uRfGva\[]Kd@
::.t\]JkH~Y*QH1$efh=jZPs~vqiljweeZ$c<WO123W+9W@.B80ckQ#9c1|$nTM>/A{OBQ/Sl1%{0oLY@1r*VE{)!oAe<)8^eHewF$2EJQ(cR8FDw%!0N<5yRH70DN>b)H~z
::Y?9!%VX]6zf3m8I}J<b+]-G~PlI>4Z5{H8tEospxH,hO)39XXKC11Yj|_mX#d+MFGf$~_Wg$D=EN5lhP2=?[LE8Z+=B@zFzHzB!+HoP.1H<~EfX41c9m>n^nH/&f/._*eK
::N;Zh0KYWIzp1CR`(,Uz3q](3b/s&EHv`Z8(W}^cE;&9W.F,/Y4i0Ee`wU2fvmof[h^]6hTP=CUc]2bAMITD~H9TjT.jf4quyrm]+$,d,35>UQ=)tCS>#LJE\k$.O_~z*K7
::>6CKK(Icb$w0BnG^siE{l(@H^KBOW>y&TwFD``&MN}``n```/&As4^v=_mHqQpCi=nKO````=K9KxVfS^~ghrH{VJs;U6U4A+4RrDi\x+X`)n%lr+&GIerK%69R@^FAzRD
::[,+4Z|V$^,QE;4VZ{4QTmThjj,|imc`X_KlclE)4hlFG%g4UB1@]w+BvyS[,gibef`r%(E0]7lXY*=|n$Z*f4;i#A7^k1US7tX|y%~}TP*2x?W$2b=QaUVV*1t|,bs6\1K
::OjfX}o)P|wS%CxH)vx4])Qff+~0UHav2wI|L4fRV\}!NWV`H9isTH}?.`f$t*DBq.6#_kvH_1Z=t&VD^M]V*8c6U~/H*i8)^{B,h<uo5]LmB*E&PL8V&(o%|;c5E.c+uXI
::!bS%i<FB!l7CDYm^=)q>L_.q__vRHLsqB{{Uu|YshIiG/6`,TOG<3|$2k^=L#%$nt-}<DA]>^@a$,Y#4d)-BL^Sbumt({5.^>PceJY=#8+C2vU4=g#9f.%dHK5=-mvadfT
::r;K#o1V\J}FW8u)>klHIQTCE$%p^83a&C;on0A.B+u@Vt1fLb<RR\&g&oeDn{Lp.ld|\uRA_~iZ]m*]kY1UR.rYl4TgH/y>McU{A)\!/.s|t$NhG7kK~$SFUJ=KRFdc9i2
::(y[)cVY3}c\u2TF\a%w1y]n+Ak}%*q`-.8w+~sD1<$XV4W?qm,f>/_om1C2i&DN7/r&0n^|cWxw]k>o.eCdpP0zbZWDPt9mT=PkrPPi%)+P>2t9^WovEg@58uRTpo(rBjP
::yS2N*lQV]n_QrArs-ogs6VENiQu,Ghh(PqgDiq0}jeWirm0s%~xM\N(M6}q^;ZOMV)z%-,c2(#UZ.~[#.(i155zHr$VIj1\~3jx4?=5CKf9])2nE;LWr?#VgQ[43]?.Ipc
::Xf[&<n)}n6lN@AjvgLZIidNW52+4qL&RTcwsVV^s0ay.uu&.q9Bg;IV+FTrx-0ce{gBEVZlt;b>el#HGv(}KtlO/#C_}H-#5jX*##EQ)8AQ/(&Nuy0o=Npa`v>ml3Q3GNp
::s}aGKvk}]a6~j}+uRi)I*L||4f{\csmV(H^x\G1;T7QApDd_.sDTN6[UK(qwaJ}T/|ruob@hY.f\;\`Lct(#@&Y^m=C=tk~mopZiE[VnW;}%XWpUeG7m$f|<S^&sJQy>R*
::{07c9>.z&Q]#X7olREiv7|E=+R(|_X[#czs8ztm*W5JBsZEjK.wA7J2d)D&cz#&csp-C$=mW,yA}@cO,U$RHG```/2kEhN]2f}````zDiMJ7````[7``zDc0fxu,b$7```
::766&SZ````A!````)EP)__k0i`````u~<7.```l0C```]<87cPQIJ7````J.%hq```5Y>```V%^C<jlZXD````)K9_&d````.G``5Y8%2-QC3D}`````aEN4````8[c```
::*{``I)Pr``````f~n5/```h[=```WZ``Dp!R5`````CC@x)```xhR/``````2?,5``````TT<d>```76>```kTMm44VFf`````76;25}````!a``````pUROz5``````9m
::iu````An````J-m}~;hD/`````Zp*u7```UZ7```f-90s_rzv`````j\#Cf```pU)```y8CzRN?e#}````pUxn37````T5``76J>`2T.7-5`````#791````{@````?csX
::\GV*c`````u~H//```&M/````F,V*hbEZ7````)K&A>```<PV##&g86~]p3Crj_~i{kr0$=_xNhISC8cfJ&{[A_D*H%SjQK<y}yZ6TdmLtSB;(LrMUTj*XBZ_/>]~Vwm!H
::fO=N.D(CLX++-\v[7```````)K5`)`r`,.\mC$7`nYI`L5(d}L``}6o`L5(d}L``.Y,`I7j/5I5Y56)`I7j/5I)Kn6D`|`If115Y7`C`T`.7(d}L``}6o`V5zC<P76C`-`
::````````l0C6L`S5rcfe2UuYJ```WCP2xhd6L`u5xcvp``}6T`.7````V%/6o`i79GJx)KnY)`~`$5sc````760`D5scQJph$Y-`G7Ana+<PC`````WCP2xhd6L`u5xcvp
::``}6T`X7````V%/6o`i79GJx)KnY)`~`V59c````760`D5scQJph$Y-`G7Anvp76C`````Md{+pUC`o`{7rG````xh)Y0`H7p$11Tin`w`<7uuIVTimYH`z5<MP22U,`>`
::-5uu11Ti,`*`V5<Mh[ph$`u`87p$l0phfY^`z5}{}L~P,`^`37xcvpphuYL`A5tMl0TiiYZ`)5fV}L7`}Yc`$76G/2``<Dc`;7FnJx)Kd`;`$7xGh[``~PM`97Vf[#@anY
::?`T7``````)K/6J`55zCP27```````?/d?wrHPX`x`!},wxhHDT`o79GCUpUC```````c,IVph)Y<`07yc,#Ti,`b`)5@{QJ2U,`*`*7tM,#og)`J`Z5.c3Q7`````\`l/
::c;Mj/6{`f7QG/2l0n6~`R5=)4456uY-`z5+{Sz56,```b7H,eI2Ui`@`(7=)J.7`````````\&FpfQfSV>.}9=R5````/]>ner>,i8UpGaf```Xi24Opi-DuUR~G``````
::S$[HQ~DAHAGZ5|aT~V%*e3]S0]b1%Q````````Xix41/,!KlHAGZhFr\E$kp,!h@}I4Gi|#whm````MdsxvT)8o8.!uAumBd``(6+r5|aT~V%*ZoQlf776YU#do8h8gm2S
::SJpt{=L^=c|zUHfSf7````````MdsxKV19=He3]SYR(n12Gd.MZ```76Hp)no8h8iSCS{m4GA<bx.M``````0?P>a.,|YF]82zpHec``A~{AUgD#ys?M[iT^k2sA-/~G?`
::``<PTl&G51;2aTOgSB<SC`G9phf`A`x73,|5<DiYw`77jiFu56G`````````eI7`.`{`O`q55Iwr/6i`+`t/eI``<PmYH`)5yc442U,YL`%54u,#ph)`g`````````)K/6
::J`o7zCP2ph,YV`~51u``````5YT`G7QG44``.Yi`~`559c````````X7Ifh[zDC`?`c7N}mlpU/6-`^5xc``````````\7&M<Pogn`E`-52ifeogmY0`$5^V44Tg)`E`{5
::````````76J`%5&MP2~PuYH`77xcpUog)`````?dpU5YHDc`;7Vfi<@ad6Z`P79cdb/Y.6*`A5|V4476)`Z`R5````````5Y)OhLC```L@````t7``r3<`5Y)C``{GydM`
::u```%n``<X=c##UJ\S``````{```G`5Yk#\d]8m>v5````E).`pU5`763U\d]8~`5Y1d``fR``uuz)>nH+``#sX`Tgd```rpEmaA;)+*)Ww,uV``zD7c``H.``11,oic.<
::7`pU~`zD.```L$vt[3)5``_+``o.``l0DG6+un@Co`````LR``.7``44JHDRn}8p)```5Y?c``E)``11|Tic.<*zC```76&c``CI``11|Tic.<fxC`````[G``~u``uu(/
::P1T```fe$`Tg}`5Y}xyMd```vp7`x.]5(Qx-RoisP`i<L0RY0C[`j71Xdsl|``3<97jvRpB).{f`86e576J.yiF~L{uF3W``x.]5(QmbHDdsN`y7X$5YJ.yio.Et=),r7`
::x.]5(Q`T39ds6`YV*aWHp]Yp!IS`Y6xiGRp}sImlS82])F|`_ycOFG-jrJZr=`j7~XV+rGOrvp|ALjDpi5@aPz-0)F)roXp}sImlS8o9Cz|TBB4>f6YD3-p]G`T!b]`Fsf
::xB4>f6YD3-}c@<%,ZB4139CAD`f5L0RY7)is]-q/``%z`;{Fr`{}$O4`()B7\dl/Xp`.````````[_7YDi````WfC`4```Xi````5```r3C75Y0R``#9)`pUZ55YU<7```
::R^%5M)##e3]S6C1GTUv4$nABx})KvJPn;2b\fBo8=/AnG7``````````%Rf7``eK``.h)```````````,6C`J.p7``Mx``````````5Y`y````.```````````````````
::``````````bd,`````76k#``````V%g}``````lXI```````\#``````76*}``````IVI`````5YE#``````)KL}``````8,I```````~#``````pUr}``````!nI`````
::``h#``````MjL}``````&/I```````````````pUo5``````GQ)`````76@2``````l0%}``````vSo```````>2``````;o]}``````q%o`````5Y82``````C$N}````
::``b<o`````5YO2``````|56}``````O>o`````5Y5!``````Mj6}``````QJo`````5Yu!``````vpz}``````CBo```````v!``````vp<}``````&Po`````5YN!````
::``76~}``````!!o```````E!``````xhH}``````==o```````2!``````C$-}``````93o`````5Yq!``````@a-}``````_so`````5Y.#````````````````AKC```
::``<PJl``````}L{5``````db)`````76u2``````3QA}``````6oo```````G2``````TgS}``````zDo`````5Y`2``````440}``````OMo```````qp``````J.0}``
::````~uo`````5Y|p````````````````nIu4[&h}4%``1LvSByb1U3``5V3F)nyM-`T{8QFH;ujRMz/`ws{j/[axbx]8O&k21V6Z/`Pdx4X=sxGr!QJ`76[Y~+aTC`Wv60
::6Bp#$Q)SL@WP`a8,HV+#T(>A``(iyh+>C*hU``D$Q=h\NBf+7`/*g]hu]S`&r}rc606B<Bk2,`SzYUkRq>Pn%F)K(6FH\SWAX7``K7+8X=Zq8,!QJ`dc8Qp#oujRMz/`vS
::$&+r33<X.MZ`3Qz60LOSE%~JSti~_l)B~Bi-EX.)5`!A8Mqn]ZWT^{^Lt$iS6A.tv2(7```7uLC4BK3EEli]=;M3Bv9M)^CQ)`J.mY|B}+F<iSEG.YkY0Lf.VAEG0=c38;
::icg`3Qdz#p^HQl<>K[?2yMJ^[&@?4%``98Dv!>P1H+R5f8+#MSaA``S^c;RJ{;,3Bvn{Pe5.5YW5lbaA|bC*t2aT,$PeJELAT7?*sHeTJ^D>m-El*/4G9=[d}`{+00#c<c
::/SWA@>L[]F``ATl^eTM)&LUH$`76.67yd}bnv2Uzi8kzSH5y8>LrysGd.Mv!ogxY0LOS9w3>arF3Uzi8kzy}``p/lbaA<>K[_64Ti8I!C.``j/lbaAuJLr33L5().ZE()Y
::3d&/9Aa/t=?l[;m9^`<P_`egIQDR-ZSH/|lM]{115O{RSJ4#]F%LS4wB{(>R9mPn;`35NKVxjwzgB#,!Ql<>K[?2yMQ$+es}5Yxd(bZA?m4G1bH,[Bm>56Q7k$b1_=eTtV
::QLIH)`J.WUN06AdLRUKv?8J`r.2iQLIHQli]!GA#Pxp4*pm2XRBZ&=F3``%-sHeTM)v^OSi0mmSd%F[dbc#sYhnSumFG5IfY>[axGMK8*p&bv%_85`K).6>[axGMK8*pv$
::9A~JBdvC3u}4t!w}MR%)/1o`XuCv%FBv)c`5pHu0$mLf``O/CCu|-5f8=HMSZAzDZP1F[d]8.X!(jR>ZE[9`)KZP1F[d]8Oo8Eu0tmSd%F[dbc``L1)EqpRQTRCV-1K2~z
::n6B.]/Ql]JuZt2^TC`q%00#cQdHusAs%vtHgqWNBI!C.5YAd)2hTIZSHwp3xC`443uG8u+g?JlXmd=t2OsyMBL?-uYm7wo4%6J2KU3MdI{dX2ITRV7XMi<,rpM?,#}c0<J
::);Rs``<Mi<,rpMh?%H~IA2L;AFo\C`sH3uG8u+i-*l~JL[@sMdI{L`,#$6&pv.WA_$9fS+H<,bUpHEmYc7wo4%6JOK,3!TGc.<56IY&pv.WAR>St[39<fB3gogIY&pv.WA
::|$+ryskTd`QJ3uG8u+F(*l[>>rJpr\C`+L3uG8u+RQpSe>Qf33``.ci<,rpM}5gm?w!>0=DUaT=c##=/``G7wo4%6J<K$3#,*4)u4mcYb/Ob1@kbarys<dC4BL}/xv``EK
::=K#{_Ct2K4|B&d.a)YK/Ob1@6RK[t22;t9y7<pkDVI<HN18x.M````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::0i``y7D5``}`````````````````````````|5````E```j\G`````5Y;``5c,4M~)C6~`S5rcfeog,```````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````Md{+pUC`o`{7rG``````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````zD)Y~`S5rcfeog,`````````````````
::````````````````````````````````````````````````````````````````````````````````````````````````````````````````````Md{+pUC`o`{7rG
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``zD)Y~`S5rcfeog,`````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::````````````````````Md{+pUC`o`{7rG````````````````````````````````````````````````````````````````````````````````````````````````
::````````````````````````````````````zD)Y~`S5rcfeog,```````````````````````````````````````````````````````````````````````````````
::````````````````````````````````````````````````````````````````31``C```Fu.5<P````?&i`{}````````````Tgf}767```h[z`An````O]7`~`````
::````````oyX`{}````_w7`T```5Y)5767`````````````O8``)```pUi}767```QJT`An````````````zD9n5Y7```y7<`An````I-7`~`````````````oyX`{}````
::v%7`T```5YM5767`````````````O8``)```pU)}767```L@o`An````````````zD9n5Y7```C$<`An````zZ7`~`````````````oyX`{}````p%7`T```76^}5Y7```
::``````````O8``)```pU,}767```gkI`An````````````zD9n5Y7```;o<`An````5e7`~```````````````````````````````Tg`7xh````v$YtguL20-zn>h<Q=[
::DC3[5`~```@a6%hZfb2+=K-3}j&tf9K)/}767```+}q\J0ZcAhRgFSX4_]V}J]i`f5``76m]puiMXn`LFPabwagtent1``C```]mRK4X?ijV!4GZ6!{<2is5z`An````xF
::I,L582#7kej}OrD|xm|4``)`````````````````````````````````````````````````````````````````````%5``D```V%-p#z@$9oY9;j3`g~=Ke-AzI$|z0$
::6oGTu$(6{d|JN)KidCg/sK<>SLfB#7N$Oon?60mJDd`^C$TX4iJ/};ALzES%\z-$NIh1f`````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
::``````````````````````````````````
:niblld:
');
