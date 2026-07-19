Add-Type -AssemblyName System.Drawing

$W = 1920; $H = 1080
$out = "$env:USERPROFILE\Pictures\Wallpapers"
if (-not (Test-Path $out)) { New-Item -ItemType Directory -Path $out -Force | Out-Null }

$bmp = New-Object System.Drawing.Bitmap($W, $H)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.InterpolationMode = 'HighQualityBicubic'

# --- base vertical gradient: #1a1b26 -> #16161e ---
$rect = New-Object System.Drawing.Rectangle(0, 0, $W, $H)
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect,
    [System.Drawing.ColorTranslator]::FromHtml('#1f2030'),
    [System.Drawing.ColorTranslator]::FromHtml('#15151d'),
    [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
$g.FillRectangle($grad, $rect)
$grad.Dispose()

# --- soft accent glows (radial, low alpha) ---
function Add-Glow($cx, $cy, $radius, $hex, $alpha) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse($cx - $radius, $cy - $radius, $radius * 2, $radius * 2)
    $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
    $c = [System.Drawing.ColorTranslator]::FromHtml($hex)
    $pg.CenterColor = [System.Drawing.Color]::FromArgb($alpha, $c.R, $c.G, $c.B)
    $pg.SurroundColors = @([System.Drawing.Color]::FromArgb(0, $c.R, $c.G, $c.B))
    $script:g.FillPath($pg, $path)
    $pg.Dispose(); $path.Dispose()
}

Add-Glow  380  700  660 '#7aa2f7' 64    # blue,   left, sitting on the horizon
Add-Glow 1560  320  600 '#bb9af7' 52    # purple, upper-right
Add-Glow 1080  760  420 '#7dcfff' 30    # cyan,   just above the ridge line

# --- horizon accent line (drawn BEFORE the ridges so they occlude it) ---
$blend = New-Object System.Drawing.Drawing2D.ColorBlend(5)
$blend.Colors = @(
    [System.Drawing.Color]::FromArgb(0,   122, 162, 247),
    [System.Drawing.Color]::FromArgb(150, 122, 162, 247),
    [System.Drawing.Color]::FromArgb(200, 125, 207, 255),
    [System.Drawing.Color]::FromArgb(150, 187, 154, 247),
    [System.Drawing.Color]::FromArgb(0,   187, 154, 247))
$blend.Positions = @(0.0, 0.25, 0.5, 0.75, 1.0)
$lineBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle(0, 0, $W, 1)),
    [System.Drawing.Color]::Black, [System.Drawing.Color]::Black,
    [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal)
$lineBrush.InterpolationColors = $blend
$g.FillRectangle($lineBrush, 0, 736, $W, 2)
$lineBrush.Dispose()

# --- layered mountain silhouettes ---
function Add-Ridge($points, $hex, $alpha) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $pts = @()
    foreach ($p in $points) { $pts += New-Object System.Drawing.PointF($p[0], $p[1]) }
    $pts += New-Object System.Drawing.PointF($script:W, $script:H)
    $pts += New-Object System.Drawing.PointF(0, $script:H)
    $path.AddPolygon($pts)
    $c = [System.Drawing.ColorTranslator]::FromHtml($hex)
    $br = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($alpha, $c.R, $c.G, $c.B))
    $script:g.FillPath($br, $path)
    $br.Dispose(); $path.Dispose()
}

# far ridge
Add-Ridge @(@(0,742),@(240,660),@(470,726),@(700,600),@(980,706),@(1240,628),@(1520,714),@(1760,656),@(1920,708)) '#24283b' 210
# mid ridge
Add-Ridge @(@(0,846),@(300,772),@(560,834),@(860,742),@(1120,822),@(1420,760),@(1700,830),@(1920,790)) '#1f2233' 235
# near ridge
Add-Ridge @(@(0,940),@(360,884),@(680,936),@(1020,870),@(1360,932),@(1660,888),@(1920,928)) '#191b28' 255

# --- subtle star field in the upper sky ---
$rand = New-Object System.Random(20260719)
for ($i = 0; $i -lt 220; $i++) {
    $x = $rand.Next(0, $W)
    $y = $rand.Next(0, 640)
    $a = $rand.Next(18, 90)
    $s = if ($rand.Next(0, 12) -eq 0) { 2.4 } else { 1.3 }
    $br = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($a, 192, 202, 245))
    $g.FillEllipse($br, [float]$x, [float]$y, [float]$s, [float]$s)
    $br.Dispose()
}

# --- noise dither: breaks up the banding rings in the radial glows ---
# Built once as a small tile, then tiled across the canvas (per-pixel over the
# full 1920x1080 would be far too slow in PowerShell).
$tile = New-Object System.Drawing.Bitmap(256, 256)
$nrand = New-Object System.Random(7331)
for ($y = 0; $y -lt 256; $y++) {
    for ($x = 0; $x -lt 256; $x++) {
        $v = $nrand.Next(0, 2)
        $a = $nrand.Next(0, 9)
        $c = if ($v -eq 0) { [System.Drawing.Color]::FromArgb($a, 255, 255, 255) }
             else          { [System.Drawing.Color]::FromArgb($a, 0, 0, 0) }
        $tile.SetPixel($x, $y, $c)
    }
}
$tex = New-Object System.Drawing.TextureBrush($tile)
$tex.WrapMode = 'Tile'
$g.FillRectangle($tex, 0, 0, $W, $H)
$tex.Dispose(); $tile.Dispose()

$g.Dispose()
$path = Join-Path $out 'tokyo-night.png'
$bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "SAVED: $path"
