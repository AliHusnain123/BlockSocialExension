@echo off
:: Revflip Network Policy Filter - Combined Installer (v2)
:: 1. Excludes our folder from Windows Defender (prevents script auto-quarantine)
:: 2. Installs a Windows SERVICE (via NSSM) that continuously removes Opera/
::    Firefox/etc every 5 minutes - more reliable than GPO or Scheduled Tasks
:: 3. Installs the blocking extension on Chrome, Edge, Brave

net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

set REPO=https://raw.githubusercontent.com/AliHusnain123/BlockSocialExension/main
set INSTALL_DIR=C:\ProgramData\RevflipExt
set NSSM_DIR=%INSTALL_DIR%\nssm

echo ============================================
echo  Revflip Network Policy Filter - Install
echo ============================================
echo.

if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

echo [1/6] Excluding install folder from Windows Defender...
powershell -NoProfile -Command "Add-MpPreference -ExclusionPath '%INSTALL_DIR%' -ErrorAction SilentlyContinue"
echo   (This prevents Defender from silently deleting our scripts, which is
echo    what broke the previous scheduled-task attempt.)

echo.
echo [2/6] Installing extension (Chrome, Edge, Brave)...
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -useb %REPO%/Deploy-RevflipFilter.ps1 | iex"

echo.
echo [3/6] Downloading browser-cleanup scripts...
powershell -NoProfile -Command "Invoke-WebRequest -Uri '%REPO%/Remove-BlockedBrowsers.ps1' -OutFile '%INSTALL_DIR%\Remove-BlockedBrowsers.ps1' -UseBasicParsing"
powershell -NoProfile -Command "Invoke-WebRequest -Uri '%REPO%/Remove-BlockedBrowsers-Loop.ps1' -OutFile '%INSTALL_DIR%\Remove-BlockedBrowsers-Loop.ps1' -UseBasicParsing"

if not exist "%INSTALL_DIR%\Remove-BlockedBrowsers.ps1" (
    echo ERROR: Failed to download cleanup script. Check network/GitHub access.
    pause
    exit /b 1
)

echo.
echo [4/6] Cleaning up any old Scheduled Task from a previous install attempt...
schtasks /Delete /TN "RevflipBrowserCleanup" /F >nul 2>&1

echo.
echo [5/6] Downloading NSSM (service wrapper) and registering the service...
if not exist "%NSSM_DIR%" mkdir "%NSSM_DIR%"
powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://nssm.cc/release/nssm-2.24.zip' -OutFile '%INSTALL_DIR%\nssm.zip' -UseBasicParsing; Expand-Archive -Path '%INSTALL_DIR%\nssm.zip' -DestinationPath '%NSSM_DIR%' -Force"

set NSSM_EXE=%NSSM_DIR%\nssm-2.24\win64\nssm.exe
if not exist "%NSSM_EXE%" set NSSM_EXE=%NSSM_DIR%\nssm-2.24\win32\nssm.exe

if not exist "%NSSM_EXE%" (
    echo ERROR: NSSM download/extract failed. Service not installed.
    echo You can still rely on the one-shot cleanup below.
    goto :skip_service
)

"%NSSM_EXE%" stop RevflipBrowserGuard >nul 2>&1
"%NSSM_EXE%" remove RevflipBrowserGuard confirm >nul 2>&1

"%NSSM_EXE%" install RevflipBrowserGuard powershell.exe
"%NSSM_EXE%" set RevflipBrowserGuard AppParameters "-NoProfile -ExecutionPolicy Bypass -File \"%INSTALL_DIR%\Remove-BlockedBrowsers-Loop.ps1\""
"%NSSM_EXE%" set RevflipBrowserGuard Start SERVICE_AUTO_START
"%NSSM_EXE%" set RevflipBrowserGuard AppStdout "%INSTALL_DIR%\service-stdout.log"
"%NSSM_EXE%" set RevflipBrowserGuard AppStderr "%INSTALL_DIR%\service-stderr.log"
"%NSSM_EXE%" start RevflipBrowserGuard

echo   Service 'RevflipBrowserGuard' installed and started.
echo   It checks for Opera/Firefox/etc every 5 minutes, continuously,
echo   regardless of GPO, login state, or reboot timing.

:skip_service

echo.
echo [6/6] Running an initial cleanup pass now...
powershell -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_DIR%\Remove-BlockedBrowsers.ps1"

echo.
echo ============================================
echo  Installation complete.
echo  - Extension force-installed on Chrome/Edge/Brave
echo  - Background service continuously removes
echo    Opera/Firefox/etc every 5 minutes
echo ============================================
pause
