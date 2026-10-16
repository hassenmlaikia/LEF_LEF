# LEF_LEF PASS72 — Action Logic Audit

## Changes applied in this pass
- Removed hard-coded Tunis fallback coordinates from the ride-message map. It now refuses to show a fake pickup marker when a ride has no saved pickup coordinates.
- Prevented map-message pins from being saved at invented coordinates. If the provider live position is not available, the pin uses the ride's real saved pickup coordinates; if those are missing/invalid, sending is blocked with a user-facing message.
- Made destination marker conditional on valid saved destination coordinates.
- Firestore rules now allow a verified available provider with the correct role/capability to accept a fixed-price ride directly, matching `acceptFixedRide`; the existing offer flow remains for negotiable rides.
- Added `randonnee` to partner-eligible ride kinds in Firestore rules and to both provider-side query/display allowlists, so the UI and rules agree.
- Prevented stage-message bubbles from being positioned on a guessed straight line when the real road-route geometry is unavailable.

## Validation performed
- `tool/lef_lef_static_audit.sh`: PASS.
- ZIP integrity check: performed after packaging.
- Flutter SDK/Dart SDK are not installed in this work container, so `flutter analyze`, Android build, Firebase emulator rules tests, and live two-account ride tests could not be run here.

## Remaining end-to-end checks
1. Register/login and profile repair with Firebase Auth + Firestore.
2. Owner bootstrap and role/capability boundaries.
3. Fixed-price ride acceptance, negotiated offers/counteroffers, cancel and status transitions.
4. Provider live location updates and map message synchronization on both accounts.
5. Posts, comments, likes, stories, reactions, chat, notifications, event RSVP, companies/products/employees, and settings persistence.
6. Deploy Firestore/Storage rules only after reviewing against the actual Firebase project; this ZIP does not deploy rules.
