# PASS87 — User-reported whole-app logic repairs

## Specific fixes applied
- Ride cancellation is rejected once a ride reaches `active`, for both client and provider, in client service guards and Firestore rules. The corresponding cancel controls are hidden during the active stage; the provider's normal progression remains `active -> completed`.
- Removed automatically generated per-stage speech bubbles from the map. The stage remains visible in the ride status panel; only a message deliberately sent by a participant appears as a map pin.
- Flattened the map-message pin (no Material elevation / pseudo-3D shadow).
- Added edit and delete actions for a user's own original posts. Editing supports text, replacing/removing attached image/video, preserves the existing media if not changed, and rejects edits to repost wrappers. Firestore rules already permit author updates to text/media fields and author deletion.
- Hardened media upload with file existence, non-zero size, size-limit, extension and media-type validation. User-facing media publishing errors now state practical troubleshooting rather than SDK details.
- Removed raw startup exception text from the user-visible error screen. Technical details remain in developer logs rather than the product UI.

## Validation performed
- `bash tool/lef_lef_static_audit.sh`: PASS.
- `google-services.json` and `firestore.indexes.json`: JSON parse passed.
- ZIP integrity and source-level regression assertions: passed.

## Verification boundary
Flutter/Dart SDK is not installed in this execution environment. Therefore `flutter analyze`, APK compilation, emulator/device tests, live Firebase Auth/Firestore/Storage tests, and deployment of Firestore/Storage rules were not performed. The changed Firestore rules must be deployed to Firebase for the mid-ride cancellation restriction to be enforced against direct client requests. The Storage rules included in this archive must likewise be deployed if the live project is using different rules.
