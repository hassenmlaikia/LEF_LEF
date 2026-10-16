# LEF_LEF PASS95 — Whole-app action logic continuation

## Repairs applied

- Ride creation now checks for an existing unfinished ride for the same client and writes the new ride in the same Firestore transaction, reducing duplicate active requests caused by double taps or multiple devices.
- Provider offer submission and fixed-price acceptance now read the provider profile inside the same transaction as the ride update. Current verification, availability, role, and service compatibility are checked immediately before the ride is assigned.
- Provider offers and client counter-offers are bounded to positive amounts no greater than 100,000 TND in client logic and Firestore rules.
- Employee invite acceptance now activates the invitation, creates the employee profile, and changes the user's role atomically. The public profile mirror is updated separately and cannot make a committed activation appear to have failed.
- Employee invite rejection now uses a transaction so stale or duplicate attempts cannot overwrite an already-handled invitation.
- Firestore employee rules use `getAfter`/`existsAfter` to validate the multi-document employee activation transaction.
- Event RSVP now verifies the event is published and has not started, and creates the attendance record transactionally. Firestore rules independently reject RSVP creation for events that are not published or have already started.
- Selling an inactive product is rejected.
- Creating a company requires an approved/verified partner, not merely a role label.
- Added the composite rides index needed for the active-ride duplicate guard.
- Bumped app/build metadata to `1.0.0+66` / Android `versionCode 66`.
- Added PASS95 static regression assertions.

## Validation performed

- `tool/lef_lef_static_audit.sh`: PASS.
- `firestore.indexes.json`: valid JSON.
- Dart delimiter smoke check: PASS.
- PASS95 regression assertions: PASS.
- ZIP integrity: checked after packaging.

## Not verified / remaining release blockers

- Flutter/Dart SDK is not installed in this execution environment, so `flutter pub get`, `flutter analyze`, Android APK build, emulator/device tests, and Firebase Emulator rules tests could not run.
- Firebase rules and indexes are source changes only and must be deployed to the intended Firebase project before live behavior changes.
- `android/gradlew` remains the project's custom system-Gradle launcher, not a standard self-contained Gradle Wrapper. This ZIP is source code, not an APK.
- The app still does not contain a complete electronic payment provider integration or a real secure AI backend; these are not simulated as completed.
