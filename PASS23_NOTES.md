# LEF_LEF PASS23

Source: LEF_LEF_CORE_COMPLETE_PASS22.zip (verified raw bytes).

## Fixed / hardened
- Version aligned to `1.0.0+23` / Android `versionCode 23`.
- Provider request queries now include service-compatible `kind` constraints so Firestore security rules can authorize the query instead of relying only on client-side filtering.
- Added the required composite Firestore index for provider request queries.
- Ride creation validates all pickup/destination coordinates before the write, in addition to Firestore validation.
- Role-request approval/rejection now creates a notification for the requesting user.
- Notification rules now permit authorized role-request notifications without requiring a ride document.
- Owner role protection tightened: existing Owner accounts cannot be changed into another role, and non-owner users cannot be promoted to Owner through the normal management update path.
- Onboarding now uses the supplied visual assets as true full-screen backgrounds rather than rounded cards.
- Map stage message pins are tied to the route and move to a defined route fraction for every service stage: searching, offer, counter-offer, accepted, driver coming, arrived, trip started, completed, cancelled.
- Removed the duplicate floating map status bubble; the stage message is now represented by the route marker itself.

## Verification performed
- PASS22 ZIP was extracted and inspected (91 archive entries / 63 extracted files).
- `google-services.json` is present in `android/app/`.
- Dart bracket balance checked after edits: clean.
- No Flutter SDK is available at `/root/flutter/bin/flutter` in this execution environment, so `flutter analyze`, `flutter test`, and APK build remain UNKNOWN.
- Firestore emulator/deployment tests were not run here; runtime Firebase behavior remains UNKNOWN until deployed/tested against the configured project.
