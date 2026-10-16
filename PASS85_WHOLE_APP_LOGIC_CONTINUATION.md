# LEF_LEF PASS85 — Whole-app logic continuation

This update is based on the complete PASS84 archive, preserving the existing project and features.

## Additional fixes applied
- **Fare integrity:** ride creation now requires the per-kilometre rate to match the declared `pricingPeriod` (`day` or `night`), instead of accepting either rate for either period. This prevents a stale/mismatched fare from being written.
- **Conversation access and creation:** conversation setup now uses a Firestore transaction, validates IDs/titles, creates a conversation only when absent, and refuses to add the current user to an existing conversation they are not a member of. This aligns client behavior with the existing Firestore membership rules and avoids a misleading “message sent” path.
- **Chat validation:** messages are checked against the same 4,000-character maximum enforced by Firestore rules.
- **Ride notification navigation:** tapping a ride notification now opens the exact referenced ride instead of opening the map without the notification's ride ID. MapScreen restores the requested ride document when provided.
- **Social action truthfulness:** reporting a post now validates sign-in, post ID, reason length and post existence; blocking rejects invalid/self targets; reposting rejects unauthenticated/invalid requests instead of returning a success-shaped null.
- **Story reaction validation:** story reactions validate sign-in, ID, reaction length, story existence, and expiry before writing.
- **Event creation validation:** invalid, empty, overlong, or past-dated event input now raises an explicit error rather than returning null in a way that a caller could mistake for success.
- **Company workspace recovery:** company loading failures now show a retryable error instead of leaving the user on an endless spinner; company creation failures are surfaced to the user, and retry clears stale error state.
- **Static audit expansion:** added checks for these invariants to `tool/lef_lef_static_audit.sh`.

## Verification performed
- Full archive extracted and source tree reviewed across screens, services, models, rules, and action callbacks.
- `tool/lef_lef_static_audit.sh`: PASS, including the company error-recovery invariant.
- Modified Dart files: delimiter-balance check passed (braces, parentheses, square brackets).
- ZIP integrity check performed after packaging.

## Verification not possible in this environment
- Flutter and Dart SDK executables are not installed, so `flutter analyze`, tests, and Android APK build were not run.
- Firebase runtime, Firestore emulator/security-rule tests, device-level navigation, GPS permissions, and multi-account tests were not run. The source/rules still require those integration tests before claiming every feature is runtime verified.
