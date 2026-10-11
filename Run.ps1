# SwitchDeck - executor de acoes (chamado pelos atalhos e pelo Stream Deck, sem janela)
param(
    [ValidateSet('button','audio','profile')] [string]$Do,
    [string]$Id,     # -Do button: id do botao
    [string]$Name,   # -Do audio: nome do aparelho (atalhos da versao 1)
    [string]$File    # -Do profile: arquivo .dat do arranjo de telas (atalhos da versao 1)
)
. (Join-Path $PSScriptRoot 'src\Engine.ps1')

# Aviso discreto na bandeja; nada de caixa de dialogo que trava o botao.
function Show-SDNotice([string]$text) {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $ni = New-Object System.Windows.Forms.NotifyIcon
        $ico = Join-Path $PSScriptRoot 'bin\SwitchDeck.ico'
        if (Test-Path -LiteralPath $ico) { $ni.Icon = New-Object System.Drawing.Icon($ico) } else { $ni.Icon = [System.Drawing.SystemIcons]::Information }
        $ni.Visible = $true
        $ni.ShowBalloonTip(4000, 'SwitchDeck', $text, [System.Windows.Forms.ToolTipIcon]::Warning)
        Start-Sleep -Milliseconds 4200
        $ni.Visible = $false
        $ni.Dispose()
    } catch { }
}

switch ($Do) {
    'button' {
        $r = Invoke-SDButton -Id $Id
        if (-not $r.Ok) { Show-SDNotice (($r.Warnings + $r.Lines) -join "`n") }
    }
    'audio' {
        if ($Name) {
            $all = @([SwitchDeck.AudioNative]::List(0)) + @([SwitchDeck.AudioNative]::List(1))
            $d = _sdFind $all $Name
            if ($d) { [SwitchDeck.AudioNative]::SetDefault($d.Id) } else { Show-SDNotice (_sdText 'run' 'missingOutput' $Name) }
        }
    }
    'profile' {
        if ($File -and (Test-Path -LiteralPath $File)) { [void][SwitchDeck.DisplayNative]::Load($File) }
    }
}
