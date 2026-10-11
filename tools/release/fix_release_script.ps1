$path = ".\tools\release\publish_stable.ps1"
$backup = "$env:TEMP\publish_stable.before_encoding_fix.ps1"
Copy-Item -LiteralPath $path -Destination $backup -Force
$fullPath = (Resolve-Path -LiteralPath $path).Path
$content = [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
$pattern = 'gh release create \$version\.tag \$stableApk \$shaFile --repo \$Repo --title .*? --notes-file \$ReleaseNotesFile --latest'
$replacement = 'gh release create $version.tag $stableApk $shaFile --repo $Repo --title "School Schedule $($version.name)" --notes-file $ReleaseNotesFile --latest'
$updated = [regex]::Replace($content, $pattern, $replacement)
if ($updated -eq $content) { throw 'Expected gh release create line not found. No file changed.' }
[System.IO.File]::WriteAllText($fullPath, $updated, [System.Text.UTF8Encoding]::new($false))
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($fullPath, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
    $errors | Format-List
    Copy-Item -LiteralPath $backup -Destination $fullPath -Force
    throw 'PowerShell parsing failed. The original file was restored from backup.'
}
Write-Host 'PowerShell parser validation passed. Backup saved in TEMP.' -ForegroundColor Green
