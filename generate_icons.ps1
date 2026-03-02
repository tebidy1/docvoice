Add-Type -AssemblyName System.Drawing

$sourcePath = "e:\d\DOCVOICE-ORG\docvoice\web\icons\Icon-512.png"
$source = [System.Drawing.Image]::FromFile($sourcePath)
Write-Host "Source: $($source.Width)x$($source.Height)"

function Resize-Image {
    param([System.Drawing.Image]$src, [int]$size, [string]$outPath)
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.DrawImage($src, 0, 0, $size, $size)
    $g.Dispose()
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "Created: $outPath ($($size)x$($size))"
}

# Chrome Extension icons (16, 48, 128)
Resize-Image $source 16 "e:\d\DOCVOICE-ORG\docvoice\web\icons\Icon-16.png"
Resize-Image $source 48 "e:\d\DOCVOICE-ORG\docvoice\web\icons\Icon-48.png"
Resize-Image $source 128 "e:\d\DOCVOICE-ORG\docvoice\web\icons\Icon-128.png"

# Favicon (32x32)
Resize-Image $source 32 "e:\d\DOCVOICE-ORG\docvoice\web\favicon.png"

# Windows ICO (256, 48, 32, 16 — multi-size ICO)
# Create individual sizes first
$sizes = @(256, 48, 32, 16)
$bitmaps = @()
foreach ($size in $sizes) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.DrawImage($source, 0, 0, $size, $size)
    $g.Dispose()
    $bitmaps += $bmp
}

# Save as ICO using binary writer
$icoPath = "e:\d\DOCVOICE-ORG\docvoice\windows\runner\resources\app_icon.ico"
$ms = New-Object System.IO.MemoryStream

# Write ICO header
$bw = New-Object System.IO.BinaryWriter($ms)
$bw.Write([UInt16]0)        # Reserved
$bw.Write([UInt16]1)        # Type: 1 = ICO
$bw.Write([UInt16]$bitmaps.Count) # Number of images

# Calculate data offset (header = 6 bytes, each entry = 16 bytes)
$dataOffset = 6 + (16 * $bitmaps.Count)

# Collect PNG data for each bitmap
$pngDataList = @()
foreach ($bmp in $bitmaps) {
    $pngMs = New-Object System.IO.MemoryStream
    $bmp.Save($pngMs, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngDataList += , ($pngMs.ToArray())
    $pngMs.Dispose()
}

# Write directory entries
for ($i = 0; $i -lt $bitmaps.Count; $i++) {
    $size = $sizes[$i]
    $sizeVal = if ($size -ge 256) { 0 } else { $size }
    $bw.Write([byte]$sizeVal) # Width
    $bw.Write([byte]$sizeVal) # Height
    $bw.Write([byte]0)        # Color palette
    $bw.Write([byte]0)        # Reserved
    $bw.Write([UInt16]1)      # Color planes
    $bw.Write([UInt16]32)     # Bits per pixel
    $bw.Write([UInt32]$pngDataList[$i].Length) # Size of data
    $bw.Write([UInt32]$dataOffset)             # Offset of data
    $dataOffset += $pngDataList[$i].Length
}

# Write PNG data
foreach ($pngData in $pngDataList) {
    $bw.Write($pngData)
}

# Save ICO file
[System.IO.File]::WriteAllBytes($icoPath, $ms.ToArray())
$bw.Dispose()
$ms.Dispose()
Write-Host "Created: $icoPath (multi-size ICO with $($sizes -join ', ')px)"

# Cleanup
foreach ($bmp in $bitmaps) { $bmp.Dispose() }
$source.Dispose()

Write-Host "`nAll icons generated successfully!"
