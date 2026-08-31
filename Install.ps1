<#
Revflip Network Policy Filter - One-line installer (v2, no GUI dependency)
Run as: iwr -useb <raw-url>/Install.ps1 | iex
Must be run from an elevated (Administrator) PowerShell window.
#>

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This must be run as Administrator. Right-click PowerShell -> Run as Administrator, then re-run this command." -ForegroundColor Red
    return
}

$REPO = "https://raw.githubusercontent.com/AliHusnain123/BlockSocialExension/main"
$InstallDir = "C:\ProgramData\RevflipExt"
$NssmDir = "$InstallDir\nssm"
$ExtensionId = "lcmgecogfadobkimnacpbfgdpimgccgk"

Write-Host "============================================"
Write-Host " Revflip Network Policy Filter - Install"
Write-Host "============================================"

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

Write-Host "`n[1/6] Excluding install folder from Windows Defender..."
try { Add-MpPreference -ExclusionPath $InstallDir -ErrorAction Stop; Write-Host "  Done." } catch { Write-Host "  (Could not set exclusion - continuing anyway)" }

Write-Host "`n[2/6] Installing extension files (Chrome, Edge, Brave) - no GUI, direct..."
try {
    Invoke-WebRequest -Uri "$REPO/extension.crx" -OutFile "$InstallDir\extension.crx" -UseBasicParsing -ErrorAction Stop
    Invoke-WebRequest -Uri "$REPO/update.xml" -OutFile "$InstallDir\update.xml" -UseBasicParsing -ErrorAction Stop
    Write-Host "  Downloaded extension.crx and update.xml."

    $policyValue = "$ExtensionId;file:///C:/ProgramData/RevflipExt/update.xml"
    $browserPaths = @{
        "Chrome" = "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"
        "Edge"   = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist"
        "Brave"  = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist"
    }
    foreach ($b in $browserPaths.Keys) {
        New-Item -Path $browserPaths[$b] -Force | Out-Null
        Set-ItemProperty -Path $browserPaths[$b] -Name "1" -Value $policyValue
        Write-Host "  $b policy set."
    }

    # VERIFY it actually took - read it back immediately, don't just assume
    $verify = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" -Name "1" -ErrorAction SilentlyContinue
    if ($verify."1" -eq $policyValue) {
        Write-Host "  VERIFIED: Chrome registry key confirmed present." -ForegroundColor Green
    } else {
        Write-Host "  WARNING: Chrome registry key did NOT verify - something blocked the write." -ForegroundColor Red
    }
}
catch {
    Write-Host "  ERROR installing extension: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n[3/6] Downloading browser-cleanup scripts..."
Invoke-WebRequest -Uri "$REPO/Remove-BlockedBrowsers.ps1" -OutFile "$InstallDir\Remove-BlockedBrowsers.ps1" -UseBasicParsing
Invoke-WebRequest -Uri "$REPO/Remove-BlockedBrowsers-Loop.ps1" -OutFile "$InstallDir\Remove-BlockedBrowsers-Loop.ps1" -UseBasicParsing

if (-not (Test-Path "$InstallDir\Remove-BlockedBrowsers.ps1")) {
    Write-Host "ERROR: Failed to download cleanup script. Check network/GitHub access." -ForegroundColor Red
    return
}
Write-Host "  VERIFIED: Remove-BlockedBrowsers.ps1 exists on disk: $(Test-Path "$InstallDir\Remove-BlockedBrowsers.ps1")" -ForegroundColor Green

Write-Host "`n[4/6] Cleaning up any old Scheduled Task from a previous attempt..."
schtasks /Delete /TN "RevflipBrowserCleanup" /F 2>$null | Out-Null

Write-Host "`n[5/6] Downloading NSSM and registering the background service..."
$existingNssm = Get-ChildItem -Path $NssmDir -Filter "nssm.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($existingNssm) {
    & $existingNssm.FullName stop RevflipBrowserGuard 2>$null | Out-Null
    & $existingNssm.FullName remove RevflipBrowserGuard confirm 2>$null | Out-Null
    Start-Sleep -Seconds 1
}

New-Item -ItemType Directory -Path $NssmDir -Force | Out-Null
Invoke-WebRequest -Uri "https://nssm.cc/release/nssm-2.24.zip" -OutFile "$InstallDir\nssm.zip" -UseBasicParsing
Expand-Archive -Path "$InstallDir\nssm.zip" -DestinationPath $NssmDir -Force -ErrorAction SilentlyContinue

$NssmExe = "$NssmDir\nssm-2.24\win64\nssm.exe"
if (-not (Test-Path $NssmExe)) { $NssmExe = "$NssmDir\nssm-2.24\win32\nssm.exe" }

if (Test-Path $NssmExe) {
    & $NssmExe install RevflipBrowserGuard powershell.exe 2>$null | Out-Null
    & $NssmExe set RevflipBrowserGuard AppParameters "-NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\Remove-BlockedBrowsers-Loop.ps1`""
    & $NssmExe set RevflipBrowserGuard Start SERVICE_AUTO_START
    & $NssmExe set RevflipBrowserGuard AppStdout "$InstallDir\service-stdout.log"
    & $NssmExe set RevflipBrowserGuard AppStderr "$InstallDir\service-stderr.log"
    & $NssmExe start RevflipBrowserGuard

    Start-Sleep -Seconds 2
    $svc = Get-Service -Name RevflipBrowserGuard -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq "Running") {
        Write-Host "  VERIFIED: Service is RUNNING." -ForegroundColor Green
    } else {
        Write-Host "  WARNING: Service status is '$($svc.Status)' - NOT confirmed running." -ForegroundColor Red
    }
} else {
    Write-Host "  ERROR: NSSM executable not found after extraction - service NOT installed." -ForegroundColor Red
}

Write-Host "`n[6/6] Running an initial cleanup pass now (visible output below)..."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$InstallDir\Remove-BlockedBrowsers.ps1"
Write-Host "`n--- Cleanup log contents ---"
Get-Content "$InstallDir\browser-cleanup.log" -Tail 15 -ErrorAction SilentlyContinue

Write-Host "`n============================================"
Write-Host " Installation complete. Review the VERIFIED/"
Write-Host " WARNING lines above for the real status."
Write-Host "============================================"
