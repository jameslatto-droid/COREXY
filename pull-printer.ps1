$ErrorActionPreference = "Stop"

$files = @(
    "printer.cfg",
    "mainsail.cfg",
    "hardware.cfg",
    "tuning.cfg",
    "thermistors.cfg",
    "fans.cfg",
    "probe.cfg",
    "advanced.cfg",
    "system.cfg",
    "macro.cfg",
    "calibration.cfg",
    "neopixel1.cfg",
    "menu.cfg",
    "timelapse.cfg",
    "mainsail-mobile.cfg",
    "moonraker.conf",
    "crowsnest.conf",
    "sonar.conf"
)

Write-Host "Pulling active Klipper configuration only..."
foreach ($file in $files) {
    Write-Host "  $file"
    scp "klipper:/home/pi/printer_data/config/$file" "$PSScriptRoot\config\$file"
    if ($LASTEXITCODE -ne 0) {
        throw "scp failed while pulling $file"
    }
}

Write-Host ""
Write-Host "Done. Historical/backup files were not copied."
Write-Host "Use capture-live-config.ps1 when a complete forensic snapshot is required."
Write-Host ""
Write-Host "Current Git changes:"
git -C $PSScriptRoot status --short
