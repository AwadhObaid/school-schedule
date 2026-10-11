$path = ".\tools\release\publish_stable.ps1"
$fullPath = (Resolve-Path -LiteralPath $path).Path
$content = [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
$pattern = 'gh release create \$version\.tag \$stableApk \$shaFile --repo \$Repo --title .*? --notes-file \$ReleaseNotesFile --latest'
$replacement = 'gh release create $version.tag $stableApk $shaFile --repo $Repo --title "School Schedule $($version.name)" --notes-file $ReleaseNotesFile --latest'
$updated = [regex]::Replace($content, $pattern, $replacement)
if ($updated -eq $content) { throw 'Expected release title line not found; no changes made.' }
[System.IO.File]::WriteAllText($fullPath, $updated, [System.Text.UTF8Encoding]::new($false))
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($fullPath, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) { $errors | Format-List; throw 'PowerShell parser validation failed.' }
Write-Host 'Release script parser validation passed.' -ForegroundColor Green
