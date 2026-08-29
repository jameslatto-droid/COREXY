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

Write-Host "Active configuration files that will be pushed:"
foreach ($file in $files) {
    $path = Join-Path $PSScriptRoot "config\$file"
    if (-not (Test-Path $path)) {
        throw "Required deployment file missing: $path"
    }
    Write-Host "  $file"
}

Write-Host ""
Write-Host "Current Git changes:"
git -C $PSScriptRoot status --short

Write-Host ""
$confirm = Read-Host "Push active config to CoreXY printer? (y/N)"
if ($confirm -ne "y") {
    Write-Host "Cancelled."
    exit
}

Write-Host "Uploading active configuration only..."
foreach ($file in $files) {
    $path = Join-Path $PSScriptRoot "config\$file"
    scp $path "klipper:/home/pi/printer_data/config/$file"
    if ($LASTEXITCODE -ne 0) {
        throw "scp failed while uploading $file"
    }
}

Write-Host ""
Write-Host "Upload complete. No historical/backup files were copied."
Write-Host "Restart Klipper from Mainsail when ready."
