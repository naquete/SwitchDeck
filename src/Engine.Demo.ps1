# In-memory demo. Every generated file stays under the process temp directory.
$script:SDDemoRoot = $PSScriptRoot
$script:SDDemoText = Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'ui\strings.json') | ConvertFrom-Json
$script:SDDemoTemp = Join-Path ([IO.Path]::GetTempPath()) ('SwitchDeck-Demo-' + $PID)
$script:SDDemoButtons = New-Object System.Collections.ArrayList
$script:SDDemoLayouts = New-Object System.Collections.ArrayList
foreach ($item in $script:SDDemoText.demoLayouts) { [void]$script:SDDemoLayouts.Add($item) }
foreach ($item in $script:SDDemoText.demoButtons) {
    $item.IconPath = Join-Path $PSScriptRoot ('ui\demo\' + $item.IconPath)
    [void]$script:SDDemoButtons.Add($item)
}
$script:SDDemoState = [pscustomobject]@{
    Output = $script:SDDemoText.demoOutput; OutputShort = $script:SDDemoText.demoOutput
    OutputComm = $script:SDDemoText.demoComm; OutputCommShort = $script:SDDemoText.demoComm
    Mic = $script:SDDemoText.demoMic; MicShort = 'Tank3'
    MicComm = $script:SDDemoText.demoMic; MicCommShort = 'Tank3'
    ScreenCount = 2; Screens = $script:SDDemoText.demoLayout
}
$script:SDDemoCurrentLayout = $script:SDDemoText.demoLayouts[0].Name

function Copy-SDDemoObject($Value) { $Value | ConvertTo-Json -Depth 12 -Compress | ConvertFrom-Json }
function Get-SDDevices {
    $outputs = @(foreach ($item in $script:SDDemoText.demoOutputs) { Copy-SDDemoObject $item })
    $mics = @(foreach ($item in $script:SDDemoText.demoMics) { Copy-SDDemoObject $item })
    foreach ($o in $outputs) { $o.IsDefault = $o.Name -eq $script:SDDemoState.Output; $o.IsComm = $o.Name -eq $script:SDDemoState.OutputComm }
    foreach ($m in $mics) { $m.IsDefault = $m.Name -eq $script:SDDemoState.Mic; $m.IsComm = $m.Name -eq $script:SDDemoState.MicComm }
    [pscustomobject]@{ Outputs = $outputs; Mics = $mics }
}
function Get-SDState { Copy-SDDemoObject $script:SDDemoState }
function Get-SDLayouts { foreach ($item in $script:SDDemoLayouts) { Copy-SDDemoObject $item } }
function Save-SDLayout {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { throw 'Name is required.' }
    Remove-SDLayout -Name $Name
    $item = [pscustomobject]@{ Name = $Name; Summary = $script:SDDemoState.Screens; ScreenCount = $script:SDDemoState.ScreenCount }
    [void]$script:SDDemoLayouts.Add($item)
    Copy-SDDemoObject $item
}
function Remove-SDLayout {
    param([string]$Name)
    for ($i = $script:SDDemoLayouts.Count - 1; $i -ge 0; $i--) { if ($script:SDDemoLayouts[$i].Name -eq $Name) { $script:SDDemoLayouts.RemoveAt($i) } }
}
function Get-SDButtons {
    $devices = Get-SDDevices
    foreach ($stored in $script:SDDemoButtons) {
        $b = Copy-SDDemoObject $stored
        $missing = @()
        foreach ($name in @($b.Output, $b.Comm)) { if ($name -and $name -notin @($devices.Outputs.Name)) { $missing += $name } }
        if ($b.Mic -and $b.Mic -notin @($devices.Mics.Name)) { $missing += $b.Mic }
        $b.Missing = @($missing | Select-Object -Unique)
        $active = ($b.Missing.Count -eq 0)
        if ($b.Output) { $active = $active -and ($b.Output -eq $script:SDDemoState.Output) }
        $comm = $b.Comm
        if (-not $comm -and $b.Output) { $comm = $b.Output }
        if ($comm) { $active = $active -and ($comm -eq $script:SDDemoState.OutputComm) }
        if ($b.Mic) { $active = $active -and ($b.Mic -eq $script:SDDemoState.Mic) }
        if ($b.Layout) { $active = $active -and ($b.Layout -eq $script:SDDemoCurrentLayout) }
        $b.IsActive = $active
        $b
    }
}
function New-SDButtonDraft {
    [pscustomobject]@{ Id = [guid]::NewGuid().ToString('N'); Name = ''; Top = ''; Output = $null; Comm = $null; Mic = $null; Layout = $null; Glyph = 'headset'; Color = '#9FADFF'; IconPath = ''; IsActive = $false; Missing = @() }
}
function Get-SDSuggestion {
    param($Button)
    $name = 'A50'; $top = $script:SDDemoText.demoButtons[0].Top; $glyph = 'headset'; $color = '#9FADFF'
    if ($Button.Output) {
        $name = $Button.Output
        if ($name -match 'SC8') { $name = 'SC8'; $glyph = 'mixer' }
        elseif ($name -match 'A50') { $name = 'A50' }
        elseif ($name -match 'HD') { $name = 'HD'; $glyph = 'speaker'; $color = '#65DCAE' }
        elseif ($name -match 'TV') { $name = 'TV'; $glyph = 'tv'; $color = '#65DCAE' }
    } elseif ($Button.Mic) { $name = $Button.Mic -replace '^Microfone ', ''; $top = $script:SDDemoText.demoButtons[4].Top; $glyph = 'mic'; $color = '#C2A2FF' }
    elseif ($Button.Layout) { $name = 'PC'; $top = $Button.Layout; $glyph = 'monitor'; $color = '#88B8FF' }
    elseif ($Button.Comm) { $name = $Button.Comm }
    [pscustomobject]@{ Name = $name; Top = $top; Glyph = $glyph; Color = $color }
}
function Save-SDButton {
    param($Button)
    $copy = Copy-SDDemoObject $Button
    $copy.IconPath = New-SDPreviewIcon -Button $copy
    $found = -1
    for ($i = 0; $i -lt $script:SDDemoButtons.Count; $i++) { if ($script:SDDemoButtons[$i].Id -eq $copy.Id) { $found = $i; break } }
    if ($found -ge 0) { $script:SDDemoButtons[$found] = $copy } else { [void]$script:SDDemoButtons.Add($copy) }
    Copy-SDDemoObject $copy
}
function Remove-SDButton {
    param([string]$Id)
    for ($i = $script:SDDemoButtons.Count - 1; $i -ge 0; $i--) { if ($script:SDDemoButtons[$i].Id -eq $Id) { $script:SDDemoButtons.RemoveAt($i) } }
}
function Move-SDButton {
    param([string]$Id, [int]$Index)
    $item = @($script:SDDemoButtons | Where-Object Id -eq $Id)[0]
    if ($null -eq $item) { throw 'Button not found.' }
    $script:SDDemoButtons.Remove($item)
    $Index = [Math]::Max(0, [Math]::Min($Index, $script:SDDemoButtons.Count))
    $script:SDDemoButtons.Insert($Index, $item)
}
function Invoke-SDButton {
    param([string]$Id)
    $b = @(Get-SDButtons | Where-Object Id -eq $Id)[0]
    if ($null -eq $b) { throw 'Button not found.' }
    if (@($b.Missing).Count -gt 0) { return [pscustomobject]@{ Ok = $false; Lines = @(); Warnings = @($script:SDDemoText.demoMissing) } }
    if ($b.Output) { $script:SDDemoState.Output = $b.Output; $script:SDDemoState.OutputShort = $b.Output }
    $comm = $b.Comm
    if (-not $comm -and $b.Output) { $comm = $b.Output }
    if ($comm) { $script:SDDemoState.OutputComm = $comm; $script:SDDemoState.OutputCommShort = $comm }
    if ($b.Mic) { $script:SDDemoState.Mic = $b.Mic; $script:SDDemoState.MicShort = $b.Mic -replace '^Microfone ', ''; $script:SDDemoState.MicComm = $b.Mic; $script:SDDemoState.MicCommShort = $script:SDDemoState.MicShort }
    if ($b.Layout) { $layout = @(Get-SDLayouts | Where-Object Name -eq $b.Layout)[0]; $script:SDDemoCurrentLayout = $b.Layout; $script:SDDemoState.ScreenCount = $layout.ScreenCount; $script:SDDemoState.Screens = $layout.Summary }
    [pscustomobject]@{ Ok = $true; Lines = @($script:SDDemoText.demoDone); Warnings = @() }
}
function New-SDPreviewIcon {
    param($Button)
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
    [void][IO.Directory]::CreateDirectory($script:SDDemoTemp)
    $name = [Security.SecurityElement]::Escape([string]$Button.Name)
    $top = [Security.SecurityElement]::Escape([string]$Button.Top)
    $color = '#9FADFF'
    if ($Button.Color -match '^#[0-9a-fA-F]{6}$') { $color = $Button.Color }
    $paths = @{
        headset = 'M30,75 C30,10 130,10 130,75 M30,70 V115 H49 V70 Z M130,70 V115 H111 V70 Z M122,115 Q122,136 90,136 H79'
        mixer = 'M30,20 V130 M80,20 V130 M130,20 V130 M18,50 H42 M68,96 H92 M118,70 H142'
        speaker = 'M25,60 H50 L87,28 V126 L50,95 H25 Z M107,52 Q129,77 107,102 M128,30 Q164,77 128,125'
        mic = 'M61,30 Q80,9 99,30 V85 Q80,107 61,85 Z M43,76 Q43,123 80,123 Q117,123 117,76 M80,123 V143 M57,143 H103'
        monitor = 'M10,22 H150 V110 H10 Z M80,110 V136 M50,136 H110'
        tv = 'M10,22 H150 V110 H10 Z M35,110 L22,135 M125,110 L138,135 M68,48 L99,66 L68,87 Z'
    }
    $geometry = $paths[[string]$Button.Glyph]
    if (-not $geometry) { $geometry = $paths.headset }
    $xaml = @"
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Width="256" Height="256" Background="#131C29">
<Rectangle Height="4" Fill="$color" VerticalAlignment="Top"/>
<TextBlock Text="$top" FontFamily="Segoe UI" FontSize="17" FontWeight="SemiBold" Foreground="#D3DBE5" TextTrimming="CharacterEllipsis" Margin="12,15,12,0" HorizontalAlignment="Center"/>
<Path Data="$geometry" Stroke="$color" StrokeThickness="9" StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round" Width="110" Height="110" Stretch="Uniform" VerticalAlignment="Top" Margin="0,57,0,0"/>
<Border Height="76" Background="$color" VerticalAlignment="Bottom"><Viewbox Margin="14,8" Stretch="Uniform" StretchDirection="DownOnly"><TextBlock Text="$name" Foreground="#0A1019" FontFamily="Segoe UI" FontSize="48" FontWeight="Bold"/></Viewbox></Border>
</Grid>
"@
    $visual = [Windows.Markup.XamlReader]::Parse($xaml)
    $visual.Measure([Windows.Size]::new(256,256)); $visual.Arrange([Windows.Rect]::new(0,0,256,256)); $visual.UpdateLayout()
    $bitmap = [Windows.Media.Imaging.RenderTargetBitmap]::new(256,256,96,96,[Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($visual)
    $encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    # A stable content hash avoids accumulating one preview per keystroke forever.
    $hash = [Security.Cryptography.SHA256]::Create()
    try { $key = [BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($xaml))).Replace('-','').Substring(0,24) } finally { $hash.Dispose() }
    $path = Join-Path $script:SDDemoTemp ($key + '.png')
    $stream = [IO.File]::Create($path)
    try { $encoder.Save($stream) } finally { $stream.Dispose() }
    return $path
}
function Get-SDGlyphs { $script:SDDemoText.demoGlyphs }
function Get-SDColors { $script:SDDemoText.demoColors }
function New-SDShortcut {
    param([string]$Id, [switch]$Desktop)
    [void][IO.Directory]::CreateDirectory($script:SDDemoTemp)
    $safeId = $Id -replace '[^a-zA-Z0-9-]', ''
    $path = Join-Path $script:SDDemoTemp ($safeId + '.lnk')
    $shell = New-Object -ComObject WScript.Shell
    try {
        $shortcut = $shell.CreateShortcut($path)
        $shortcut.TargetPath = Join-Path $PSHOME 'powershell.exe'
        $shortcut.Arguments = '-NoProfile -Sta -ExecutionPolicy Bypass -File "' + (Join-Path (Split-Path $script:SDDemoRoot) 'SwitchDeck.ps1') + '" -Demo'
        $shortcut.Save()
    } finally { if ($shortcut) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shortcut) }; [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell) }
    $path
}
function Get-SDCommand { param([string]$Id) 'powershell.exe -NoProfile -Sta -File ".\SwitchDeck.ps1" -Demo' }
function Export-SDIcons {
    param([string]$Folder)
    # Intentionally ignore external destinations in demo mode.
    $target = Join-Path $script:SDDemoTemp 'export'
    [void][IO.Directory]::CreateDirectory($target)
    foreach ($b in $script:SDDemoButtons) { $safeId = $b.Id -replace '[^a-zA-Z0-9-]', ''; Copy-Item -LiteralPath $b.IconPath -Destination (Join-Path $target ($safeId + '.png')) -Force }
    $script:SDDemoButtons.Count
}
function Add-SDStarterButtons {
    foreach ($output in (Get-SDDevices).Outputs) {
        if (@($script:SDDemoButtons | Where-Object Output -eq $output.Name).Count -gt 0) { continue }
        $draft = New-SDButtonDraft; $draft.Output = $output.Name
        $suggestion = Get-SDSuggestion -Button $draft
        foreach ($key in @('Name','Top','Glyph','Color')) { $draft.$key = $suggestion.$key }
        Save-SDButton -Button $draft
    }
}
function Get-SDUlanzi { [pscustomobject]@{ Installed = $true; Running = $true; Device = 'Ulanzi D200'; Profile = 'SwitchDeck'; Supported = $true; Reason = '' } }
function Send-SDToUlanzi { Start-Sleep -Milliseconds 1800; [pscustomobject]@{ Ok = $true; Lines = @($script:SDDemoText.demoSent); Warnings = @() } }
