# SwitchDeck - instalacao (executar uma vez)
$root = $PSScriptRoot
Write-Host 'Instalando SwitchDeck...' -ForegroundColor Cyan

# 1) Desbloqueia arquivos baixados da internet (Mark-of-the-Web)
Get-ChildItem $root -Recurse -File | Unblock-File -ErrorAction SilentlyContinue

# 2) Carrega o motor (compila o codigo nativo) e garante o lancador sem janela
. (Join-Path $root 'src\Engine.ps1')
Confirm-SDRunHidden

# 3) Gera o icone do app
$appPng = Join-Path $root 'bin\SwitchDeck.png'
New-SDTileImage -Top 'SWITCH' -Big 'DECK' -Glyph 'mixer' -Color '#71DED0' -Size 256 -OutFile $appPng -Ico | Out-Null
$appIco = [IO.Path]::ChangeExtension($appPng, '.ico')

# 4) Cria o atalho na Area de Trabalho para abrir o app (sem janela de terminal)
$wsh = New-Object -ComObject WScript.Shell
$lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'SwitchDeck.lnk'
$sc = $wsh.CreateShortcut($lnk)
$sc.TargetPath = (Join-Path $root 'bin\RunHidden.exe')
$sc.Arguments = "-NoProfile -ExecutionPolicy Bypass -Sta -File `"$(Join-Path $root 'SwitchDeck.ps1')`""
$sc.WorkingDirectory = $root
if (Test-Path $appIco) { $sc.IconLocation = "$appIco,0" }
$sc.Description = 'SwitchDeck - som, microfone e telas em um clique'
$sc.Save()

Write-Host ''
Write-Host 'Pronto! Atalho "SwitchDeck" criado na Area de Trabalho.' -ForegroundColor Green
Write-Host 'Abra por ele sempre que quiser criar ou mudar seus botoes.'
Write-Host ''
Start-Sleep -Seconds 2
