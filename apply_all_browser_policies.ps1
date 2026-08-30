# Applies the force-install policy to every installed Chromium-based browser.
# Each browser reads its OWN registry tree - Chrome's policy does not cascade to Edge/Brave/Opera.

$ExtensionId = "lcmgecogfadobkimnacpbfgdpimgccgk"
$UpdateXmlPath = "file:///C:/ProgramData/RevflipExt/update.xml"
$PolicyValue = "$ExtensionId;$UpdateXmlPath"

$BrowserPolicyPaths = @{
    "Chrome" = "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"
    "Edge"   = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist"
    "Brave"  = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist"
    # Opera: Chromium-based but does NOT reliably honor enterprise ExtensionInstallForcelist -
    # Opera's own extension store/policy engine frequently ignores this Chrome-standard key.
    # Included here on the chance it works in your Opera version, but treat it as best-effort, not guaranteed.
    "Opera"  = "HKLM:\SOFTWARE\Policies\Opera Software\Opera Stable\ExtensionInstallForcelist"
}

foreach ($browser in $BrowserPolicyPaths.Keys) {
    $path = $BrowserPolicyPaths[$browser]
    New-Item -Path $path -Force | Out-Null
    Set-ItemProperty -Path $path -Name "1" -Value $PolicyValue
    Write-Host "$browser policy set: $path"
}

Write-Host ""
Write-Host "Done. Chrome, Edge, and Brave will force-install and lock the extension."
Write-Host "Opera support is best-effort - verify manually on a test machine."
Write-Host "Firefox requires a SEPARATE .xpi build (different extension format) - see Firefox deployment package."
