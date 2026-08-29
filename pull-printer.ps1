$ErrorActionPreference = "Stop"

Write-Host "Pulling live Klipper configuration..."

scp -r klipper:/home/pi/printer_data/config/* "$PSScriptRoot\config\"

Write-Host ""
Write-Host "Done. Current Git changes:"
git -C $PSScriptRoot status --short
