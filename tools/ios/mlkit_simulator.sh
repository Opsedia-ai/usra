#!/bin/bash
# Lets the app link for an Apple Silicon iOS Simulator. DEV ONLY.
#
# Google ships ML Kit (text recognition, used by the scanner) as static
# frameworks whose arm64 slice is built for devices only, so
# `flutter build ios --simulator` fails with "Building for 'iOS-simulator',
# but linking in object file ... built for 'iOS'". This re-tags that
# slice's objects as iOS Simulator (the usual arm64-to-sim trick).
#
#   cd app/ios && pod install && ../../tools/ios/mlkit_simulator.sh
#   cd .. && flutter build ios --simulator --debug
#
# Afterwards the Pods no longer link for a DEVICE: delete app/ios/Pods and
# run `pod install` before building for a phone or archiving. Nothing here
# touches committed files (Pods/ is ignored). Running it twice is harmless.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
pods="${1:-$here/../../app/ios/Pods}"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
retag() { python3 -I "$here/macho_to_sim.py" "$1"; }
for bin in "$pods"/MLImage/Frameworks/MLImage.framework/MLImage "$pods"/MLKit*/Frameworks/*.framework/MLKit*; do
  [ -f "$bin" ] || continue
  d="$work/$(basename "$bin")"
  mkdir -p "$d/o"
  lipo "$bin" -thin arm64 -output "$d/arm64"
  lipo "$bin" -thin x86_64 -output "$d/x86_64"
  if file -b "$d/arm64" | grep -q "ar archive"; then
    python3 -I "$here/ar_split.py" "$d/arm64" "$d/o" >/dev/null
    for o in "$d"/o/*; do retag "$o"; done
    libtool -static -o "$d/arm64" "$d"/o/* 2>/dev/null
  else
    retag "$d/arm64"
  fi
  lipo -create "$d/arm64" "$d/x86_64" -output "$bin"
  echo "simulator arm64: $bin"
done
