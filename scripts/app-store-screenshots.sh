#!/bin/bash
# Usage: bash scripts/app-store-screenshots.sh SIMULATOR_ID OUTPUT_DIR [EXISTING_XCRESULT]
# Runs isolated Japanese/English UI flows, exports evidence, then composes English candidates.
# Pass an existing successful xcresult to reuse already validated captures without rerunning tests.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
simulator_id="${1:?Simulator UDID is required}"
output_dir="${2:?Output directory is required}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
work_dir="$(mktemp -d /tmp/usedwell-capture.XXXXXX)"
result_path="${3:-$work_dir/capture.xcresult}"
if [ "$#" -lt 3 ]; then
  xcodebuild test -project "$repo_root/UsedWell.xcodeproj" -scheme UsedWell \
    -destination "platform=iOS Simulator,id=$simulator_id" \
    -parallel-testing-enabled NO -resultBundlePath "$result_path" \
    -only-testing:UsedWellUITests/LocalizationUITests > "$output_dir/capture.log" 2>&1
fi
xcrun xcresulttool export attachments --path "$result_path" --output-path "$work_dir/attachments"
python3 "$repo_root/scripts/export-ui-evidence.py" "$work_dir/attachments" "$output_dir/raw"
swift -module-cache-path "$work_dir/modules" "$repo_root/scripts/render-app-store.swift" "$output_dir/raw" "$output_dir/app-store-en-US"
sips -g pixelWidth -g pixelHeight -g format -g hasAlpha "$output_dir"/app-store-en-US/0*.png
