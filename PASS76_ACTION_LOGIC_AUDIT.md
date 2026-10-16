# LEF_LEF PASS76 — Action logic continuation

## Source change
- Event RSVP now fails explicitly when there is no authenticated user or the event ID is empty, instead of returning success-shaped completion without writing anything.
- RSVP verifies the event exists and is not marked `cancelled` before creating the attendee record.
- RSVP writes use merge semantics so repeated taps remain idempotent and do not overwrite unrelated attendee fields.
- Event un-RSVP now reports unauthenticated/invalid-ID cases rather than silently returning.

## Checks run in this environment
- `tool/lef_lef_static_audit.sh`: PASS after edits.
- ZIP integrity checked after packaging.
- Source scans reviewed Home, Explore, Profile, Settings, notifications, chat, provider and owner action handlers.

## Not verified here
- Flutter/Dart executables are not installed in this work container. `flutter analyze`, Android APK build and device runtime tests could not run.
- Firebase-backed actions still require live testing with at least two accounts; Firestore/Storage rules deployment is separate and was not performed.
