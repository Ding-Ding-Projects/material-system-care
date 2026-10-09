$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$root=Split-Path $PSScriptRoot
[xml]$source=Get-Content "$root\packaging\assets\mark.svg" -Raw
if($source.svg.viewBox -ne '0 0 64 64' -or $source.svg.path[0].d -ne 'M32 10 49 17v15c0 11-9 18-17 22-8-4-17-11-17-22V17Z' -or $source.svg.path[1].d -ne 'm20 32 7 0 4-10 5 20 4-10h5') { throw 'Icon source geometry changed; update the vector renderer with it' }
$background=[Drawing.ColorTranslator]::FromHtml($source.svg.rect.fill)
$shield=[Drawing.ColorTranslator]::FromHtml($source.svg.path[0].fill)
$images=@()
foreach($size in @(16,32,48,256)) {
 $bitmap=[Drawing.Bitmap]::new($size,$size,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
 $graphics=[Drawing.Graphics]::FromImage($bitmap)
 $graphics.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
 $graphics.ScaleTransform($size/64.0,$size/64.0)
 $shape=[Drawing.Drawing2D.GraphicsPath]::new()
 $shape.AddArc(0,0,40,40,180,90); $shape.AddArc(24,0,40,40,270,90); $shape.AddArc(24,24,40,40,0,90); $shape.AddArc(0,24,40,40,90,90); $shape.CloseFigure()
 $brush=[Drawing.SolidBrush]::new($background); $graphics.FillPath($brush,$shape); $brush.Dispose(); $shape.Dispose()
 $shape=[Drawing.Drawing2D.GraphicsPath]::new(); $shape.AddLine(32,10,49,17); $shape.AddLine(49,17,49,32); $shape.AddBezier(49,32,49,43,40,50,32,54); $shape.AddBezier(32,54,24,50,15,43,15,32); $shape.AddLine(15,32,15,17); $shape.CloseFigure()
 $brush=[Drawing.SolidBrush]::new($shield); $graphics.FillPath($brush,$shape); $brush.Dispose(); $shape.Dispose()
 $pen=[Drawing.Pen]::new($background,4); $pen.LineJoin=[Drawing.Drawing2D.LineJoin]::Round; $pen.StartCap=[Drawing.Drawing2D.LineCap]::Round; $pen.EndCap=$pen.StartCap
 $points=[Drawing.PointF[]]@([Drawing.PointF]::new(20,32),[Drawing.PointF]::new(27,32),[Drawing.PointF]::new(31,22),[Drawing.PointF]::new(36,42),[Drawing.PointF]::new(40,32),[Drawing.PointF]::new(45,32))
 $graphics.DrawLines($pen,$points); $pen.Dispose(); $graphics.Dispose()
 $stream=[IO.MemoryStream]::new(); $bitmap.Save($stream,[Drawing.Imaging.ImageFormat]::Png); $images+=,@{size=$size;bytes=$stream.ToArray()}; $stream.Dispose()
 if($size -eq 256) { New-Item -ItemType Directory -Force "$root\artifacts\branding" | Out-Null; $bitmap.Save("$root\artifacts\branding\icon-preview.png",[Drawing.Imaging.ImageFormat]::Png) }
 $bitmap.Dispose()
}
$output=[IO.MemoryStream]::new(); $writer=[IO.BinaryWriter]::new($output)
$writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$images.Count)
$offset=6+16*$images.Count
foreach($image in $images) { $dimension=if($image.size -eq 256) { 0 } else { $image.size }; $writer.Write([byte]$dimension); $writer.Write([byte]$dimension); $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([uint16]1); $writer.Write([uint16]32); $writer.Write([uint32]$image.bytes.Length); $writer.Write([uint32]$offset); $offset+=$image.bytes.Length }
foreach($image in $images) { $writer.Write([byte[]]$image.bytes) }
$writer.Flush(); [IO.File]::WriteAllBytes("$root\desktop\windows\runner\resources\app_icon.ico",$output.ToArray()); $writer.Dispose(); $output.Dispose()
Write-Host 'Product icon generated: 16, 32, 48, 256 pixels from the retained shield/pulse vector.'
