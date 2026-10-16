# LEF_LEF PASS28

Source: LEF_LEF_CORE_COMPLETE_PASS27.zip only.

- Removed mandatory post-auth Role selection; normal users enter Home directly and request extra roles from Profile.
- Preserved first-account Owner bootstrap and subsequent Client defaults.
- Role-review notifications now include roleRequestId and match Firestore rules.
- Role review uses authoritative userId/requestedRole stored in the request, not UI-supplied values.
- Real full-screen splash/onboarding assets preserved.
- Version 1.0.0+28 / Android versionCode 28.

UNKNOWN: Flutter analyze/build and real Firebase/Android runtime testing require the user's Termux/device because this execution environment has no Flutter/Dart SDK.
