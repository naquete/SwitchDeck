# Windows PowerShell 5.1 / WPF. Text belongs to XAML or UTF-8 strings.json.
function Show-SwitchDeckUi {
    [CmdletBinding()]
    param([switch]$Demo, [string]$Screenshot, [string]$View = 'main', [string]$EngineFile, [switch]$StartupFailed)

    $uiRoot = Join-Path $PSScriptRoot 'ui'
    if (-not ('SwitchDeck.UI.Tile' -as [type])) {
        Add-Type -Path (Join-Path $uiRoot 'ViewModels.cs') -ReferencedAssemblies PresentationCore, WindowsBase
    }
    $text = Get-Content -LiteralPath (Join-Path $uiRoot 'strings.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $theme = [Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $uiRoot 'Theme.xaml'), [Text.Encoding]::UTF8))
    # Resource references must resolve during parsing, before the Window exists.
    if (-not [Windows.Application]::Current) { $app = New-Object Windows.Application; $app.ShutdownMode = 'OnExplicitShutdown' }
    [Windows.Application]::Current.Resources.MergedDictionaries.Add($theme)
    $window = [Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $uiRoot 'MainWindow.xaml'), [Text.Encoding]::UTF8))
    $script:SDUI = @{
        Window = $window; Text = $text; Demo = [bool]$Demo; EngineFile = $EngineFile
        Controls = @{}; Buttons = @(); Draft = $null; EditingId = $null
        Updating = $false; Dirty = $false; Touched = @{}; LastDeck = ''; ForceEmpty = ($View -eq 'empty')
        Started = $false; StartupFailed = [bool]$StartupFailed; Busy = $false; Pending = $null
        Async = $null; Worker = $null; WorkerRunspace = $null; CaptureError = $null; Screenshot = $Screenshot; View = $View
    }
    $names = @('TitleBar','Minimize','Close','DemoBadge','StateOutput','StateComm','StateMic','StateScreens','ButtonCount','AddTop','DeckHousing','DeckItems','EmptyState','CreateFirst','CreateStarters','OpenExport','FooterStatus','Shade','Editor','EditorSlide','EditorTitle','EditorSubtitle','CloseEditor','EnableOutput','OutputChoice','EnableComm','CommChoice','CommHint','EnableMic','MicChoice','EnableLayout','LayoutChoice','CaptureLayout','LayoutCapture','LayoutName','SaveLayout','ButtonName','ButtonTop','Preview','GlyphChoice','ColorChoices','EditorError','SaveButton','TestButton','CancelEditor','DeleteEditor','ExportPanel','CloseExport','UlanziStatus','UlanziDetail','ExportIcons','ExportShortcuts','SendUlanzi','ConfirmShade','ConfirmTitle','ConfirmBody','ConfirmCancel','ConfirmAccept','BusyShade','BusyText','Toast','ToastText')
    foreach ($name in $names) { $script:SDUI.Controls[$name] = $window.FindName($name) }
    $c = $script:SDUI.Controls

    function ConvertTo-SDUiChoices($Items) {
        foreach ($item in $Items) {
            $choice = New-Object SwitchDeck.UI.Choice
            foreach ($key in @('Name','Short','Id','Label','Summary')) { if ($item.$key) { $choice.$key = [string]$item.$key } }
            if (-not $choice.Name) { $choice.Name = '' }
            $choice
        }
    }

    function Set-SDUiToast([string]$Message, [bool]$Warning = $false) {
        if (-not $Message) { return }
        $c = $script:SDUI.Controls
        $c.ToastText.Text = $Message
        $c.Toast.Background = '#22382F'; $c.Toast.BorderBrush = '#65DCAE'
        if ($Warning) { $c.Toast.Background = '#382F23'; $c.Toast.BorderBrush = '#F6C66E' }
        $c.Toast.Visibility = 'Visible'
        $script:SDUI.ToastTimer.Stop(); $script:SDUI.ToastTimer.Start()
    }
    function Invoke-SDUiSafe([scriptblock]$Action) {
        try { & $Action }
        catch {
            # O motor avisa em portugues com "throw 'texto'"; qualquer outra falha vira o aviso generico.
            $message = $script:SDUI.Text.error
            if ($_.CategoryInfo.Category -eq 'OperationStopped' -and $_.Exception.Message -and $_.Exception.Message.Length -lt 220) { $message = $_.Exception.Message }
            Set-SDUiToast $message $true
        }
    }
    function Read-SDUiImage([string]$Path) {
        if (-not $Path -or -not [IO.File]::Exists($Path)) { return $null }
        $stream = [IO.File]::OpenRead($Path)
        try {
            $bitmap = New-Object Windows.Media.Imaging.BitmapImage
            $bitmap.BeginInit(); $bitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bitmap.StreamSource = $stream; $bitmap.EndInit(); $bitmap.Freeze()
            return $bitmap
        } finally { $stream.Dispose() }
    }
    function Show-SDUiResult($Result) {
        $lines = @($Result.Lines) + @($Result.Warnings) | Where-Object { $_ }
        $message = $lines -join "`n"
        if (-not $message) { if ($Result.Ok) { $message = $script:SDUI.Text.ready } else { $message = $script:SDUI.Text.error } }
        Set-SDUiToast $message ((-not $Result.Ok) -or @($Result.Warnings | Where-Object { $_ }).Count -gt 0)
    }
    function Update-SDUiDeck([bool]$Force = $false) {
        $s = $script:SDUI; $c = $s.Controls; $t = $s.Text
        $buttons = @(Get-SDButtons)
        if ($s.ForceEmpty) { $buttons = @() }
        $s.Buttons = $buttons
        $signature = ConvertTo-Json -InputObject $buttons -Depth 8 -Compress
        if (-not $Force -and $signature -eq $s.LastDeck) { return }
        $s.LastDeck = $signature
        $items = New-Object System.Collections.ArrayList
        foreach ($b in $buttons) {
            $ring = '#2B3748'; $status = $t.available; $statusColor = '#8C98A8'; $active = 'Collapsed'
            if ($b.IsActive) { $ring = $b.Color; $status = $t.active; $statusColor = $b.Color; $active = 'Visible' }
            $description = New-Object System.Collections.Generic.List[string]
            $description.Add($b.Name)
            foreach ($pair in @(@('Output',$t.outputLabel), @('Comm',$t.commLabel), @('Mic',$t.micLabel), @('Layout',$t.layoutLabel))) {
                if ($b.($pair[0])) { $description.Add($pair[1] + ': ' + $b.($pair[0])) }
            }
            if (@($b.Missing).Count -gt 0) { $status = $t.missing; $statusColor = '#F6C66E'; $description.Add(($t.missingDetail -f ($b.Missing -join ', '))) }
            $image = $null
            try { $image = Read-SDUiImage $b.IconPath } catch { }
            if (-not $image) { try { $image = Read-SDUiImage (New-SDPreviewIcon -Button $b) } catch { } }
            $tile = New-Object SwitchDeck.UI.Tile -Property @{ Id=$b.Id; Name=$b.Name; Image=$image; Ring=$ring; Status=$status; StatusColor=$statusColor; ActiveVisibility=$active; NewVisibility='Collapsed'; ActionVisibility='Visible'; Description=($description -join "`n") }
            [void]$items.Add($tile)
        }
        [void]$items.Add((New-Object SwitchDeck.UI.Tile -Property @{ Id=''; Name=$t.newButton; Image=$null; Ring='#344052'; Status=''; StatusColor='#8C98A8'; ActiveVisibility='Collapsed'; NewVisibility='Visible'; ActionVisibility='Collapsed'; Description=$t.newSubtitle }))
        $c.DeckItems.ItemsSource = $items
        $c.ButtonCount.Text = $t.count -f $buttons.Count
        $c.EmptyState.Visibility = 'Collapsed'; $c.DeckHousing.Visibility = 'Visible'
        if ($buttons.Count -eq 0) { $c.EmptyState.Visibility = 'Visible'; $c.DeckHousing.Visibility = 'Collapsed' }
    }
    function Update-SDUiState {
        $s = $script:SDUI; $c = $s.Controls
        if ($s.StartupFailed -or $s.Busy) { return }
        try {
            $state = Get-SDState
            foreach ($pair in @(@('StateOutput','OutputShort','Output'), @('StateComm','OutputCommShort','OutputComm'), @('StateMic','MicShort','Mic'))) {
                $value = $state.($pair[1]); if (-not $value) { $value = $state.($pair[2]) }; if (-not $value) { $value = $s.Text.unknown }
                $c[$pair[0]].Text = $value; $c[$pair[0]].ToolTip = $state.($pair[2])
            }
            $c.StateScreens.Text = $s.Text.screenCount -f $state.ScreenCount
            if ($state.ScreenCount -eq 1) { $c.StateScreens.Text = $s.Text.screenOne }
            $c.StateScreens.ToolTip = $state.Screens
            Update-SDUiDeck
            $c.FooterStatus.Text = $s.Text.ready
            if ($s.Demo) { $c.FooterStatus.Text = $s.Text.demoNotice }
        } catch { $c.FooterStatus.Text = $s.Text.refreshError }
    }
    function Close-SDUiPanel {
        $script:SDUI.PreviewTimer.Stop()
        foreach ($name in @('Editor','ExportPanel','Shade')) { $script:SDUI.Controls[$name].Visibility = 'Collapsed' }
        $script:SDUI.Draft = $null; $script:SDUI.Dirty = $false
        [void]$script:SDUI.Controls.AddTop.Focus()
    }
    function Show-SDUiConfirm([string]$Title, [string]$Body, [string]$Accept, [scriptblock]$Action) {
        $c = $script:SDUI.Controls
        $c.ConfirmTitle.Text = $Title; $c.ConfirmBody.Text = $Body; $c.ConfirmAccept.Content = $Accept
        $script:SDUI.Pending = $Action; $c.ConfirmShade.Visibility = 'Visible'; [void]$c.ConfirmCancel.Focus()
    }
    function Request-SDUiClosePanel {
        if ($script:SDUI.Dirty) { Show-SDUiConfirm $script:SDUI.Text.discardTitle $script:SDUI.Text.discardBody $script:SDUI.Text.discardConfirm { Close-SDUiPanel } }
        else { Close-SDUiPanel }
    }
    function Get-SDUiDraft {
        $s = $script:SDUI; $c = $s.Controls; $b = $s.Draft
        $b.Name = $c.ButtonName.Text.Trim(); $b.Top = $c.ButtonTop.Text.Trim()
        $b.Output = $null; $b.Comm = $null; $b.Mic = $null; $b.Layout = $null
        if ($c.EnableOutput.IsChecked) { $b.Output = $c.OutputChoice.SelectedValue }
        if ($c.EnableComm.IsChecked -and $c.CommChoice.SelectedValue) { $b.Comm = $c.CommChoice.SelectedValue }
        if ($c.EnableMic.IsChecked -and $c.MicChoice.SelectedValue) { $b.Mic = $c.MicChoice.SelectedValue }
        if ($c.EnableLayout.IsChecked -and $c.LayoutChoice.SelectedValue) { $b.Layout = $c.LayoutChoice.SelectedValue }
        if ($c.GlyphChoice.SelectedValue) { $b.Glyph = $c.GlyphChoice.SelectedValue }
        return $b
    }
    function Update-SDUiColor {
        foreach ($button in $script:SDUI.Controls.ColorChoices.Children) {
            $button.BorderBrush = 'Transparent'; $button.BorderThickness = 2
            if ($button.Tag -eq $script:SDUI.Draft.Color) { $button.BorderBrush = '#F5F6F2' }
        }
    }
    function Update-SDUiPreview {
        $s = $script:SDUI
        $s.PreviewTimer.Stop()
        if (-not $s.Draft -or $s.Updating) { return }
        try { $s.Controls.Preview.Source = Read-SDUiImage (New-SDPreviewIcon -Button (Get-SDUiDraft)) }
        catch { $s.Controls.EditorError.Text = $s.Text.previewError; $s.Controls.EditorError.Visibility = 'Visible' }
    }
    function Queue-SDUiPreview {
        if ($script:SDUI.Updating -or -not $script:SDUI.Draft) { return }
        $script:SDUI.Dirty = $true
        $script:SDUI.Controls.EditorError.Visibility = 'Collapsed'
        $script:SDUI.PreviewTimer.Stop(); $script:SDUI.PreviewTimer.Start()
    }
    function Update-SDUiActions {
        $s = $script:SDUI; $c = $s.Controls
        if ($s.Updating -or -not $s.Draft) { return }
        $s.Updating = $true
        try {
            $c.OutputChoice.IsEnabled = [bool]$c.EnableOutput.IsChecked
            $c.CommChoice.IsEnabled = [bool]$c.EnableComm.IsChecked
            $c.MicChoice.IsEnabled = [bool]$c.EnableMic.IsChecked
            $c.LayoutChoice.IsEnabled = [bool]$c.EnableLayout.IsChecked
            $c.CommHint.Visibility = 'Collapsed'
            # The engine contract couples communications to Output when Comm is null.
            # Keep this implicit behavior visible rather than promise "do not change".
            if ($c.EnableOutput.IsChecked -and -not $c.EnableComm.IsChecked) { $c.CommHint.Visibility = 'Visible' }
            $b = Get-SDUiDraft
            $suggestion = Get-SDSuggestion -Button $b
            if (-not $s.Touched.Name) { $c.ButtonName.Text = $suggestion.Name }
            if (-not $s.Touched.Top) { $c.ButtonTop.Text = $suggestion.Top }
            if (-not $s.Touched.Glyph) { $c.GlyphChoice.SelectedValue = $suggestion.Glyph }
            if (-not $s.Touched.Color) { $b.Color = $suggestion.Color; Update-SDUiColor }
        } catch { Set-SDUiToast $s.Text.error $true }
        finally { $s.Updating = $false }
        Queue-SDUiPreview
    }
    function Open-SDUiEditor([string]$Id) {
        $s = $script:SDUI; $c = $s.Controls
        $s.Updating = $true
        try {
            $s.EditingId = $Id; $s.Touched = @{}
            if ($Id) {
                $source = @(Get-SDButtons | Where-Object Id -eq $Id)[0]
                $s.Draft = $source | ConvertTo-Json -Depth 10 | ConvertFrom-Json
                foreach ($key in @('Name','Top','Glyph','Color')) { $s.Touched[$key] = $true }
                $c.EditorSubtitle.Text = $s.Text.editSubtitle; $c.DeleteEditor.Visibility = 'Visible'
            } else { $s.Draft = New-SDButtonDraft; $c.EditorSubtitle.Text = $s.Text.newSubtitle; $c.DeleteEditor.Visibility = 'Collapsed' }
            $b = $s.Draft; $devices = Get-SDDevices
            $outputs = @($devices.Outputs); $mics = @($devices.Mics)
            foreach ($missing in @($b.Output,$b.Comm)) { if ($missing -and $missing -notin @($outputs.Name)) { $outputs += [pscustomobject]@{ Name=$missing; Short=($missing + ' - ' + $s.Text.missing) } } }
            if ($b.Mic -and $b.Mic -notin @($mics.Name)) { $mics += [pscustomobject]@{ Name=$b.Mic; Short=($b.Mic + ' - ' + $s.Text.missing) } }
            $c.OutputChoice.ItemsSource = @(ConvertTo-SDUiChoices $outputs)
            $c.CommChoice.ItemsSource = @(ConvertTo-SDUiChoices (@([pscustomobject]@{ Name=''; Short=$s.Text.sameOutput }) + $outputs))
            $c.MicChoice.ItemsSource = @(ConvertTo-SDUiChoices (@([pscustomobject]@{ Name=''; Short=$s.Text.noChange }) + $mics))
            $layouts = @(Get-SDLayouts)
            if ($b.Layout -and $b.Layout -notin @($layouts.Name)) { $layouts += [pscustomobject]@{Name=$b.Layout; Summary=$s.Text.unknown; ScreenCount=0} }
            $c.LayoutChoice.ItemsSource = @([pscustomobject]@{ Name=''; Summary=$s.Text.noChange }) + $layouts
            # Use a separate display label for the null layout option.
            $c.LayoutChoice.DisplayMemberPath = 'Summary'
            $layoutChoices = @([pscustomobject]@{Name=''; Summary=$s.Text.noChange})
            foreach ($layout in $layouts) { $layoutChoices += [pscustomobject]@{Name=$layout.Name; Summary=$layout.Name} }
            $c.LayoutChoice.ItemsSource = @(ConvertTo-SDUiChoices $layoutChoices)
            $c.GlyphChoice.ItemsSource = @(ConvertTo-SDUiChoices @(Get-SDGlyphs))
            $c.ButtonName.Text = $b.Name; $c.ButtonTop.Text = $b.Top; $c.GlyphChoice.SelectedValue = $b.Glyph
            $c.EnableOutput.IsChecked = [bool]$b.Output; $c.EnableComm.IsChecked = [bool]($b.Comm -or $b.Output); $c.EnableMic.IsChecked = [bool]$b.Mic; $c.EnableLayout.IsChecked = [bool]$b.Layout
            $c.OutputChoice.SelectedValue = $b.Output
            $c.CommChoice.SelectedIndex = 0; if ($b.Comm) { $c.CommChoice.SelectedValue = $b.Comm }
            $c.MicChoice.SelectedIndex = 0; if ($b.Mic) { $c.MicChoice.SelectedValue = $b.Mic }
            $c.LayoutChoice.SelectedIndex = 0; if ($b.Layout) { $c.LayoutChoice.SelectedValue = $b.Layout }
            foreach ($pair in @(@('OutputChoice','EnableOutput'),@('CommChoice','EnableComm'),@('MicChoice','EnableMic'),@('LayoutChoice','EnableLayout'))) { $c[$pair[0]].IsEnabled = [bool]$c[$pair[1]].IsChecked }
            $c.CommHint.Visibility = 'Collapsed'; $c.EditorError.Visibility = 'Collapsed'; $c.LayoutCapture.Visibility = 'Collapsed'
            $c.ColorChoices.Children.Clear()
            foreach ($color in @(Get-SDColors)) {
                $swatch = New-Object Windows.Controls.Button
                $swatch.Width=28; $swatch.Height=30; $swatch.Margin='0,0,5,0'; $swatch.Padding=5
                $swatch.Background=$color.Id; $swatch.Tag=$color.Id; $swatch.ToolTip=$color.Label
                [Windows.Automation.AutomationProperties]::SetName($swatch, $color.Label)
                $swatch.Add_Click({ param($sender,$args) $script:SDUI.Draft.Color = [string]$sender.Tag; $script:SDUI.Touched.Color = $true; Update-SDUiColor; Queue-SDUiPreview })
                [void]$c.ColorChoices.Children.Add($swatch)
            }
            Update-SDUiColor
            $c.Shade.Visibility='Visible'; $c.Editor.Visibility='Visible'; $c.ExportPanel.Visibility='Collapsed'
            $animation = [Windows.Media.Animation.DoubleAnimation]::new(55,0,[Windows.Duration]::new([TimeSpan]::FromMilliseconds(180)))
            $animation.EasingFunction = New-Object Windows.Media.Animation.CubicEase
            $c.EditorSlide.BeginAnimation([Windows.Media.TranslateTransform]::XProperty,$animation)
            $s.Dirty=$false
        } finally { $s.Updating=$false }
        Update-SDUiPreview
        [void]$c.EnableOutput.Focus()
    }
    function Test-SDUiDraft {
        $b = Get-SDUiDraft; $c = $script:SDUI.Controls; $t = $script:SDUI.Text; $errorText = ''
        if (-not $b.Name) { $errorText = $t.nameRequired }
        elseif ($c.EnableOutput.IsChecked -and -not $b.Output) { $errorText = $t.deviceRequired }
        elseif ($c.EnableComm.IsChecked -and -not $b.Comm -and -not $b.Output) { $errorText = $t.deviceRequired }
        elseif (-not ($b.Output -or $b.Comm -or $b.Mic -or $b.Layout)) { $errorText = $t.actionRequired }
        $c.EditorError.Text=$errorText; $c.EditorError.Visibility='Collapsed'
        if ($errorText) { $c.EditorError.Visibility='Visible'; return $false }
        return $true
    }
    function Remove-SDUiButton([string]$Id) {
        $script:SDUI.DeleteId = $Id
        Show-SDUiConfirm $script:SDUI.Text.deleteTitle $script:SDUI.Text.deleteBody $script:SDUI.Text.deleteConfirm {
            Remove-SDButton -Id $script:SDUI.DeleteId
            Close-SDUiPanel; Update-SDUiDeck $true; Set-SDUiToast $script:SDUI.Text.removed
        }
    }
    function Invoke-SDUiTileAction([string]$Action, [string]$Id) {
        switch ($Action) {
            'edit' { Open-SDUiEditor $Id }
            'run' { if (-not $Id) { Open-SDUiEditor '' } else { Show-SDUiResult (Invoke-SDButton -Id $Id); Update-SDUiState } }
            'shortcut' { $null=New-SDShortcut -Id $Id -Desktop; if ($script:SDUI.Demo) { Set-SDUiToast $script:SDUI.Text.demoShortcut } else { Set-SDUiToast $script:SDUI.Text.shortcut } }
            'command' { [Windows.Clipboard]::SetText([string](Get-SDCommand -Id $Id)); Set-SDUiToast $script:SDUI.Text.copied }
            'delete' { Remove-SDUiButton $Id }
            { $_ -in 'left','right' } {
                $ids = @($script:SDUI.Buttons.Id); $index=[array]::IndexOf($ids,$Id)
                if ($Action -eq 'left') { $index-- } else { $index++ }
                if ($index -ge 0 -and $index -lt $ids.Count) { Move-SDButton -Id $Id -Index $index; Update-SDUiDeck $true }
            }
        }
    }
    function Show-SDUiTileMenu($Target, [string]$Id) {
        $menu=New-Object Windows.Controls.ContextMenu
        foreach ($pair in @(@('edit','edit'),@('shortcut','createShortcut'),@('command','copyCommand'),@('left','moveLeft'),@('right','moveRight'),@('delete','delete'))) {
            $item=New-Object Windows.Controls.MenuItem; $item.Header=$script:SDUI.Text.($pair[1]); $item.Tag=@{ Action=$pair[0]; Id=$Id }
            $item.Add_Click({ param($sender,$args) Invoke-SDUiSafe { Invoke-SDUiTileAction $sender.Tag.Action $sender.Tag.Id } })
            if ($pair[0] -eq 'delete') { $item.Foreground='#FF8277' }
            $ids=@($script:SDUI.Buttons.Id); $index=[array]::IndexOf($ids,$Id)
            if (($pair[0] -eq 'left' -and $index -eq 0) -or ($pair[0] -eq 'right' -and $index -eq ($ids.Count-1))) { $item.IsEnabled=$false }
            [void]$menu.Items.Add($item)
        }
        $menu.PlacementTarget=$Target; $menu.Placement='Bottom'; $menu.IsOpen=$true
    }
    function Open-SDUiExport {
        $s=$script:SDUI; $c=$s.Controls; $t=$s.Text
        $u=Get-SDUlanzi
        $c.UlanziStatus.Text=$t.ulanziAbsent; $c.UlanziDetail.Text=$t.ulanziAbsentHint
        $c.UlanziStatus.Foreground='#8C98A8'; $c.SendUlanzi.IsEnabled=$false
        if ($u.Installed) {
            $running=$t.ulanziStopped; if ($u.Running) { $running=$t.ulanziRunning }
            $c.UlanziStatus.Text=([string]$u.Device + '  /  ' + $running)
            $c.UlanziStatus.Foreground='#65DCAE'; $c.UlanziDetail.Text=[string]$u.Profile
            $c.SendUlanzi.IsEnabled=[bool]$u.Supported
            if (-not $u.Supported) { $c.UlanziStatus.Foreground='#F6C66E'; $c.UlanziDetail.Text=$t.ulanziUnsupported }
            if ($u.Reason) { $c.UlanziDetail.Text=([string]$c.UlanziDetail.Text + "`n" + [string]$u.Reason).Trim() }
        }
        $c.ExportIcons.IsEnabled=$s.Buttons.Count -gt 0; $c.ExportShortcuts.IsEnabled=$s.Buttons.Count -gt 0
        $c.SendUlanzi.IsEnabled=$c.SendUlanzi.IsEnabled -and $s.Buttons.Count -gt 0
        $c.Shade.Visibility='Visible'; $c.ExportPanel.Visibility='Visible'; $c.Editor.Visibility='Collapsed'
        [void]$c.CloseExport.Focus()
    }
    function Start-SDUiSend {
        $s=$script:SDUI
        $s.Busy=$true; $s.Controls.BusyText.Text=$s.Text.working; $s.Controls.BusyShade.Visibility='Visible'
        try {
            $s.WorkerRunspace=[RunspaceFactory]::CreateRunspace(); $s.WorkerRunspace.ApartmentState='STA'; $s.WorkerRunspace.ThreadOptions='ReuseThread'; $s.WorkerRunspace.Open()
            $s.Worker=[PowerShell]::Create(); $s.Worker.Runspace=$s.WorkerRunspace
            [void]$s.Worker.AddScript('param($engine) $ErrorActionPreference = "Stop"; . $engine; Send-SDToUlanzi').AddArgument($s.EngineFile)
            $s.Async=$s.Worker.BeginInvoke(); $s.WorkTimer.Start()
        } catch { $s.Busy=$false; $s.Controls.BusyShade.Visibility='Collapsed'; if($s.Worker){$s.Worker.Dispose()}; if($s.WorkerRunspace){$s.WorkerRunspace.Dispose()}; throw }
    }

    $s=$script:SDUI
    $s.ToastTimer=New-Object Windows.Threading.DispatcherTimer; $s.ToastTimer.Interval=[TimeSpan]::FromSeconds(6)
    $s.ToastTimer.Add_Tick({ $script:SDUI.Controls.Toast.Visibility='Collapsed'; $script:SDUI.ToastTimer.Stop() })
    $s.PreviewTimer=New-Object Windows.Threading.DispatcherTimer; $s.PreviewTimer.Interval=[TimeSpan]::FromMilliseconds(180)
    $s.PreviewTimer.Add_Tick({ Update-SDUiPreview })
    $s.StateTimer=New-Object Windows.Threading.DispatcherTimer; $s.StateTimer.Interval=[TimeSpan]::FromSeconds(2)
    $s.StateTimer.Add_Tick({ Update-SDUiState })
    $s.WorkTimer=New-Object Windows.Threading.DispatcherTimer; $s.WorkTimer.Interval=[TimeSpan]::FromMilliseconds(150)
    $s.WorkTimer.Add_Tick({
        $s=$script:SDUI
        if (-not $s.Async.IsCompleted) { return }
        $s.WorkTimer.Stop()
        try {
            $result=@($s.Worker.EndInvoke($s.Async))
            if ($s.Worker.HadErrors -or $result.Count -eq 0) { throw 'Worker failed.' }
            Show-SDUiResult $result[-1]
        } catch { Set-SDUiToast $s.Text.error $true }
        finally { $s.Worker.Dispose(); $s.WorkerRunspace.Dispose(); $s.Worker=$null; $s.WorkerRunspace=$null; $s.Async=$null; $s.Busy=$false; $s.Controls.BusyShade.Visibility='Collapsed' }
        Invoke-SDUiSafe { Open-SDUiExport; Update-SDUiState }
    })
    $c.TitleBar.Add_MouseLeftButtonDown({ param($sender,$args) if ($args.OriginalSource -isnot [Windows.Controls.Button]) { try { $script:SDUI.Window.DragMove() } catch { } } })
    $c.Minimize.Add_Click({ $script:SDUI.Window.WindowState='Minimized' })
    $c.Close.Add_Click({ $script:SDUI.Window.Close() })
    $window.Add_Closing({ param($sender,$args)
        if ($script:SDUI.Busy) { $args.Cancel=$true; return }
        if ($script:SDUI.Dirty -and -not $script:SDUI.Screenshot) {
            $args.Cancel=$true
            Show-SDUiConfirm $script:SDUI.Text.discardTitle $script:SDUI.Text.discardBody $script:SDUI.Text.discardConfirm { $script:SDUI.Dirty=$false; $script:SDUI.Window.Close() }
        }
    })
    $window.Add_Closed({ foreach ($name in @('StateTimer','PreviewTimer','ToastTimer','WorkTimer','CaptureTimer')) { if ($script:SDUI[$name]) { $script:SDUI[$name].Stop() } } })
    $window.Add_Activated({ if ($script:SDUI.Started) { Update-SDUiState } })
    $window.Add_PreviewKeyDown({ param($sender,$args)
        if ($args.Key -eq 'Escape' -and -not $script:SDUI.Busy) {
            if ($script:SDUI.Controls.ConfirmShade.Visibility -eq 'Visible') { $script:SDUI.Controls.ConfirmShade.Visibility='Collapsed'; $script:SDUI.Pending=$null }
            else { Request-SDUiClosePanel }; $args.Handled=$true
        }
    })
    foreach ($name in @('AddTop','CreateFirst')) { $c[$name].Add_Click({ Invoke-SDUiSafe { Open-SDUiEditor '' } }) }
    $c.CreateStarters.Add_Click({ Invoke-SDUiSafe { $null=Add-SDStarterButtons; $script:SDUI.ForceEmpty=$false; Update-SDUiDeck $true; Set-SDUiToast $script:SDUI.Text.starter } })
    foreach ($name in @('CloseEditor','CancelEditor','CloseExport')) { $c[$name].Add_Click({ Request-SDUiClosePanel }) }
    $c.Shade.Add_MouseLeftButtonDown({ Request-SDUiClosePanel })
    $c.OpenExport.Add_Click({ Invoke-SDUiSafe { Open-SDUiExport } })
    $c.DeckItems.AddHandler([Windows.Controls.Primitives.ButtonBase]::ClickEvent,[Windows.RoutedEventHandler]{ param($sender,$args)
        $target=$args.OriginalSource
        if ($target -isnot [Windows.Controls.Button]) { return }
        $item=$target.DataContext; if (-not $item) { return }
        $args.Handled=$true
        Invoke-SDUiSafe { if ($target.Tag -eq 'menu') { Show-SDUiTileMenu $target $item.Id } else { Invoke-SDUiTileAction $target.Tag $item.Id } }
    })
    $c.DeckItems.Add_PreviewMouseRightButtonUp({ param($sender,$args)
        $node=$args.OriginalSource
        while ($node -and $node -isnot [Windows.Controls.Button]) { $node=[Windows.Media.VisualTreeHelper]::GetParent($node) }
        if ($node -and $node.DataContext.Id) { Show-SDUiTileMenu $node $node.DataContext.Id; $args.Handled=$true }
    })
    foreach ($name in @('EnableOutput','EnableComm','EnableMic','EnableLayout')) { $c[$name].Add_Click({ Update-SDUiActions }) }
    foreach ($name in @('OutputChoice','CommChoice','MicChoice','LayoutChoice')) { $c[$name].Add_SelectionChanged({ Update-SDUiActions }) }
    $c.ButtonName.Add_TextChanged({ if (-not $script:SDUI.Updating) { $script:SDUI.Touched.Name=$true; Queue-SDUiPreview } })
    $c.ButtonTop.Add_TextChanged({ if (-not $script:SDUI.Updating) { $script:SDUI.Touched.Top=$true; Queue-SDUiPreview } })
    $c.GlyphChoice.Add_SelectionChanged({ if (-not $script:SDUI.Updating) { $script:SDUI.Touched.Glyph=$true; Queue-SDUiPreview } })
    $c.CaptureLayout.Add_Click({ $script:SDUI.Controls.LayoutCapture.Visibility='Visible'; [void]$script:SDUI.Controls.LayoutName.Focus() })
    $c.SaveLayout.Add_Click({ Invoke-SDUiSafe {
        $s=$script:SDUI; $name=$s.Controls.LayoutName.Text.Trim()
        if (-not $name) { Set-SDUiToast $s.Text.layoutNameRequired $true; return }
        $null=Save-SDLayout -Name $name
        $choices=@([pscustomobject]@{Name=''; Summary=$s.Text.noChange})
        foreach ($layout in @(Get-SDLayouts)) { $choices += [pscustomobject]@{Name=$layout.Name; Summary=$layout.Name} }
        $s.Updating=$true
        try { $s.Controls.LayoutChoice.ItemsSource=@(ConvertTo-SDUiChoices $choices); $s.Controls.EnableLayout.IsChecked=$true; $s.Controls.LayoutChoice.SelectedValue=$name; $s.Controls.LayoutCapture.Visibility='Collapsed' } finally { $s.Updating=$false }
        Update-SDUiActions; Set-SDUiToast $s.Text.layoutSaved
    } })
    $c.SaveButton.Add_Click({ Invoke-SDUiSafe {
        if (-not (Test-SDUiDraft)) { return }
        $null=Save-SDButton -Button (Get-SDUiDraft)
        $script:SDUI.ForceEmpty=$false; Close-SDUiPanel; Update-SDUiDeck $true; Set-SDUiToast $script:SDUI.Text.saved
    } })
    $c.TestButton.Add_Click({ Invoke-SDUiSafe {
        if (-not (Test-SDUiDraft)) { return }
        # Invoke requires a saved ID. A temporary button preserves the original
        # button, including unsaved edits, and is removed even if invoke fails.
        $copy=Get-SDUiDraft | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $copy.Id=(New-SDButtonDraft).Id
        try { $null=Save-SDButton -Button $copy; Show-SDUiResult (Invoke-SDButton -Id $copy.Id) }
        finally { Remove-SDButton -Id $copy.Id }
        Update-SDUiState
    } })
    $c.DeleteEditor.Add_Click({ Remove-SDUiButton $script:SDUI.EditingId })
    $c.ConfirmCancel.Add_Click({ $script:SDUI.Controls.ConfirmShade.Visibility='Collapsed'; $script:SDUI.Pending=$null })
    $c.ConfirmAccept.Add_Click({ $action=$script:SDUI.Pending; $script:SDUI.Controls.ConfirmShade.Visibility='Collapsed'; $script:SDUI.Pending=$null; Invoke-SDUiSafe $action })
    $c.ExportIcons.Add_Click({ Invoke-SDUiSafe {
        Add-Type -AssemblyName System.Windows.Forms
        $picker=New-Object System.Windows.Forms.FolderBrowserDialog
        try {
            $picker.Description=$script:SDUI.Text.folderTitle
            if ($picker.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $count=Export-SDIcons -Folder $picker.SelectedPath
                $message=$script:SDUI.Text.exported -f $count
                if ($script:SDUI.Demo) { $message=$script:SDUI.Text.demoExport -f $count }
                Set-SDUiToast $message
            }
        } finally { $picker.Dispose() }
    } })
    $c.ExportShortcuts.Add_Click({ Invoke-SDUiSafe {
        foreach ($b in @(Get-SDButtons)) { $null=New-SDShortcut -Id $b.Id -Desktop }
        if ($script:SDUI.Demo) { Set-SDUiToast $script:SDUI.Text.demoShortcut } else { Set-SDUiToast $script:SDUI.Text.shortcuts }
    } })
    $c.SendUlanzi.Add_Click({ Show-SDUiConfirm $script:SDUI.Text.ulanziTitle $script:SDUI.Text.ulanziBody $script:SDUI.Text.ulanziConfirm { Start-SDUiSend } })
    if ($Demo) { $c.DemoBadge.Visibility='Visible' }
    $c.BusyShade.Visibility='Visible'
    # Fit the logical window within the current work area at 100/125/150% DPI.
    if (-not $Screenshot) {
        $area=[Windows.SystemParameters]::WorkArea
        $window.Width=[Math]::Min(1180,$area.Width-24); $window.Height=[Math]::Min(760,$area.Height-24)
        $window.MinWidth=[Math]::Min(880,$window.Width); $window.MinHeight=[Math]::Min(600,$window.Height)
    }
    $window.Add_ContentRendered({
        $s=$script:SDUI; if ($s.Started) { return }; $s.Started=$true
        if ($s.StartupFailed) {
            $s.Controls.FooterStatus.Text=$s.Text.startupError
            foreach ($name in @('AddTop','CreateFirst','CreateStarters','OpenExport')) { $s.Controls[$name].IsEnabled=$false }
            Set-SDUiToast $s.Text.startupError $true
        } else {
            Update-SDUiState
            Invoke-SDUiSafe { if ($s.View -eq 'editor') { $id=''; if ($s.Buttons.Count -gt 0) { $id=$s.Buttons[0].Id }; Open-SDUiEditor $id }; if ($s.View -eq 'export') { Open-SDUiExport } }
            $s.StateTimer.Start()
        }
        $s.Controls.BusyShade.Visibility='Collapsed'
        if ($s.Screenshot) {
            $s.CaptureTimer=New-Object Windows.Threading.DispatcherTimer
            $s.CaptureTimer.Interval=[TimeSpan]::FromMilliseconds(600)
            $s.CaptureTimer.Add_Tick({
                $s=$script:SDUI; $s.CaptureTimer.Stop()
                try {
                    $s.Window.UpdateLayout()
                    $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$s.Window.ActualWidth,[int]$s.Window.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32)
                    $bitmap.Render($s.Window)
                    $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder; $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
                    $path=[IO.Path]::GetFullPath($s.Screenshot); [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
                    $stream=[IO.File]::Create($path); try { $encoder.Save($stream) } finally { $stream.Dispose() }
                } catch { $s.CaptureError=$_ }
                finally { $s.Dirty=$false; $s.Window.Close() }
            })
            $s.CaptureTimer.Start()
        }
    })
    try { [void]$window.ShowDialog() }
    finally { [Windows.Application]::Current.Resources.MergedDictionaries.Remove($theme) | Out-Null }
    if ($script:SDUI.CaptureError) { throw $script:SDUI.CaptureError }
}
