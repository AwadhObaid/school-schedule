param(
    [Parameter(Mandatory=$true)]
    [string]$ManifestPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "AndroidManifest.xml not found: $ManifestPath"
}

$androidNs = 'http://schemas.android.com/apk/res/android'
[xml]$xml = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8
$manifest = $xml.DocumentElement

$application = @($manifest.ChildNodes) |
    Where-Object {
        $_.NodeType -eq [System.Xml.XmlNodeType]::Element -and
        $_.LocalName -eq 'application'
    } |
    Select-Object -First 1

if (-not $application) {
    throw 'AndroidManifest.xml does not contain an application element.'
}

$className = 'com.dexterous.flutterlocalnotifications.SchoolScheduleTimeZoneChangeReceiver'
$receiver = $null

foreach ($node in @($application.ChildNodes)) {
    if ($node.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
    if ($node.LocalName -ne 'receiver') { continue }

    if ($node.GetAttribute('name', $androidNs) -eq $className) {
        $receiver = $node
        break
    }
}

if (-not $receiver) {
    $receiver = $xml.CreateElement('receiver')
    $receiver.SetAttribute('name', $androidNs, $className) | Out-Null
    $receiver.SetAttribute('exported', $androidNs, 'false') | Out-Null
    $application.AppendChild($receiver) | Out-Null
}

$existingFilter = @($receiver.ChildNodes) |
    Where-Object {
        $_.NodeType -eq [System.Xml.XmlNodeType]::Element -and
        $_.LocalName -eq 'intent-filter'
    } |
    Select-Object -First 1

if (-not $existingFilter) {
    $existingFilter = $xml.CreateElement('intent-filter')
    $receiver.AppendChild($existingFilter) | Out-Null
}

foreach ($actionName in @(
    'android.intent.action.TIMEZONE_CHANGED',
    'android.intent.action.TIME_SET'
)) {
    $exists = $false
    foreach ($action in @($existingFilter.ChildNodes)) {
        if ($action.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
        if ($action.LocalName -ne 'action') { continue }
        if ($action.GetAttribute('name', $androidNs) -eq $actionName) {
            $exists = $true
            break
        }
    }

    if (-not $exists) {
        $action = $xml.CreateElement('action')
        $action.SetAttribute('name', $androidNs, $actionName) | Out-Null
        $existingFilter.AppendChild($action) | Out-Null
    }
}

$settings = New-Object System.Xml.XmlWriterSettings
$settings.Indent = $true
$settings.Encoding = New-Object System.Text.UTF8Encoding($false)

$writer = [System.Xml.XmlWriter]::Create($ManifestPath, $settings)
try {
    $xml.Save($writer)
}
finally {
    $writer.Dispose()
}

Write-Host '[OK] Dynamic timezone receiver registered.' -ForegroundColor Green
Write-Host 'Actions: TIMEZONE_CHANGED, TIME_SET'
