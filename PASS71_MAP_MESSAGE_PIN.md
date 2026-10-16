PASS71 — SHARED RIDE MAP MESSAGE PIN

Implemented in this pass:
- Added RideMessageMapScreen for both participants of an accepted ride.
- The screen streams the ride document from Firestore and renders a message-bubble map pin at the stored coordinates.
- Driver/provider can open it from the active ride card; the client can open it from the active ride map.
- Either assigned participant can publish a short message (max 180 chars) with a map location; the other participant sees it through the Firestore stream.
- Added FirebaseService.sendRideMapMessage validation and Firestore rules limited to the assigned client/provider and active ride states.

Validation limits:
- ZIP/source-level checks only in this environment. Flutter/Dart executables are not installed here, so flutter analyze, Android build, Firebase emulator/security-rules tests, and two-device live sync were not run.
- Deploy the updated firestore.rules to Firebase for the new shared message write to work. Do not treat live synchronization as verified until tested with client and driver accounts.
