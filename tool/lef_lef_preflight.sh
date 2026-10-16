#!/usr/bin/env bash
set -euo pipefail
flutter pub get
flutter analyze
[[ -f android/app/google-services.json ]] || { echo "google-services.json: MISSING"; exit 1; }
python3 -m json.tool android/app/google-services.json >/dev/null
python3 -m json.tool firestore.indexes.json >/dev/null
grep -q "applicationId 'com.leflef.app'" android/app/build.gradle || { echo "applicationId: WRONG"; exit 1; }
grep -q "versionCode 78" android/app/build.gradle || { echo "versionCode: WRONG"; exit 1; }
grep -q "version: 1.0.0+78" pubspec.yaml || { echo "pubspec version: WRONG"; exit 1; }
grep -q "compileSdk 36" android/app/build.gradle || { echo "compileSdk: WRONG"; exit 1; }
grep -q "minSdk 24" android/app/build.gradle || { echo "minSdk: WRONG"; exit 1; }
for asset in \
  assets/lef_logo_mark.png \
  assets/lef_logo_lockup.png \
  assets/splash_light_real.jpg \
  assets/splash_dark_real.jpg \
  assets/onboarding_mobility_real.jpg \
  assets/onboarding_connect_real.jpg \
  assets/onboarding_safe_real.jpg; do
  [[ -f "$asset" ]] || { echo "asset missing: $asset"; exit 1; }
done
if grep -RInE "Colors\.black10|UnimplementedError|TODO|FIXME" lib; then
  echo "blocking markers found"
  exit 1
fi
if grep -RInE "This will cancel|This request can no longer|Your offer is|Estimate [0-9]|Status:" lib; then
  echo "English UI marker found"
  exit 1
fi
echo "LEF_LEF PREFLIGHT: PASS"
