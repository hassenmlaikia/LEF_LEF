# LEF_LEF PASS27

Source: LEF_LEF_CORE_COMPLETE_PASS26.zip only.

## Logic hardening
- Role requests now notify the Owner when a request is created.
- Role-request notification writes are constrained in Firestore to the bootstrap Owner and the actual role request.
- New service requests notify the bootstrap Owner as a real event.
- Provider available-request discovery avoids a composite status+kind query; provider UI filters to capabilities appropriate to its role.
- Role-request duplicate detection avoids a composite userId+status query.
- Upcoming events avoid a composite query and are filtered/sorted client-side.
- Subscription plans are validated to free/plus/business and document uid must match.
- Saved-place IDs no longer collapse all non-Latin names into one underscore ID.
- Tunisian wording extended to onboarding, map pricing/status text, owner dialog and common labels.
- Version updated to 1.0.0+27 / Android versionCode 27.

## Verified locally
- PASS26 extracted as source.
- 76 source/package files before packaging.
- 22 Dart files.
- Real full-screen splash/onboarding JPEG assets present.
- Dart bracket count balanced after edits.
- ZIP test will be performed on final archive.

## UNKNOWN
- Flutter analyze/build cannot run in this execution environment because Flutter/Dart SDK is not installed.
- Firebase deployment/runtime and real Android device flows remain to be tested in Termux/device.
