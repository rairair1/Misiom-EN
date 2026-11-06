# Switches the Misiom "O HUB" driver app (version 1.0.10) to English.
# Replaces resources\app.asar with the translated copy next to this script,
# after backing up the original as app.asar.chinese-original.
# Run Restore-Chinese.ps1 to undo.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$newAsar = Join-Path $here 'app.asar'
$OriginalHash = '491E6A5091D5D8555D5C598D344777BAA68FBE10E9D1FCE3CADA0AA8EDC4E658'  # O HUB 1.0.10, unmodified
$EnglishHash  = '34BAE2C671A2B09B699F3EBE76E883409FBEDE1CB5AA7590C66992A3BDD6FD47'  # this kit's app.asar

function Find-OHub {
    $candidates = @()
    foreach ($root in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
                      'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
                      'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall') {
        Get-ChildItem $root -ErrorAction SilentlyContinue | ForEach-Object {
            $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            if ($p.DisplayName -like 'O HUB*' -and $p.InstallLocation) { $candidates += $p.InstallLocation.Trim('"') }
        }
    }
    $candidates += "$env:LOCALAPPDATA\Programs\O HUB", "$env:ProgramFiles\O HUB", "${env:ProgramFiles(x86)}\O HUB"
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath (Join-Path $c 'resources\app.asar'))) { return $c }
    }
    return $null
}

if ((Get-FileHash -LiteralPath $newAsar -Algorithm SHA256).Hash -ne $EnglishHash) {
    throw "app.asar in this folder is incomplete or corrupted. Download the kit again."
}
$dir = Find-OHub
if (-not $dir) { throw "Couldn't find O HUB. Install it from misiom.cn first (Windows 10 or later)." }
$target = Join-Path $dir 'resources\app.asar'
$backup = "$target.chinese-original"
Write-Host "Found O HUB at: $dir"

$current = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
if ($current -eq $EnglishHash) { Write-Host 'O HUB is already in English. Nothing to do.'; return }
if ($current -ne $OriginalHash) {
    throw "This O HUB isn't the unmodified version 1.0.10 this kit was made for (Misiom may have updated it). Nothing was changed."
}

# Program Files installs need administrator rights: relaunch elevated if we can't write there.
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $denied = $false
    try { [IO.File]::OpenWrite($target).Close() }
    catch { $denied = ($_.Exception -is [UnauthorizedAccessException]) -or ($_.Exception.InnerException -is [UnauthorizedAccessException]) }
    if ($denied) {
        Write-Host 'Administrator rights needed. Approve the Windows prompt...'
        Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
        return
    }
}

# O HUB keeps running in the system tray, which locks the file.
Get-Process -Name 'O HUB' -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

if (-not (Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $target -Destination $backup }
Copy-Item -LiteralPath $newAsar -Destination $target -Force

if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $EnglishHash) {
    Copy-Item -LiteralPath $backup -Destination $target -Force
    throw "Copy failed, so the original was put back. Close O HUB (including its tray icon) and try again."
}
Write-Host ''
Write-Host 'Done. O HUB is now in English. Backup of the original:' -ForegroundColor Green
Write-Host "  $backup"
Write-Host ''
Write-Host 'If it still opens in Chinese (you used it before), click the gear icon at the top,'
Write-Host 'then General Settings > Language > English (see README.txt for the Chinese labels).'
