# SwitchDeck - executor de ações (chamado pelos atalhos, sem interface)
param(
    [ValidateSet('audio','profile')] [string]$Do,
    [string]$Id,
    [string]$File
)
. (Join-Path $PSScriptRoot 'src\Core.ps1')
switch ($Do) {
    'audio'   { if ($Id)   { Set-SDAudioDefault $Id } }
    'profile' { if ($File -and (Test-Path $File)) { Invoke-SDProfile -File $File } }
}
