# ============================================================================
#  SwitchDeck - Core
#  Áudio (saída/microfone), monitores (perfis CCD), ícones e atalhos.
#  Sem dependências externas (apenas .NET Framework / Windows PowerShell).
# ============================================================================

$script:AppRoot   = Split-Path -Parent $PSScriptRoot
$script:DataDir   = Join-Path $AppRoot 'data'
$script:ProfDir   = Join-Path $DataDir 'profiles'
$script:IconDir   = Join-Path $DataDir 'icons'
$script:ShortDir  = Join-Path $DataDir 'shortcuts'
$script:RunHidden = Join-Path $AppRoot 'bin\RunHidden.exe'
$script:RunScript = Join-Path $AppRoot 'Run.ps1'
foreach ($d in @($DataDir,$ProfDir,$IconDir,$ShortDir)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null } }

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

# ---------------------------------------------------------------------------
#  Carrega os tipos nativos (áudio + monitores). Compila a DLL na 1ª vez.
# ---------------------------------------------------------------------------
function Import-SDNative {
    if ('SwitchDeck.AudioNative' -as [type]) { return }
    $dll = Join-Path $AppRoot 'bin\SwitchDeck.Native.dll'
    $cs  = Join-Path $PSScriptRoot 'Native.cs'
    if (Test-Path $dll) { Add-Type -Path $dll; return }
    # Sem DLL ainda: compila a partir do .cs e gera a DLL para as próximas vezes
    try { Add-Type -Path $cs -OutputAssembly $dll -ErrorAction Stop } catch { }
    if ('SwitchDeck.AudioNative' -as [type]) { return }
    if (Test-Path $dll) { Add-Type -Path $dll } else { Add-Type -Path $cs }
}
Import-SDNative

# ---------------------------------------------------------------------------
#  ÁUDIO
# ---------------------------------------------------------------------------
function Get-SDAudioOutputs { [SwitchDeck.AudioNative]::List(0) }
function Get-SDMicrophones  { [SwitchDeck.AudioNative]::List(1) }
function Set-SDAudioDefault { param([string]$Id) [SwitchDeck.AudioNative]::SetDefault($Id) }

# ---------------------------------------------------------------------------
#  PERFIS DE MONITOR
# ---------------------------------------------------------------------------
function Get-SDProfiles {
    Get-ChildItem $ProfDir -Filter '*.dat' -ErrorAction SilentlyContinue | ForEach-Object {
        $audioId=$null; $audioName=$null
        $json = [IO.Path]::ChangeExtension($_.FullName, '.json')
        if (Test-Path $json) { $m = Get-Content $json -Raw | ConvertFrom-Json; $audioId=$m.AudioId; $audioName=$m.AudioName }
        $desc = try { [SwitchDeck.DisplayNative]::Describe($_.FullName) } catch { '' }
        [PSCustomObject]@{ Name=$_.BaseName; File=$_.FullName; Desc=$desc; AudioId=$audioId; AudioName=$audioName }
    }
}
function Save-SDProfile {
    param([string]$Name, [string]$AudioId, [string]$AudioName)
    $safe = ($Name -replace '[\\/:*?"<>|]', '_').Trim()
    if (-not $safe) { throw "Nome inválido" }
    $dat = Join-Path $ProfDir "$safe.dat"
    [SwitchDeck.DisplayNative]::Save($dat)
    $json = [IO.Path]::ChangeExtension($dat,'.json')
    if ($AudioId) { @{ AudioId=$AudioId; AudioName=$AudioName } | ConvertTo-Json | Set-Content $json -Encoding UTF8 }
    elseif (Test-Path $json) { Remove-Item $json -Force }
    return $dat
}
function Invoke-SDProfile {
    param([string]$File)
    $r = [SwitchDeck.DisplayNative]::Load($File)
    $json = [IO.Path]::ChangeExtension($File, '.json')
    if (Test-Path $json) { $m = Get-Content $json -Raw | ConvertFrom-Json; if ($m.AudioId) { Set-SDAudioDefault $m.AudioId } }
    return $r
}
function Remove-SDProfile {
    param([string]$File)
    Remove-Item $File -ErrorAction SilentlyContinue
    Remove-Item ([IO.Path]::ChangeExtension($File,'.json')) -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
#  ÍCONES (PNG + ICO gerados por GDI+)
# ---------------------------------------------------------------------------
function New-SDIcon {
    param([string]$Type,[string]$Top,[string]$Big,[string]$OutFile,[string]$ColorA,[string]$ColorB)
    function _c([string]$h){ $h=$h.TrimStart('#'); [System.Drawing.Color]::FromArgb(255,[Convert]::ToInt32($h.Substring(0,2),16),[Convert]::ToInt32($h.Substring(2,2),16),[Convert]::ToInt32($h.Substring(4,2),16)) }
    function _round([double]$x,[double]$y,[double]$w,[double]$h,[double]$r){ $p=New-Object System.Drawing.Drawing2D.GraphicsPath; $d=2*$r; $p.AddArc($x,$y,$d,$d,180,90); $p.AddArc($x+$w-$d,$y,$d,$d,270,90); $p.AddArc($x+$w-$d,$y+$h-$d,$d,$d,0,90); $p.AddArc($x,$y+$h-$d,$d,$d,90,90); $p.CloseFigure(); $p }
    $bmp=New-Object System.Drawing.Bitmap(256,256); $g=[System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode='AntiAlias'; $g.TextRenderingHint='AntiAliasGridFit'
    $rect=New-Object System.Drawing.Rectangle(0,0,256,256)
    $grad=New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,(_c $ColorA),(_c $ColorB),90); $g.FillRectangle($grad,$rect)
    $gb=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(28,255,255,255)); $gl=_round 0 0 256 128 4; $g.FillPath($gb,$gl)
    $white=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $soft=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(210,255,255,255))
    $pen=New-Object System.Drawing.Pen([System.Drawing.Color]::White,7.0); $pen.StartCap='Round'; $pen.EndCap='Round'
    $cx=128.0; $cy=112.0; $s=130.0
    switch ($Type) {
      'speaker' { $pts=@((New-Object System.Drawing.PointF(($cx-0.34*$s),($cy-0.12*$s))),(New-Object System.Drawing.PointF(($cx-0.14*$s),($cy-0.12*$s))),(New-Object System.Drawing.PointF(($cx+0.06*$s),($cy-0.30*$s))),(New-Object System.Drawing.PointF(($cx+0.06*$s),($cy+0.30*$s))),(New-Object System.Drawing.PointF(($cx-0.14*$s),($cy+0.12*$s))),(New-Object System.Drawing.PointF(($cx-0.34*$s),($cy+0.12*$s))))
        $g.FillPolygon($white,$pts); $g.DrawArc($pen,($cx+0.10*$s),($cy-0.16*$s),(0.20*$s),(0.32*$s),-60,120); $g.DrawArc($pen,($cx+0.04*$s),($cy-0.26*$s),(0.36*$s),(0.52*$s),-55,110) }
      'mic' { $mp=_round ($cx-0.13*$s) ($cy-0.34*$s) (0.26*$s) (0.40*$s) (0.13*$s); $g.FillPath($white,$mp); $g.DrawArc($pen,($cx-0.22*$s),($cy-0.20*$s),(0.44*$s),(0.44*$s),25,130); $g.DrawLine($pen,$cx,($cy+0.14*$s),$cx,($cy+0.30*$s)); $g.DrawLine($pen,($cx-0.13*$s),($cy+0.30*$s),($cx+0.13*$s),($cy+0.30*$s)) }
      'monitor' { $mp=_round ($cx-0.32*$s) ($cy-0.26*$s) (0.64*$s) (0.42*$s) (0.05*$s); $g.FillPath($white,$mp); $g.DrawLine($pen,$cx,($cy+0.16*$s),$cx,($cy+0.26*$s)); $g.DrawLine($pen,($cx-0.16*$s),($cy+0.28*$s),($cx+0.16*$s),($cy+0.28*$s)) }
    }
    $fTop=New-Object System.Drawing.Font('Segoe UI',15,[System.Drawing.FontStyle]::Bold); $sf=New-Object System.Drawing.StringFormat; $sf.Alignment='Center'
    $g.DrawString($Top.ToUpper(),$fTop,$soft,(New-Object System.Drawing.RectangleF(0,16,256,26)),$sf)
    $size=62.0
    do { $fBig=New-Object System.Drawing.Font('Segoe UI',$size,[System.Drawing.FontStyle]::Bold); if($g.MeasureString($Big,$fBig).Width -le 224 -or $size -le 12){break}; $fBig.Dispose(); $size-=2 } while($true)
    $mb=$g.MeasureString($Big,$fBig)
    $g.DrawString($Big,$fBig,$white,(New-Object System.Drawing.PointF((128-$mb.Width/2),(196-$mb.Height/2))))
    $bmp.Save($OutFile,[System.Drawing.Imaging.ImageFormat]::Png)
    try { $h=$bmp.GetHicon(); $ico=[System.Drawing.Icon]::FromHandle($h); $fs=[IO.File]::Create([IO.Path]::ChangeExtension($OutFile,'.ico')); $ico.Save($fs); $fs.Dispose(); $ico.Dispose() } catch {}
    $g.Dispose(); $bmp.Dispose()
    return $OutFile
}

# ---------------------------------------------------------------------------
#  ATALHOS (.lnk -> RunHidden.exe, sem flash de terminal)
# ---------------------------------------------------------------------------
function Get-SDShortLabel([string]$s) {
    if ($s -match '\(([^)]+)\)') { $inner = ($Matches[1] -replace '\b(High Definition Audio|NVIDIA|Device|Game|Output)\b','' -replace '\s+',' ').Trim(); if ($inner.Length -ge 2) { return $inner } }
    return ($s.Substring(0, [Math]::Min(12, $s.Length))).Trim()
}
function Confirm-SDRunHidden {
    # Compila bin\RunHidden.exe a partir do .cs, se ainda não existir.
    if (Test-Path $RunHidden) { return }
    $cs = Join-Path $PSScriptRoot 'RunHidden.cs'
    try { Add-Type -Path $cs -OutputAssembly $RunHidden -OutputType WindowsApplication -ErrorAction Stop } catch {}
}
function New-SDShortcut {
    param([string]$Name,[string]$Arguments,[string]$IconPath,[switch]$OnDesktop)
    Confirm-SDRunHidden
    $wsh = New-Object -ComObject WScript.Shell
    $targets = @($ShortDir)
    if ($OnDesktop) { $targets += [Environment]::GetFolderPath('Desktop') }
    $made=@()
    foreach ($folder in $targets) {
        $lnk = Join-Path $folder ($Name + '.lnk')
        $sc = $wsh.CreateShortcut($lnk)
        $sc.TargetPath = $RunHidden
        $sc.Arguments  = "-NoProfile -ExecutionPolicy Bypass -File `"$RunScript`" $Arguments"
        $sc.WorkingDirectory = $AppRoot
        $ico = [IO.Path]::ChangeExtension($IconPath,'.ico')
        if ($ico -and (Test-Path $ico)) { $sc.IconLocation = "$ico,0" }
        $sc.Save()
        $made += $lnk
    }
    return $made
}
function New-SDAudioShortcut {
    param($Device,[switch]$Mic,[switch]$OnDesktop)
    $prefix = if ($Mic) { 'Mic' } else { 'Audio' }
    $name = ("$prefix - $($Device.Name)") -replace '[\\/:*?"<>|]', '_'
    $icon = Join-Path $IconDir ($name + '.png')
    New-SDIcon -Type $(if($Mic){'mic'}else{'speaker'}) -Top $prefix -Big (Get-SDShortLabel $Device.Name) -OutFile $icon -ColorA $(if($Mic){'#8B5CF6'}else{'#10B981'}) -ColorB $(if($Mic){'#7C3AED'}else{'#059669'}) | Out-Null
    New-SDShortcut -Name $name -Arguments "-Do audio -Id `"$($Device.Id)`"" -IconPath $icon -OnDesktop:$OnDesktop | Out-Null
    return $name
}
function New-SDProfileShortcut {
    param([string]$ProfileName,[string]$File,[switch]$OnDesktop)
    $name = ("Monitor - $ProfileName") -replace '[\\/:*?"<>|]', '_'
    $icon = Join-Path $IconDir ($name + '.png')
    New-SDIcon -Type 'monitor' -Top 'MONITOR' -Big (Get-SDShortLabel $ProfileName) -OutFile $icon -ColorA '#3B82F6' -ColorB '#2563EB' | Out-Null
    New-SDShortcut -Name $name -Arguments "-Do profile -File `"$File`"" -IconPath $icon -OnDesktop:$OnDesktop | Out-Null
    return $name
}
