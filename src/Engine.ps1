# ============================================================================
#  SwitchDeck - Engine
#  Botoes (som + voz + microfone + telas), icones, atalhos e exportacao.
#  Sem dependencias externas: Windows PowerShell 5.1 + .NET Framework.
#  Arquivo em ASCII puro; todo texto para o usuario vem de messages.json (UTF-8).
# ============================================================================

$script:SDRoot      = Split-Path -Parent $PSScriptRoot
$script:SDData      = Join-Path $script:SDRoot 'data'
if ($env:SWITCHDECK_DATA) { $script:SDData = $env:SWITCHDECK_DATA }   # testes: dados em outra pasta
$script:SDIconDir   = Join-Path $script:SDData 'icons'
$script:SDLayoutDir = Join-Path $script:SDData 'profiles'
$script:SDShortDir  = Join-Path $script:SDData 'shortcuts'
$script:SDBackupDir = Join-Path $script:SDData 'backups'
$script:SDConfig    = Join-Path $script:SDData 'config.json'
$script:SDRunHidden = Join-Path $script:SDRoot 'bin\RunHidden.exe'
$script:SDRunScript = Join-Path $script:SDRoot 'Run.ps1'
$script:SDUtf8      = New-Object System.Text.UTF8Encoding($false)

foreach ($d in @($script:SDData,$script:SDIconDir,$script:SDLayoutDir,$script:SDShortDir,(Join-Path $script:SDRoot 'bin'))) {
    if (-not (Test-Path -LiteralPath $d)) { [void][System.IO.Directory]::CreateDirectory($d) }
}

. (Join-Path $PSScriptRoot 'Icons.ps1')

$script:SDMsg = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot 'messages.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
function _sdText([string]$group,[string]$key) {
    $v = $script:SDMsg.$group.$key
    if ($null -eq $v) { return "$group.$key" }
    if ($args.Count) { return ($v -f $args) }
    return $v
}

# ---------------------------------------------------------------------------
#  Codigo nativo (audio + telas). A DLL leva no nome o resumo do .cs: mudou o
#  fonte, compila outra; nunca tenta sobrescrever uma DLL em uso.
# ---------------------------------------------------------------------------
function Import-SDNative {
    if ('SwitchDeck.AudioNative' -as [type]) { return }
    $cs = Join-Path $PSScriptRoot 'Native.cs'
    $sha = [System.Security.Cryptography.SHA1]::Create()
    try { $hash = ([System.BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes($cs))) -replace '-','').Substring(0,10).ToLowerInvariant() } finally { $sha.Dispose() }
    $dll = Join-Path $script:SDRoot ("bin\SwitchDeck.Native.$hash.dll")
    if (-not (Test-Path -LiteralPath $dll)) {
        try { Add-Type -Path $cs -OutputAssembly $dll -ErrorAction Stop } catch { }
    }
    if (Test-Path -LiteralPath $dll) { try { Add-Type -Path $dll -ErrorAction Stop } catch { } }
    if (-not ('SwitchDeck.AudioNative' -as [type])) { Add-Type -Path $cs }
}
Import-SDNative

# ---------------------------------------------------------------------------
#  Nomes de aparelho
# ---------------------------------------------------------------------------
# Nome curto para exibir: "Fones de ouvido (A50 Game)" -> "A50 Game"
function _sdShort([string]$name) {
    if (-not $name) { return '' }
    $n = ($name -replace '^\s*\d+-\s*','').Trim()
    $inner = ''; $outer = $n
    if ($n -match '^(.*)\(([^()]+)\)\s*$') { $outer = $Matches[1].Trim(); $inner = ($Matches[2] -replace '^\s*\d+-\s*','') }
    $clean = ($inner -replace '(?i)\b(High Definition Audio Device|High Definition Audio|NVIDIA|Realtek\(R\) Audio|Realtek|USB Audio Device|Audio Device|Device)\b','' -replace '\s+',' ').Trim(' -')
    if ($clean.Length -ge 2) { return $clean }
    if ($outer.Length -ge 2) { return $outer }
    return $n
}
# Forma de comparar: sem o prefixo "2- " que o Windows cria ao trocar de porta USB
function _sdNorm([string]$name) {
    if (-not $name) { return '' }
    return (($name -replace '(^|\()\s*\d+-\s*','$1' -replace '\s+',' ').Trim().ToLowerInvariant())
}
function _sdSame([string]$a,[string]$b) {
    if (-not $a -or -not $b) { return $false }
    if ((_sdNorm $a) -eq (_sdNorm $b)) { return $true }
    return ((_sdNorm (_sdShort $a)) -eq (_sdNorm (_sdShort $b)))
}
function _sdFind($list,[string]$name) {
    if (-not $name) { return $null }
    foreach ($d in $list) { if ($d.Name -eq $name) { return $d } }
    $n = _sdNorm $name
    foreach ($d in $list) { if ((_sdNorm $d.Name) -eq $n) { return $d } }
    $s = _sdNorm (_sdShort $name)
    foreach ($d in $list) { if ((_sdNorm (_sdShort $d.Name)) -eq $s) { return $d } }
    return $null
}
function _sdRaw([int]$flow) { return @([SwitchDeck.AudioNative]::List($flow)) }
function _sdPublic($d) { [pscustomobject]@{ Name = $d.Name; Short = (_sdShort $d.Name); IsDefault = [bool]$d.IsDefault; IsComm = [bool]$d.IsComm } }

function Get-SDDevices {
    [pscustomobject]@{
        Outputs = @(_sdRaw 0 | ForEach-Object { _sdPublic $_ })
        Mics    = @(_sdRaw 1 | ForEach-Object { _sdPublic $_ })
    }
}

function Get-SDState {
    $o = [SwitchDeck.AudioNative]::DefaultName(0,0); $oc = [SwitchDeck.AudioNative]::DefaultName(0,2)
    $m = [SwitchDeck.AudioNative]::DefaultName(1,0); $mc = [SwitchDeck.AudioNative]::DefaultName(1,2)
    $count = 0; $screens = ''
    try { $count = [SwitchDeck.DisplayNative]::ActiveCount(); $screens = [SwitchDeck.DisplayNative]::DescribeCurrent() } catch { }
    [pscustomobject]@{
        Output = $o; OutputShort = (_sdShort $o); OutputComm = $oc; OutputCommShort = (_sdShort $oc)
        Mic = $m; MicShort = (_sdShort $m); MicComm = $mc; MicCommShort = (_sdShort $mc)
        ScreenCount = $count; Screens = $screens
    }
}

# ---------------------------------------------------------------------------
#  Arranjos de tela
# ---------------------------------------------------------------------------
function _sdSafeName([string]$name) { return (($name -replace '[\\/:*?"<>|]','_').Trim().TrimEnd('.')) }
function _sdLayoutFile([string]$name) { return (Join-Path $script:SDLayoutDir ((_sdSafeName $name) + '.dat')) }
function _sdLayoutInfo([string]$file) {
    $summary = ''; $count = 0
    try { $summary = [SwitchDeck.DisplayNative]::Describe($file); $count = [SwitchDeck.DisplayNative]::CountOf($file) } catch { }
    [pscustomobject]@{ Name = [System.IO.Path]::GetFileNameWithoutExtension($file); Summary = $summary; ScreenCount = $count }
}
function Get-SDLayouts {
    @(Get-ChildItem -LiteralPath $script:SDLayoutDir -Filter '*.dat' -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object { _sdLayoutInfo $_.FullName })
}
function Save-SDLayout {
    param([Parameter(Mandatory)][string]$Name)
    $safe = _sdSafeName $Name
    if (-not $safe) { throw (_sdText 'run' 'layoutName') }
    $file = _sdLayoutFile $safe
    [SwitchDeck.DisplayNative]::Save($file)
    return (_sdLayoutInfo $file)
}
function Remove-SDLayout {
    param([Parameter(Mandatory)][string]$Name)
    $file = _sdLayoutFile $Name
    if (Test-Path -LiteralPath $file) { [System.IO.File]::Delete($file) }
    $old = [System.IO.Path]::ChangeExtension($file,'.json')   # sobra da versao 1
    if (Test-Path -LiteralPath $old) { [System.IO.File]::Delete($old) }
}

# ---------------------------------------------------------------------------
#  Botoes
# ---------------------------------------------------------------------------
function _sdNull($v) { if ($null -eq $v) { return $null }; $s = ([string]$v).Trim(); if ($s) { return $s }; return $null }
function _sdCore($b) {
    [pscustomobject][ordered]@{
        Id = (_sdNull $b.Id); Name = (_sdNull $b.Name); Top = (_sdNull $b.Top)
        Output = (_sdNull $b.Output); Comm = (_sdNull $b.Comm); Mic = (_sdNull $b.Mic); Layout = (_sdNull $b.Layout)
        Glyph = (_sdNull $b.Glyph); Color = (_sdNull $b.Color)
    }
}
function _sdLoad {
    if (-not (Test-Path -LiteralPath $script:SDConfig)) { return @() }
    $j = [System.IO.File]::ReadAllText($script:SDConfig, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    if (-not $j -or -not $j.buttons) { return @() }
    return @($j.buttons | Where-Object { $_ -and $_.Id } | ForEach-Object { _sdCore $_ })
}
function _sdStore($buttons) {
    $doc = [ordered]@{ version = 2; buttons = @($buttons | Where-Object { $_ -and $_.Id } | ForEach-Object { _sdCore $_ }) }
    [System.IO.File]::WriteAllText($script:SDConfig, ($doc | ConvertTo-Json -Depth 6), $script:SDUtf8)
}
function _sdIconPath([string]$id) { return (Join-Path $script:SDIconDir ($id + '.png')) }
function _sdRender($b,[int]$size,[string]$file,[switch]$Ico) {
    New-SDTileImage -Top $b.Top -Big $b.Name -Glyph $b.Glyph -Color $b.Color -Size $size -OutFile $file -Ico:$Ico | Out-Null
}
function _sdIsActive($b,$state) {
    $any = $false
    if ($b.Output) {
        $any = $true
        if (-not (_sdSame $state.Output $b.Output)) { return $false }
        # voz: o aparelho escolhido, ou o proprio aparelho de som (quando o de voz esta desligado)
        if (-not ((_sdSame $state.OutputComm $b.Output) -or ($b.Comm -and (_sdSame $state.OutputComm $b.Comm)))) { return $false }
    } elseif ($b.Comm) {
        $any = $true
        if (-not (_sdSame $state.OutputComm $b.Comm)) { return $false }
    }
    if ($b.Mic) { $any = $true; if (-not (_sdSame $state.Mic $b.Mic)) { return $false } }
    if ($b.Layout) {
        $any = $true
        $file = _sdLayoutFile $b.Layout
        if (-not (Test-Path -LiteralPath $file)) { return $false }
        try { if (-not [SwitchDeck.DisplayNative]::Matches($file)) { return $false } } catch { return $false }
    }
    return $any
}
function _sdMissing($b,$outs,$mics) {
    $miss = @()
    if ($b.Output -and -not (_sdFind $outs $b.Output)) { $miss += $b.Output }
    if ($b.Comm -and -not (_sdFind $outs $b.Comm)) { $miss += $b.Comm }
    if ($b.Mic -and -not (_sdFind $mics $b.Mic)) { $miss += $b.Mic }
    if ($b.Layout -and -not (Test-Path -LiteralPath (_sdLayoutFile $b.Layout))) { $miss += $b.Layout }
    return ,@($miss)
}
function _sdEnrich($b,$state,$outs,$mics) {
    $icon = _sdIconPath $b.Id
    if (-not (Test-Path -LiteralPath $icon)) { try { _sdRender $b 256 $icon -Ico } catch { } }
    [pscustomobject][ordered]@{
        Id = $b.Id; Name = $b.Name; Top = $b.Top; Output = $b.Output; Comm = $b.Comm; Mic = $b.Mic; Layout = $b.Layout
        Glyph = $b.Glyph; Color = $b.Color; IconPath = $icon
        IsActive = [bool](_sdIsActive $b $state); Missing = (_sdMissing $b $outs $mics)
    }
}

function Get-SDButtons {
    $list = @(_sdLoad)
    if (-not $list.Count) { return @() }
    $state = Get-SDState; $outs = _sdRaw 0; $mics = _sdRaw 1
    return @($list | ForEach-Object { _sdEnrich $_ $state $outs $mics })
}

function New-SDButtonDraft {
    [pscustomobject][ordered]@{
        Id = ([guid]::NewGuid().ToString('N').Substring(0,8)); Name = ''; Top = ''
        Output = $null; Comm = $null; Mic = $null; Layout = $null
        Glyph = 'headset'; Color = '#9FADFF'; IconPath = ''; IsActive = $false; Missing = @()
    }
}

# Sugere nome, rotulo, simbolo e cor a partir do que o botao faz.
function Get-SDSuggestion {
    param([Parameter(Mandatory)]$Button)
    $b = _sdCore $Button
    $main = $b.Output; if (-not $main) { $main = $b.Comm }
    $text = ''
    if ($main) { $text = _sdShort $main } elseif ($b.Mic) { $text = _sdShort $b.Mic } elseif ($b.Layout) { $text = $b.Layout }
    # tira palavras que so repetem o papel do aparelho
    $name = ($text -replace '(?i)\b(Game|Voice|Chat|Mic|Microphone|Microfone|Output|Speakers?|Headphones?|Headset|Stream Out)\b','' -replace '\s+',' ').Trim(' -')
    if ($name.Length -lt 2) { $name = $text }
    if ($name.Length -gt 12) { $first = ($name -split ' ')[0]; if ($first.Length -ge 2 -and $first.Length -le 14) { $name = $first } else { $name = $name.Substring(0,12).Trim() } }
    $parts = @()
    if ($main) { $parts += (_sdText 'top' 'som') }
    if ($b.Mic) { $parts += (_sdText 'top' 'mic') }
    if ($b.Layout) { $parts += (_sdText 'top' 'telas') }
    $top = ($parts -join ' + ')
    if (-not $main -and $b.Mic -and -not $b.Layout) { $top = _sdText 'top' 'micOnly' }
    $probe = ("$main").ToLowerInvariant()
    $glyph = 'speaker'; $color = '#65DCAE'
    if ($main) {
        if ($probe -match 'mixer|sc8|goxlr|wave ?link|voicemeeter|interface|scarlett|focusrite') { $glyph = 'mixer'; $color = '#9FADFF' }
        elseif ($probe -match 'fone|head|a50|arctis|cloud|hyperx|kraken|airpods|buds|earphone') { $glyph = 'headset'; $color = '#9FADFF' }
        elseif ($probe -match '\btv\b|hdmi|nvidia|lg |samsung|sony|display audio') { $glyph = 'speaker'; $color = '#65DCAE' }
        elseif ($probe -match 'caixa|speaker|alto-falante|soundbar|high definition') { $glyph = 'speakers'; $color = '#65DCAE' }
    } elseif ($b.Mic) {
        $glyph = 'mic'; $color = '#C2A2FF'
        if (("$($b.Mic)").ToLowerInvariant() -notmatch 'head|fone|a50') { $glyph = 'desktopmic' }
    } elseif ($b.Layout) {
        $count = 0; try { $count = [SwitchDeck.DisplayNative]::CountOf((_sdLayoutFile $b.Layout)) } catch { }
        if ($count -le 1) { $glyph = 'singletv'; $color = '#F6C66E' } elseif ($count -eq 2) { $glyph = 'dual'; $color = '#BDC9D7' } else { $glyph = 'triple'; $color = '#88B8FF' }
    }
    [pscustomobject]@{ Name = $name.ToUpperInvariant(); Top = $top; Glyph = $glyph; Color = $color }
}

function Save-SDButton {
    param([Parameter(Mandatory)]$Button)
    $b = _sdCore $Button
    if (-not $b.Id) { $b.Id = [guid]::NewGuid().ToString('N').Substring(0,8) }
    if (-not ($b.Output -or $b.Comm -or $b.Mic -or $b.Layout)) { throw (_sdText 'run' 'nothing') }
    if (-not $b.Name -or -not $b.Glyph -or -not $b.Color) {
        $s = Get-SDSuggestion -Button $b
        if (-not $b.Name) { $b.Name = $s.Name }
        if (-not $b.Top) { $b.Top = $s.Top }
        if (-not $b.Glyph) { $b.Glyph = $s.Glyph }
        if (-not $b.Color) { $b.Color = $s.Color }
    }
    if (-not $b.Name) { throw (_sdText 'run' 'noName') }
    $list = @(_sdLoad); $found = $false
    for ($i = 0; $i -lt $list.Count; $i++) { if ($list[$i].Id -eq $b.Id) { $list[$i] = $b; $found = $true } }
    if (-not $found) { $list += $b }
    _sdStore $list
    _sdRender $b 256 (_sdIconPath $b.Id) -Ico
    return (_sdEnrich $b (Get-SDState) (_sdRaw 0) (_sdRaw 1))
}

function Remove-SDButton {
    param([Parameter(Mandatory)][string]$Id)
    _sdStore @(_sdLoad | Where-Object { $_.Id -ne $Id })
    foreach ($ext in '.png','.ico') { $f = Join-Path $script:SDIconDir ($Id + $ext); if (Test-Path -LiteralPath $f) { [System.IO.File]::Delete($f) } }
}

function Move-SDButton {
    param([Parameter(Mandatory)][string]$Id,[Parameter(Mandatory)][int]$Index)
    $list = New-Object System.Collections.ArrayList
    foreach ($x in @(_sdLoad)) { [void]$list.Add($x) }
    $item = $null
    foreach ($x in $list) { if ($x.Id -eq $Id) { $item = $x } }
    if (-not $item) { return }
    $list.Remove($item)
    if ($Index -lt 0) { $Index = 0 }
    if ($Index -gt $list.Count) { $Index = $list.Count }
    $list.Insert($Index,$item)
    _sdStore $list.ToArray()
}

# Executa o botao. Telas primeiro: a saida de som de uma TV so aparece depois que a tela liga.
function Invoke-SDButton {
    param([Parameter(Mandatory)][string]$Id)
    $lines = @(); $warn = @()
    $b = @(_sdLoad | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1
    if (-not $b) { return [pscustomobject]@{ Ok = $false; Lines = @(); Warnings = @(_sdText 'run' 'notFound') } }
    if (-not ($b.Output -or $b.Comm -or $b.Mic -or $b.Layout)) { return [pscustomobject]@{ Ok = $false; Lines = @(); Warnings = @(_sdText 'run' 'nothing') } }

    $waitForDevices = $false
    if ($b.Layout) {
        $file = _sdLayoutFile $b.Layout
        if (-not (Test-Path -LiteralPath $file)) { $warn += (_sdText 'run' 'missingLayout' $b.Layout) }
        else {
            try {
                $code = [SwitchDeck.DisplayNative]::Load($file)
                if ($code -eq 0) { $lines += (_sdText 'run' 'layout' $b.Layout); $waitForDevices = $true }
                else { $warn += (_sdText 'run' 'layoutFailed' $b.Layout $code) }
            } catch { $warn += (_sdText 'run' 'failed' $b.Layout $_.Exception.Message) }
        }
    }

    $outs = _sdRaw 0
    $dev = $null
    if ($b.Output) {
        $dev = _sdFind $outs $b.Output
        if (-not $dev -and $waitForDevices) {
            for ($i = 0; $i -lt 10 -and -not $dev; $i++) { Start-Sleep -Milliseconds 500; $outs = _sdRaw 0; $dev = _sdFind $outs $b.Output }
        }
        if ($dev) {
            try { [SwitchDeck.AudioNative]::SetRoles($dev.Id, $true, (-not $b.Comm)); $lines += (_sdText 'run' 'output' (_sdShort $dev.Name)) }
            catch { $warn += (_sdText 'run' 'failed' (_sdShort $b.Output) $_.Exception.Message); $dev = $null }
        } else { $warn += (_sdText 'run' 'missingOutput' (_sdShort $b.Output)) }
    }
    if ($b.Comm) {
        $cdev = _sdFind $outs $b.Comm
        try {
            if ($cdev) { [SwitchDeck.AudioNative]::SetRoles($cdev.Id, $false, $true); $lines += (_sdText 'run' 'comm' (_sdShort $cdev.Name)) }
            elseif ($dev) { [SwitchDeck.AudioNative]::SetRoles($dev.Id, $false, $true); $lines += (_sdText 'run' 'commFallback' (_sdShort $dev.Name) (_sdShort $b.Comm)) }
            else { $warn += (_sdText 'run' 'missingOutput' (_sdShort $b.Comm)) }
        } catch { $warn += (_sdText 'run' 'failed' (_sdShort $b.Comm) $_.Exception.Message) }
    }
    if ($b.Mic) {
        $mdev = _sdFind (_sdRaw 1) $b.Mic
        if ($mdev) {
            try { [SwitchDeck.AudioNative]::SetRoles($mdev.Id, $true, $true); $lines += (_sdText 'run' 'mic' (_sdShort $mdev.Name)) }
            catch { $warn += (_sdText 'run' 'failed' (_sdShort $b.Mic) $_.Exception.Message) }
        } else { $warn += (_sdText 'run' 'missingMic' (_sdShort $b.Mic)) }
    }
    return [pscustomobject]@{ Ok = ($warn.Count -eq 0); Lines = @($lines); Warnings = @($warn) }
}

function New-SDPreviewIcon {
    param([Parameter(Mandatory)]$Button)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) 'SwitchDeck\preview'
    if (-not (Test-Path -LiteralPath $dir)) { [void][System.IO.Directory]::CreateDirectory($dir) }
    $limit = (Get-Date).AddMinutes(-5)
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter 'p-*.png' -ErrorAction SilentlyContinue)) { if ($f.LastWriteTime -lt $limit) { try { [System.IO.File]::Delete($f.FullName) } catch { } } }
    $b = _sdCore $Button
    $big = $b.Name; if (-not $big) { $big = ' ' }
    $glyph = $b.Glyph; if (-not $glyph) { $glyph = 'headset' }
    $color = $b.Color; if (-not $color) { $color = '#9FADFF' }
    $file = Join-Path $dir ('p-' + [guid]::NewGuid().ToString('N') + '.png')
    New-SDTileImage -Top $b.Top -Big $big -Glyph $glyph -Color $color -Size 256 -OutFile $file | Out-Null
    return $file
}

function Get-SDGlyphs { @($script:SDMsg.glyphs | ForEach-Object { [pscustomobject]@{ Id = $_.Id; Label = $_.Label } }) }
function Get-SDColors { @($script:SDMsg.colors | ForEach-Object { [pscustomobject]@{ Id = $_.Id; Label = $_.Label } }) }

# ---------------------------------------------------------------------------
#  Levar para fora: atalho, comando, icones
# ---------------------------------------------------------------------------
function Confirm-SDRunHidden {
    if (Test-Path -LiteralPath $script:SDRunHidden) { return }
    $cs = Join-Path $PSScriptRoot 'RunHidden.cs'
    try { Add-Type -Path $cs -OutputAssembly $script:SDRunHidden -OutputType WindowsApplication -ErrorAction Stop } catch { }
}
function _sdArgs([string]$id) { return ('-NoProfile -ExecutionPolicy Bypass -File "{0}" -Do button -Id {1}' -f $script:SDRunScript, $id) }
function _sdButton([string]$id) {
    $b = @(_sdLoad | Where-Object { $_.Id -eq $id }) | Select-Object -First 1
    if (-not $b) { throw (_sdText 'run' 'notFound') }
    return $b
}
function _sdFileLabel($b) {
    $label = $b.Name
    if ($b.Top) { $label = $b.Top + ' - ' + $b.Name }
    $label = _sdSafeName $label
    if (-not $label) { $label = $b.Id }
    return $label
}

function Get-SDCommand {
    param([Parameter(Mandatory)][string]$Id)
    [void](_sdButton $Id)
    Confirm-SDRunHidden
    $exe = $script:SDRunHidden
    if ($exe -match '\s') { $exe = '"' + $exe + '"' }
    return ($exe + ' ' + (_sdArgs $Id))
}

function New-SDShortcut {
    param([Parameter(Mandatory)][string]$Id,[switch]$Desktop)
    $b = _sdButton $Id
    Confirm-SDRunHidden
    $ico = [System.IO.Path]::ChangeExtension((_sdIconPath $b.Id),'.ico')
    if (-not (Test-Path -LiteralPath $ico)) { _sdRender $b 256 (_sdIconPath $b.Id) -Ico }
    $folder = $script:SDShortDir
    if ($Desktop) { $folder = [Environment]::GetFolderPath('Desktop') }
    $lnk = Join-Path $folder ((_sdFileLabel $b) + '.lnk')
    $wsh = New-Object -ComObject WScript.Shell
    $sc = $wsh.CreateShortcut($lnk)
    $sc.TargetPath = $script:SDRunHidden
    $sc.Arguments = (_sdArgs $b.Id)
    $sc.WorkingDirectory = $script:SDRoot
    if (Test-Path -LiteralPath $ico) { $sc.IconLocation = "$ico,0" }
    $sc.Save()
    return $lnk
}

function Export-SDIcons {
    param([Parameter(Mandatory)][string]$Folder,[int]$Size = 256)
    if (-not (Test-Path -LiteralPath $Folder)) { [void][System.IO.Directory]::CreateDirectory($Folder) }
    $used = @{}; $n = 0
    foreach ($b in @(_sdLoad)) {
        $label = _sdFileLabel $b
        if ($used.ContainsKey($label.ToLowerInvariant())) { $label = $label + ' ' + $b.Id }
        $used[$label.ToLowerInvariant()] = $true
        _sdRender $b $Size (Join-Path $Folder ($label + '.png'))
        $n++
    }
    return $n
}

# Primeiro uso: um botao para cada aparelho de som ligado agora.
function Add-SDStarterButtons {
    $made = @()
    $existing = @(_sdLoad)
    foreach ($o in @(_sdRaw 0)) {
        $dup = $false
        foreach ($e in $existing) { if ($e.Output -and (_sdSame $e.Output $o.Name)) { $dup = $true } }
        if ($dup) { continue }
        $draft = New-SDButtonDraft
        $draft.Output = $o.Name
        $s = Get-SDSuggestion -Button $draft
        $draft.Name = $s.Name; $draft.Top = $s.Top; $draft.Glyph = $s.Glyph; $draft.Color = $s.Color
        $made += (Save-SDButton -Button $draft)
    }
    return @($made)
}

. (Join-Path $PSScriptRoot 'Ulanzi.ps1')
