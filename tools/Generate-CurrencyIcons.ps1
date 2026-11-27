param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "..\Media\Currency")
)

Add-Type -AssemblyName System.Drawing

$resolvedOutput = [System.IO.Path]::GetFullPath($OutputDirectory)
[System.IO.Directory]::CreateDirectory($resolvedOutput) | Out-Null

function Convert-HexColor([string]$Value) {
    return [System.Drawing.ColorTranslator]::FromHtml($Value)
}

function New-CoinIcon {
    param(
        [string]$Name,
        [string]$Dark,
        [string]$Rim,
        [string]$Face,
        [string]$Highlight
    )

    $bitmap = [System.Drawing.Bitmap]::new(64, 64)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.Clear([System.Drawing.Color]::Transparent)

    $shadowBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(105, 0, 0, 0))
    $darkBrush = [System.Drawing.SolidBrush]::new((Convert-HexColor $Dark))
    $rimBrush = [System.Drawing.SolidBrush]::new((Convert-HexColor $Rim))
    $faceBrush = [System.Drawing.SolidBrush]::new((Convert-HexColor $Face))
    $highlightBrush = [System.Drawing.SolidBrush]::new((Convert-HexColor $Highlight))
    $edgePen = [System.Drawing.Pen]::new((Convert-HexColor $Dark), 2.5)
    $innerPen = [System.Drawing.Pen]::new((Convert-HexColor $Rim), 2)

    $graphics.FillEllipse($shadowBrush, 5, 7, 54, 54)
    $graphics.FillEllipse($darkBrush, 3, 3, 56, 56)
    $graphics.FillEllipse($rimBrush, 6, 6, 50, 50)
    $graphics.FillEllipse($faceBrush, 11, 11, 40, 40)
    $graphics.DrawEllipse($edgePen, 3, 3, 56, 56)
    $graphics.DrawEllipse($innerPen, 10, 10, 42, 42)
    $graphics.FillEllipse($highlightBrush, 17, 14, 16, 8)
    $graphics.FillEllipse($highlightBrush, 14, 20, 7, 13)

    $path = Join-Path $resolvedOutput ("coin-{0}.png" -f $Name)
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)

    $innerPen.Dispose()
    $edgePen.Dispose()
    $highlightBrush.Dispose()
    $faceBrush.Dispose()
    $rimBrush.Dispose()
    $darkBrush.Dispose()
    $shadowBrush.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}

New-CoinIcon -Name "gold" -Dark "#684005" -Rim "#C98A0B" -Face "#F2C94C" -Highlight "#FFF1A3"
New-CoinIcon -Name "silver" -Dark "#38434D" -Rim "#8996A3" -Face "#D8E0E6" -Highlight "#FFFFFF"
New-CoinIcon -Name "copper" -Dark "#592A18" -Rim "#A44F2C" -Face "#D87B48" -Highlight "#FFD0A3"

Write-Output "Generated currency icons in $resolvedOutput"
