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
            $text = Get-Content $manifest -Raw -Encoding UTF8
            $text = $text -replace 'android:label="schedule"', 'android:label="التوقيت المدرسي"'
            Set-Content $manifest $text -Encoding UTF8
        }
    } else {
        Step 'Android Flutter scaffold already exists; keeping it'
    }

    Push-Location $FlutterRoot
    try {
        Step 'Cleaning Flutter V2'
        flutter clean

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
