# SwitchDeck - ponto de entrada da interface gráfica
. (Join-Path $PSScriptRoot 'src\Core.ps1')
. (Join-Path $PSScriptRoot 'src\Gui.ps1')
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
Show-SwitchDeckGui
