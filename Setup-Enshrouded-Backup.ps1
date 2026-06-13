# Setup-Enshrouded-Backup.ps1
# GUI setup for automatic GPORTAL Enshrouded server backups.
#
# Creates:
# - Backup folders
# - Backup PowerShell script
# - FTP info update script
# - Helper batch files
# - Optional Windows scheduled task
#
# Default location:
# Documents\Gportal_backup
#
# Remote save folder:
# /savegame
#
# Requires:
# - Windows
# - PowerShell
#
# Optional installer features:
# - Install WinSCP if missing
# - Install BurntToast PowerShell module for Windows toast notifications
#
# Scheduled backups run silently/hidden.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

function Get-DefaultProjectFolder {
    $documents = [Environment]::GetFolderPath("MyDocuments")
    return Join-Path $documents "Gportal_backup"
}

function Get-WinSCPPath {
    $paths = @(
        "C:\Program Files (x86)\WinSCP\WinSCP.com",
        "C:\Program Files\WinSCP\WinSCP.com",
        "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com"
    )

    return ($paths | Where-Object { Test-Path $_ } | Select-Object -First 1)
}

function Normalize-HostInput {
    param (
        [string]$HostInput
    )

    $clean = $HostInput.Trim()
    $clean = $clean -replace '^[a-zA-Z]+://', ''
    $clean = $clean -replace '/.*$', ''

    return $clean
}

function Write-FileUtf8 {
    param (
        [string]$Path,
        [string]$Content
    )

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Show-Info {
    param (
        [string]$Message,
        [string]$Title = "GPORTAL Backup Setup"
    )

    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

function Show-Error {
    param (
        [string]$Message,
        [string]$Title = "GPORTAL Backup Setup"
    )

    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

function New-Label {
    param (
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width = 150,
        [int]$Height = 22
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($Width, $Height)
    return $label
}

function New-TextBox {
    param (
        [int]$X,
        [int]$Y,
        [int]$Width = 250,
        [string]$Text = ""
    )

    $box = New-Object System.Windows.Forms.TextBox
    $box.Location = New-Object System.Drawing.Point($X, $Y)
    $box.Size = New-Object System.Drawing.Size($Width, 23)
    $box.Text = $Text
    return $box
}

function New-CheckBox {
    param (
        [string]$Text,
        [int]$X,
        [int]$Y,
        [bool]$Checked = $false,
        [int]$Width = 400
    )

    $check = New-Object System.Windows.Forms.CheckBox
    $check.Text = $Text
    $check.Location = New-Object System.Drawing.Point($X, $Y)
    $check.Size = New-Object System.Drawing.Size($Width, 24)
    $check.Checked = $Checked
    return $check
}

function Install-WinSCPIfNeeded {
    try {
        $existing = Get-WinSCPPath

        if ($existing) {
            return "WinSCP is already installed: $existing"
        }

        $winget = Get-Command winget.exe -ErrorAction SilentlyContinue

        if (-not $winget) {
            return "WinSCP was not installed. winget was not found on this computer."
        }

        $arguments = @(
            "install",
            "--id", "WinSCP.WinSCP",
            "-e",
            "--silent",
            "--accept-package-agreements",
            "--accept-source-agreements"
        )

        $output = & $winget.Source @arguments 2>&1
        $exitCode = $LASTEXITCODE

        Start-Sleep -Seconds 2

        $installed = Get-WinSCPPath

        if ($installed) {
            return "WinSCP installed successfully: $installed"
        }

        if ($exitCode -eq 0) {
            return "WinSCP install command finished, but WinSCP.com was not found in the expected locations."
        }

        return "WinSCP install failed. winget exit code: $exitCode`r`n`r`n$output"
    }
    catch {
        return "WinSCP install failed: $($_.Exception.Message)"
    }
}

function Install-BurntToastIfNeeded {
    try {
        if (Get-Module -ListAvailable -Name BurntToast) {
            return "BurntToast is already installed."
        }

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        try {
            Install-PackageProvider `
                -Name NuGet `
                -MinimumVersion 2.8.5.201 `
                -Scope CurrentUser `
                -Force `
                -ErrorAction SilentlyContinue | Out-Null
        }
        catch {
            # Continue anyway. Install-Module may still work if provider already exists.
        }

        Install-Module `
            -Name BurntToast `
            -Scope CurrentUser `
            -Repository PSGallery `
            -Force `
            -AllowClobber `
            -ErrorAction Stop

        if (Get-Module -ListAvailable -Name BurntToast) {
            return "BurntToast installed successfully."
        }

        return "BurntToast install command completed, but the module was not found afterward."
    }
    catch {
        return "BurntToast install failed: $($_.Exception.Message)"
    }
}

function Run-FirstBackup {
    param (
        [string]$BackupScriptPath,
        [string]$LogsFolder
    )

    try {
        if (!(Test-Path $BackupScriptPath)) {
            return "First backup was not run. Backup script was not found: $BackupScriptPath"
        }

        $arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$BackupScriptPath`""

        $process = Start-Process `
            -FilePath "powershell.exe" `
            -ArgumentList $arguments `
            -WindowStyle Hidden `
            -Wait `
            -PassThru

        if ($process.ExitCode -eq 0) {
            return "First backup completed successfully. Check logs folder: $LogsFolder"
        }

        return "First backup failed with exit code $($process.ExitCode). Check logs folder: $LogsFolder"
    }
    catch {
        return "First backup failed to start: $($_.Exception.Message)"
    }
}

function Create-BackupScriptContent {
    return @'
# Backup-Enshrouded-WinSCP.ps1
# Automatic backup script for a GPORTAL-hosted Enshrouded server.
#
# Reads settings from enshrouded-backup-config.json in the same folder.
# Downloads the whole /savegame folder using WinSCP.
# Creates zip backups under the saves folder.
# Writes detailed run logs under the logs folder.

$ErrorActionPreference = "Stop"

$ConfigPath = Join-Path $PSScriptRoot "enshrouded-backup-config.json"

if (!(Test-Path $ConfigPath)) {
    throw "Missing config file: $ConfigPath"
}

$Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

$Protocol = $Config.Protocol
$HostName = $Config.HostName
$PortNumber = [int]$Config.PortNumber
$UserName = $Config.UserName
$EncryptedPassword = $Config.EncryptedPassword
$RemotePath = $Config.RemotePath
$RootFolder = $Config.RootFolder
$SavesFolder = $Config.SavesFolder
$LogsFolder = $Config.LogsFolder
$TempFolder = $Config.TempFolder
$KeepBackups = [int]$Config.KeepBackups
$KeepLogs = [int]$Config.KeepLogs
$EnableToastNotifications = [bool]$Config.EnableToastNotifications

$Stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

$BackupWorkRoot = Join-Path $TempFolder "backup_work_$Stamp"
$LocalSaveFolder = Join-Path $BackupWorkRoot "savegame"

$ZipFile = Join-Path $SavesFolder "savegame_$Stamp.zip"
$WinSCPScript = Join-Path $TempFolder "winscp_enshrouded_$Stamp.txt"
$WinSCPLogFile = Join-Path $LogsFolder "winscp_$Stamp.log"
$RunLogFile = Join-Path $LogsFolder "backup_run_$Stamp.txt"
$StatusFile = Join-Path $LogsFolder "last-result.txt"

$RunLogLines = New-Object System.Collections.Generic.List[string]

function Write-RunLog {
    param (
        [string]$Message = ""
    )

    Write-Host $Message
    [void]$RunLogLines.Add($Message)
}

function Save-RunLog {
    try {
        New-Item -ItemType Directory -Force -Path $LogsFolder | Out-Null
        $RunLogLines | Set-Content -Path $RunLogFile -Encoding UTF8
    }
    catch {
        Write-Host "Could not write detailed run log."
    }
}

function Convert-SecureStringToPlainText {
    param (
        [System.Security.SecureString]$SecureString
    )

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)

    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Escape-WinSCPArg {
    param (
        [string]$Value
    )

    return ($Value -replace '"', '""')
}

function Protect-LogText {
    param (
        [string]$Text,
        [string]$PlainPassword,
        [string]$EncodedPassword
    )

    $clean = $Text

    if (-not [string]::IsNullOrEmpty($PlainPassword)) {
        $clean = $clean -replace [regex]::Escape($PlainPassword), "<password>"
    }

    if (-not [string]::IsNullOrEmpty($EncodedPassword)) {
        $clean = $clean -replace [regex]::Escape($EncodedPassword), "<password>"
    }

    return $clean
}

function Send-BackupNotification {
    param (
        [string]$Title,
        [string]$Message
    )

    if (-not $EnableToastNotifications) {
        return
    }

    try {
        Import-Module BurntToast -ErrorAction Stop
        New-BurntToastNotification -Text $Title, $Message -Silent
    }
    catch {
        Write-RunLog "Toast notification skipped."
    }
}

try {
    Write-RunLog "Running Enshrouded backup..."
    Write-RunLog "Time: $(Get-Date)"
    Write-RunLog "Remote path: $RemotePath"
    Write-RunLog "Saves folder: $SavesFolder"
    Write-RunLog "Logs folder: $LogsFolder"
    Write-RunLog ""

    $WinSCPPaths = @(
        "C:\Program Files (x86)\WinSCP\WinSCP.com",
        "C:\Program Files\WinSCP\WinSCP.com",
        "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com"
    )

    $WinSCP = $WinSCPPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $WinSCP) {
        throw "Could not find WinSCP.com. Make sure WinSCP is installed."
    }

    Write-RunLog "WinSCP found: $WinSCP"

    New-Item -ItemType Directory -Force -Path $RootFolder | Out-Null
    New-Item -ItemType Directory -Force -Path $SavesFolder | Out-Null
    New-Item -ItemType Directory -Force -Path $LogsFolder | Out-Null
    New-Item -ItemType Directory -Force -Path $TempFolder | Out-Null
    New-Item -ItemType Directory -Force -Path $BackupWorkRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $LocalSaveFolder | Out-Null

    $SecurePassword = $EncryptedPassword | ConvertTo-SecureString
    $PlainPassword = Convert-SecureStringToPlainText $SecurePassword

    $EncodedUserName = [System.Uri]::EscapeDataString($UserName)
    $EncodedPassword = [System.Uri]::EscapeDataString($PlainPassword)

    # WinSCP scripting does not accept -username / -password on the open command.
    # Use a URL-encoded session URL instead.
    $OpenUrl = "${Protocol}://${EncodedUserName}:${EncodedPassword}@${HostName}:${PortNumber}/"

    $EscapedOpenUrl = Escape-WinSCPArg $OpenUrl
    $EscapedRemotePath = Escape-WinSCPArg $RemotePath
    $EscapedLocalSaveFolder = Escape-WinSCPArg $LocalSaveFolder

@"
option batch abort
option confirm off
option transfer binary
open "$EscapedOpenUrl"
lcd "$EscapedLocalSaveFolder"
get -preservetime "$EscapedRemotePath/*"
exit
"@ | Set-Content -Path $WinSCPScript -Encoding UTF8

    Write-RunLog ""
    Write-RunLog "Starting WinSCP transfer..."
    Write-RunLog "WinSCP script: $WinSCPScript"
    Write-RunLog "WinSCP log: $WinSCPLogFile"
    Write-RunLog ""

    $WinSCPOutput = & $WinSCP /script="$WinSCPScript" /log="$WinSCPLogFile" 2>&1
    $WinSCPExitCode = $LASTEXITCODE

    foreach ($line in $WinSCPOutput) {
        $safeLine = Protect-LogText `
            -Text ([string]$line) `
            -PlainPassword $PlainPassword `
            -EncodedPassword $EncodedPassword

        Write-RunLog $safeLine
    }

    Remove-Item $WinSCPScript -Force -ErrorAction SilentlyContinue

    Write-RunLog ""
    Write-RunLog "WinSCP exit code: $WinSCPExitCode"

    if ($WinSCPExitCode -ne 0) {
        throw "WinSCP backup failed. Check log: $WinSCPLogFile"
    }

    Write-RunLog ""
    Write-RunLog "Checking downloaded files..."

    $DownloadedFiles = Get-ChildItem $LocalSaveFolder -File -Recurse -ErrorAction SilentlyContinue

    if ($DownloadedFiles.Count -eq 0) {
        throw "Backup failed: no files were downloaded from $RemotePath"
    }

    $TotalBytes = ($DownloadedFiles | Measure-Object Length -Sum).Sum
    $TotalMB = [math]::Round($TotalBytes / 1MB, 2)

    Write-RunLog "Files downloaded: $($DownloadedFiles.Count)"
    Write-RunLog "Downloaded size: $TotalMB MB"
    Write-RunLog ""

    Write-RunLog "Creating zip backup:"
    Write-RunLog $ZipFile

    Compress-Archive -Path $LocalSaveFolder -DestinationPath $ZipFile -Force

    Write-RunLog "Zip backup created."

    Remove-Item $BackupWorkRoot -Recurse -Force

    Write-RunLog ""
    Write-RunLog "Cleaning old backups..."

    Get-ChildItem $SavesFolder -Filter "savegame_*.zip" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip $KeepBackups |
        Remove-Item -Force

    Write-RunLog "Cleaning old logs..."

    Get-ChildItem $LogsFolder -Filter "winscp_*.log" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip $KeepLogs |
        Remove-Item -Force

    Get-ChildItem $LogsFolder -Filter "backup_run_*.txt" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip $KeepLogs |
        Remove-Item -Force

    Write-RunLog ""
    Write-RunLog "SUCCESS"
    Write-RunLog "Backup complete: $ZipFile"
    Write-RunLog "Detailed run log: $RunLogFile"
    Write-RunLog "WinSCP log: $WinSCPLogFile"

    $message = @"
SUCCESS
Time: $(Get-Date)
Remote path: $RemotePath
Backup: $ZipFile
Size: $TotalMB MB
Files downloaded: $($DownloadedFiles.Count)
Detailed run log: $RunLogFile
WinSCP log: $WinSCPLogFile

Console output:
$($RunLogLines -join "`r`n")
"@

    $message | Set-Content -Path $StatusFile -Encoding UTF8

    Save-RunLog

    Send-BackupNotification `
        -Title "Enshrouded backup complete" `
        -Message "Backup succeeded. Size: $TotalMB MB."

    exit 0
}
catch {
    $ErrorMessage = $_.Exception.Message

    Write-RunLog ""
    Write-RunLog "FAILED"
    Write-RunLog "Error: $ErrorMessage"
    Write-RunLog "Detailed run log: $RunLogFile"
    Write-RunLog "WinSCP log: $WinSCPLogFile"

    try {
        New-Item -ItemType Directory -Force -Path $LogsFolder | Out-Null

        $message = @"
FAILED
Time: $(Get-Date)
Error: $ErrorMessage
Detailed run log: $RunLogFile
WinSCP log: $WinSCPLogFile

Console output:
$($RunLogLines -join "`r`n")
"@

        $message | Set-Content -Path $StatusFile -Encoding UTF8
    }
    catch {
        Write-Host "Could not write status file."
    }

    Save-RunLog

    Send-BackupNotification `
        -Title "Enshrouded backup FAILED" `
        -Message $ErrorMessage

    exit 1
}
finally {
    if ($WinSCPScript -and (Test-Path $WinSCPScript)) {
        Remove-Item $WinSCPScript -Force -ErrorAction SilentlyContinue
    }
}
'@
}

function Create-UpdateFtpScriptContent {
    return @'
# Update-FTP-Info.ps1
# Updates the saved FTP connection information for the GPORTAL Enshrouded backup.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

function Normalize-HostInput {
    param (
        [string]$HostInput
    )

    $clean = $HostInput.Trim()
    $clean = $clean -replace '^[a-zA-Z]+://', ''
    $clean = $clean -replace '/.*$', ''

    return $clean
}

function Write-FileUtf8 {
    param (
        [string]$Path,
        [string]$Content
    )

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Show-Info {
    param (
        [string]$Message,
        [string]$Title = "Update FTP Info"
    )

    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

function Show-Error {
    param (
        [string]$Message,
        [string]$Title = "Update FTP Info"
    )

    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

function New-Label {
    param (
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width = 130,
        [int]$Height = 22
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($Width, $Height)
    return $label
}

function New-TextBox {
    param (
        [int]$X,
        [int]$Y,
        [int]$Width = 250,
        [string]$Text = ""
    )

    $box = New-Object System.Windows.Forms.TextBox
    $box.Location = New-Object System.Drawing.Point($X, $Y)
    $box.Size = New-Object System.Drawing.Size($Width, 23)
    $box.Text = $Text
    return $box
}

$ConfigPath = Join-Path $PSScriptRoot "enshrouded-backup-config.json"

if (!(Test-Path $ConfigPath)) {
    Show-Error "Could not find config file:`r`n$ConfigPath"
    exit 1
}

try {
    $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
}
catch {
    Show-Error "Could not read config file:`r`n$ConfigPath"
    exit 1
}

function Save-FtpInfo {
    try {
        $RawHost = $txtHost.Text.Trim()
        $UserName = $txtUser.Text.Trim()
        $Password = $txtPassword.Text

        if ([string]::IsNullOrWhiteSpace($RawHost)) {
            throw "FTP host/server cannot be blank."
        }

        if ([string]::IsNullOrWhiteSpace($UserName)) {
            throw "FTP username cannot be blank."
        }

        $PortNumber = 0

        if (-not [int]::TryParse($txtPort.Text.Trim(), [ref]$PortNumber)) {
            throw "FTP port must be a number."
        }

        if ($PortNumber -lt 1 -or $PortNumber -gt 65535) {
            throw "FTP port must be between 1 and 65535."
        }

        $CleanHost = Normalize-HostInput $RawHost

        if ($CleanHost -match '^([^:]+):(\d+)$') {
            $HostName = $matches[1]
            $PortNumber = [int]$matches[2]
            $txtPort.Text = "$PortNumber"
        }
        else {
            $HostName = $CleanHost
        }

        if ([string]::IsNullOrWhiteSpace($HostName)) {
            throw "FTP host/server is invalid."
        }

        $EncryptedPassword = $Config.EncryptedPassword

        if (-not [string]::IsNullOrWhiteSpace($Password)) {
            $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
            $EncryptedPassword = $SecurePassword | ConvertFrom-SecureString
        }

        if ([string]::IsNullOrWhiteSpace($EncryptedPassword)) {
            throw "FTP password cannot be blank."
        }

        $RootFolder = $Config.RootFolder
        if ([string]::IsNullOrWhiteSpace($RootFolder)) {
            $RootFolder = Split-Path $PSScriptRoot -Parent
        }

        $ScriptsFolder = $Config.ScriptsFolder
        if ([string]::IsNullOrWhiteSpace($ScriptsFolder)) {
            $ScriptsFolder = $PSScriptRoot
        }

        $SavesFolder = $Config.SavesFolder
        if ([string]::IsNullOrWhiteSpace($SavesFolder)) {
            $SavesFolder = Join-Path $RootFolder "saves"
        }

        $LogsFolder = $Config.LogsFolder
        if ([string]::IsNullOrWhiteSpace($LogsFolder)) {
            $LogsFolder = Join-Path $RootFolder "logs"
        }

        $TempFolder = $Config.TempFolder
        if ([string]::IsNullOrWhiteSpace($TempFolder)) {
            $TempFolder = Join-Path $RootFolder "temp"
        }

        $ScheduleFolder = $Config.ScheduleFolder
        if ([string]::IsNullOrWhiteSpace($ScheduleFolder)) {
            $ScheduleFolder = Join-Path $RootFolder "schedule"
        }

        $KeepBackups = [int]$Config.KeepBackups
        if ($KeepBackups -lt 1) {
            $KeepBackups = 21
        }

        $KeepLogs = [int]$Config.KeepLogs
        if ($KeepLogs -lt 1) {
            $KeepLogs = 30
        }

        $EnableToastNotifications = [bool]$Config.EnableToastNotifications

        $newConfig = [ordered]@{
            Protocol = "ftp"
            HostName = $HostName
            PortNumber = $PortNumber
            UserName = $UserName
            EncryptedPassword = $EncryptedPassword
            RemotePath = "/savegame"
            RootFolder = $RootFolder
            ScriptsFolder = $ScriptsFolder
            SavesFolder = $SavesFolder
            LogsFolder = $LogsFolder
            TempFolder = $TempFolder
            ScheduleFolder = $ScheduleFolder
            KeepBackups = $KeepBackups
            KeepLogs = $KeepLogs
            EnableToastNotifications = $EnableToastNotifications
        }

        $json = $newConfig | ConvertTo-Json -Depth 5
        Write-FileUtf8 -Path $ConfigPath -Content $json

        Show-Info "FTP information updated successfully.`r`n`r`nRemote folder remains fixed as:`r`n/savegame"

        $form.Close()
    }
    catch {
        Show-Error $_.Exception.Message
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Update GPORTAL FTP Information"
$form.Size = New-Object System.Drawing.Size(560, 340)
$form.MinimumSize = New-Object System.Drawing.Size(560, 340)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "Sizable"
$form.MaximizeBox = $true
$form.AutoScroll = $true

$title = New-Object System.Windows.Forms.Label
$title.Text = "Update GPORTAL FTP Information"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$title.Location = New-Object System.Drawing.Point(20, 15)
$title.Size = New-Object System.Drawing.Size(500, 30)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Update the FTP host, port, username, or password used by the backup script."
$subtitle.Location = New-Object System.Drawing.Point(22, 48)
$subtitle.Size = New-Object System.Drawing.Size(500, 22)
$form.Controls.Add($subtitle)

$form.Controls.Add((New-Label "FTP host/server:" 25 90 125))
$txtHost = New-TextBox 160 88 260 $Config.HostName
$form.Controls.Add($txtHost)

$form.Controls.Add((New-Label "Port:" 435 90 40))
$txtPort = New-TextBox 475 88 45 "$($Config.PortNumber)"
$form.Controls.Add($txtPort)

$form.Controls.Add((New-Label "FTP username:" 25 130 125))
$txtUser = New-TextBox 160 128 260 $Config.UserName
$form.Controls.Add($txtUser)

$form.Controls.Add((New-Label "New FTP password:" 25 170 125))
$txtPassword = New-TextBox 160 168 260 ""
$txtPassword.UseSystemPasswordChar = $true
$form.Controls.Add($txtPassword)

$passwordHelp = New-Object System.Windows.Forms.Label
$passwordHelp.Text = "Leave blank to keep the current saved password."
$passwordHelp.Location = New-Object System.Drawing.Point(160, 195)
$passwordHelp.Size = New-Object System.Drawing.Size(330, 22)
$form.Controls.Add($passwordHelp)

$remoteLabel = New-Object System.Windows.Forms.Label
$remoteLabel.Text = "Remote folder is fixed: /savegame"
$remoteLabel.Location = New-Object System.Drawing.Point(25, 225)
$remoteLabel.Size = New-Object System.Drawing.Size(300, 22)
$form.Controls.Add($remoteLabel)

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "Save FTP Info"
$btnSave.Location = New-Object System.Drawing.Point(330, 255)
$btnSave.Size = New-Object System.Drawing.Size(110, 30)
$form.Controls.Add($btnSave)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancel"
$btnCancel.Location = New-Object System.Drawing.Point(450, 255)
$btnCancel.Size = New-Object System.Drawing.Size(75, 30)
$form.Controls.Add($btnCancel)

$btnSave.Add_Click({
    Save-FtpInfo
})

$btnCancel.Add_Click({
    $form.Close()
})

[void]$form.ShowDialog()
'@
}

function Install-GportalBackup {
    try {
        $RootFolder = $txtRoot.Text.Trim()
        $RawHost = $txtHost.Text.Trim()
        $UserName = $txtUser.Text.Trim()
        $FtpPassword = $txtFtpPassword.Text
        $TaskName = $txtTaskName.Text.Trim()
        $TaskUser = $txtTaskUser.Text.Trim()
        $TaskPassword = $txtTaskPassword.Text

        if ([string]::IsNullOrWhiteSpace($RootFolder)) {
            throw "Project folder cannot be blank."
        }

        if ([string]::IsNullOrWhiteSpace($RawHost)) {
            throw "FTP host/server cannot be blank."
        }

        if ([string]::IsNullOrWhiteSpace($UserName)) {
            throw "FTP username cannot be blank."
        }

        if ([string]::IsNullOrWhiteSpace($FtpPassword)) {
            throw "FTP password cannot be blank."
        }

        if ([string]::IsNullOrWhiteSpace($TaskName)) {
            throw "Scheduled task name cannot be blank."
        }

        $PortNumber = 0

        if (-not [int]::TryParse($txtPort.Text.Trim(), [ref]$PortNumber)) {
            throw "FTP port must be a number."
        }

        if ($PortNumber -lt 1 -or $PortNumber -gt 65535) {
            throw "FTP port must be between 1 and 65535."
        }

        $KeepBackups = 0

        if (-not [int]::TryParse($txtKeepBackups.Text.Trim(), [ref]$KeepBackups) -or $KeepBackups -lt 1) {
            throw "Backups to keep must be a positive number."
        }

        $KeepLogs = 0

        if (-not [int]::TryParse($txtKeepLogs.Text.Trim(), [ref]$KeepLogs) -or $KeepLogs -lt 1) {
            throw "Logs to keep must be a positive number."
        }

        $RunEveryHours = 0

        if (-not [int]::TryParse($txtRunEvery.Text.Trim(), [ref]$RunEveryHours) -or $RunEveryHours -lt 1) {
            throw "Run every X hours must be a positive number."
        }

        if ($chkCreateTask.Checked -and $chkRunLoggedOff.Checked) {
            if ([string]::IsNullOrWhiteSpace($TaskUser)) {
                throw "Windows task user cannot be blank."
            }

            if ([string]::IsNullOrWhiteSpace($TaskPassword)) {
                throw "Windows password is required when creating a task that runs while logged off."
            }
        }

        $Protocol = "ftp"
        $RemotePath = "/savegame"

        $CleanHost = Normalize-HostInput $RawHost

        if ($CleanHost -match '^([^:]+):(\d+)$') {
            $HostName = $matches[1]
            $PortNumber = [int]$matches[2]
            $txtPort.Text = "$PortNumber"
        }
        else {
            $HostName = $CleanHost
        }

        if ([string]::IsNullOrWhiteSpace($HostName)) {
            throw "FTP host/server is invalid."
        }

        $WinSCPMessage = "WinSCP install was not requested."

        if ($chkInstallWinSCP.Checked) {
            $WinSCPMessage = Install-WinSCPIfNeeded
            $winscpPathAfterInstall = Get-WinSCPPath

            if ($winscpPathAfterInstall) {
                $winscpStatus.Text = "WinSCP found: $winscpPathAfterInstall"
            }
            else {
                $winscpStatus.Text = "WinSCP was not found in the default install paths."
            }
        }
        else {
            $winscpPathExisting = Get-WinSCPPath

            if ($winscpPathExisting) {
                $WinSCPMessage = "WinSCP is already installed: $winscpPathExisting"
            }
            else {
                $WinSCPMessage = "WinSCP was not found. Install WinSCP before running backups."
            }
        }

        $ScriptsFolder = Join-Path $RootFolder "scripts"
        $SavesFolder = Join-Path $RootFolder "saves"
        $LogsFolder = Join-Path $RootFolder "logs"
        $TempFolder = Join-Path $RootFolder "temp"
        $ScheduleFolder = Join-Path $RootFolder "schedule"

        New-Item -ItemType Directory -Force -Path $RootFolder | Out-Null
        New-Item -ItemType Directory -Force -Path $ScriptsFolder | Out-Null
        New-Item -ItemType Directory -Force -Path $SavesFolder | Out-Null
        New-Item -ItemType Directory -Force -Path $LogsFolder | Out-Null
        New-Item -ItemType Directory -Force -Path $TempFolder | Out-Null
        New-Item -ItemType Directory -Force -Path $ScheduleFolder | Out-Null

        $SetupCopyPath = Join-Path $ScriptsFolder "Setup-Enshrouded-Backup.ps1"
        $ConfigPath = Join-Path $ScriptsFolder "enshrouded-backup-config.json"
        $BackupScriptPath = Join-Path $ScriptsFolder "Backup-Enshrouded-WinSCP.ps1"
        $UpdateFtpScriptPath = Join-Path $ScriptsFolder "Update-FTP-Info.ps1"

        if ($PSCommandPath -and (Test-Path $PSCommandPath)) {
            $sourceFull = [System.IO.Path]::GetFullPath($PSCommandPath)
            $targetFull = [System.IO.Path]::GetFullPath($SetupCopyPath)

            if ($sourceFull -ne $targetFull) {
                Copy-Item -Path $PSCommandPath -Destination $SetupCopyPath -Force
            }
        }

        $BurntToastMessage = "BurntToast was not installed by setup."

        if ($chkInstallBurntToast.Checked) {
            $BurntToastMessage = Install-BurntToastIfNeeded
        }
        elseif ($chkToast.Checked) {
            if (Get-Module -ListAvailable -Name BurntToast) {
                $BurntToastMessage = "BurntToast is already installed."
            }
            else {
                $BurntToastMessage = "Toast notifications are enabled, but BurntToast is not installed."
            }
        }

        $SecureFtpPassword = ConvertTo-SecureString $FtpPassword -AsPlainText -Force
        $EncryptedPassword = $SecureFtpPassword | ConvertFrom-SecureString

        $config = [ordered]@{
            Protocol = $Protocol
            HostName = $HostName
            PortNumber = $PortNumber
            UserName = $UserName
            EncryptedPassword = $EncryptedPassword
            RemotePath = $RemotePath
            RootFolder = $RootFolder
            ScriptsFolder = $ScriptsFolder
            SavesFolder = $SavesFolder
            LogsFolder = $LogsFolder
            TempFolder = $TempFolder
            ScheduleFolder = $ScheduleFolder
            KeepBackups = $KeepBackups
            KeepLogs = $KeepLogs
            EnableToastNotifications = [bool]$chkToast.Checked
        }

        $configJson = $config | ConvertTo-Json -Depth 5
        Write-FileUtf8 -Path $ConfigPath -Content $configJson

        $backupContent = Create-BackupScriptContent
        Write-FileUtf8 -Path $BackupScriptPath -Content $backupContent

        $updateFtpContent = Create-UpdateFtpScriptContent
        Write-FileUtf8 -Path $UpdateFtpScriptPath -Content $updateFtpContent

        $RunBackupNowBat = Join-Path $ScheduleFolder "Run-Backup-Now.bat"
        $UpdateFtpBat = Join-Path $ScheduleFolder "Update-FTP-Info.bat"
        $CreateLoggedOffBat = Join-Path $ScheduleFolder "Create-Scheduled-Task-Logged-Off.bat"
        $CreateLoggedInBat = Join-Path $ScheduleFolder "Create-Scheduled-Task-Logged-In-Only.bat"
        $DeleteTaskBat = Join-Path $ScheduleFolder "Delete-Scheduled-Task.bat"
        $ShowLastResultBat = Join-Path $ScheduleFolder "Show-Last-Result.bat"

        $runNowContent = @"
@echo off
title Run Enshrouded Backup
echo Running Enshrouded backup now...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$BackupScriptPath"
echo.
pause
"@

        Set-Content -Path $RunBackupNowBat -Value $runNowContent -Encoding ASCII

        $updateFtpBatContent = @"
@echo off
title Update GPORTAL FTP Info
echo Opening FTP information updater...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$UpdateFtpScriptPath"
echo.
pause
"@

        Set-Content -Path $UpdateFtpBat -Value $updateFtpBatContent -Encoding ASCII

        $loggedOffContent = @"
@echo off
title Create Silent Enshrouded Backup Scheduled Task
set "TASK_NAME=$TaskName"
set "SCRIPT_PATH=$BackupScriptPath"
set "TASK_USER=%USERDOMAIN%\%USERNAME%"

echo Creating scheduled task that runs silently, even when Windows is at the logon screen.
echo.
echo Task name: %TASK_NAME%
echo User: %TASK_USER%
echo Interval: every $RunEveryHours hours
echo.
echo Windows will ask for the password for %TASK_USER%.
echo.

schtasks /Delete /TN "%TASK_NAME%" /F >nul 2>nul

schtasks /Create /TN "%TASK_NAME%" /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""%SCRIPT_PATH%""" /SC HOURLY /MO $RunEveryHours /ST 00:00 /RL LIMITED /RU "%TASK_USER%" /RP * /F

echo.
pause
"@

        Set-Content -Path $CreateLoggedOffBat -Value $loggedOffContent -Encoding ASCII

        $loggedInContent = @"
@echo off
title Create Silent Enshrouded Backup Scheduled Task
set "TASK_NAME=$TaskName"
set "SCRIPT_PATH=$BackupScriptPath"
set "TASK_USER=%USERDOMAIN%\%USERNAME%"

echo Creating scheduled task that runs silently when this Windows user is logged in.
echo.
echo Task name: %TASK_NAME%
echo User: %TASK_USER%
echo Interval: every $RunEveryHours hours
echo.

schtasks /Delete /TN "%TASK_NAME%" /F >nul 2>nul

schtasks /Create /TN "%TASK_NAME%" /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""%SCRIPT_PATH%""" /SC HOURLY /MO $RunEveryHours /ST 00:00 /RL LIMITED /RU "%TASK_USER%" /IT /F

echo.
pause
"@

        Set-Content -Path $CreateLoggedInBat -Value $loggedInContent -Encoding ASCII

        $deleteTaskContent = @"
@echo off
title Delete Enshrouded Backup Scheduled Task
set "TASK_NAME=$TaskName"

echo Deleting scheduled task:
echo %TASK_NAME%
echo.

schtasks /Delete /TN "%TASK_NAME%" /F

echo.
pause
"@

        Set-Content -Path $DeleteTaskBat -Value $deleteTaskContent -Encoding ASCII

        $showResultContent = @"
@echo off
title Enshrouded Backup Last Result
set "RESULT_FILE=$LogsFolder\last-result.txt"

if exist "%RESULT_FILE%" (
    type "%RESULT_FILE%"
) else (
    echo No last-result.txt found yet.
)

echo.
pause
"@

        Set-Content -Path $ShowLastResultBat -Value $showResultContent -Encoding ASCII

        $taskMessage = "Scheduled task was not created."

        if ($chkCreateTask.Checked) {
            $TaskRun = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$BackupScriptPath`""

            & schtasks.exe /Delete /TN $TaskName /F 2>$null | Out-Null

            if ($chkRunLoggedOff.Checked) {
                $TaskArgs = @(
                    "/Create",
                    "/TN", $TaskName,
                    "/TR", $TaskRun,
                    "/SC", "HOURLY",
                    "/MO", "$RunEveryHours",
                    "/ST", "00:00",
                    "/RL", "LIMITED",
                    "/RU", $TaskUser,
                    "/RP", $TaskPassword,
                    "/F"
                )

                $taskOutput = & schtasks.exe @TaskArgs 2>&1

                if ($LASTEXITCODE -ne 0) {
                    throw "Setup files were created, but scheduled task creation failed.`r`n`r`n$taskOutput"
                }

                $taskMessage = "Scheduled task created. It runs silently and can run while Windows is at the logon screen."
            }
            else {
                if ([string]::IsNullOrWhiteSpace($TaskUser)) {
                    $TaskUser = whoami
                }

                $TaskArgs = @(
                    "/Create",
                    "/TN", $TaskName,
                    "/TR", $TaskRun,
                    "/SC", "HOURLY",
                    "/MO", "$RunEveryHours",
                    "/ST", "00:00",
                    "/RL", "LIMITED",
                    "/RU", $TaskUser,
                    "/IT",
                    "/F"
                )

                $taskOutput = & schtasks.exe @TaskArgs 2>&1

                if ($LASTEXITCODE -ne 0) {
                    throw "Setup files were created, but scheduled task creation failed.`r`n`r`n$taskOutput"
                }

                $taskMessage = "Scheduled task created. It runs silently when that Windows user is logged in."
            }
        }

        $FirstBackupMessage = "First backup was not run."

        if ($chkRunBackupAfterInstall.Checked) {
            $FirstBackupMessage = Run-FirstBackup `
                -BackupScriptPath $BackupScriptPath `
                -LogsFolder $LogsFolder
        }

        $summary = @"
Setup complete.

Project folder:
$RootFolder

Backup script:
$BackupScriptPath

FTP update script:
$UpdateFtpScriptPath

Config file:
$ConfigPath

Saves folder:
$SavesFolder

Logs folder:
$LogsFolder

Schedule helper batch files:
$ScheduleFolder

Remote folder:
/savegame

WinSCP setup:
$WinSCPMessage

Notification setup:
$BurntToastMessage

First backup:
$FirstBackupMessage

$taskMessage
"@

        Show-Info $summary

        if ($chkOpenFolder.Checked) {
            Start-Process explorer.exe $RootFolder
        }
    }
    catch {
        Show-Error $_.Exception.Message
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "GPORTAL Enshrouded Backup Setup"
$form.Size = New-Object System.Drawing.Size(760, 680)
$form.MinimumSize = New-Object System.Drawing.Size(760, 540)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "Sizable"
$form.MaximizeBox = $true
$form.AutoScroll = $false

$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

$contentPanel = New-Object System.Windows.Forms.Panel
$contentPanel.Location = New-Object System.Drawing.Point(0, 0)
$contentPanel.Size = New-Object System.Drawing.Size(744, 580)
$contentPanel.Anchor = "Top, Bottom, Left, Right"
$contentPanel.AutoScroll = $true
$form.Controls.Add($contentPanel)

$buttonPanel = New-Object System.Windows.Forms.Panel
$buttonPanel.Height = 55
$buttonPanel.Dock = "Bottom"
$form.Controls.Add($buttonPanel)

$title = New-Object System.Windows.Forms.Label
$title.Text = "GPORTAL Enshrouded Backup Setup"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
$title.Location = New-Object System.Drawing.Point(20, 15)
$title.Size = New-Object System.Drawing.Size(700, 32)
$contentPanel.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Creates backup folders, a WinSCP backup script, helper batch files, and an optional scheduled task."
$subtitle.Location = New-Object System.Drawing.Point(22, 50)
$subtitle.Size = New-Object System.Drawing.Size(700, 22)
$contentPanel.Controls.Add($subtitle)

$y = 88

$contentPanel.Controls.Add((New-Label "Project folder:" 25 $y 120))
$txtRoot = New-TextBox 150 $y 470 (Get-DefaultProjectFolder)
$contentPanel.Controls.Add($txtRoot)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse..."
$btnBrowse.Location = New-Object System.Drawing.Point(630, $y)
$btnBrowse.Size = New-Object System.Drawing.Size(85, 25)
$contentPanel.Controls.Add($btnBrowse)

$btnBrowse.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Choose the main Gportal_backup project folder"
    $dialog.SelectedPath = $txtRoot.Text

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtRoot.Text = $dialog.SelectedPath
    }
})

$y += 45

$ftpGroup = New-Object System.Windows.Forms.GroupBox
$ftpGroup.Text = "GPORTAL FTP Connection"
$ftpGroup.Location = New-Object System.Drawing.Point(20, $y)
$ftpGroup.Size = New-Object System.Drawing.Size(700, 150)
$contentPanel.Controls.Add($ftpGroup)

$ftpGroup.Controls.Add((New-Label "FTP host/server:" 15 32 125))
$txtHost = New-TextBox 145 30 380 ""
$ftpGroup.Controls.Add($txtHost)

$ftpGroup.Controls.Add((New-Label "Port:" 545 32 40))
$txtPort = New-TextBox 590 30 75 "21"
$ftpGroup.Controls.Add($txtPort)

$ftpGroup.Controls.Add((New-Label "FTP username:" 15 70 125))
$txtUser = New-TextBox 145 68 250 ""
$ftpGroup.Controls.Add($txtUser)

$ftpGroup.Controls.Add((New-Label "FTP password:" 15 108 125))
$txtFtpPassword = New-TextBox 145 106 250 ""
$txtFtpPassword.UseSystemPasswordChar = $true
$ftpGroup.Controls.Add($txtFtpPassword)

$remoteLabel = New-Object System.Windows.Forms.Label
$remoteLabel.Text = "Remote folder is fixed: /savegame"
$remoteLabel.Location = New-Object System.Drawing.Point(420, 108)
$remoteLabel.Size = New-Object System.Drawing.Size(240, 22)
$ftpGroup.Controls.Add($remoteLabel)

$y += 165

$settingsGroup = New-Object System.Windows.Forms.GroupBox
$settingsGroup.Text = "Backup and Schedule Settings"
$settingsGroup.Location = New-Object System.Drawing.Point(20, $y)
$settingsGroup.Size = New-Object System.Drawing.Size(700, 240)
$contentPanel.Controls.Add($settingsGroup)

$settingsGroup.Controls.Add((New-Label "Backups to keep:" 15 32 125))
$txtKeepBackups = New-TextBox 145 30 70 "21"
$settingsGroup.Controls.Add($txtKeepBackups)

$settingsGroup.Controls.Add((New-Label "Logs to keep:" 250 32 95))
$txtKeepLogs = New-TextBox 345 30 70 "30"
$settingsGroup.Controls.Add($txtKeepLogs)

$settingsGroup.Controls.Add((New-Label "Run every hours:" 455 32 120))
$txtRunEvery = New-TextBox 575 30 70 "8"
$settingsGroup.Controls.Add($txtRunEvery)

$settingsGroup.Controls.Add((New-Label "Task name:" 15 70 125))
$txtTaskName = New-TextBox 145 68 360 "Enshrouded WinSCP Backup"
$settingsGroup.Controls.Add($txtTaskName)

$chkCreateTask = New-CheckBox "Create or update scheduled task now" 145 100 $true 350
$settingsGroup.Controls.Add($chkCreateTask)

$chkRunLoggedOff = New-CheckBox "Run silently even when Windows is sitting at the logon screen" 145 128 $true 480
$settingsGroup.Controls.Add($chkRunLoggedOff)

$chkRunBackupAfterInstall = New-CheckBox "Run one backup immediately after install" 145 154 $true 420
$settingsGroup.Controls.Add($chkRunBackupAfterInstall)

$chkToast = New-CheckBox "Show Windows toast notifications when logged in" 145 180 $false 420
$settingsGroup.Controls.Add($chkToast)

$chkInstallBurntToast = New-CheckBox "Install BurntToast notification module if needed" 145 206 $false 430
$settingsGroup.Controls.Add($chkInstallBurntToast)

$y += 255

$taskGroup = New-Object System.Windows.Forms.GroupBox
$taskGroup.Text = "Windows Scheduled Task Account"
$taskGroup.Location = New-Object System.Drawing.Point(20, $y)
$taskGroup.Size = New-Object System.Drawing.Size(700, 105)
$contentPanel.Controls.Add($taskGroup)

$currentUser = whoami

$taskGroup.Controls.Add((New-Label "Windows user:" 15 32 125))
$txtTaskUser = New-TextBox 145 30 250 $currentUser
$taskGroup.Controls.Add($txtTaskUser)

$taskGroup.Controls.Add((New-Label "Windows password:" 15 68 125))
$txtTaskPassword = New-TextBox 145 66 250 ""
$txtTaskPassword.UseSystemPasswordChar = $true
$taskGroup.Controls.Add($txtTaskPassword)

$taskHelp = New-Object System.Windows.Forms.Label
$taskHelp.Text = "Password is only needed when creating a task that runs while logged off."
$taskHelp.Location = New-Object System.Drawing.Point(415, 67)
$taskHelp.Size = New-Object System.Drawing.Size(260, 35)
$taskGroup.Controls.Add($taskHelp)

$y += 120

$dependencyGroup = New-Object System.Windows.Forms.GroupBox
$dependencyGroup.Text = "Optional Components"
$dependencyGroup.Location = New-Object System.Drawing.Point(20, $y)
$dependencyGroup.Size = New-Object System.Drawing.Size(700, 90)
$contentPanel.Controls.Add($dependencyGroup)

$winscpPath = Get-WinSCPPath

$winscpStatus = New-Object System.Windows.Forms.Label
$winscpStatus.Location = New-Object System.Drawing.Point(15, 25)
$winscpStatus.Size = New-Object System.Drawing.Size(660, 22)

if ($winscpPath) {
    $winscpStatus.Text = "WinSCP found: $winscpPath"
}
else {
    $winscpStatus.Text = "WinSCP was not found in the default install paths."
}

$dependencyGroup.Controls.Add($winscpStatus)

$defaultInstallWinSCP = $false
if (-not $winscpPath) {
    $defaultInstallWinSCP = $true
}

$chkInstallWinSCP = New-CheckBox "Install WinSCP if missing using winget" 15 52 $defaultInstallWinSCP 360
$dependencyGroup.Controls.Add($chkInstallWinSCP)

$y += 105

$chkOpenFolder = New-CheckBox "Open project folder when setup finishes" 25 $y $true 320
$contentPanel.Controls.Add($chkOpenFolder)

$y += 45

$bottomSpacer = New-Object System.Windows.Forms.Label
$bottomSpacer.Text = ""
$bottomSpacer.Location = New-Object System.Drawing.Point(25, $y)
$bottomSpacer.Size = New-Object System.Drawing.Size(690, 10)
$contentPanel.Controls.Add($bottomSpacer)

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = "Install / Update"
$btnInstall.Size = New-Object System.Drawing.Size(120, 32)
$btnInstall.Anchor = "Right, Bottom"
$buttonPanel.Controls.Add($btnInstall)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancel"
$btnCancel.Size = New-Object System.Drawing.Size(90, 32)
$btnCancel.Anchor = "Right, Bottom"
$buttonPanel.Controls.Add($btnCancel)

function Position-BottomButtons {
    $btnCancel.Location = New-Object System.Drawing.Point(($buttonPanel.ClientSize.Width - 105), 11)
    $btnInstall.Location = New-Object System.Drawing.Point(($buttonPanel.ClientSize.Width - 235), 11)
}

$buttonPanel.Add_SizeChanged({
    Position-BottomButtons
})

Position-BottomButtons

$btnCancel.Add_Click({
    $form.Close()
})

function Update-TaskControls {
    $taskEnabled = $chkCreateTask.Checked
    $loggedOff = $chkRunLoggedOff.Checked

    $chkRunLoggedOff.Enabled = $taskEnabled
    $txtTaskName.Enabled = $taskEnabled
    $txtTaskUser.Enabled = $taskEnabled
    $txtTaskPassword.Enabled = ($taskEnabled -and $loggedOff)
}

function Update-NotificationControls {
    if ($chkToast.Checked) {
        $chkInstallBurntToast.Enabled = $true
    }
    else {
        $chkInstallBurntToast.Checked = $false
        $chkInstallBurntToast.Enabled = $false
    }
}

$chkCreateTask.Add_CheckedChanged({
    Update-TaskControls
})

$chkRunLoggedOff.Add_CheckedChanged({
    Update-TaskControls
})

$chkToast.Add_CheckedChanged({
    Update-NotificationControls
})

$btnInstall.Add_Click({
    Install-GportalBackup
})

Update-TaskControls
Update-NotificationControls

[void]$form.ShowDialog()
