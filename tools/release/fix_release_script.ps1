$path = ".\tools\release\publish_stable.ps1"
$backup = "$env:TEMP\publish_stable.before_fix.ps1"
$fullPath = (Resolve-Path -LiteralPath $path).Path
Copy-Item -LiteralPath $fullPath -Destination $backup -Force
$content = [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
$pattern = 'gh release create \$version\.tag \$stableApk \$shaFile --repo \$Repo --title .*? --notes-file \$ReleaseNotesFile --latest'
$replacement = 'gh release create $version.tag $stableApk $shaFile --repo $Repo --title "School Schedule $($version.name)" --notes-file $ReleaseNotesFile --latest'
if ($content -match $pattern) {
    $content = [regex]::Replace($content, $pattern, $replacement)
} elseif ($content -notmatch 'gh release create \$version\.tag') {
    throw 'Could not find GitHub release creation command. Original file was left unchanged.'
}
[System.IO.File]::WriteAllText($fullPath, $content, [System.Text.UTF8Encoding]::new($false))
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($fullPath, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
    $errors | Format-List
    Copy-Item -LiteralPath $backup -Destination $fullPath -Force
    throw 'PowerShell parsing failed; original script restored from backup.'
}
Write-Host 'Release script parsing passed.' -ForegroundColor Green
Write-Host "Backup: $backup"
