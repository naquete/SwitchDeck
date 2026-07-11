@echo off
rem SwitchDeck - abrir a interface grafica
if exist "%~dp0bin\RunHidden.exe" (
  start "" "%~dp0bin\RunHidden.exe" -NoProfile -ExecutionPolicy Bypass -Sta -File "%~dp0SwitchDeck.ps1"
) else (
  start "" powershell -NoProfile -ExecutionPolicy Bypass -Sta -WindowStyle Hidden -File "%~dp0SwitchDeck.ps1"
)
