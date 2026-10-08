param(
    [Parameter(Mandatory=$true)]
    [string]$FlutterRoot
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

function ColorFromHex([string]$Hex) {
    $value = $Hex.TrimStart('#')
    return [System.Drawing.Color]::FromArgb(
        255,
        [Convert]::ToInt32($value.Substring(0, 2), 16),
        [Convert]::ToInt32($value.Substring(2, 2), 16),
        [Convert]::ToInt32($value.Substring(4, 2), 16)
    )
}

function RoundedRectPath(
    [float]$X,
    [float]$Y,
    [float]$Width,
    [float]$Height,
    [float]$Radius
) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $diameter = $Radius * 2

    $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
    $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
    $path.AddArc(
        $X + $Width - $diameter,
        $Y + $Height - $diameter,
        $diameter,
        $diameter,
        0,
        90
    )
    $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()

    return $path
}

$outDir = Join-Path $FlutterRoot 'assets\images'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$outFile = Join-Path $outDir 'app_icon.png'

$size = 1024
$bitmap = New-Object System.Drawing.Bitmap($size, $size)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)

try {
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    $rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
    $top = ColorFromHex '#4FAF7D'
    $bottom = ColorFromHex '#2F7D5A'

    $gradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $rect,
        $top,
        $bottom,
        90
    )

    try {
        $graphics.FillRectangle($gradient, $rect)
    }
    finally {
        $gradient.Dispose()
    }

    $white = [System.Drawing.Color]::White

    $framePen = New-Object System.Drawing.Pen($white, 42)
    $framePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $framePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $framePen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

    try {
        $frame = RoundedRectPath 195 195 634 634 145
        try {
            $graphics.DrawPath($framePen, $frame)
        }
        finally {
            $frame.Dispose()
        }

        $clockPen = New-Object System.Drawing.Pen($white, 36)
        $clockPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $clockPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

        try {
            $graphics.DrawEllipse($clockPen, 322, 300, 380, 380)
            $graphics.DrawLine($clockPen, 512, 392, 512, 506)
            $graphics.DrawLine($clockPen, 512, 506, 592, 544)
        }
        finally {
            $clockPen.Dispose()
        }

        $standPen = New-Object System.Drawing.Pen($white, 28)
        $standPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $standPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

        try {
            $graphics.DrawLine($standPen, 417, 660, 407, 690)
            $graphics.DrawLine($standPen, 607, 660, 617, 690)
        }
        finally {
            $standPen.Dispose()
        }

        $standBrush = New-Object System.Drawing.SolidBrush($white)
        try {
            $stand = RoundedRectPath 365 690 294 40 18
            try {
                $graphics.FillPath($standBrush, $stand)
            }
            finally {
                $stand.Dispose()
            }
        }
        finally {
            $standBrush.Dispose()
        }
    }
    finally {
        $framePen.Dispose()
    }

    $bitmap.Save($outFile, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $graphics.Dispose()
    $bitmap.Dispose()
}

Write-Host "[OK] Brand icon generated: $outFile" -ForegroundColor Green
