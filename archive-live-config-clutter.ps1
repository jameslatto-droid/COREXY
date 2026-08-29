param(
    [string]$Remote = "klipper",
    [string]$ConfigDir = "/home/pi/printer_data/config",
    [switch]$Apply
)

$ErrorActionPreference = "Stop"

$archiveDir = "/home/pi/printer_data/config_archive/2026-08-29-cleanup"
$mode = if ($Apply) { "apply" } else { "preview" }

$bash = @'
set -euo pipefail

config_dir="$1"
archive_dir="$2"
mode="$3"

required_files=(
  printer.cfg
  mainsail.cfg
  hardware.cfg
  tuning.cfg
  thermistors.cfg
  fans.cfg
  probe.cfg
  advanced.cfg
  system.cfg
  macro.cfg
  calibration.cfg
  neopixel1.cfg
  menu.cfg
  timelapse.cfg
  mainsail-mobile.cfg
  moonraker.conf
  crowsnest.conf
  sonar.conf
)

for f in "${required_files[@]}"; do
  if [ ! -f "$config_dir/$f" ]; then
    echo "ERROR: required live file is missing: $f" >&2
    exit 2
  fi
done

keep_name() {
  case "$1" in
    printer.cfg|mainsail.cfg|hardware.cfg|tuning.cfg|thermistors.cfg|fans.cfg|probe.cfg|advanced.cfg|system.cfg|macro.cfg|calibration.cfg|neopixel1.cfg|menu.cfg|timelapse.cfg|mainsail-mobile.cfg|moonraker.conf|crowsnest.conf|sonar.conf|.theme)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

echo "Mode: $mode"
echo "Live config: $config_dir"
echo "Archive:     $archive_dir"
echo

if [ "$mode" = "apply" ]; then
  mkdir -p "$archive_dir"
  snapshot="$archive_dir/config-root-before-cleanup.tar.gz"
  echo "Creating safety archive: $snapshot"
  tar -czf "$snapshot" -C "$(dirname "$config_dir")" "$(basename "$config_dir")"
  echo
fi

find "$config_dir" -mindepth 1 -maxdepth 1 -print0 | sort -z | while IFS= read -r -d '' path; do
  name="$(basename "$path")"
  if keep_name "$name"; then
    printf 'KEEP     %s\n' "$name"
  else
    if [ "$mode" = "apply" ]; then
      printf 'ARCHIVE  %s\n' "$name"
      if [ -e "$archive_dir/$name" ]; then
        suffix="$(date +%Y%m%d-%H%M%S)"
        mv -- "$path" "$archive_dir/${name}.${suffix}"
      else
        mv -- "$path" "$archive_dir/$name"
      fi
    else
      printf 'WOULD ARCHIVE  %s\n' "$name"
    fi
  fi
done

if [ "$mode" = "apply" ]; then
  echo
  echo "Remaining live config root:"
  find "$config_dir" -mindepth 1 -maxdepth 1 -printf '  %f\n' | sort
  echo
  echo "Archived entries:"
  find "$archive_dir" -mindepth 1 -maxdepth 1 -printf '  %f\n' | sort
  echo
  echo "No G-code was issued and Klipper was not restarted."
else
  echo
  echo "Preview only. Re-run with -Apply to move the entries marked WOULD ARCHIVE."
fi
'@

# Materialize the Bash payload as an LF-only, UTF-8-without-BOM temp file.
# Copying a real script avoids CRLF/stdin-pipeline parsing differences between
# PowerShell on Windows and Bash on the Raspberry Pi.
$bash = $bash.Replace("`r`n", "`n").Replace("`r", "")
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$localScript = Join-Path ([System.IO.Path]::GetTempPath()) ("corexy-config-archive-{0}.sh" -f [guid]::NewGuid().ToString("N"))
$remoteScript = "/tmp/corexy-config-archive.sh"

try {
    [System.IO.File]::WriteAllText($localScript, $bash + "`n", $utf8NoBom)

    Write-Host "Uploading temporary archive audit script to $Remote..."
    scp $localScript "$Remote`:$remoteScript"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to upload remote archive audit script (scp exit $LASTEXITCODE)"
    }

    Write-Host "Auditing live config root on $Remote..."
    ssh $Remote "bash $remoteScript '$ConfigDir' '$archiveDir' '$mode'; rc=`$?; rm -f '$remoteScript'; exit `$rc"
    if ($LASTEXITCODE -ne 0) {
        throw "Remote archive audit failed with exit code $LASTEXITCODE"
    }
}
finally {
    Remove-Item -LiteralPath $localScript -Force -ErrorAction SilentlyContinue
}
