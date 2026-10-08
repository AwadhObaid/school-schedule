param(
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$ReleaseNotesFile = '',
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'

$Repo = 'AwadhObaid/school-schedule'
$ProductionPackage = 'com.salaheddine.schedule'
$ExpectedCertificateSha256 = '3845c92da5d39caa76006cfdda25fa2331bfd3542f20d5527cf9e3945524a576'
$StableApkName = 'SchoolSchedule.apk'
$StableShaName = 'SchoolSchedule.sha256'

function Step([string]$Message) { Write-Host "==> $Message" -ForegroundColor Cyan }
function Ok([string]$Message) { Write-Host "[OK] $Message" -ForegroundColor Green }
function Fail([string]$Message) { throw $Message }

function Find-AndroidBuildTool([string]$FileName) {
    $roots = @(
        $env:ANDROID_SDK_ROOT,
        $env:ANDROID_HOME,
        (Join-Path $env:LOCALAPPDATA 'Android\Sdk')
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

    foreach ($root in $roots) {
        $buildTools = Join-Path $root 'build-tools'
        if (-not (Test-Path $buildTools)) { continue }

        $candidate = Get-ChildItem $buildTools -Directory |
            Sort-Object Name -Descending |
            ForEach-Object { Join-Path $_.FullName $FileName } |
            Where-Object { Test-Path $_ } |
            Select-Object -First 1

        if ($candidate) { return $candidate }
    }

    return $null
}

function Read-FlutterVersion([string]$PubspecPath) {
    $line = Get-Content $PubspecPath | Where-Object { $_ -match '^version:\s*' } | Select-Object -First 1
    if (-not $line) { Fail 'Unable to find version in pubspec.yaml.' }

    $value = ($line -replace '^version:\s*', '').Trim()
    if ($value -notmatch '^(?<name>\d+\.\d+\.\d+)\+(?<code>\d+)$') {
        Fail "Version must use x.y.z+build format. Found: $value"
    }

    return [ordered]@{
        full = $value
        name = $Matches.name
        code = [int]$Matches.code
        tag = ('v' + $Matches.name)
    }
}

function Read-ApkBadging([string]$AaptPath, [string]$ApkPath) {
    $output = & $AaptPath dump badging $ApkPath 2>&1
    if ($LASTEXITCODE -ne 0) { Fail 'aapt could not read the APK.' }

    $line = $output | Select-String "^package:" | Select-Object -First 1
    if (-not $line) { Fail 'APK package metadata was not found.' }

    $text = $line.ToString()
    return [ordered]@{
        package = [regex]::Match($text, "name='([^']+)'").Groups[1].Value
        versionCode = [regex]::Match($text, "versionCode='([^']+)'").Groups[1].Value
        versionName = [regex]::Match($text, "versionName='([^']+)'").Groups[1].Value
    }
}

function Read-CertificateSha256([string]$ApkSignerPath, [string]$ApkPath) {
    $output = & $ApkSignerPath verify --print-certs $ApkPath 2>&1
    if ($LASTEXITCODE -ne 0) { Fail 'apksigner verification failed.' }

    $line = $output | Select-String 'Signer #1 certificate SHA-256 digest:' | Select-Object -First 1
    if (-not $line) { Fail 'Unable to read APK signing certificate SHA-256.' }

    return (($line.ToString() -split ':', 2)[1].Trim()).ToLowerInvariant()
}

function Require-SigningEnvironment {
    $required = @(
        'RELEASE_KEYSTORE_PATH',
        'RELEASE_KEYSTORE_PASSWORD',
        'RELEASE_KEY_ALIAS',
        'RELEASE_KEY_PASSWORD'
    )

    $missing = @()

    foreach ($name in $required) {
        $value = [Environment]::GetEnvironmentVariable($name)

        if ([string]::IsNullOrWhiteSpace($value)) {
            $missing += $name
            continue
        }

        if ($name -eq 'RELEASE_KEYSTORE_PATH' -and -not (Test-Path $value)) {
            $missing += $name
        }
    }

    if ($missing.Count -gt 0) {
        Fail ('Release signing is not configured. Missing/invalid: ' + ($missing -join ', '))
    }
}

$FlutterRoot = Join-Path $ProjectRoot 'flutter_v2'
$Pubspec = Join-Path $FlutterRoot 'pubspec.yaml'
$DistRoot = Join-Path $ProjectRoot 'stable_release'

if (-not (Test-Path $Pubspec)) { Fail "Flutter project not found: $FlutterRoot" }
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { Fail 'Flutter was not found in PATH.' }

$aapt = Find-AndroidBuildTool 'aapt.exe'
$apksigner = Find-AndroidBuildTool 'apksigner.bat'

if (-not $aapt) { Fail 'aapt.exe was not found in Android SDK build-tools.' }
if (-not $apksigner) { Fail 'apksigner.bat was not found in Android SDK build-tools.' }

$version = Read-FlutterVersion $Pubspec

Write-Host ''
Write-Host 'SCHOOL SCHEDULE STABLE RELEASE GATE' -ForegroundColor Cyan
Write-Host "Version : $($version.full)"
Write-Host "Tag     : $($version.tag)"
Write-Host "Package : $ProductionPackage"
Write-Host ''

if ($version.code -le 7) { Fail 'Flutter production versionCode must be greater than legacy versionCode 7.' }

Step 'Checking production signing environment'
Require-SigningEnvironment
Ok 'Release signing environment is present.'

Step 'Building release APK'
Push-Location $FlutterRoot
try {
    flutter clean
    if ($LASTEXITCODE -ne 0) { Fail 'flutter clean failed.' }

    flutter pub get
    if ($LASTEXITCODE -ne 0) { Fail 'flutter pub get failed.' }

    flutter analyze
    if ($LASTEXITCODE -ne 0) { Fail 'flutter analyze failed.' }

    flutter test
    if ($LASTEXITCODE -ne 0) { Fail 'flutter test failed.' }

    flutter build apk --release
    if ($LASTEXITCODE -ne 0) { Fail 'flutter build apk --release failed.' }
}
finally {
    Pop-Location
}

$builtApk = Join-Path $FlutterRoot 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $builtApk)) { Fail "Release APK was not created: $builtApk" }

Step 'Verifying package and version inside APK'
$apkMeta = Read-ApkBadging $aapt $builtApk

if ($apkMeta.package -ne $ProductionPackage) {
    Fail "REFUSED: APK package is '$($apkMeta.package)' instead of '$ProductionPackage'. Do not publish the side-by-side test package."
}
if ($apkMeta.versionName -ne $version.name) {
    Fail "REFUSED: APK versionName '$($apkMeta.versionName)' does not match pubspec '$($version.name)'."
}
if ([int]$apkMeta.versionCode -ne $version.code) {
    Fail "REFUSED: APK versionCode '$($apkMeta.versionCode)' does not match pubspec '$($version.code)'."
}
Ok "APK identity verified: $($apkMeta.package) $($apkMeta.versionName) ($($apkMeta.versionCode))"

Step 'Verifying APK signing certificate'
$certificate = Read-CertificateSha256 $apksigner $builtApk

if ($certificate -ne $ExpectedCertificateSha256) {
    Fail "REFUSED: signing certificate mismatch. Expected $ExpectedCertificateSha256 but APK is signed with $certificate"
}
Ok 'Certificate SHA-256 matches the installed stable application.'

Step 'Preparing stable release files'
if (Test-Path $DistRoot) { Remove-Item $DistRoot -Recurse -Force }
New-Item -ItemType Directory -Path $DistRoot -Force | Out-Null

$stableApk = Join-Path $DistRoot $StableApkName
Copy-Item $builtApk $stableApk -Force

$hash = (Get-FileHash $stableApk -Algorithm SHA256).Hash.ToLowerInvariant()
$shaFile = Join-Path $DistRoot $StableShaName
Set-Content -Path $shaFile -Value "$hash  $StableApkName" -Encoding ASCII

$metadata = @(
    "Repository: $Repo",
    "Tag: $($version.tag)",
    "VersionName: $($version.name)",
    "VersionCode: $($version.code)",
    "Package: $ProductionPackage",
    "CertificateSHA256: $certificate",
    "ApkSHA256: $hash"
)
Set-Content -Path (Join-Path $DistRoot 'release-metadata.txt') -Value $metadata -Encoding UTF8

Ok "Stable APK prepared: $stableApk"
Ok "APK SHA-256: $hash"

if (-not $Publish) {
    Write-Host ''
    Write-Host 'VALIDATION COMPLETED - NOTHING WAS PUBLISHED' -ForegroundColor Green
    Write-Host 'Run again with -Publish only after the in-place upgrade test succeeds.'
    Write-Host 'Stable direct URL after publishing:'
    Write-Host "https://github.com/$Repo/releases/latest/download/$StableApkName"
    exit 0
}

Step 'Checking GitHub CLI authentication'
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Fail 'GitHub CLI (gh) was not found in PATH.' }

gh auth status
if ($LASTEXITCODE -ne 0) { Fail 'GitHub CLI is not authenticated.' }

if ([string]::IsNullOrWhiteSpace($ReleaseNotesFile)) {
    Fail 'Publishing requires -ReleaseNotesFile pointing to the approved release notes.'
}
if (-not (Test-Path $ReleaseNotesFile)) { Fail "Release notes file not found: $ReleaseNotesFile" }

Step 'Ensuring the release tag does not already exist'
gh release view $version.tag --repo $Repo *> $null
if ($LASTEXITCODE -eq 0) { Fail "Release $($version.tag) already exists. Refusing to overwrite it." }

Step 'Publishing GitHub Release'
gh release create $version.tag $stableApk $shaFile --repo $Repo --title "التوقيت المدرسي $($version.name)" --notes-file $ReleaseNotesFile --latest
if ($LASTEXITCODE -ne 0) { Fail 'GitHub Release creation failed.' }

Step 'Verifying published APK asset'
$assetNames = @(gh release view $version.tag --repo $Repo --json assets --jq '.assets[].name')
if ($LASTEXITCODE -ne 0) { Fail 'Unable to verify release assets.' }

if ($assetNames -notcontains $StableApkName) {
    Fail "Release was created but $StableApkName was not found among its assets."
}

Write-Host ''
Write-Host 'STABLE RELEASE PUBLISHED SUCCESSFULLY' -ForegroundColor Green
Write-Host "Release : https://github.com/$Repo/releases/tag/$($version.tag)"
Write-Host "Latest  : https://github.com/$Repo/releases/latest"
Write-Host "APK     : https://github.com/$Repo/releases/latest/download/$StableApkName"
