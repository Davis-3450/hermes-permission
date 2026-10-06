#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Fix-HermesPermissions.ps1
    Restores ownership, enables NTFS inheritance, terminates locking processes,
    and removes Web/Zone execution locks across the Hermes installation tree.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"
$HermesDir = "$env:LOCALAPPDATA\hermes"
$CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "       HERMES PERMISSIONS & RECOVERY SCRIPT               " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $HermesDir)) {
    Write-Error "Hermes directory not found at: $HermesDir"
    exit 1
}

# 1. Terminate orphaned Hermes and gateway processes
Write-Host "`n[1/5] Terminating active Hermes processes and services..." -ForegroundColor Yellow
$processes = Get-Process | Where-Object {
    $_.Path -and ($_.Path -like "$HermesDir*" -or $_.ProcessName -match "^(hermes|gateway)")
}

if ($processes) {
    foreach ($proc in$processes) {
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
            Write-Host "  -> Terminated process: $($proc.ProcessName) (PID: $($proc.Id))"
        } catch {
            Write-Warning "  -> Could not terminate process: $($proc.ProcessName) (PID: $($proc.Id))"
        }
    }
} else {
    Write-Host "  -> No running Hermes processes detected."
}
Start-Sleep -Seconds 1

# 2. Reclaim ownership of the Hermes directory tree
Write-Host "`n[2/5] Taking recursive ownership of Hermes files..." -ForegroundColor Yellow
try {
    takeown /F $HermesDir /R /D Y *>$null
    Write-Host "  -> Ownership successfully claimed for Administrator." -ForegroundColor Green
} catch {
    Write-Warning "  -> Failed to take full ownership. Details: $_"
}

# 3. Enable inheritance and grant Full Control to current user
Write-Host "`n[3/5] Restoring NTFS inheritance and granting Full Control to '$CurrentUser'..." -ForegroundColor Yellow
try {
    # /inheritance:e re-enables inheritance cascading
    # /grant:r gives explicit replaceable Full Control
    icacls $HermesDir /inheritance:e /grant:r "${CurrentUser}:(OI)(CI)F" /T /C /Q *>$null
    Write-Host "  -> Access control lists (ACLs) successfully restored." -ForegroundColor Green
} catch {
    Write-Warning "  -> Error updating permissions with icacls: $_"
}

# 4. Remove Mark-of-the-Web (Zone.Identifier stream blocks)
Write-Host "`n[4/5] Unblocking downloaded binaries and scripts..." -ForegroundColor Yellow
Get-ChildItem -LiteralPath $HermesDir -Recurse -Force -ErrorAction SilentlyContinue | 
    Unblock-File -ErrorAction SilentlyContinue
Write-Host "  -> Mark-of-the-Web execution blocks removed." -ForegroundColor Green

# 5. Purge stale temporary custody and lock files
Write-Host "`n[5/5] Purging orphaned update custody and lock files..." -ForegroundColor Yellow
$tempPatterns = @("hermes-custody-*", "hermes-update-*")
foreach ($pattern in$tempPatterns) {
    Get-ChildItem -Path $env:TEMP -Filter$pattern -File -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
}
Write-Host "  -> Temporary lock files cleaned." -ForegroundColor Green

Write-Host "`n[SUCCESS] Hermes directory permissions repaired successfully." -ForegroundColor Green
Write-Host "You can now close this administrator window and run 'hermes' in a normal terminal.`n"
