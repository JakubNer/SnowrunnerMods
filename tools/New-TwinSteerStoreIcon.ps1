[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\twinsteer_plus_logs\ui\textures\joatTwinsteerStore.png')
)

# Original, reproducible cartoon artwork. No game textures or external art required.
# SnowRunner store cards use UiIcon328x458 and a matching PNG in ui/textures.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$scale = 3
$canvas = [Drawing.Bitmap]::new(328 * $scale, 458 * $scale)
$g = [Drawing.Graphics]::FromImage($canvas)
$g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.ScaleTransform($scale, $scale)
$ink = '#142D38'

function Fill-Box($color, [float]$x, [float]$y, [float]$w, [float]$h) {
    $brush = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($color))
    try { $g.FillRectangle($brush, $x, $y, $w, $h) } finally { $brush.Dispose() }
}
function Draw-Shape($color, [float[]]$coords, [float]$stroke = 2.5, $outline = $ink) {
    $points = [Drawing.PointF[]]@(for ($i = 0; $i -lt $coords.Length; $i += 2) {
        [Drawing.PointF]::new($coords[$i], $coords[$i + 1])
    })
    $brush = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($color))
    $pen = [Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml($outline), $stroke)
    $pen.LineJoin = [Drawing.Drawing2D.LineJoin]::Round
    try {
        $g.FillPolygon($brush, $points)
        if ($stroke -gt 0) { $g.DrawPolygon($pen, $points) }
    } finally { $brush.Dispose(); $pen.Dispose() }
}
function Draw-Oval($color, [float]$x, [float]$y, [float]$w, [float]$h, [float]$stroke = 0, $outline = $ink) {
    $brush = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($color))
    $pen = [Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml($outline), $stroke)
    try {
        $g.FillEllipse($brush, $x, $y, $w, $h)
        if ($stroke -gt 0) { $g.DrawEllipse($pen, $x, $y, $w, $h) }
    } finally { $brush.Dispose(); $pen.Dispose() }
}
function Draw-Line($color, [float]$width, [float]$x1, [float]$y1, [float]$x2, [float]$y2) {
    $pen = [Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml($color), $width)
    $pen.StartCap = $pen.EndCap = [Drawing.Drawing2D.LineCap]::Round
    try { $g.DrawLine($pen, $x1, $y1, $x2, $y2) } finally { $pen.Dispose() }
}
function Draw-Label($text, [float]$size, $color, [float]$y) {
    $font = [Drawing.Font]::new('Arial', $size, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
    $brush = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($color))
    $format = [Drawing.StringFormat]::new()
    $format.Alignment = [Drawing.StringAlignment]::Center
    try { $g.DrawString($text, $font, $brush, [Drawing.RectangleF]::new(0, $y, 328, 65), $format) }
    finally { $font.Dispose(); $brush.Dispose(); $format.Dispose() }
}

try {
    # Warm expedition-poster border, dark header, and pale mountain sky.
    Fill-Box '#EBC98B' 0 0 328 458
    Fill-Box $ink 7 7 314 444
    Fill-Box '#9FC9C3' 15 116 298 245
    Draw-Oval '#F8D895' 216 132 65 65
    Draw-Shape '#6C999D' @(15,235, 70,151, 113,205, 162,137, 238,234, 279,180, 313,225, 313,319, 15,319) 0
    Draw-Shape '#EDF0D9' @(130,179, 162,137, 194,178, 170,167, 161,176, 151,165) 0
    Draw-Shape '#EDF0D9' @(50,181, 70,151, 92,180, 71,170, 65,179) 0
    Draw-Shape '#427B7B' @(15,258, 67,223, 138,250, 214,207, 313,260, 313,328, 15,328) 0
    foreach ($tree in @(@(29,228,39), @(49,239,30), @(290,224,48), @(272,241,34), @(306,251,37))) {
        $x, $y, $h = $tree
        Draw-Line '#28585A' 4 $x $y $x ($y + $h)
        Draw-Shape '#28585A' @($x,($y - 8), ($x - 12),($y + 19), ($x - 7),($y + 18), ($x - 17),($y + 31), ($x + 17),($y + 31), ($x + 7),($y + 18), ($x + 12),($y + 19)) 0
    }
    Draw-Shape '#D5BB83' @(15,327, 103,301, 214,316, 313,302, 313,361, 15,361) 0
    Draw-Oval '#8E916D' 25 324 279 23

    # Long chassis and perspective bed: two steering axles, two rear axles.
    Draw-Shape '#47616A' @(39,296, 288,285, 304,299, 293,319, 42,328) 3
    Draw-Shape '#E8AE51' @(117,278, 285,266, 305,279, 131,295) 3
    Draw-Shape '#A26339' @(131,295, 305,279, 305,289, 131,306) 3
    Draw-Line '#F6D685' 2 141 297 297 283

    # Stacked logs with bright cut ends and bark grain.
    foreach ($log in @(@(145,251,149), @(145,234,149), @(156,218,128))) {
        $x, $y, $length = $log
        Draw-Shape '#986039' @($x,$y, ($x + $length),($y - 8), ($x + $length + 5),($y + 6), ($x + 3),($y + 16)) 2
        Draw-Line '#C58B50' 2 ($x + 11) ($y + 5) ($x + $length - 5) ($y - 2)
        Draw-Oval '#F1C67F' ($x - 6) $y 17 17 2
        Draw-Oval '#C58B50' ($x - 1) ($y + 5) 7 7 1 '#986039'
    }
    foreach ($x in @(176,267)) {
        Draw-Shape '#304B56' @($x,230, ($x + 5),230, ($x + 7),286, ($x + 2),287) 1.5
        Draw-Line '#8CA5A6' 1.5 ($x + 2) 235 ($x + 4) 280
    }

    # Exhaust stack, long orange cab and hood, roof lights, and blue glass.
    Draw-Line $ink 8 128 286 125 220
    Draw-Line '#B7CBCD' 4 128 283 125 220
    Draw-Line $ink 5 125 220 132 216
    Draw-Shape '#CF682E' @(64,236, 109,230, 126,246, 130,304, 65,310) 3
    Draw-Shape '#F4A348' @(55,237, 99,237, 110,253, 111,307, 45,314, 43,276) 3
    Draw-Shape '#FFCB6A' @(55,237, 66,230, 109,230, 99,237) 3
    Draw-Shape '#D87631' @(99,237, 109,230, 126,246, 110,253) 2
    Draw-Shape '#83CDDA' @(60,245, 92,245, 100,262, 58,265) 3
    Draw-Shape '#5795A5' @(106,245, 119,249, 122,265, 110,264) 2
    Draw-Line '#E2F4EA' 3 64 249 85 249
    Draw-Line '#CEEAE3' 2 63 256 76 256
    Draw-Shape '#F3A047' @(27,278, 63,272, 77,284, 72,310, 26,317) 3
    Draw-Shape '#FFD17A' @(27,278, 43,270, 70,268, 78,278, 63,282) 2.5
    Draw-Shape '#405562' @(25,286, 43,287, 43,308, 25,310) 2
    foreach ($x in @(29,34,39)) { Draw-Line '#A1B6B6' 1 $x 290 $x 305 }
    Draw-Shape '#B9C9C6' @(22,310, 48,310, 52,319, 22,322) 2.5
    Draw-Oval '#FFF0BA' 46 289 9 8 2
    Draw-Line '#FAD378' 2 82 274 102 273
    Draw-Line $ink 2 84 283 90 283
    Draw-Line '#7C442D' 1.5 104 270 104 302
    Draw-Line $ink 2.5 54 255 48 255
    Fill-Box '#344F58' 43 251 6 14
    foreach ($x in @(61,76,91)) { Draw-Oval '#FFDE8D' $x 233 6 4 1 }
    Draw-Shape '#90A6A7' @(86,305, 124,301, 128,310, 86,315) 2

    foreach ($wheel in @(@(60,320,19), @(108,317,19), @(245,308,18), @(283,305,18))) {
        $x, $y, $r = $wheel
        Draw-Oval '#24333D' ($x - $r) ($y - $r) ($r * 2) ($r * 2) 3
        Draw-Oval '#40515B' ($x - $r + 4) ($y - $r + 4) (($r - 4) * 2) (($r - 4) * 2) 1 '#728084'
        Draw-Oval '#C0CECA' ($x - 8) ($y - 8) 16 16 2
        Draw-Oval '#536F78' ($x - 3) ($y - 3) 6 6
        foreach ($angle in @(0,90,180,270)) {
            $rad = $angle * [Math]::PI / 180
            Draw-Oval '#304954' ($x + 5 * [Math]::Cos($rad) - 1) ($y + 5 * [Math]::Sin($rad) - 1) 2 2
        }
    }
    # Front fenders emphasize the TwinSteer's separated steering axles.
    Draw-Shape '#ED913D' @(39,304, 49,296, 68,295, 81,303, 81,312, 73,309, 67,303, 51,304, 44,312, 38,313) 2
    Draw-Shape '#ED913D' @(87,301, 98,292, 117,292, 129,301, 129,309, 121,306, 115,300, 100,300, 93,308, 87,310) 2
    Draw-Line '#F5DDAC' 2 24 351 108 351
    Draw-Line '#F5DDAC' 2 213 344 296 344

    Draw-Label '6900' 53 '#F4C77F' 14
    Draw-Label 'TWINSTEER' 30 '#F3EAD5' 72
    Draw-Label 'LONG-LOG HAULER' 19 '#F4C77F' 376
    Draw-Line '#527277' 1.5 49 411 279 411
    Draw-Label 'J o A T' 17 '#F3EAD5' 421

    $output = [IO.Path]::GetFullPath($OutputPath)
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($output)) | Out-Null
    $final = [Drawing.Bitmap]::new(328, 458)
    $resize = [Drawing.Graphics]::FromImage($final)
    try {
        $resize.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $resize.DrawImage($canvas, 0, 0, 328, 458)
        $final.Save($output, [Drawing.Imaging.ImageFormat]::Png)
    } finally { $resize.Dispose(); $final.Dispose() }
    Write-Host "Created $output (328x458 PNG)"
} finally { $g.Dispose(); $canvas.Dispose() }
