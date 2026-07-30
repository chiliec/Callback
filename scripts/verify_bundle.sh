#!/usr/bin/env bash
# Verifies App Store prerequisites inside a built .app bundle.
# Usage: scripts/verify_bundle.sh build/Callback.xcarchive/Products/Applications/Callback.app
set -euo pipefail
APP="${1:?usage: verify_bundle.sh <path to .app>}"
fail=0

if [ -f "$APP/PrivacyInfo.xcprivacy" ]; then
  echo "ok   PrivacyInfo.xcprivacy present"
else
  echo "FAIL PrivacyInfo.xcprivacy missing from bundle"; fail=1
fi

family=$(/usr/libexec/PlistBuddy -c "Print :UIDeviceFamily" "$APP/Info.plist" 2>/dev/null | tr -d ' \n')
if [ "$family" = "Array{1}" ]; then
  echo "ok   UIDeviceFamily is iPhone-only"
else
  echo "FAIL UIDeviceFamily is '$family', expected iPhone-only (Array{1})"; fail=1
fi

exit $fail
