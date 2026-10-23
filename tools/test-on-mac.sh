#!/bin/bash
# Local Android emulator testing only. Real tablets connect directly over the hotspot.
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
android_sdk="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
adb_bin="$android_sdk/platform-tools/adb"
emulator_bin="$android_sdk/emulator/emulator"

start_tablet() {
  local avd_name="$1" emulator_port="$2" package_name="$3" apk_path="$4"
  local serial="emulator-$emulator_port"
  if ! "$adb_bin" -s "$serial" get-state >/dev/null 2>&1; then
    nohup "$emulator_bin" -avd "$avd_name" -port "$emulator_port" -no-audio -no-boot-anim >"${TMPDIR:-/tmp}/oob-$avd_name.log" 2>&1 &
  fi
  local ready=false
  for ((attempt=0; attempt<120; attempt++)); do
    if [[ "$("$adb_bin" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == 1 ]]; then ready=true; break; fi
    sleep 1
  done
  if [[ "$ready" != true ]]; then echo "$avd_name did not finish booting. Check ${TMPDIR:-/tmp}/oob-$avd_name.log" >&2; exit 1; fi
  local actual_avd
  actual_avd="$("$adb_bin" -s "$serial" emu avd name | head -n 1 | tr -d '\r')"
  if [[ "$actual_avd" != "$avd_name" ]]; then echo "$serial belongs to $actual_avd, not $avd_name. Close that emulator first." >&2; exit 1; fi
  if ! "$adb_bin" -s "$serial" shell pm path "$package_name" | grep -q '^package:'; then
    "$adb_bin" -s "$serial" install "$apk_path"
  fi
  "$adb_bin" -s "$serial" shell am start --windowingMode 1 -n "$package_name/.MainActivity"
}

start_tablet Medium_Tablet 5554 dev.luminatech.oob_pos "$project_dir/dist/OOB-POS-arm64.apk"
start_tablet OOB_Menu 5556 dev.luminatech.oob_menu "$project_dir/dist/OOB-Menu-arm64.apk"
"$adb_bin" -s emulator-5554 forward tcp:18443 tcp:8443
printf '%s\n' 'Both Android apps are open.' 'POS: Connection → Start local service if stopped.' 'Menu emulator: saved POS address 10.0.2.2, port 18443.' 'Pairing is already saved on this Mac. Re-pair only after clearing app data or replacing the POS identity.'
