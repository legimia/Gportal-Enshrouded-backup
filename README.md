# GPORTAL Enshrouded Backup Setup

A Windows setup script for creating automatic backups of a GPORTAL-hosted Enshrouded server.

The script creates a local backup folder, saves your GPORTAL FTP information, downloads the server `/savegame` folder using WinSCP, creates zip backups, writes logs, and can optionally create a silent Windows scheduled task.

## Features

* Backs up the full GPORTAL `/savegame` folder
* Stores backups as zip files
* Keeps a configurable number of backups
* Keeps detailed backup logs
* Can run scheduled backups silently in the background
* Can run even while Windows is sitting at the logon screen
* Can run one backup immediately after setup
* Includes an FTP info updater
* Includes helper batch files
* Optional WinSCP install using winget
* Optional BurntToast install for Windows toast notifications

## Requirements

* Windows
* PowerShell
* GPORTAL FTP information
* WinSCP

The setup script can try to install WinSCP automatically using winget if it is missing.

## How to Use

1. Download `Setup-Enshrouded-Backup.ps1`.
2. Right-click the file.
3. Choose **Run with PowerShell**.
4. Fill in your GPORTAL FTP information.
5. Choose your backup settings.
6. Click **Install / Update**.

The remote folder is automatically set to:

```text
/savegame
```

## Default Folder Location

By default, files are created here:

```text
Documents\Gportal_backup
```

## Folder Layout

```text
Gportal_backup
├─ scripts
├─ saves
├─ logs
├─ temp
└─ schedule
```

## Created Files

The setup creates these main files:

```text
scripts\Backup-Enshrouded-WinSCP.ps1
scripts\Update-FTP-Info.ps1
scripts\enshrouded-backup-config.json
```

It also creates helper batch files:

```text
schedule\Run-Backup-Now.bat
schedule\Update-FTP-Info.bat
schedule\Create-Scheduled-Task-Logged-Off.bat
schedule\Create-Scheduled-Task-Logged-In-Only.bat
schedule\Delete-Scheduled-Task.bat
schedule\Show-Last-Result.bat
```

## Scheduled Backups

Scheduled backups are created through Windows Task Scheduler.

The scheduled backup runs silently using:

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden
```

If you choose the logged-off option, the task can run while Windows is at the logon screen. Windows will require the password for the selected Windows user when creating that task.

## Running a Backup Manually

Use:

```text
schedule\Run-Backup-Now.bat
```

This runs the backup immediately and shows the console window.

## Run First Backup After Install

The setup includes an option to run one backup immediately after installation.

This is enabled by default.

## Updating FTP Information Later

Use:

```text
schedule\Update-FTP-Info.bat
```

This lets you update the FTP host, port, username, or password without reinstalling everything.

The remote folder remains fixed as:

```text
/savegame
```

## Backup Files

Backups are saved in:

```text
saves
```

Backup zip files use this format:

```text
savegame_YYYY-MM-DD_HH-mm-ss.zip
```

## Logs

Logs are saved in:

```text
logs
```

Important log files:

```text
last-result.txt
backup_run_YYYY-MM-DD_HH-mm-ss.txt
winscp_YYYY-MM-DD_HH-mm-ss.log
```

`last-result.txt` shows the latest backup result.

`backup_run_*.txt` shows the detailed backup script output.

`winscp_*.log` shows the WinSCP transfer log.

## Default Retention

The default settings are:

```text
Backups to keep: 21
Logs to keep: 30
Run every hours: 8
```

You can change these in the setup window.

## Notifications

Windows toast notifications are optional.

To use them, enable:

```text
Show Windows toast notifications when logged in
Install BurntToast notification module if needed
```

Toast notifications only appear when a Windows user is logged in. Scheduled backups still run without them.

## Notes

The FTP password is saved using Windows user-level encryption. The scheduled task should run as the same Windows user that ran setup.

If you move the backup folder or change Windows users, run the setup again.
