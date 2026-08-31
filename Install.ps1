<#
Revflip Network Policy Filter - One-line installer
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

Write-Host "============================================"
Write-Host " Revflip Network Policy Filter - Install"
Write-Host "============================================"

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

Write-Host "`n[1/6] Excluding install folder from Windows Defender..."
try { Add-MpPreference -ExclusionPath $InstallDir -ErrorAction Stop } catch { Write-Host "  (Could not set exclusion - continuing anyway)" }

Write-Host "`n[2/6] Installing extension (Chrome, Edge, Brave)..."
Invoke-Expression (Invoke-WebRequest -Uri "$REPO/Deploy-RevflipFilter.ps1" -UseBasicParsing).Content

Write-Host "`n[3/6] Downloading browser-cleanup scripts..."
Invoke-WebRequest -Uri "$REPO/Remove-BlockedBrowsers.ps1" -OutFile "$InstallDir\Remove-BlockedBrowsers.ps1" -UseBasicParsing
Invoke-WebRequest -Uri "$REPO/Remove-BlockedBrowsers-Loop.ps1" -OutFile "$InstallDir\Remove-BlockedBrowsers-Loop.ps1" -UseBasicParsing

if (-not (Test-Path "$InstallDir\Remove-BlockedBrowsers.ps1")) {
    Write-Host "ERROR: Failed to download cleanup script. Check network/GitHub access." -ForegroundColor Red
    return
}

Write-Host "`n[4/6] Cleaning up any old Scheduled Task from a previous attempt..."
schtasks /Delete /TN "RevflipBrowserCleanup" /F 2>$null | Out-Null

Write-Host "`n[5/6] Downloading NSSM and registering the background service..."

# If a previous install already has the service running, stop it first so the
# NSSM binary isn't locked in memory (re-running this installer on an already-
# set-up host would otherwise fail to overwrite nssm.exe with a harmless-but-
# scary permission error).
$existingNssm = Get-ChildItem -Path $NssmDir -Filter "nssm.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($existingNssm) {
    & $existingNssm.FullName stop RevflipBrowserGuard 2>$null | Out-Null
    & $existingNssm.FullName remove RevflipBrowserGuard confirm 2>$null | Out-Null
    Start-Sleep -Seconds 1
}
Remove-Item -Path $NssmDir -Recurse -Force -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Path $NssmDir -Force | Out-Null
Invoke-WebRequest -Uri "https://nssm.cc/release/nssm-2.24.zip" -OutFile "$InstallDir\nssm.zip" -UseBasicParsing
Expand-Archive -Path "$InstallDir\nssm.zip" -DestinationPath $NssmDir -Force

$NssmExe = "$NssmDir\nssm-2.24\win64\nssm.exe"
if (-not (Test-Path $NssmExe)) { $NssmExe = "$NssmDir\nssm-2.24\win32\nssm.exe" }

if (Test-Path $NssmExe) {
    & $NssmExe stop RevflipBrowserGuard 2>$null | Out-Null
    & $NssmExe remove RevflipBrowserGuard confirm 2>$null | Out-Null
    & $NssmExe install RevflipBrowserGuard powershell.exe
    & $NssmExe set RevflipBrowserGuard AppParameters "-NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\Remove-BlockedBrowsers-Loop.ps1`""
    & $NssmExe set RevflipBrowserGuard Start SERVICE_AUTO_START
    & $NssmExe set RevflipBrowserGuard AppStdout "$InstallDir\service-stdout.log"
    & $NssmExe set RevflipBrowserGuard AppStderr "$InstallDir\service-stderr.log"
    & $NssmExe start RevflipBrowserGuard
    Write-Host "  Service 'RevflipBrowserGuard' installed and started (checks every 5 min)."
} else {
    Write-Host "  WARNING: NSSM download/extract failed - service not installed." -ForegroundColor Yellow
}

Write-Host "`n[6/6] Running an initial cleanup pass now..."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$InstallDir\Remove-BlockedBrowsers.ps1"

Write-Host "`n============================================"
Write-Host " Installation complete."
Write-Host "============================================"
