# LEF_LEF PASS73 — Action logic fixes

This pass continues from PASS72 and makes targeted, source-backed fixes without changing app identity or the release version.

## Fixed
- Fixed a Dart compile-time issue in `RideMessageMapScreen.sendMessage`: pickup coordinates were referenced before declaration.
- Message-pin placement can now be selected by tapping the map. The selected location is shown before sending.
- Driver-authored map messages no longer silently fall back to the client's pickup location when the driver's own live location is missing; sending now asks the driver to enable location tracking or select a real point on the map.
- Added `randonnee` to the driver's available service filter in both the Firebase query and provider UI, matching the model and Firestore `canServe` rules.
- Provider offer/accept methods now require `providerAvailable == true`, matching Firestore rules (previously a missing field passed the client check but was rejected by rules).
- Improved the provider-facing unavailable-request message to explain that the request may be taken already or the service profile/availability must be completed.

## Not claimed as verified
- Flutter/Dart SDK is not available in this work container, so `flutter analyze`, APK build, and runtime/Firebase integration tests have not been run here.
- Firestore rules still need deployment to the user's Firebase project for server-side behavior to reflect the ZIP.
