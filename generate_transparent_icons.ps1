Add-Type -AssemblyName System.Drawing

$sourcePath = "e:\d\DOCVOICE-ORG\docvoice\web\icons\Icon-512.png"
$source = [System.Drawing.Bitmap]::FromFile($sourcePath)

# Make the white background transparent
# We use MakeTransparent from the Bitmap class
$white = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
$source.MakeTransparent($white)

Write-Host "Source: $($source.Width)x$($source.Height) - Background made transparent"

function Resize-Image {
    param([System.Drawing.Image]$src, [int]$size, [string]$outPath)
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    # Need to clear with transparent background first
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($src, 0, 0, $size, $size)
    $g.Dispose()
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "Created: $outPath ($($size)x$($size))"
}

# Chrome Extension icons (16, 48, 128)
Resize-Image $source 16 "e:\d\DOCVOICE-ORG\docvoice\web_extension\icons\Icon-16.png"
Resize-Image $source 48 "e:\d\DOCVOICE-ORG\docvoice\web_extension\icons\Icon-48.png"
Resize-Image $source 128 "e:\d\DOCVOICE-ORG\docvoice\web_extension\icons\Icon-128.png"
Resize-Image $source 192 "e:\d\DOCVOICE-ORG\docvoice\web_extension\icons\Icon-192.png"

# Favicon (32x32)
Resize-Image $source 32 "e:\d\DOCVOICE-ORG\docvoice\web\favicon.png"

# Save the original transparent one back to the extension
$source.Save("e:\d\DOCVOICE-ORG\docvoice\web_extension\icons\Icon-512.png", [System.Drawing.Imaging.ImageFormat]::Png)

$source.Dispose()

Write-Host "`nAll icons generated successfully with transparent background!"
