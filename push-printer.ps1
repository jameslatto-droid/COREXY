$ErrorActionPreference = "Stop"

Write-Host "Changes that will be pushed:"
git -C $PSScriptRoot status --short

Write-Host ""
$confirm = Read-Host "Push local config to CoreXY printer? (y/N)"

if ($confirm -ne "y") {
    Write-Host "Cancelled."
    exit
}

Write-Host "Uploading configuration..."

scp -r "$PSScriptRoot\config\*" klipper:/home/pi/printer_data/config/

Write-Host ""
Write-Host "Upload complete."
Write-Host "Restart Klipper from Mainsail when ready."
