# Mainsail Mobile Pendant

A phone-focused Mainsail dashboard for the COREXY printer.

The implementation deliberately uses Mainsail and Moonraker's existing configuration mechanisms rather than forking Mainsail or creating a second printer-control web app.

## Mobile view

The mobile dashboard is reduced to:

1. **Toolhead control** — native Mainsail X/Y/Z jog, positions and homing controls.
2. **Extruder control** — native Mainsail extrude/retract controls.
3. **Temperature** — native Mainsail heater current/target controls.
4. **Probe & Level** — a dedicated mobile-only macro group populated from the Klipper objects actually loaded on the printer.

The normal generic **Macros** panel is hidden on the phone. Desktop and tablet dashboard layouts are not modified.

## Probe & Level detection

The installer checks `/printer/objects/list` and creates wrapper macros only for features that exist:

| Klipper object | Mobile macro |
| --- | --- |
| `probe` / `bltouch` | `MOBILE_PROBE_ACCURACY` |
| `bed_mesh` | `MOBILE_BED_MESH_CALIBRATE`, `MOBILE_BED_MESH_CLEAR` |
| `quad_gantry_level` | `MOBILE_QUAD_GANTRY_LEVEL` |
| `z_tilt` / `z_tilt_ng` | `MOBILE_Z_TILT_ADJUST` |
| `screws_tilt_adjust` | `MOBILE_SCREWS_TILT_CALCULATE` |
| `bed_tilt` | `MOBILE_BED_TILT_CALIBRATE` |

Interactive calibration routines such as `PROBE_CALIBRATE`, `BED_SCREWS_ADJUST` and `Z_ENDSTOP_CALIBRATE` are intentionally not added because the mobile mini-console is hidden.

The wrappers do **not** home first, call `SAVE_CONFIG`, restart Klipper, or control individual Z motors. If a calibration command requires homed axes, home the printer yourself first from the native Toolhead panel.

## Install

From the local `COREXY` repository, run a read-only dry run first.

Windows PowerShell:

```powershell
py .\mainsail\mobile-pendant\install.py --dry-run
```

Linux / macOS:

```bash
python3 mainsail/mobile-pendant/install.py --dry-run
```

The default Moonraker/Mainsail address is `http://192.168.1.203`. Override it with `--moonraker` if required.

The dry run reads the live printer/Mainsail state and writes a timestamped local backup under `backups/`, but performs no remote writes.

Then install:

```powershell
py .\mainsail\mobile-pendant\install.py
```

The installer:

- backs up the current mobile layout, existing managed macro group, main printer config and `.theme/custom.css`;
- writes `mainsail-mobile.cfg`;
- adds one marked `[include mainsail-mobile.cfg]` block to the main Klipper config;
- preserves any unrelated existing custom CSS and adds a phone-only touch-target block;
- creates/updates the dedicated `Probe & Level` Mainsail macro group;
- replaces only `dashboard.mobileLayout`.

It does **not** call any Moonraker printer-control endpoint.

## Activate

After installation, inspect the generated `mainsail-mobile.cfg` and the managed include from desktop Mainsail.

When you are ready, run `FIRMWARE_RESTART` yourself so Klipper loads the new wrapper macros. The installer intentionally does not restart the printer.

Refresh Mainsail on the phone after the restart. A hard refresh may be needed for the custom CSS.

## Files managed on the printer

```text
printer_data/config/
├── <main printer config>       # one marked include block
├── mainsail-mobile.cfg         # generated wrapper macros
└── .theme/
    └── custom.css              # one marked mobile CSS block
```

All edits use `BEGIN/END COREXY MOBILE PENDANT` markers so rerunning the installer updates its own block instead of duplicating it.

## Safety boundary

This repository code configures the UI only. Installation performs no G-code execution, no movement, no homing, no probing, no levelling, no heating, and no printer restart.
