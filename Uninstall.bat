@echo off
:: Revflip Network Policy Filter - Uninstaller
:: Double-click this file. It will request admin rights and remove the extension + policy.

net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo ============================================
echo  Revflip Network Policy Filter - Uninstall
echo ============================================
echo.

echo [1/5] Removing browser force-install policies (Chrome, Edge, Brave, Opera)...
powershell -NoProfile -Command "Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist' -Name '1' -ErrorAction SilentlyContinue; Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist' -Name '1' -ErrorAction SilentlyContinue; Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist' -Name '1' -ErrorAction SilentlyContinue; Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Opera Software\Opera Stable\ExtensionInstallForcelist' -Name '1' -ErrorAction SilentlyContinue"

echo [2/5] Removing the browser-cleanup scheduled task...
schtasks /Delete /TN "RevflipBrowserCleanup" /F >nul 2>&1

echo [3/5] Closing all browsers so policy changes take effect...
taskkill /IM chrome.exe /F >nul 2>&1
taskkill /IM msedge.exe /F >nul 2>&1
taskkill /IM brave.exe /F >nul 2>&1
taskkill /IM opera.exe /F >nul 2>&1

echo [4/5] Removing installed extension files...
if exist "C:\ProgramData\RevflipExt" (
    rmdir /S /Q "C:\ProgramData\RevflipExt"
)

echo [5/5] Checking for MSI-based install record...
powershell -NoProfile -Command "$app = Get-CimInstance -Class Win32_Product -Filter \"Name='Revflip Network Policy Filter'\" -ErrorAction SilentlyContinue; if ($app) { $app.Uninstall() | Out-Null; Write-Host 'MSI install record removed.' } else { Write-Host 'No MSI install record found (installed via script - already cleaned above).' }"

echo.
echo ============================================
echo  Uninstall complete.
echo  Chrome will no longer force-install or lock
echo  this extension. You can reopen Chrome now.
echo ============================================
pause
