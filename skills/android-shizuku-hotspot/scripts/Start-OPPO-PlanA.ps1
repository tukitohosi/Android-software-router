param([switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
$adbPath = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if (-not (Test-Path -LiteralPath $adbPath)) { throw 'Android platform-tools was not found on this computer.' }
$deviceRows = & $adbPath devices
if ($LASTEXITCODE -ne 0) { throw 'Cannot list USB devices.' }
$matchesForPhone = @()
foreach ($row in $deviceRows) {
    if ($row -match '^([^\s]+)\s+device\s*$') {
        $candidateSerial = $Matches[1]
        $candidateModel = (& $adbPath -s $candidateSerial shell getprop ro.product.model).Trim()
        if ($candidateModel -eq 'PFTM10') { $matchesForPhone += $candidateSerial }
    }
}
if ($matchesForPhone.Count -ne 1) { throw 'Connect and authorize exactly one OPPO A97 (PFTM10) with USB debugging enabled.' }
$phoneSerial = $matchesForPhone[0]
$packagePaths = & $adbPath -s $phoneSerial shell pm path moe.shizuku.privileged.api
$baseApk = ($packagePaths | Where-Object { $_ -match '^package:/data/app/.+/base\.apk$' } | Select-Object -First 1)
if (-not $baseApk) { throw 'Shizuku is not installed or its APK location could not be resolved.' }
$baseApk = ($baseApk -replace '^package:', '').Trim()
if ($baseApk -notmatch '^/data/app/[a-zA-Z0-9_~/=+.-]+/base\.apk$') { throw 'Unexpected Shizuku APK path.' }
$starterPath = ($baseApk -replace '/base\.apk$', '/lib/arm64/libshizuku.so')
& $adbPath -s $phoneSerial shell test -x $starterPath
if ($LASTEXITCODE -ne 0) { throw 'This installed Shizuku version has no compatible executable starter.' }
if ($CheckOnly) {
    Write-Output 'Ready: authorized OPPO A97 and Shizuku executable located. No phone settings changed.'
    exit 0
}
& $adbPath -s $phoneSerial shell $starterPath
if ($LASTEXITCODE -ne 0) { throw 'Shizuku startup command failed.' }
$serverPid = ''
for ($attempt = 0; $attempt -lt 10; $attempt++) {
    $serverPid = & $adbPath -s $phoneSerial shell pidof shizuku_server
    if ($serverPid) { break }
    Start-Sleep -Milliseconds 300
}
if (-not $serverPid) { throw 'Shizuku server was not detected after startup.' }
Write-Output 'Shizuku server is running. Check that its app shows no restricted-permission warning.'
Write-Output 'On the phone: start FlClash VPN, then open Shizzi and tap Start (VPN mode: Always).'
Write-Output 'A running Shizuku server alone does not verify hotspot forwarding. Test from a connected client.'
