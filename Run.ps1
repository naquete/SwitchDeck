# SwitchDeck - executor de ações (chamado pelos atalhos, sem interface)
param(
    [ValidateSet('audio','profile')] [string]$Do,
    [string]$Name,   # nome do dispositivo (preferido, estavel)
    [string]$Id,     # id do endpoint (compatibilidade)
    [string]$File
)
. (Join-Path $PSScriptRoot 'src\Core.ps1')
switch ($Do) {
    'audio'   { if ($Name) { Set-SDAudioByName $Name | Out-Null } elseif ($Id) { Set-SDAudioDefault $Id | Out-Null } }
    'profile' { if ($File -and (Test-Path $File)) { Invoke-SDProfile -File $File } }
}
