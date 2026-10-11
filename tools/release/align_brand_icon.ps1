param(
    [Parameter(Mandatory = $true)]
    [string]$ImagePath
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $ImagePath)) {
    throw "Brand icon asset not found: $ImagePath"
}

Add-Type -AssemblyName System.Drawing
$fullPath = (Resolve-Path -LiteralPath $ImagePath).Path
$tempPath = "$fullPath.brand.tmp.png"
$bitmap = [System.Drawing.Bitmap]::new($fullPath)
try {
    $brandGreen = [System.Drawing.Color]::FromArgb(47, 125, 90)
    $changed = 0
    for ($y = 0; $y -lt $bitmap.Height; $y++) {
        for ($x = 0; $x -lt $bitmap.Width; $x++) {
            $pixel = $bitmap.GetPixel($x, $y)
            if ($pixel.A -gt 0 -and
                ($pixel.B -gt ($pixel.R + 10)) -and
                ($pixel.B -gt ($pixel.G + 8))) {
                $bitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($pixel.A, $brandGreen.R, $brandGreen.G, $brandGreen.B))
                $changed++
            }
        }
    }
    if ($changed -eq 0) {
        throw 'No blue-dominant pixels were found; refusing to silently alter an unexpected icon asset.'
    }
    $bitmap.Save($tempPath, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $bitmap.Dispose()
}

try {
    Move-Item -LiteralPath $tempPath -Destination $fullPath -Force
    Write-Host "Brand identity aligned: converted $changed blue pixels to #2F7D5A in $fullPath" -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force }
}
