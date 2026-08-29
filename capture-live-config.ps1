param(
    [string]$Remote = "klipper",
    [string]$RemoteConfig = "/home/pi/printer_data/config"
)

$ErrorActionPreference = "Stop"

$timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
$repoRoot = $PSScriptRoot
$snapshotRoot = Join-Path $repoRoot "backups\$timestamp-post-update-live"

Write-Host "Creating read-only live Klipper configuration snapshot..."
Write-Host "Source: $Remote`:$RemoteConfig"
Write-Host "Destination: $snapshotRoot"
Write-Host ""

New-Item -ItemType Directory -Force -Path $snapshotRoot | Out-Null

# Copy the directory itself (rather than config/*) so hidden files/directories
# are retained by scp where supported. This command only reads from the Pi.
scp -r "$Remote`:$RemoteConfig" "$snapshotRoot\"
if ($LASTEXITCODE -ne 0) {
    throw "scp failed with exit code $LASTEXITCODE"
}

$configRoot = Join-Path $snapshotRoot "config"
if (-not (Test-Path $configRoot)) {
    throw "Expected copied config directory not found at: $configRoot"
}

Write-Host "Generating SHA256 manifest..."
$manifestPath = Join-Path $snapshotRoot "SHA256SUMS.txt"
$hashLines = foreach ($file in Get-ChildItem -Path $configRoot -File -Recurse | Sort-Object FullName) {
    $hash = (Get-FileHash -Algorithm SHA256 -Path $file.FullName).Hash.ToLowerInvariant()
    $relative = [System.IO.Path]::GetRelativePath($configRoot, $file.FullName).Replace('\', '/')
    "$hash  $relative"
}
$hashLines | Set-Content -Path $manifestPath -Encoding ascii

Write-Host "Auditing G-code macros and LED effects..."
$macroPattern = '^\s*\[gcode_macro\s+([^\]]+)\]\s*$'
$effectPattern = '^\s*\[led_effect\s+([^\]]+)\]\s*$'
$includePattern = '^\s*\[include\s+([^\]]+)\]\s*$'

$macroRows = @()
$effectRows = @()
$includeRows = @()

foreach ($cfg in Get-ChildItem -Path $configRoot -Filter *.cfg -File -Recurse | Sort-Object FullName) {
    $relativeFile = [System.IO.Path]::GetRelativePath($configRoot, $cfg.FullName).Replace('\', '/')
    $lineNumber = 0

    foreach ($line in Get-Content -Path $cfg.FullName) {
        $lineNumber++

        if ($line -match $macroPattern) {
            $name = $Matches[1].Trim()
            $macroRows += [pscustomobject]@{
                Macro = $name
                HiddenByName = $name.StartsWith('_')
                File = $relativeFile
                Line = $lineNumber
            }
        }

        if ($line -match $effectPattern) {
            $name = $Matches[1].Trim()
            $effectRows += [pscustomobject]@{
                Effect = $name
                File = $relativeFile
                Line = $lineNumber
            }
        }

        if ($line -match $includePattern) {
            $includeRows += [pscustomobject]@{
                Include = $Matches[1].Trim()
                File = $relativeFile
                Line = $lineNumber
            }
        }
    }
}

$macroCsv = Join-Path $snapshotRoot "MACRO_INVENTORY.csv"
$effectCsv = Join-Path $snapshotRoot "LED_EFFECT_INVENTORY.csv"
$includeCsv = Join-Path $snapshotRoot "INCLUDE_INVENTORY.csv"
$visibleTxt = Join-Path $snapshotRoot "VISIBLE_MACROS.txt"

$macroRows | Sort-Object Macro, File | Export-Csv -Path $macroCsv -NoTypeInformation -Encoding utf8
$effectRows | Sort-Object Effect, File | Export-Csv -Path $effectCsv -NoTypeInformation -Encoding utf8
$includeRows | Sort-Object File, Line | Export-Csv -Path $includeCsv -NoTypeInformation -Encoding utf8

$visibleMacros = $macroRows | Where-Object { -not $_.HiddenByName } | Sort-Object Macro
$visibleMacros | ForEach-Object { "{0}  [{1}:{2}]" -f $_.Macro, $_.File, $_.Line } | Set-Content -Path $visibleTxt -Encoding utf8

Write-Host ""
Write-Host "Snapshot complete."
Write-Host "Files:"
Write-Host "  $manifestPath"
Write-Host "  $macroCsv"
Write-Host "  $effectCsv"
Write-Host "  $includeCsv"
Write-Host "  $visibleTxt"
Write-Host ""
Write-Host ("Macros found: {0} total / {1} visible-by-name" -f $macroRows.Count, $visibleMacros.Count)
Write-Host ("LED effects found: {0}" -f $effectRows.Count)
Write-Host ""
Write-Host "No files were written to the printer and no G-code was issued."
Write-Host ""
Write-Host "Current Git status:"
git -C $repoRoot status --short
