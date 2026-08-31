<#
.SYNOPSIS
    Continuous loop wrapper around the browser-removal logic, meant to run as a
    Windows Service (via NSSM) rather than a one-shot scheduled task.
    Checks every 5 minutes, forever, so a reinstalled browser is caught within
    minutes instead of only at next reboot.
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CleanupScript = Join-Path $ScriptDir "Remove-BlockedBrowsers.ps1"
$IntervalSeconds = 300  # 5 minutes

while ($true) {
    try {
        if (Test-Path $CleanupScript) {
            & $CleanupScript
        }
    }
    catch {
        # Swallow errors so the loop itself never dies - a single bad run
        # shouldn't kill the whole service. Errors are already logged inside
        # Remove-BlockedBrowsers.ps1 itself.
    }
    Start-Sleep -Seconds $IntervalSeconds
}
