# Stage 13D firmware recommission bundle

Prepared 2026-08-29 from the read-only `klipper` Pi inspection.

## Pinned sources

- Klipper target offered by Moonraker: `ac2a7f8b0e1ba61afe51e7e25583772d6e65e1fa`
  (`v0.13.0-743-gac2a7f8b0`, `origin/master`, 318 commits ahead of the live
  checkout).
- Direct `git ls-remote` during preparation reported a newer ref:
  `f0892d82b0f1c1228454f09eb508eddde2250f4b`
  (`v0.13.0-745-gf0892d82b`). Moonraker's cached offered target was used for
  this bundle so the host update can match the offered version.
- klipper-led_effect target: `266f1049c7172c2fba0da4a52314dcfc0c3bb56f`
  (`v0.0.19`, `origin/master`). Live was `a558cb7c88430f00fd9be8f534f9aeb22bd8f3e9`
  (`v0.0.16`), 25 commits behind.

All source operations and builds were isolated from the live Pi checkout.
Nothing in this bundle has been flashed, installed, or executed on the Pi.

## Recovered SKR Pro MCU settings

Evidence agrees across the live USB identity, runtime klippy logs, the live
`.config.old`, and upstream `generic-bigtreetech-skr-pro.cfg`:

- Board/MCU: BigTreeTech SKR Pro, `STM32F407xx`
- Application address: `0x08008000` (32 KiB bootloader)
- MCU clock: `168000000` Hz
- Clock reference: `8000000` Hz
- Transport: USB CDC serial, not CAN or UART
- USB: VID `0x1d50`, PID `0x614e`, chip-ID serial
- Observed device:
  `/dev/serial/by-id/usb-Klipper_stm32f407xx_4E0032001750563641353820-if00`
  (kernel device `/dev/ttyACM0`)
- Runtime config used `serial:`; no `canbus_uuid` or `restart_method` was set.

The live runtime reported `CLOCK_FREQ=168000000 MCU=stm32f407xx`, and the USB
identity reported `stm32f407xx`, `1d50:614e`, and chip serial
`4E0032001750563641353820`. `CONFIG_HAVE_STM32_CANBUS` in `.config.old` is a
compiled capability, not an indication that this printer used CAN.

## Artifacts

- `firmware.bin`: STM32F407 USB firmware, built from the Moonraker target.
- `stm32.config`: normalized exact build configuration derived from live
  `/home/pi/klipper/.config.old`.
- `generic-bigtreetech-skr-pro.cfg`: pinned upstream board reference.
- `klipper_host_mcu.elf`: 32-bit ARM Linux host-MCU ELF (ELF32, ARM,
  EABI5, hard-float ABI; ARMv7-A/Thumb-2), built from the host configuration
  with the isolated `arm-linux-gnueabihf` toolchain. SHA256:
  `d3838502682edaf6fa3aa3923b84e10aad22544320b7c727c7f7373f1a21bbcb`.
  The prior live inspection identified `/usr/local/bin/klipper_mcu` as
  32-bit ARM EABI5; this replaces the incorrect ARM64 bundle artifact.
  Verify locally before installation and prefer rebuilding on the Pi after
  the host source update if the host toolchain or filesystem differs.
- `host-mcu.config`: normalized exact Linux host-MCU build configuration
  derived from live `/home/pi/klipper/.config`.
- `SHA256SUMS.txt`: hashes for every bundle artifact.

The host MCU uses `/tmp/klipper_host_mcu` at runtime and is not a USB/CAN
device. The bundle build used `CONFIG_CLOCK_FREQ=50000000`, Linux host MCU
settings from the live configuration, and the pinned Klipper source commit
with GCC 13.3.0 (`arm-linux-gnueabihf`, binutils 2.42) in isolated WSL.

## Safe physical sequence (no motion tests)

1. Do not issue G-code. Power the printer and SKR Pro fully down.
2. Copy only `firmware.bin` to the root of a FAT32 SKR Pro SD card.
3. Insert the card, power the board, and wait for the bootloader to process it.
4. Power down before removing the card. Verify the bootloader renamed or
   accepted the file (normally `FIRMWARE.CUR`; do not assume acceptance if it
   remains `firmware.bin`).
5. Only after acceptance, perform the host Klipper and led_effect update using
   `host-update-commands.txt`. Restart services only as directed there.
6. Verify versions, MCU connection, and logs. Perform no homing, calibration,
   heater, extrusion, or other motion tests in this stage.

## Rollback

Keep the previous board firmware and the live source/config backups offline
before the physical step. If the SD update is not accepted, power down,
remove the card, and restore the prior known-good `firmware.bin`; do not
continue with host updates. If the board accepts the image but host startup
fails, stop the host service, restore the prior Klipper and led_effect
checkouts/configuration, and use the prior host-MCU build rather than this
bundle's artifact.

## Compatibility note

The pinned led_effect `v0.0.19` source passed Python syntax compilation and
uses APIs present in the target Klipper: event handlers, `gcode.register_command`,
`display_status.get_status`, and `led_helper._check_transmit`. It also retains a
fallback for the older `check_transmit` API. No formal dependency declaration
was found; retain the pinned pair and verify startup logs before any printer
operation.
