<#
.SYNOPSIS
    Silently uninstalls any browser NOT on the approved list (Chrome, Edge, Brave)
    every time it runs. Designed to be triggered by a GPO Startup Script so it
    re-enforces on every boot, even if a user reinstalls a blocked browser.

.NOTES
    - Run as SYSTEM (GPO Computer startup scripts run this way automatically).
    - Approved (untouched): Google Chrome, Microsoft Edge, Brave.
    - Removed on sight: Opera, Opera GX, Firefox, Vivaldi, Tor Browser, Waterfox,
      SeaMonkey, Yandex Browser, Maxthon, UC Browser, Comodo Dragon, Epic Privacy Browser.
      Add more DisplayName patterns to $BlockedBrowsers as needed.
    - Logs actions to C:\ProgramData\RevflipExt\browser-cleanup.log
#>

$LogFile = "C:\ProgramData\RevflipExt\browser-cleanup.log"
New-Item -ItemType Directory -Path (Split-Path $LogFile) -Force -ErrorAction SilentlyContinue | Out-Null

function Write-Log($msg) {
    "$(Get-Date -Format s)  $msg" | Out-File -FilePath $LogFile -Append -Encoding utf8
}

# DisplayName patterns to remove (wildcards allowed). Case-insensitive match.
$BlockedBrowsers = @(
    "Opera*",
    "Mozilla Firefox*",
    "Vivaldi*",
    "Tor Browser*",
    "Waterfox*",
    "SeaMonkey*",
    "Yandex*",
    "Maxthon*",
    "UC Browser*",
    "Comodo Dragon*",
    "Epic Privacy Browser*"
)

$UninstallKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

Write-Log "=== Browser cleanup started ==="

$found = $false

foreach ($keyPath in $UninstallKeys) {
    $entries = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName }

    foreach ($entry in $entries) {
        foreach ($pattern in $BlockedBrowsers) {
            if ($entry.DisplayName -like $pattern) {
                $found = $true
                Write-Log "Found blocked browser: $($entry.DisplayName)"

                $uninstallCmd = $entry.UninstallString
                if (-not $uninstallCmd) {
                    Write-Log "  No UninstallString for $($entry.DisplayName) - skipping."
                    continue
                }

                try {
                    if ($uninstallCmd -match "msiexec") {
                        $productCode = $entry.PSChildName
                        Start-Process "msiexec.exe" -ArgumentList "/x $productCode /qn /norestart" -Wait -NoNewWindow
                        Write-Log "  Uninstalled: $($entry.DisplayName)"
                    }
                    elseif ($entry.DisplayName -like "Opera*") {
                        # Opera's official uninstaller cannot be made silent, so we remove it
                        # manually. IMPORTANT: Opera also installs a background autoupdate
                        # scheduled task + a separate Roaming data folder outside the main
                        # install directory - if those survive, Opera can silently re-download
                        # and reinstall itself even after we delete the main folder. Remove all of it.
                        Write-Log "  Opera has no working silent-uninstall switch - removing manually instead."

                        # Kill every Opera-related process, including the updater/crash reporter
                        Get-Process "opera*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                        Start-Sleep -Seconds 2

                        # Remove Opera's autoupdate scheduled task(s) - this is what silently
                        # re-triggers a reinstall/repair even after manual deletion
                        Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like "*Opera*" } | ForEach-Object {
                            Unregister-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -Confirm:$false -ErrorAction SilentlyContinue
                            Write-Log "  Removed scheduled task: $($_.TaskName)"
                        }

                        # Main install folder (per-user, AppData\Local)
                        $foldersToRemove = @()
                        if ($entry.InstallLocation -and (Test-Path $entry.InstallLocation)) {
                            $foldersToRemove += $entry.InstallLocation
                        } else {
                            $foldersToRemove += "$env:LOCALAPPDATA\Programs\Opera"
                        }
                        # Roaming profile/updater data - NOT covered by deleting the install folder above
                        $foldersToRemove += "$env:APPDATA\Opera Software"
                        # Also sweep every real user profile on the machine, since this script
                        # runs as SYSTEM at startup and $env:* only resolves to SYSTEM's own paths,
                        # not the actual user (ahusnain) - this is why the first pass could miss folders.
                        Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                            $foldersToRemove += "$($_.FullName)\AppData\Local\Programs\Opera"
                            $foldersToRemove += "$($_.FullName)\AppData\Roaming\Opera Software"
                        }

                        foreach ($folder in ($foldersToRemove | Select-Object -Unique)) {
                            if (Test-Path $folder) {
                                Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
                                if (Test-Path $folder) {
                                    Write-Log "  WARNING: Could not fully delete $folder (files may be locked)."
                                } else {
                                    Write-Log "  Deleted: $folder"
                                }
                            }
                        }

                        # Remove Start Menu / Desktop shortcuts across all user profiles
                        Get-ChildItem "C:\Users\*\AppData\Roaming\Microsoft\Windows\Start Menu\Programs" -Filter "Opera*.lnk" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                        Get-ChildItem "C:\Users\*\Desktop" -Filter "Opera*.lnk" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                        Get-ChildItem "$env:PUBLIC\Desktop" -Filter "Opera*.lnk" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

                        # Remove taskbar pins (stored as GUID-named .lnk files, not "Opera*")
                        Get-ChildItem "C:\Users\*\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar" -Filter "*.lnk" -ErrorAction SilentlyContinue |
                            Where-Object { (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -match "Opera" } |
                            Remove-Item -Force -ErrorAction SilentlyContinue

                        Remove-Item -Path $entry.PSPath -Force -ErrorAction SilentlyContinue

                        Write-Log "  Uninstalled (manual removal): $($entry.DisplayName)"
                    }
                    else {
                        if ($uninstallCmd -match '^\s*"([^"]+)"\s*(.*)$') {
                            $exePath = $Matches[1]
                            $existingArgs = $Matches[2].Trim()
                        }
                        elseif ($uninstallCmd -match '^\s*(\S+\.exe)\s*(.*)$') {
                            $exePath = $Matches[1]
                            $existingArgs = $Matches[2].Trim()
                        }
                        else {
                            $exePath = $uninstallCmd.Trim()
                            $existingArgs = ""
                        }

                        if (-not (Test-Path $exePath)) {
                            Write-Log "  Resolved path not found: '$exePath' (raw string was: $uninstallCmd)"
                            continue
                        }

                        if ($entry.DisplayName -like "Mozilla Firefox*") {
                            $finalArgs = if ($existingArgs) { "$existingArgs /S" } else { "/S" }
                        }
                        else {
                            $finalArgs = if ($existingArgs) { $existingArgs } else { "/S" }
                        }

                        Write-Log "  Running: `"$exePath`" $finalArgs"
                        Start-Process -FilePath $exePath -ArgumentList $finalArgs -Wait -ErrorAction Stop
                        Write-Log "  Uninstalled: $($entry.DisplayName)"
                    }
                }
                catch {
                    Write-Log "  ERROR uninstalling $($entry.DisplayName): $($_.Exception.Message)"
                    Write-Log "  Raw UninstallString was: $uninstallCmd"
                }
            }
        }
    }
}

if (-not $found) {
    Write-Log "No blocked browsers found this run."
}

Write-Log "=== Browser cleanup finished ==="
