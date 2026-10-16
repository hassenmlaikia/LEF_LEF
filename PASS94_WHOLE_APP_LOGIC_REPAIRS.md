# LEF_LEF PASS94 — Whole-app logic follow-up repairs

## Changes made

- Provider applications now check for all required document keys before uploading and query for an existing pending application directly, rather than checking only a limited sample of old requests.
- Application-submission and review-notification failures are non-blocking after the underlying write commits, preventing misleading failure messages and duplicate retries.
- Owner approval revalidates the submitted identity/contact fields, vehicle/company details, and required private document path prefixes before changing the role.
- Approval now copies the applicant's submitted name and phone into the user profile; partner approval also copies company name and tax/registration ID. Public-profile display name/search fields are synchronized during approval.
- Public-profile rules now allow the authorized role reviewer to synchronize only role/name metadata, fixing the approval transaction being rejected when updating another user's public profile.
- Offline or unverified providers no longer subscribe to or read available ride requests; the provider screen explains that approval and availability are required.
- Accepting a provider offer now re-reads the provider profile in the same Firestore transaction and rejects stale, unverified, unavailable, incompatible, or invalid-price offers.
- Accepting a counter-offer now rechecks the provider's current verified/available state and service compatibility.
- Counter-offer values must be strictly positive in the UI, service, and Firestore rules; zero-value counters can no longer strand a negotiation.
- Map reverse-geocoding responses are sequenced so a slow response from an earlier map tap cannot overwrite the place selected by a later tap.
- Bumped source/build metadata to `1.0.0+65` / Android versionCode `65`.

## Validation performed

- `tool/lef_lef_static_audit.sh`: PASS, including PASS94 regression assertions.
- `firestore.indexes.json`: valid JSON.
- Dart delimiter-count smoke check: no mismatched raw counts detected.
- ZIP integrity: checked after packaging.

## Not verified / blockers

- Flutter and Dart SDK are not installed in this environment. `flutter analyze`, Android compilation, APK generation, emulator/device tests, and Firebase emulator tests could not run.
- Firestore and Storage rules have not been deployed to the live Firebase project. The approval and document-protection behavior depends on deploying and testing these rules.
- The supplied project still has a custom `android/gradlew` script rather than a standard Gradle wrapper directory/JAR/properties. This archive is a source project, not a built APK; the Android wrapper/build setup needs repair in the user's Flutter/Termux build environment before claiming a reproducible standalone build.
- No real AI backend or electronic payment integration was added; those require external secure service configuration and are not simulated as completed.
