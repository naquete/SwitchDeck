# ============================================================================
#  SwitchDeck - Ulanzi D200 (experimental)
#  Cria, dentro do perfil em uso no programa da Ulanzi, uma pasta "SwitchDeck"
#  com uma tecla para cada botao. O programa precisa estar fechado para a
#  mudanca valer, entao ele e fechado e reaberto. Sempre guarda copia antes.
#  Carregado por Engine.ps1. Arquivo em ASCII puro.
# ============================================================================

# Teste sem tocar no perfil de verdade: aponte SWITCHDECK_ULANZI_ROOT para uma copia.
function _sdUlanziRoot {
    if ($env:SWITCHDECK_ULANZI_ROOT) { return $env:SWITCHDECK_ULANZI_ROOT }
    return (Join-Path $env:APPDATA 'Ulanzi\UlanziDeck')
}
function _sdUlanziIsTest { return [bool]$env:SWITCHDECK_ULANZI_ROOT }
function _sdUlanziExe {
    $p = Get-Process UlanziDeck -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($p) { try { if ($p.MainModule.FileName) { return $p.MainModule.FileName } } catch { } }
    foreach ($base in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
        if ($base) { $c = Join-Path $base 'Ulanzi Studio\UlanziDeck.exe'; if (Test-Path -LiteralPath $c) { return $c } }
    }
    return $null
}
function _sdJsonRead([string]$file) { return ([System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8) | ConvertFrom-Json) }
function _sdJsonWrite([string]$file,$obj) { [System.IO.File]::WriteAllText($file, ($obj | ConvertTo-Json -Depth 40 -Compress), $script:SDUtf8) }
function _sdFwd([string]$path) { return ($path -replace '\\','/') }

function _sdUlanziLocate {
    $root = _sdUlanziRoot
    $r = [ordered]@{ Installed = $false; Running = $false; Device = ''; Profile = ''; Supported = $false; Reason = ''; Root = $root; ProfileDir = $null }
    $profiles = Join-Path $root 'ProfilesV2'
    if (-not (Test-Path -LiteralPath $profiles)) { $r.Reason = _sdText 'ulanzi' 'notInstalled'; return [pscustomobject]$r }
    $r.Installed = $true
    $r.Running = [bool](Get-Process UlanziDeck -ErrorAction SilentlyContinue)
    $settings = Join-Path $root 'Config\setting_source.json'
    $dev = $null
    if (Test-Path -LiteralPath $settings) {
        try {
            $s = _sdJsonRead $settings
            $dev = @($s.Devices | Where-Object { $_.CurrentDevice -eq $s.CurrentDeviceType }) | Select-Object -First 1
        } catch { }
    }
    if (-not $dev) { $r.Reason = _sdText 'ulanzi' 'noDevice'; return [pscustomobject]$r }
    $r.Device = [string]$dev.DeviceType
    $r.Profile = [string]$dev.CurrentProfile
    foreach ($dir in @(Get-ChildItem -LiteralPath $profiles -Directory -Filter '*.ulanziProfile')) {
        $mf = Join-Path $dir.FullName 'manifest.json'
        if (-not (Test-Path -LiteralPath $mf)) { continue }
        try {
            $m = _sdJsonRead $mf
            if ($m.Device.UUID -eq $dev.CurrentDevice -and $m.Name -eq $dev.CurrentProfile) { $r.ProfileDir = $dir.FullName; break }
        } catch { }
    }
    if (-not $r.ProfileDir) { $r.Reason = _sdText 'ulanzi' 'noProfile'; return [pscustomobject]$r }
    if ($r.Device -ne 'D200') { $r.Reason = _sdText 'ulanzi' 'unsupported' $r.Device; return [pscustomobject]$r }
    $r.Supported = $true
    $r.Reason = _sdText 'ulanzi' 'ready'
    return [pscustomobject]$r
}

function Get-SDUlanzi {
    $u = _sdUlanziLocate
    [pscustomobject]@{ Installed = $u.Installed; Running = $u.Running; Device = $u.Device; Profile = $u.Profile; Supported = $u.Supported; Reason = $u.Reason }
}

function _sdUlanziAction([string]$action,[string]$name,$param,$plugin,$views,[int]$state = 0) {
    return [ordered]@{
        Action = 'com.ulanzi.ulanzideck.' + $action
        ActionID = [guid]::NewGuid().ToString()
        ActionParam = $param
        LinkedTitle = $true
        Name = $name
        Plugin = $plugin
        State = $state
        ViewParam = @($views)
    }
}
function _sdKeypad($manifest) { return (@($manifest.Controllers | Where-Object { $_.Type -eq 'Keypad' }) | Select-Object -First 1) }
# O programa grava as teclas em ordem alfabetica; mantem igual.
function _sdSortedActions($table) {
    $sorted = [ordered]@{}
    foreach ($k in @($table.Keys | Sort-Object { $_ })) { $sorted[$k] = $table[$k] }
    return [pscustomobject]$sorted
}

function Send-SDToUlanzi {
    param([switch]$NoRestart)
    $lines = @(); $warn = @()
    $u = _sdUlanziLocate
    if (-not $u.Supported) { return [pscustomobject]@{ Ok = $false; Lines = @(); Warnings = @($u.Reason) } }
    $buttons = @(_sdLoad)
    if (-not $buttons.Count) { return [pscustomobject]@{ Ok = $false; Lines = @(); Warnings = @(_sdText 'ulanzi' 'noButtons') } }
    $test = _sdUlanziIsTest

    # 1) fecha o programa (ele so le o perfil ao abrir e regrava ao fechar)
    $exe = _sdUlanziExe
    if (-not $test) {
        $proc = Get-Process UlanziDeck -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($proc) {
            & taskkill.exe /PID $proc.Id /T /F 2>$null | Out-Null
            for ($i = 0; $i -lt 16 -and (Get-Process UlanziDeck -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 500 }
        }
        if (Get-Process UlanziDeck -ErrorAction SilentlyContinue) { return [pscustomobject]@{ Ok = $false; Lines = @(); Warnings = @(_sdText 'ulanzi' 'stillRunning') } }
    }

    try {
        # 2) copia de seguranca do perfil inteiro
        if (-not (Test-Path -LiteralPath $script:SDBackupDir)) { [void][System.IO.Directory]::CreateDirectory($script:SDBackupDir) }
        $backup = Join-Path $script:SDBackupDir ('ulanzi-' + (Get-Date).ToString('yyyyMMdd-HHmmss'))
        Copy-Item -LiteralPath $u.ProfileDir -Destination $backup -Recurse
        $lines += (_sdText 'ulanzi' 'backup' $backup)

        # 3) qual pagina e a nossa (lembrada entre envios)
        $mapFile = Join-Path $script:SDData 'ulanzi.json'
        $map = @{}
        if (Test-Path -LiteralPath $mapFile) { try { (_sdJsonRead $mapFile).PSObject.Properties | ForEach-Object { $map[$_.Name] = [string]$_.Value } } catch { } }
        $profileKey = Split-Path -Leaf $u.ProfileDir
        $pagesDir = Join-Path $u.ProfileDir 'Profiles'
        $pageId = $map[$profileKey]
        if (-not $pageId -or -not (Test-Path -LiteralPath (Join-Path $pagesDir $pageId))) { $pageId = [guid]::NewGuid().ToString() }
        $pageDir = Join-Path $pagesDir $pageId
        $imgDir = Join-Path $pageDir 'Images'
        if (-not (Test-Path -LiteralPath $imgDir)) { [void][System.IO.Directory]::CreateDirectory($imgDir) }

        # 4) monta a pagina: voltar + ate 12 botoes + janela larga com relogio
        $slots = @('1_0','2_0','3_0','4_0','0_1','1_1','2_1','3_1','4_1','0_2','1_2','2_2')
        if ($buttons.Count -gt $slots.Count) { $warn += (_sdText 'ulanzi' 'tooMany' ($buttons.Count - $slots.Count)) }
        $system = [ordered]@{ Name = 'System'; UUID = ''; Version = '1.0' }
        $pagesPlugin = [ordered]@{ Name = 'Pages'; UUID = ''; Version = '1.0' }
        $acts = @{}
        $backIcon = _sdFwd (Join-Path $u.Root 'System\Plugins\com.ulanzi.deck.page\Images\btn_backToParent.png')
        $acts['0_0'] = _sdUlanziAction 'page.back' 'Parent Folder' @{} $pagesPlugin @([ordered]@{ Icon = $backIcon; IconRel = '' })
        $keep = @{}
        $sent = 0
        for ($i = 0; $i -lt $buttons.Count -and $i -lt $slots.Count; $i++) {
            $b = $buttons[$i]
            $file = 'sd_' + $b.Id + '.png'
            _sdRender $b 196 (Join-Path $imgDir $file)
            $keep[$file] = $true
            $view = [ordered]@{ Icon = (_sdFwd (Join-Path $imgDir $file)); IconRel = 'Images/' + $file }
            $acts[$slots[$i]] = _sdUlanziAction 'system.open' 'Open' ([ordered]@{ Path = (Get-SDCommand -Id $b.Id) }) $system @($view)
            $sent++
        }
        $windowName = 'Background settings'
        $top = _sdJsonRead (Join-Path $u.ProfileDir 'manifest.json')
        $topPages = @($top.Pages.Pages)
        $pageDocs = @{}
        foreach ($pid2 in $topPages) {
            $pm = Join-Path $pagesDir "$pid2\manifest.json"
            if (Test-Path -LiteralPath $pm) {
                try {
                    $pageDocs[$pid2] = _sdJsonRead $pm
                    $kp = _sdKeypad $pageDocs[$pid2]
                    foreach ($prop in @($kp.Actions.PSObject.Properties)) { if ($prop.Value.Action -like '*smallwindow.window' -and $prop.Value.Name) { $windowName = $prop.Value.Name } }
                } catch { }
            }
        }
        $acts['3_2'] = _sdUlanziAction 'smallwindow.window' $windowName ([ordered]@{ SmallViewMode = 1 }) @{} @([ordered]@{ Icon = ''; IconRel = '' })
        $page = [ordered]@{
            Controllers = @(
                [ordered]@{ Actions = @{}; Type = 'Encoder' },
                [ordered]@{ Actions = (_sdSortedActions $acts); Type = 'Keypad' }
            )
            Icon = ''; Name = ''
        }
        _sdJsonWrite (Join-Path $pageDir 'manifest.json') $page
        foreach ($old in @(Get-ChildItem -LiteralPath $imgDir -Filter 'sd_*.png' -ErrorAction SilentlyContinue)) { if (-not $keep.ContainsKey($old.Name)) { try { [System.IO.File]::Delete($old.FullName) } catch { } } }
        $lines += (_sdText 'ulanzi' 'page' $sent)
        $map[$profileKey] = $pageId
        _sdJsonWrite $mapFile ([pscustomobject]$map)

        # 5) tecla de pasta numa pagina principal, na primeira posicao livre
        $exists = $false
        foreach ($pid2 in $topPages) {
            if (-not $pageDocs.ContainsKey($pid2)) { continue }
            $kp = _sdKeypad $pageDocs[$pid2]
            foreach ($prop in @($kp.Actions.PSObject.Properties)) { if ($prop.Value.Action -like '*page.folder' -and $prop.Value.ActionParam.ProfileUUID -eq $pageId) { $exists = $true } }
        }
        if ($exists) { $lines += (_sdText 'ulanzi' 'folderKept') }
        else {
            $all = @('0_0','1_0','2_0','3_0','4_0','0_1','1_1','2_1','3_1','4_1','0_2','1_2','2_2')
            $placed = $false; $number = 0
            foreach ($pid2 in $topPages) {
                $number++
                if ($placed -or -not $pageDocs.ContainsKey($pid2)) { continue }
                $kp = _sdKeypad $pageDocs[$pid2]
                $usedKeys = @($kp.Actions.PSObject.Properties | ForEach-Object { $_.Name })
                $free = @($all | Where-Object { $usedKeys -notcontains $_ }) | Select-Object -First 1
                if (-not $free) { continue }
                $topImg = Join-Path $pagesDir "$pid2\Images"
                if (-not (Test-Path -LiteralPath $topImg)) { [void][System.IO.Directory]::CreateDirectory($topImg) }
                New-SDTileImage -Top (_sdText 'top' 'folder') -Big 'SWITCH' -Glyph 'folder' -Color '#71DED0' -Size 196 -OutFile (Join-Path $topImg 'sd_folder.png') | Out-Null
                $view = [ordered]@{ Icon = (_sdFwd (Join-Path $topImg 'sd_folder.png')); IconRel = 'Images/sd_folder.png' }
                $table = @{}
                foreach ($prop in @($kp.Actions.PSObject.Properties)) { $table[$prop.Name] = $prop.Value }
                $table[$free] = [pscustomobject](_sdUlanziAction 'page.folder' 'Create Folder' ([ordered]@{ ProfileUUID = $pageId }) $pagesPlugin @($view))
                $kp.Actions = _sdSortedActions $table
                _sdJsonWrite (Join-Path $pagesDir "$pid2\manifest.json") $pageDocs[$pid2]
                $placed = $true
                $lines += (_sdText 'ulanzi' 'folderAdded' $number)
            }
            if (-not $placed) { $warn += (_sdText 'ulanzi' 'noSlot') }
        }
        if ($script:SDRoot -match '\s') { $warn += (_sdText 'ulanzi' 'spaces') }
    }
    catch {
        $warn += $_.Exception.Message
    }
    finally {
        # 6) reabre o programa, mesmo se algo falhou no meio
        if (-not $test -and -not $NoRestart -and $exe -and (Test-Path -LiteralPath $exe)) {
            try { Start-Process -FilePath $exe -WorkingDirectory (Split-Path -Parent $exe); $lines += (_sdText 'ulanzi' 'restarted') } catch { $warn += (_sdText 'ulanzi' 'notRestarted') }
        } elseif (-not $test) { $lines += (_sdText 'ulanzi' 'notRestarted') }
    }
    return [pscustomobject]@{ Ok = ($warn.Count -eq 0); Lines = @($lines); Warnings = @($warn) }
}
