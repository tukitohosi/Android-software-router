param(
    [switch]$CheckOnly,
    [string]$Serial,
    [string]$AdbPath
)
$ErrorActionPreference = 'Stop'

# This helper starts Shizuku only; it does not configure VPN or tethering.
if (-not $AdbPath) {
    $AdbPath = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    if (-not (Test-Path -LiteralPath $AdbPath -PathType Leaf)) {
        $adbCommand = Get-Command adb.exe -ErrorAction SilentlyContinue
        if ($adbCommand) { $AdbPath = $adbCommand.Source }
    }
}
if (-not (Test-Path -LiteralPath $AdbPath -PathType Leaf)) {
    throw 'Install official Android Platform-Tools or pass -AdbPath with its full adb.exe path.'
}
$AdbPath = (Resolve-Path -LiteralPath $AdbPath).Path

function Invoke-AdbChecked {
    param([string[]]$Arguments)
    $result = & $AdbPath @Arguments
    if ($LASTEXITCODE -ne 0) { throw 'An ADB query failed. Check the device connection and debugging authorization.' }
    return $result
}

$deviceRows = @(Invoke-AdbChecked -Arguments @('devices'))
$devices = @()
foreach ($row in $deviceRows) {
    if ($row -match '^([^\s]+)\s+(device|offline|unauthorized)\s*$') {
        $devices += [pscustomobject]@{ Serial = $Matches[1]; State = $Matches[2] }
    }
}
if ($Serial) {
    $selected = @($devices | Where-Object { $_.Serial -ceq $Serial })
    if ($selected.Count -ne 1 -or $selected[0].State -ne 'device') {
        throw 'The selected device is absent, offline, or unauthorized. Unlock it and allow USB debugging.'
    }
} else {
    if ($devices.Count -ne 1 -or $devices[0].State -ne 'device') {
        throw 'Connect and authorize one Android device, or select one explicitly with -Serial from adb devices.'
    }
    $Serial = $devices[0].Serial
}
$target = @('-s', $Serial)
$model = ((Invoke-AdbChecked -Arguments ($target + @('shell', 'getprop', 'ro.product.model'))) -join "`n").Trim()
$sdkText = ((Invoke-AdbChecked -Arguments ($target + @('shell', 'getprop', 'ro.build.version.sdk'))) -join "`n").Trim()
$sdk = 0
if (-not [int]::TryParse($sdkText, [ref]$sdk) -or $sdk -lt 23) {
    throw 'Could not confirm an Android version supported by Shizuku (API 23+).'
}
Write-Output "Selected Android device: $model (API $sdk)."
Write-Output 'This checks Shizuku startup only. Shizzi, VPN, and Wi-Fi relay compatibility need separate validation.'

# Do not restart a healthy server merely because the helper was invoked again.
$serverPid = & $AdbPath @target shell pidof shizuku_server
if ($LASTEXITCODE -eq 0 -and (($serverPid -join ' ').Trim() -match '^\d+(\s+\d+)*$')) {
    Write-Output 'Shizuku server is already running. No startup command was sent.'
} else {
    $packagePaths = @(Invoke-AdbChecked -Arguments ($target + @('shell', 'pm', 'path', 'moe.shizuku.privileged.api')))
    $basePaths = @($packagePaths | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^package:/data/app/[a-zA-Z0-9_~/=+.-]+/base\.apk$' })
    if ($basePaths.Count -ne 1) { throw 'Shizuku is missing or its installation layout is unsupported. Check its app startup instructions.' }
    $packageDir = ($basePaths[0] -replace '^package:', '') -replace '/base\.apk$', ''
    if ($packageDir -match '(^|/)\.\.?(/|$)') { throw 'Unexpected Shizuku installation path.' }
    $packageInfo = @(Invoke-AdbChecked -Arguments ($target + @('shell', 'dumpsys', 'package', 'moe.shizuku.privileged.api')))
    $libraryDirs = @()
    foreach ($line in $packageInfo) {
        if ($line -match '^\s*(?:nativeLibraryDir|legacyNativeLibraryDir)=(\S+)\s*$') {
            $libraryDir = $Matches[1]
            if ($libraryDir -cmatch ('^' + [regex]::Escape($packageDir) + '/lib/(arm64|arm|x86_64|x86)$')) {
                $libraryDirs += $libraryDir
            }
        }
    }
    $libraryDirs = @($libraryDirs | Select-Object -Unique)
    if ($libraryDirs.Count -ne 1) {
        throw 'Could not identify a unique native library directory. Use the startup command shown in the Shizuku app.'
    }
    $starterPath = $libraryDirs[0] + '/libshizuku.so'
    & $AdbPath @target shell test -x $starterPath
    if ($LASTEXITCODE -ne 0) { throw 'This Shizuku installation has no executable starter at its reported library location.' }
    if ($CheckOnly) {
        Write-Output 'Ready: authorized Android device and Shizuku starter found. No phone settings changed.'
        exit 0
    }
    & $AdbPath @target shell $starterPath
    if ($LASTEXITCODE -ne 0) { throw 'Shizuku startup command failed. Check the message above and the Shizuku app.' }
    $running = $false
    for ($attempt = 0; $attempt -lt 10; $attempt++) {
        $serverPid = & $AdbPath @target shell pidof shizuku_server
        if ($LASTEXITCODE -eq 0 -and (($serverPid -join ' ').Trim() -match '^\d+(\s+\d+)*$')) { $running = $true; break }
        Start-Sleep -Milliseconds 300
    }
    if (-not $running) { throw 'Shizuku server was not detected after startup.' }
    Write-Output 'Shizuku server is running. Check that its app shows no restricted-permission warning.'
}
Write-Output 'On the phone: start FlClash VPN, then open Shizzi and tap Start (VPN mode: Always).'
Write-Output 'A running Shizuku server alone does not verify hotspot forwarding. Test from a connected client.'
