# ============================================================================
#  SwitchDeck - Icons
#  Desenha a "tecla" de cada botao (PNG e ICO) com GDI+, sem fonte de icones.
#  Tudo e vetorial num espaco de 196 unidades e escalado para o tamanho pedido.
#  Arquivo em ASCII puro: texto com acento chega por parametro.
# ============================================================================

Add-Type -AssemblyName System.Drawing

$script:SDInk   = [System.Drawing.ColorTranslator]::FromHtml('#131C29')
$script:SDWhite = [System.Drawing.ColorTranslator]::FromHtml('#F5F6F2')
$script:SDMuted = [System.Drawing.ColorTranslator]::FromHtml('#D3DBE5')

function _sdColor([string]$hex) {
    try { return [System.Drawing.ColorTranslator]::FromHtml($hex) } catch { return [System.Drawing.ColorTranslator]::FromHtml('#9FADFF') }
}
function _sdRound([single]$x,[single]$y,[single]$w,[single]$h,[single]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($x,$y,$d,$d,180,90)
    $p.AddArc(($x+$w-$d),$y,$d,$d,270,90)
    $p.AddArc(($x+$w-$d),($y+$h-$d),$d,$d,0,90)
    $p.AddArc($x,($y+$h-$d),$d,$d,90,90)
    $p.CloseFigure()
    return $p
}
function _sdBox($g,$c,[single]$x,[single]$y,[single]$w,[single]$h,[single]$r=0) {
    $b = New-Object System.Drawing.SolidBrush($c)
    try {
        if ($r -gt 0) {
            $p = _sdRound $x $y $w $h $r
            try { $g.FillPath($b,$p) } finally { $p.Dispose() }
        } else { $g.FillRectangle($b,$x,$y,$w,$h) }
    } finally { $b.Dispose() }
}
function _sdEllipse($g,$c,[single]$x,[single]$y,[single]$w,[single]$h) {
    $b = New-Object System.Drawing.SolidBrush($c)
    try { $g.FillEllipse($b,$x,$y,$w,$h) } finally { $b.Dispose() }
}
function _sdStroke($g,$c,[single]$width,[single]$x1,[single]$y1,[single]$x2,[single]$y2) {
    $p = New-Object System.Drawing.Pen($c,$width)
    $p.StartCap = 'Round'; $p.EndCap = 'Round'
    try { $g.DrawLine($p,$x1,$y1,$x2,$y2) } finally { $p.Dispose() }
}
function _sdArc($g,$c,[single]$width,[single]$x,[single]$y,[single]$w,[single]$h,[single]$start,[single]$sweep) {
    $p = New-Object System.Drawing.Pen($c,$width)
    $p.StartCap = 'Round'; $p.EndCap = 'Round'
    try { $g.DrawArc($p,$x,$y,$w,$h,$start,$sweep) } finally { $p.Dispose() }
}
function _sdPolygon($g,$c,[single[]]$coords) {
    $pts = New-Object 'System.Drawing.PointF[]' ($coords.Length / 2)
    for ($i=0; $i -lt $pts.Length; $i++) { $pts[$i] = New-Object System.Drawing.PointF($coords[2*$i],$coords[2*$i+1]) }
    $b = New-Object System.Drawing.SolidBrush($c)
    try { $g.FillPolygon($b,$pts) } finally { $b.Dispose() }
}
# Texto como caminho vetorial, centrado em (cx,cy) e encaixado em maxW x height.
# Mede so a altura das maiusculas/minusculas sem acento, para "SO TV" com acento nao encolher.
function _sdLabel($g,[string]$text,$c,[single]$cx,[single]$cy,[single]$maxW,[single]$height) {
    if ([string]::IsNullOrWhiteSpace($text)) { return }
    $ff = New-Object System.Drawing.FontFamily('Segoe UI')
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $ref = New-Object System.Drawing.Drawing2D.GraphicsPath
    $m = New-Object System.Drawing.Drawing2D.Matrix
    $b = New-Object System.Drawing.SolidBrush($c)
    try {
        $fmt = [System.Drawing.StringFormat]::GenericTypographic
        $origin = New-Object System.Drawing.PointF(0,0)
        $p.AddString($text,$ff,[int][System.Drawing.FontStyle]::Bold,100,$origin,$fmt)
        $ref.AddString('H',$ff,[int][System.Drawing.FontStyle]::Bold,100,$origin,$fmt)
        $bounds = $p.GetBounds(); $cap = $ref.GetBounds()
        if ($bounds.Width -le 0 -or $bounds.Height -le 0) { return }
        $scale = [Math]::Min($maxW/$bounds.Width, $height/$cap.Height)
        $m.Translate($cx,$cy)
        $m.Scale($scale,$scale)
        $m.Translate(-($bounds.X+$bounds.Width/2), -($cap.Y+$cap.Height/2))
        $p.Transform($m)
        $g.FillPath($b,$p)
    } finally { $b.Dispose(); $m.Dispose(); $p.Dispose(); $ref.Dispose(); $ff.Dispose() }
}
function _sdScreen($g,$c,[single]$x,[single]$y,[single]$w,[single]$h,[bool]$stand=$true) {
    _sdBox $g $c $x $y $w $h 7
    _sdBox $g $script:SDInk ($x+7) ($y+7) ($w-14) ($h-14) 2
    if ($stand) {
        _sdStroke $g $c 7 ($x+$w/2) ($y+$h) ($x+$w/2) ($y+$h+11)
        _sdStroke $g $c 7 ($x+$w/2-14) ($y+$h+13) ($x+$w/2+14) ($y+$h+13)
    }
}

# Simbolos desenhados num espaco de 256 unidades, centro em (128,106).
function _sdSymbol($g,[string]$kind,$a) {
    $w = $script:SDWhite
    switch ($kind) {
        'headset' {
            _sdArc $g $w 12 80 56 96 96 180 180
            _sdBox $g $a 73 96 26 47 10
            _sdBox $g $a 157 96 26 47 10
            _sdStroke $g $w 8 169 141 154 151
            _sdBox $g $a 133 144 27 12 6
        }
        'mixer' {
            foreach ($x in @(83,128,173)) { _sdStroke $g $w 8 $x 63 $x 147 }
            _sdBox $g $a 66 77 34 18 6
            _sdBox $g $a 111 116 34 18 6
            _sdBox $g $a 156 88 34 18 6
        }
        'speaker' {
            _sdPolygon $g $a @(68,90,90,90,125,63,125,149,90,122,68,122)
            _sdArc $g $w 9 121 80 44 53 -57 114
            _sdArc $g $a 9 123 61 74 91 -56 112
        }
        'speakers' {
            _sdBox $g $a 69 57 49 99 9
            _sdBox $g $w 138 57 49 99 9
            foreach ($x in @(69,138)) {
                _sdEllipse $g $script:SDInk ($x+17) 70 15 15
                _sdEllipse $g $script:SDInk ($x+9) 103 31 31
                _sdEllipse $g $a ($x+19) 113 11 11
            }
        }
        'mic' {
            _sdBox $g $a 109 55 38 63 19
            _sdBox $g $script:SDInk 120 67 16 6 3
            _sdBox $g $script:SDInk 120 82 16 6 3
            _sdArc $g $w 9 94 79 68 55 0 180
            _sdStroke $g $w 9 128 134 128 151
            _sdStroke $g $w 9 108 153 148 153
        }
        'desktopmic' {
            _sdBox $g $a 106 54 44 72 18
            foreach ($y in @(69,83,97)) { _sdBox $g $script:SDInk 117 $y 22 6 3 }
            _sdStroke $g $w 9 94 93 94 130
            _sdStroke $g $w 9 162 93 162 130
            _sdStroke $g $w 9 94 131 162 131
            _sdStroke $g $w 9 128 132 128 151
            _sdBox $g $w 99 150 58 9 4
        }
        'gamingtv' {
            _sdScreen $g $a 60 62 136 81 $false
            _sdPolygon $g $w @(117,80,117,122,149,101)
            _sdStroke $g $w 8 83 145 75 155
            _sdStroke $g $w 8 173 145 181 155
        }
        'singletv' {
            _sdScreen $g $a 61 65 134 77 $false
            _sdStroke $g $w 9 109 154 147 154
            _sdStroke $g $w 7 128 144 128 151
        }
        'dual' {
            _sdScreen $g $a 46 74 77 62 $true
            _sdScreen $g $w 133 74 77 62 $true
        }
        'triple' {
            _sdScreen $g $a 87 53 82 48 $false
            _sdScreen $g $w 46 109 77 44 $false
            _sdScreen $g $w 133 109 77 44 $false
        }
        'folder' {
            _sdBox $g $a 54 48 61 22 6
            _sdBox $g $a 54 61 148 103 11
            _sdBox $g $script:SDInk 61 68 134 89 6
            foreach ($x in @(100,128,156)) { _sdStroke $g $w 7 $x 92 $x 134 }
            _sdBox $g $a 89 98 22 13 4
            _sdBox $g $a 117 116 22 13 4
            _sdBox $g $a 145 103 22 13 4
        }
        default {
            # simbolo desconhecido: um ponto neutro, para nunca falhar
            _sdEllipse $g $a 98 76 60 60
        }
    }
}

$script:SDGlyphIds = @('headset','mixer','speaker','speakers','mic','desktopmic','gamingtv','singletv','dual','triple')

# Desenha uma tecla. -Size em pixels (196 = Ulanzi D200, 256 = uso geral).
function New-SDTileImage {
    param(
        [string]$Top, [string]$Big, [string]$Glyph, [string]$Color,
        [int]$Size = 256, [Parameter(Mandatory)][string]$OutFile, [switch]$Ico
    )
    $accent = _sdColor $Color
    $bmp = New-Object System.Drawing.Bitmap($Size,$Size,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.SmoothingMode = 'AntiAlias'
        $g.PixelOffsetMode = 'HighQuality'
        $g.Clear($script:SDInk)
        $g.ScaleTransform(($Size/196.0),($Size/196.0))
        _sdBox $g $accent 0 0 196 4
        if ($Top) { _sdLabel $g $Top.ToUpperInvariant() $script:SDMuted 98 23 168 12.5 }
        $state = $g.Save()
        try {
            $g.ScaleTransform((196.0/256),(196.0/256))
            _sdSymbol $g $Glyph $accent
        } finally { $g.Restore($state) }
        _sdBox $g $accent 0 133 196 63
        _sdLabel $g $Big $script:SDInk 98 164.5 168 26
        $dir = Split-Path -Parent $OutFile
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { [void][System.IO.Directory]::CreateDirectory($dir) }
        $bmp.Save($OutFile,[System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $g.Dispose(); $bmp.Dispose() }
    if ($Ico) { ConvertTo-SDIco -PngFile $OutFile | Out-Null }
    return $OutFile
}

# ICO com um PNG de 256 px dentro (formato aceito do Windows Vista em diante).
function ConvertTo-SDIco {
    param([Parameter(Mandatory)][string]$PngFile)
    $src = [System.Drawing.Image]::FromFile($PngFile)
    try {
        $bmp = New-Object System.Drawing.Bitmap(256,256,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        try {
            $g.InterpolationMode = 'HighQualityBicubic'
            $g.DrawImage($src,0,0,256,256)
        } finally { $g.Dispose() }
        $ms = New-Object System.IO.MemoryStream
        try { $bmp.Save($ms,[System.Drawing.Imaging.ImageFormat]::Png); $png = $ms.ToArray() } finally { $ms.Dispose(); $bmp.Dispose() }
    } finally { $src.Dispose() }
    $ico = [System.IO.Path]::ChangeExtension($PngFile,'.ico')
    $fs = [System.IO.File]::Create($ico)
    $bw = New-Object System.IO.BinaryWriter($fs)
    try {
        $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]1)          # ICONDIR
        $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0) # 256x256, sem paleta
        $bw.Write([uint16]1); $bw.Write([uint16]32)                                 # planos, bits
        $bw.Write([uint32]$png.Length); $bw.Write([uint32]22)                       # tamanho, deslocamento
        $bw.Write($png)
    } finally { $bw.Dispose(); $fs.Dispose() }
    return $ico
}
