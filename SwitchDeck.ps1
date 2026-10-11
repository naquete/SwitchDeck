[CmdletBinding()]
param(
    [switch]$Demo,
    [string]$Screenshot,
    [ValidateSet('main', 'editor', 'empty', 'export')][string]$View = 'main'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml
$engineFile = Join-Path $PSScriptRoot 'src\Engine.ps1'
if ($Demo) { $engineFile = Join-Path $PSScriptRoot 'src\Engine.Demo.ps1' }
$startupFailed = $false
try {
    . $engineFile
    if ($Demo -and $View -eq 'empty') { $script:SDDemoButtons.Clear() }
} catch { $startupFailed = $true }
. (Join-Path $PSScriptRoot 'src\Ui.ps1')
Show-SwitchDeckUi -Demo:$Demo -Screenshot $Screenshot -View $View -EngineFile $engineFile -StartupFailed:$startupFailed
