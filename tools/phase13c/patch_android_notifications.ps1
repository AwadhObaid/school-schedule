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

if ($manifest.LocalName -ne 'manifest') {
    throw 'Unexpected AndroidManifest.xml structure.'
}

function Get-AndroidAttribute(
    [System.Xml.XmlElement]$Element,
    [string]$Name
) {
    return $Element.GetAttribute($Name, $androidNs)
}

function Ensure-Permission([string]$Name) {
    foreach ($node in @($manifest.ChildNodes)) {
        if ($node.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
        if ($node.LocalName -ne 'uses-permission') { continue }

        if ((Get-AndroidAttribute $node 'name') -eq $Name) {
            return
        }
    }

    $permission = $xml.CreateElement('uses-permission')
    $permission.SetAttribute('name', $androidNs, $Name) | Out-Null

    $application = @($manifest.ChildNodes) | Where-Object {
        $_.NodeType -eq [System.Xml.XmlNodeType]::Element -and
        $_.LocalName -eq 'application'
    } | Select-Object -First 1

    if ($application) {
        $manifest.InsertBefore($permission, $application) | Out-Null
    }
    else {
        $manifest.AppendChild($permission) | Out-Null
    }
}

function Ensure-Receiver(
    [System.Xml.XmlElement]$Application,
    [string]$ClassName,
    [string[]]$Actions
) {
    foreach ($node in @($Application.ChildNodes)) {
        if ($node.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
        if ($node.LocalName -ne 'receiver') { continue }

        if ((Get-AndroidAttribute $node 'name') -eq $ClassName) {
            return
        }
    }

    $receiver = $xml.CreateElement('receiver')
    $receiver.SetAttribute('name', $androidNs, $ClassName) | Out-Null
    $receiver.SetAttribute('exported', $androidNs, 'false') | Out-Null

    if ($Actions.Count -gt 0) {
        $filter = $xml.CreateElement('intent-filter')

        foreach ($actionName in $Actions) {
            $action = $xml.CreateElement('action')
            $action.SetAttribute('name', $androidNs, $actionName) | Out-Null
            $filter.AppendChild($action) | Out-Null
        }

        $receiver.AppendChild($filter) | Out-Null
    }

    $Application.AppendChild($receiver) | Out-Null
}

Ensure-Permission 'android.permission.POST_NOTIFICATIONS'
Ensure-Permission 'android.permission.VIBRATE'
Ensure-Permission 'android.permission.RECEIVE_BOOT_COMPLETED'
Ensure-Permission 'android.permission.SCHEDULE_EXACT_ALARM'

$application = @($manifest.ChildNodes) | Where-Object {
    $_.NodeType -eq [System.Xml.XmlNodeType]::Element -and
    $_.LocalName -eq 'application'
} | Select-Object -First 1

if (-not $application) {
    throw 'AndroidManifest.xml does not contain an application element.'
}

Ensure-Receiver $application 'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver' @()
Ensure-Receiver $application 'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver' @(
    'android.intent.action.BOOT_COMPLETED',
    'android.intent.action.MY_PACKAGE_REPLACED',
    'android.intent.action.QUICKBOOT_POWERON',
    'com.htc.intent.action.QUICKBOOT_POWER_ON'
)

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

Write-Host '[OK] Android notification scheduling manifest patched.' -ForegroundColor Green
Write-Host 'Permissions: POST_NOTIFICATIONS, VIBRATE, RECEIVE_BOOT_COMPLETED, SCHEDULE_EXACT_ALARM'
Write-Host 'Receivers  : ScheduledNotificationReceiver, ScheduledNotificationBootReceiver'