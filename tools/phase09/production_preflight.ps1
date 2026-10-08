param(
    [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
$StablePackage = 'com.salaheddine.schedule'
$TestPackage = 'com.salaheddine.schedule.flutterv2'
$ReportRoot = Join-Path $ProjectRoot ('phase09_production_preflight_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))

function Step([string]$Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Warn([string]$Message) {
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Ok([string]$Message) {
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Get-PackageDump([string]$PackageName) {
    $raw = adb shell dumpsys package $PackageName 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $raw) {
        return $null
    }

    $joined = ($raw -join [Environment]::NewLine)
    if ($joined -notmatch [regex]::Escape($PackageName)) {
        return $null
    }

    return $joined
}

function Read-Metadata([string]$Dump) {
    if (-not $Dump) { return $null }

    $versionName = [regex]::Match($Dump, 'versionName=([^\s]+)').Groups[1].Value
    $versionCode = [regex]::Match($Dump, 'versionCode=(\d+)').Groups[1].Value
    $minSdk = [regex]::Match($Dump, 'minSdk=(\d+)').Groups[1].Value
    $targetSdk = [regex]::Match($Dump, 'targetSdk=(\d+)').Groups[1].Value
    $firstInstall = [regex]::Match($Dump, 'firstInstallTime=([^\r\n]+)').Groups[1].Value.Trim()
    $lastUpdate = [regex]::Match($Dump, 'lastUpdateTime=([^\r\n]+)').Groups[1].Value.Trim()

    return [ordered]@{
        versionName = $versionName
        versionCode = $versionCode
        minSdk = $minSdk
        targetSdk = $targetSdk
        firstInstallTime = $firstInstall
        lastUpdateTime = $lastUpdate
    }
}

function Find-ApkSigner {
    $command = Get-Command apksigner -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $sdkCandidates = @(
        $env:ANDROID_SDK_ROOT,
        $env:ANDROID_HOME,
        (Join-Path $env:LOCALAPPDATA 'Android\Sdk')
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

    foreach ($sdk in $sdkCandidates) {
        $buildTools = Join-Path $sdk 'build-tools'
        if (-not (Test-Path $buildTools)) { continue }

        $candidate = Get-ChildItem $buildTools -Directory |
            Sort-Object Name -Descending |
            ForEach-Object { Join-Path $_.FullName 'apksigner.bat' } |
            Where-Object { Test-Path $_ } |
            Select-Object -First 1

        if ($candidate) { return $candidate }
    }

    return $null
}

function Get-InstalledApk([string]$PackageName, [string]$Destination) {
    $line = adb shell pm path $PackageName 2>$null |
        Select-String '^package:' |
        Select-Object -First 1

    if (-not $line) { return $null }

    $remotePath = $line.ToString().Substring('package:'.Length).Trim()
    adb pull $remotePath $Destination | Out-Null

    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $Destination)) {
        return $null
    }

    return $Destination
}

New-Item -ItemType Directory -Path $ReportRoot -Force | Out-Null
$ReportFile = Join-Path $ReportRoot 'production_preflight.txt'

Step 'Checking prerequisites'

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    throw 'adb was not found in PATH.'
}

$state = (adb get-state 2>$null | Select-Object -First 1)
if ($LASTEXITCODE -ne 0 -or $state -ne 'device') {
    throw 'No authorized Android device is connected.'
}
Ok 'ADB device is connected and authorized.'

$report = New-Object System.Collections.Generic.List[string]
$report.Add('SCHOOL SCHEDULE FLUTTER V2 - PHASE 09 PRODUCTION PREFLIGHT')
$report.Add('Generated: ' + (Get-Date).ToString('s'))
$report.Add('')

Step 'Inspecting stable legacy package'
$stableDump = Get-PackageDump $StablePackage

if ($stableDump) {
    $stableMeta = Read-Metadata $stableDump
    Ok "$StablePackage is installed."
    $report.Add("Stable package: $StablePackage")
    foreach ($item in $stableMeta.GetEnumerator()) {
        $report.Add(('  {0}: {1}' -f $item.Key, $item.Value))
    }
} else {
    Warn "$StablePackage is not installed on the connected device."
    $report.Add("Stable package: NOT INSTALLED")
}

$report.Add('')

Step 'Inspecting Flutter V2 side-by-side test package'
$testDump = Get-PackageDump $TestPackage

if ($testDump) {
    $testMeta = Read-Metadata $testDump
    Ok "$TestPackage is installed."
    $report.Add("Flutter V2 test package: $TestPackage")
    foreach ($item in $testMeta.GetEnumerator()) {
        $report.Add(('  {0}: {1}' -f $item.Key, $item.Value))
    }
} else {
    Warn "$TestPackage is not installed on the connected device."
    $report.Add("Flutter V2 test package: NOT INSTALLED")
}

$report.Add('')

Step 'Reading current local Flutter V2 version'
$pubspec = Join-Path $ProjectRoot 'flutter_v2\pubspec.yaml'
if (Test-Path $pubspec) {
    $versionLine = Get-Content $pubspec | Where-Object { $_ -match '^version:\s*' } | Select-Object -First 1
    $localVersion = if ($versionLine) { ($versionLine -replace '^version:\s*', '').Trim() } else { 'UNKNOWN' }
    Ok "Local Flutter V2 version: $localVersion"
    $report.Add("Local Flutter V2 version: $localVersion")
} else {
    Warn 'flutter_v2\pubspec.yaml was not found.'
    $report.Add('Local Flutter V2 version: NOT FOUND')
}

$report.Add('')

Step 'Checking release signing environment variable presence'
$signingVars = @(
    'RELEASE_KEYSTORE_PATH',
    'RELEASE_KEYSTORE_PASSWORD',
    'RELEASE_KEY_ALIAS',
    'RELEASE_KEY_PASSWORD'
)

foreach ($name in $signingVars) {
    $value = [Environment]::GetEnvironmentVariable($name)
    $present = -not [string]::IsNullOrWhiteSpace($value)
    if ($name -eq 'RELEASE_KEYSTORE_PATH' -and $present) {
        $present = Test-Path $value
    }

    if ($present) {
        Ok "$name is available."
        $report.Add("${name}: PRESENT")
    } else {
        Warn "$name is missing or invalid."
        $report.Add("${name}: MISSING")
    }
}

$report.Add('')

Step 'Reading installed stable signing certificate'
$apksigner = Find-ApkSigner

if (-not $stableDump) {
    Warn 'Stable package signature cannot be checked because the package is not installed.'
    $report.Add('Stable certificate SHA-256: NOT CHECKED')
} elseif (-not $apksigner) {
    Warn 'apksigner was not found. Signature fingerprint was not extracted.'
    $report.Add('Stable certificate SHA-256: APKSIGNER NOT FOUND')
} else {
    $pulledApk = Join-Path $ReportRoot 'legacy-installed-base.apk'
    $apk = Get-InstalledApk $StablePackage $pulledApk

    if (-not $apk) {
        Warn 'Unable to pull the installed stable APK.'
        $report.Add('Stable certificate SHA-256: APK PULL FAILED')
    } else {
        $signerOutput = & $apksigner verify --print-certs $apk 2>&1
        $digestLine = $signerOutput |
            Select-String 'Signer #1 certificate SHA-256 digest:' |
            Select-Object -First 1

        if ($digestLine) {
            $digest = ($digestLine.ToString() -split ':', 2)[1].Trim()
            Ok "Stable certificate SHA-256: $digest"
            $report.Add("Stable certificate SHA-256: $digest")
            Set-Content -Path (Join-Path $ReportRoot 'legacy_certificate_sha256.txt') -Value $digest -Encoding ASCII
        } else {
            Warn 'Certificate digest was not found in apksigner output.'
            $report.Add('Stable certificate SHA-256: NOT FOUND')
        }

        Remove-Item $pulledApk -Force -ErrorAction SilentlyContinue
    }
}

$report.Add('')
$report.Add('IMPORTANT:')
$report.Add('- This checker made no package/data changes.')
$report.Add('- Do not uninstall the stable legacy package.')
$report.Add('- Final production APK must use com.salaheddine.schedule.')
$report.Add('- Final production APK must be signed by the same certificate shown above.')
$report.Add('- An in-place upgrade rehearsal is still required before release.')

$report | Set-Content -Path $ReportFile -Encoding UTF8

Write-Host ''
Write-Host 'SCHOOL SCHEDULE PHASE 09 PRODUCTION PREFLIGHT COMPLETED' -ForegroundColor Green
Write-Host "Report : $ReportFile"
