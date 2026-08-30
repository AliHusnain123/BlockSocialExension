<#
.SYNOPSIS
    Revflip Network Policy Filter - one-click GUI installer.
    Run with:
    iwr -useb https://raw.githubusercontent.com/<your-org>/<your-repo>/main/Deploy-RevflipFilter.ps1 | iex

.NOTES
    Requires: Windows PowerShell 5+, admin rights (for HKLM registry write).
    Edit $RepoBase below to match your actual GitHub repo before publishing.
#>

#Requires -RunAsAdministrator

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---- CONFIG: update this to your actual GitHub repo raw URL ----
$RepoBase = "https://raw.githubusercontent.com/AliHusnain123/BlockSocialExension/main"
$Files = @(
    @{ Url = "$RepoBase/extension.crx"; Dest = "extension.crx" },
    @{ Url = "$RepoBase/update.xml";    Dest = "update.xml" },
    @{ Url = "$RepoBase/RevflipNetworkFilter.msi"; Dest = "RevflipNetworkFilter.msi" }
)
$InstallDir = "C:\ProgramData\RevflipExt"
$TempDir    = "$env:TEMP\RevflipExtDeploy"
$ExtensionId = "lcmgecogfadobkimnacpbfgdpimgccgk"

# ---------------- GUI ----------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Revflip Network Policy Filter - Installer"
$form.Size = New-Object System.Drawing.Size(560, 420)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Revflip Network Policy Filter"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$titleLabel.AutoSize = $true
$titleLabel.Location = New-Object System.Drawing.Point(20, 15)
$form.Controls.Add($titleLabel)

$subLabel = New-Object System.Windows.Forms.Label
$subLabel.Text = "Blocks social media & piracy sites in Chrome. Pulls latest package from GitHub."
$subLabel.AutoSize = $true
$subLabel.Location = New-Object System.Drawing.Point(20, 45)
$form.Controls.Add($subLabel)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 80)
$progressBar.Size = New-Object System.Drawing.Size(500, 25)
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$form.Controls.Add($progressBar)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.Location = New-Object System.Drawing.Point(20, 120)
$logBox.Size = New-Object System.Drawing.Size(500, 200)
$logBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($logBox)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Ready. Click Install to begin."
$statusLabel.AutoSize = $true
$statusLabel.Location = New-Object System.Drawing.Point(20, 330)
$form.Controls.Add($statusLabel)

$installButton = New-Object System.Windows.Forms.Button
$installButton.Text = "Install"
$installButton.Location = New-Object System.Drawing.Point(340, 355)
$installButton.Size = New-Object System.Drawing.Size(90, 32)
$form.Controls.Add($installButton)

$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = "Close"
$closeButton.Location = New-Object System.Drawing.Point(440, 355)
$closeButton.Size = New-Object System.Drawing.Size(90, 32)
$closeButton.Add_Click({ $form.Close() })
$form.Controls.Add($closeButton)

function Write-Log($msg) {
    $logBox.AppendText("$(Get-Date -Format 'HH:mm:ss')  $msg`r`n")
    $logBox.SelectionStart = $logBox.Text.Length
    $logBox.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Set-Progress($pct, $status) {
    $progressBar.Value = [Math]::Min($pct, 100)
    $statusLabel.Text = $status
    [System.Windows.Forms.Application]::DoEvents()
}

$installButton.Add_Click({
    $installButton.Enabled = $false
    try {
        New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
        Set-Progress 5 "Starting..."
        Write-Log "Deployment started."

        $step = 0
        $totalSteps = $Files.Count + 2
        foreach ($f in $Files) {
            $step++
            $pct = [int](($step / $totalSteps) * 80)
            Set-Progress $pct "Downloading $($f.Dest)..."
            Write-Log "Fetching $($f.Url)"
            Invoke-WebRequest -Uri $f.Url -OutFile (Join-Path $TempDir $f.Dest) -UseBasicParsing
            Write-Log "  -> saved to $TempDir\$($f.Dest)"
        }

        Set-Progress 85 "Installing files..."
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
        Copy-Item -Path (Join-Path $TempDir "extension.crx") -Destination $InstallDir -Force
        Copy-Item -Path (Join-Path $TempDir "update.xml") -Destination $InstallDir -Force
        Write-Log "Copied extension files to $InstallDir"

        Set-Progress 92 "Applying Chrome policy..."
        $regPath = "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"
        New-Item -Path $regPath -Force | Out-Null
        Set-ItemProperty -Path $regPath -Name "1" -Value "$ExtensionId;file:///C:/ProgramData/RevflipExt/update.xml"
        Write-Log "Registry policy set: extension force-installed and locked for all users."

        Set-Progress 100 "Done."
        Write-Log "Installation complete. Chrome will install the extension automatically on next launch."
        Write-Log "The extension will self-update its blocklist weekly from open-source sources."
        [System.Windows.Forms.MessageBox]::Show("Installation complete. Restart Chrome (or the PC) for the policy to take effect.", "Success", "OK", "Information")
    }
    catch {
        Write-Log "ERROR: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("Installation failed: $($_.Exception.Message)", "Error", "OK", "Error")
    }
    finally {
        $installButton.Enabled = $true
    }
})

[void]$form.ShowDialog()
