param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch]$BuildApk
)

$ErrorActionPreference = 'Stop'
$FlutterRoot = Join-Path $RepoRoot 'flutter_v2'
$TempProject = Join-Path $env:TEMP ("school_schedule_flutter_bootstrap_" + [guid]::NewGuid().ToString('N'))

function Step([string]$Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Get-ArabicAppLabel {
    # Build the Arabic label from Unicode code points so this script remains
    # ASCII-only and is safe in Windows PowerShell 5.1 as well as PowerShell 7.
    $codePoints = @(
        0x0627, 0x0644, 0x062A, 0x0648, 0x0642, 0x064A, 0x062A,
        0x0020,
        0x0627, 0x0644, 0x0645, 0x062F, 0x0631, 0x0633, 0x064A
    )
    return -join ($codePoints | ForEach-Object { [char]$_ })
}

function Ensure-WindowsKotlinCrossDriveFix {
    if ($env:OS -ne 'Windows_NT') { return }

    $gradleProps = Join-Path $FlutterRoot 'android\gradle.properties'
    if (-not (Test-Path $gradleProps)) { return }

    Step 'Applying Windows Kotlin cross-drive build compatibility'
    $lines = @(Get-Content $gradleProps -ErrorAction Stop)
    $lines = @($lines | Where-Object { $_ -notmatch '^\s*kotlin\.incremental\s*=' })
    $lines += 'kotlin.incremental=false'

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($gradleProps, $lines, $utf8NoBom)
}

Step 'Checking Flutter SDK'
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter was not found in PATH.'
}

if (-not (Test-Path (Join-Path $FlutterRoot 'pubspec.yaml'))) {
    throw "Flutter V2 source not found: $FlutterRoot"
}

try {
    if (-not (Test-Path (Join-Path $FlutterRoot 'android'))) {
        Step 'Generating isolated Android Flutter scaffold'
        flutter create --platforms=android --org com.salaheddine --project-name schedule $TempProject
        if ($LASTEXITCODE -ne 0) { throw 'flutter create failed.' }

        Copy-Item (Join-Path $TempProject 'android') (Join-Path $FlutterRoot 'android') -Recurse -Force
        if (Test-Path (Join-Path $TempProject '.metadata')) {
            Copy-Item (Join-Path $TempProject '.metadata') (Join-Path $FlutterRoot '.metadata') -Force
        }

        $manifest = Join-Path $FlutterRoot 'android\app\src\main\AndroidManifest.xml'
        if (Test-Path $manifest) {
            $appLabel = Get-ArabicAppLabel
            $replacement = 'android:label="' + $appLabel + '"'
            $text = Get-Content $manifest -Raw -Encoding UTF8
            $text = $text -replace 'android:label="schedule"', $replacement
            Set-Content $manifest $text -Encoding UTF8
        }
    }
    else {
        Step 'Android Flutter scaffold already exists; keeping it'
    }

    Ensure-WindowsKotlinCrossDriveFix

    Push-Location $FlutterRoot
    try {
        Step 'Cleaning Flutter V2'
        flutter clean
        if ($LASTEXITCODE -ne 0) { throw 'flutter clean failed.' }

        Step 'Resolving packages'
        flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }

        Step 'Analyzing Flutter V2'
        flutter analyze
        if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed.' }

        Step 'Running Flutter V2 tests'
        flutter test
        if ($LASTEXITCODE -ne 0) { throw 'flutter test failed.' }

        if ($BuildApk) {
            Step 'Building debug APK'
            flutter build apk --debug
            if ($LASTEXITCODE -ne 0) { throw 'flutter build apk --debug failed.' }
            Write-Host "APK: $(Join-Path $FlutterRoot 'build\app\outputs\flutter-apk\app-debug.apk')" -ForegroundColor Green
        }
    }
    finally {
        Pop-Location
    }

    Write-Host ''
    Write-Host 'SCHOOL SCHEDULE FLUTTER V2 PHASE 01 COMPLETED' -ForegroundColor Green
    Write-Host "Project : $FlutterRoot"
    Write-Host 'Package : com.salaheddine.schedule'
    Write-Host 'Legacy  : Root Capacitor application was not replaced'
}
finally {
    if (Test-Path $TempProject) {
        Remove-Item $TempProject -Recurse -Force -ErrorAction SilentlyContinue
    }
}
