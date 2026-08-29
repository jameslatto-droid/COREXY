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

while IFS= read -r -d '' path; do
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
done < <(find "$config_dir" -mindepth 1 -maxdepth 1 -print0 | sort -z)

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

# Windows Git checkouts commonly use CRLF. Bash on the Pi requires LF-only
# input here; otherwise tokens such as 'pipefail' arrive as 'pipefail\r'.
$bash = $bash.Replace("`r", "")

Write-Host "Auditing live config root on $Remote..."
$bash | ssh $Remote bash -s -- $ConfigDir $archiveDir $mode
if ($LASTEXITCODE -ne 0) {
    throw "Remote archive audit failed with exit code $LASTEXITCODE"
}
