#!/usr/bin/env bash
# Security plan S5: only app/lib/core/log.dart may write to the console, so no
# health data, name, phone number or token ends up in device logs.
# app/test/security/log_test.dart checks the same thing inside flutter test.
set -euo pipefail
cd "$(dirname "$0")/../.."

pattern='\b(print|debugPrint|debugPrintStack|printError)[[:space:]]*\('
pattern+='|\bZone\.current\.print\b|\b(dumpErrorToConsole|presentError)\b'
pattern+='|\bstd(out|err)\.'
pattern+=$'|import[[:space:]]+[\'"]dart:developer[\'"]'
if matches=$(grep -rnE --include='*.dart' --exclude='*.g.dart' "$pattern" app/lib \
    | grep -v '^app/lib/core/log\.dart:' \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//'); then
  echo "Console output outside app/lib/core/log.dart (use Log.error):"
  echo "$matches"
  exit 1
fi
echo "No print/debugPrint outside app/lib/core/log.dart."
