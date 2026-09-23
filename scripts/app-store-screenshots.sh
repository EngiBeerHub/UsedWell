#!/bin/bash
# Usage: bash scripts/app-store-screenshots.sh IPHONE_17_PRO_UDID OUTPUT_DIR ja-JP|en-US|all [XCRESULT]
# Capture the dedicated Store flow, then compose five screenshots and a contact sheet per locale.
# Reuse a successful result bundle without building or rerunning captures.
# Keep output outside app-store/screenshots until the presentation has been reviewed.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
simulator_id="${1:?iPhone 17 Pro simulator UDID is required}"
output_dir="${2:?Output directory is required}"
locale="${3:?Specify ja-JP, en-US, or all}"
case "$locale" in
  ja-JP) locales=(ja-JP); selector="AppStoreScreenshotTests/testJapaneseStoreScreenshots" ;;
  en-US) locales=(en-US); selector="AppStoreScreenshotTests/testEnglishStoreScreenshots" ;;
  all) locales=(ja-JP en-US); selector="AppStoreScreenshotTests" ;;
  *) echo "Unsupported locale: $locale" >&2; exit 1 ;;
esac
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
work_dir="$(mktemp -d /tmp/usedwell-store-capture.XXXXXX)"
result_path="${4:-$work_dir/capture.xcresult}"
if [ "$#" -lt 4 ]; then
  if ! xcrun simctl list devices booted | rg -q "$simulator_id"; then
    xcrun simctl boot "$simulator_id"
  fi
  xcrun simctl bootstatus "$simulator_id" -b
  original_appearance="$(xcrun simctl ui "$simulator_id" appearance)"
  cleanup() {
    xcrun simctl status_bar "$simulator_id" clear || true
    xcrun simctl ui "$simulator_id" appearance "$original_appearance" || true
  }
  trap cleanup EXIT
  xcrun simctl ui "$simulator_id" appearance light
  xcrun simctl status_bar "$simulator_id" override --time "9:41" \
    --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active \
    --cellularBars 4 --batteryState discharging --batteryLevel 100
  xcodebuild test -project "$repo_root/UsedWell.xcodeproj" -scheme UsedWell \
    -destination "platform=iOS Simulator,id=$simulator_id" \
    -parallel-testing-enabled NO -derivedDataPath "$work_dir/DerivedData" \
    -resultBundlePath "$result_path" -only-testing:"UsedWellUITests/$selector" \
    SWIFT_EMIT_LOC_STRINGS=NO > "$output_dir/capture.log" 2>&1
fi
xcrun xcresulttool export attachments --path "$result_path" --output-path "$work_dir/attachments"
python3 "$repo_root/scripts/export-ui-evidence.py" "$work_dir/attachments" "$output_dir/raw"
for language in "${locales[@]}"; do
  destination="$output_dir/app-store-$language"
  swift -module-cache-path "$work_dir/modules" "$repo_root/scripts/render-app-store.swift" \
    "$output_dir/raw" "$destination" "$language"
  python3 - "$destination" <<'PY'
from pathlib import Path
import struct
import sys

folder = Path(sys.argv[1])
expected = {"01-hero", "02-progress", "03-decision", "04-notes", "05-cost"}
files = list(folder.glob("0*.png"))
assert {path.stem for path in files} == expected, "Expected exactly five Store PNGs"
for path in files:
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", f"{path}: not PNG"
    width, height, depth, color = struct.unpack(">IIBB", data[16:26])
    assert (width, height, depth, color) == (1284, 2778, 8, 2), \
        f"{path}: expected 1284x2778, 8-bit RGB without alpha"
print(f"Verified {folder.name}: five 1284x2778 RGB PNGs without alpha")
PY
done
echo "Runtime captures: $output_dir/raw"
echo "Result bundle: $result_path"
