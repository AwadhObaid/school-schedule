param(
    [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'

function Step([string]$Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

if (Test-Path (Join-Path $ProjectRoot 'pubspec.yaml')) {
    $FlutterRoot = $ProjectRoot
}
elseif (Test-Path (Join-Path $ProjectRoot 'flutter_v2\pubspec.yaml')) {
    $FlutterRoot = Join-Path $ProjectRoot 'flutter_v2'
}
else {
    throw 'Could not find pubspec.yaml. Run this from the project root or flutter_v2.'
}

$AndroidRoot = Join-Path $FlutterRoot 'android'
$GradleProps = Join-Path $AndroidRoot 'gradle.properties'

if (-not (Test-Path $GradleProps)) {
    throw "Android gradle.properties not found: $GradleProps"
}

Step 'Stopping Gradle daemons'
Push-Location $AndroidRoot
try {
    if (Test-Path '.\gradlew.bat') {
        & .\gradlew.bat --stop
    }
}
finally {
    Pop-Location
}

Step 'Disabling Kotlin incremental compilation for this Windows project'
$lines = @(Get-Content $GradleProps -ErrorAction Stop)
$lines = @($lines | Where-Object { $_ -notmatch '^\s*kotlin\.incremental\s*=' })
$lines += 'kotlin.incremental=false'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($GradleProps, $lines, $utf8NoBom)

Step 'Removing project-local Kotlin and Gradle caches'
$targets = @(
    (Join-Path $FlutterRoot 'build'),
    (Join-Path $AndroidRoot '.gradle'),
    (Join-Path $FlutterRoot '.dart_tool')
)
foreach ($target in $targets) {
    if (Test-Path $target) {
        Remove-Item $target -Recurse -Force -ErrorAction Stop
    }
}

Push-Location $FlutterRoot
try {
    Step 'Flutter clean'
    flutter clean
    if ($LASTEXITCODE -ne 0) { throw 'flutter clean failed.' }

    Step 'Resolving packages'
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }

    Step 'Analyzing Flutter V2'
    flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed.' }

    Step 'Running tests'
    flutter test
    if ($LASTEXITCODE -ne 0) { throw 'flutter test failed.' }

    Step 'Building debug APK with Kotlin incremental compilation disabled'
    flutter build apk --debug
    if ($LASTEXITCODE -ne 0) { throw 'flutter build apk --debug failed.' }

    $apk = Join-Path $FlutterRoot 'build\app\outputs\flutter-apk\app-debug.apk'
    Write-Host ''
    Write-Host 'SCHOOL SCHEDULE FLUTTER V2 PHASE 01 ANDROID BUILD COMPLETED' -ForegroundColor Green
    Write-Host "APK: $apk" -ForegroundColor Green
}
finally {
    Pop-Location
}
