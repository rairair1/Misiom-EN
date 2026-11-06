# Undoes Install-English.ps1: puts the original O HUB app.asar back.
$ErrorActionPreference = 'Stop'
$found = $null
foreach ($c in "$env:LOCALAPPDATA\Programs\O HUB", "$env:ProgramFiles\O HUB", "${env:ProgramFiles(x86)}\O HUB") {
    if (Test-Path -LiteralPath (Join-Path $c 'resources\app.asar.chinese-original')) { $found = $c; break }
}
if (-not $found) { throw "No backup found (app.asar.chinese-original). Reinstalling O HUB from misiom.cn also restores the original." }
$target = Join-Path $found 'resources\app.asar'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $denied = $false
    try { [IO.File]::OpenWrite($target).Close() }
    catch { $denied = ($_.Exception -is [UnauthorizedAccessException]) -or ($_.Exception.InnerException -is [UnauthorizedAccessException]) }
    if ($denied) {
        Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
        return
    }
}
Get-Process -Name 'O HUB' -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
Copy-Item -LiteralPath "$target.chinese-original" -Destination $target -Force
Write-Host 'Original (Chinese) O HUB restored.' -ForegroundColor Green
