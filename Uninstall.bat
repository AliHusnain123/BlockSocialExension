@echo off
:: Revflip Network Policy Filter - Uninstaller (v2)

net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

set INSTALL_DIR=C:\ProgramData\RevflipExt

echo ============================================
echo  Revflip Network Policy Filter - Uninstall
echo ============================================
echo.

echo [1/6] Removing browser force-install policies (Chrome, Edge, Brave, Opera)...
powershell -NoProfile -Command "Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist' -Name '1' -ErrorAction SilentlyContinue; Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist' -Name '1' -ErrorAction SilentlyContinue; Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist' -Name '1' -ErrorAction SilentlyContinue; Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Opera Software\Opera Stable\ExtensionInstallForcelist' -Name '1' -ErrorAction SilentlyContinue"

echo [2/6] Stopping and removing the background service...
set NSSM_EXE=%INSTALL_DIR%\nssm\nssm-2.24\win64\nssm.exe
if not exist "%NSSM_EXE%" set NSSM_EXE=%INSTALL_DIR%\nssm\nssm-2.24\win32\nssm.exe
if exist "%NSSM_EXE%" (
    "%NSSM_EXE%" stop RevflipBrowserGuard >nul 2>&1
    "%NSSM_EXE%" remove RevflipBrowserGuard confirm >nul 2>&1
) else (
    sc stop RevflipBrowserGuard >nul 2>&1
    sc delete RevflipBrowserGuard >nul 2>&1
)

echo [3/6] Removing any leftover Scheduled Task from earlier attempts...
schtasks /Delete /TN "RevflipBrowserCleanup" /F >nul 2>&1

echo [4/6] Closing all browsers so policy changes take effect...
taskkill /IM chrome.exe /F >nul 2>&1
taskkill /IM msedge.exe /F >nul 2>&1
taskkill /IM brave.exe /F >nul 2>&1
taskkill /IM opera.exe /F >nul 2>&1

echo [5/6] Removing Defender exclusion and installed files...
powershell -NoProfile -Command "Remove-MpPreference -ExclusionPath '%INSTALL_DIR%' -ErrorAction SilentlyContinue"
if exist "%INSTALL_DIR%" (
    rmdir /S /Q "%INSTALL_DIR%"
)

echo [6/6] Checking for MSI-based install record...
powershell -NoProfile -Command "$app = Get-CimInstance -Class Win32_Product -Filter \"Name='Revflip Network Policy Filter'\" -ErrorAction SilentlyContinue; if ($app) { $app.Uninstall() | Out-Null; Write-Host 'MSI install record removed.' } else { Write-Host 'No MSI install record found.' }"

echo.
echo ============================================
echo  Uninstall complete.
echo ============================================
pause
