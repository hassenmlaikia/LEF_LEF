# PASS70 — Logic and settings continuation (2026-10-09)

## Changes made
- Map taps now set the selected pickup/destination pin, and the target can be switched explicitly in the map panel.
- Added reverse geocoding through OpenStreetMap Nominatim so a dropped pin resolves to a readable place name; if lookup fails, coordinates remain visible as a fallback.
- Selecting a new pin clears stale route/fare values and recalculates the road route once both endpoints are set.
- Removed the two unnecessary Cloud Firestore imports reported by `flutter analyze`.
- Synchronized release metadata to `1.0.0+61` / Android `versionCode 61`.
- Set compileSdk 36, minSdk 24, NDK `28.2.13676358`, and Gradle JVM heap `1536M` to match the current AndroidX/Flutter project requirements and low-memory build constraints.

## Checks
- Static source/package checks: run using `tool/lef_lef_static_audit.sh`.
- Flutter analyze, Gradle build, Firebase Rules emulator, and multi-account/device flows: NOT run in this container; Flutter SDK/device/Firebase emulator are not available here.
- This ZIP must still pass `flutter pub get`, `flutter analyze`, and `tool/lef_lef_preflight.sh` in the user's Termux Ubuntu environment before release.

## Remaining logic audit targets
- Validate Firestore rules against all role paths (Owner bootstrap, manager boundaries, role requests, provider updates).
- Device-test map reverse geocoding, OSRM route fallback, SOS/ambulance/Isuzu price negotiation, profile media, Stories, chat, notification routing, and settings persistence.
