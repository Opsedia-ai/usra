#!/usr/bin/env bash
# Security plan S6/S20: checks the manifest Android actually ships, after
# library manifests are merged in, which app/test/security cannot see.
# Run from app/ after `flutter build ... --<variant>`. Usage: <debug|release>
set -euo pipefail
variant=${1:?usage: check_merged_manifest.sh debug|release}

manifest=$(find build/app/intermediates -path "*merged_manifest*/${variant}/*" \
  -name AndroidManifest.xml | head -n 1)
if [[ -z "$manifest" ]]; then
  echo "No merged ${variant} manifest under build/app/intermediates." >&2
  exit 1
fi
echo "Checking $manifest"

forbidden=('usesCleartextTraffic="true"' 'allowBackup="true"')
# Debug builds are debuggable by design.
[[ "$variant" == release ]] && forbidden+=('debuggable="true"')
failed=0
for attr in "${forbidden[@]}"; do
  if grep -q "android:$attr" "$manifest"; then
    echo "Merged ${variant} manifest has android:$attr" >&2
    failed=1
  fi
done
grep -q 'android:usesCleartextTraffic="false"' "$manifest" \
  || { echo 'Merged manifest lacks android:usesCleartextTraffic="false"' >&2; failed=1; }
exit $failed
