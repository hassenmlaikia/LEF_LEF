# LEF_LEF PASS97 — Provider assignment and negotiated pricing

## Repairs in this pass

- A negotiated-service offer now opens with an empty amount field instead of misleadingly showing `0.00` as if it were a valid suggested price. The provider must enter a positive amount before sending.
- Provider offer/accept transactions check for another pending offer or active assignment belonging to that provider. This reduces accidental double-booking when several requests appear at once or the provider taps quickly on multiple devices.
- Added the composite Firestore index for `rides(providerId, status)` used by the assignment check.
- Build metadata bumped to `1.0.0+68` / Android `versionCode 68`.

## Validation performed

- `bash tool/lef_lef_static_audit.sh` — PASS.
- `firestore.indexes.json` parsed as JSON.
- ZIP archive integrity checked after packaging.

## Important limitation

This environment has no Flutter/Dart SDK, so `flutter analyze`, Dart compilation, Android APK build, and Firebase Emulator tests could not be run. The transaction check is a client-side safeguard and must be backed by Firebase rules/Cloud Functions or a server-authoritative assignment workflow for strict protection against simultaneous transactions on different rides. Deploy the new Firestore index and rules to the intended Firebase project, then test two providers accepting the same ride and one provider attempting multiple jobs.
