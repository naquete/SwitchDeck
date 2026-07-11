# SwitchDeck - instalação (executar uma vez)
$root = $PSScriptRoot
Write-Host 'Instalando SwitchDeck...' -ForegroundColor Cyan

# 1) Desbloqueia arquivos baixados da internet (Mark-of-the-Web)
Get-ChildItem $root -Recurse -File | Unblock-File -ErrorAction SilentlyContinue

# 2) Carrega o núcleo (compila a DLL nativa) e garante o lançador RunHidden.exe
. (Join-Path $root 'src\Core.ps1')
Confirm-SDRunHidden

# 3) Gera o ícone do app
$appPng = Join-Path $root 'bin\SwitchDeck.png'
New-SDIcon -Type 'monitor' -Top 'SWITCH' -Big 'DECK' -OutFile $appPng -ColorA '#0EA5A4' -ColorB '#2563EB' | Out-Null
$appIco = [IO.Path]::ChangeExtension($appPng,'.ico')

# 4) Cria atalho na Área de Trabalho para abrir o app (sem flash de terminal)
$wsh = New-Object -ComObject WScript.Shell
$lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'SwitchDeck.lnk'
$sc = $wsh.CreateShortcut($lnk)
$sc.TargetPath = (Join-Path $root 'bin\RunHidden.exe')
$sc.Arguments  = "-NoProfile -ExecutionPolicy Bypass -Sta -File `"$(Join-Path $root 'SwitchDeck.ps1')`""
$sc.WorkingDirectory = $root
if (Test-Path $appIco) { $sc.IconLocation = "$appIco,0" }
$sc.Description = 'SwitchDeck - trocar áudio, microfone e monitores'
$sc.Save()

Write-Host ''
Write-Host 'Pronto! Atalho "SwitchDeck" criado na Area de Trabalho.' -ForegroundColor Green
Write-Host 'Abra por ele sempre que quiser configurar seus dispositivos.'
Write-Host ''
Start-Sleep -Seconds 2
