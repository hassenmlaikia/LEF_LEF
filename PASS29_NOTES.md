# LEF_LEF PASS29

Source: LEF_LEF_CORE_COMPLETE_PASS28.zip only.

## Logic hardening completed
- Fixed a Dart compile error in the notification helper caused by an undefined role-request variable inside ride notifications.
- Role approval/rejection notifications now carry the actual `roleRequestId`, so the Firestore rule can validate the event.
- Fixed role-request notification authorization: the requester can create the notification only for the bootstrap Owner and only when the referenced request belongs to the requester.
- Fixed provider ride discovery: the Firestore query now includes the exact service kinds allowed for the provider role. This avoids relying on Firestore rules as client-side filters and prevents a permission-denied query.
- Preserved transaction-safe ride state transitions, owner-first bootstrap, capability authorization, pricing validation, real notifications, map tracking and full-screen onboarding/splash assets.
- Version: 1.0.0+29 / Android versionCode 29.

## Local verification
- PASS28 extracted as the sole source.
- 78 files / 22 Dart files / 12 assets before packaging.
- Real splash and three real onboarding JPEGs are present.
- Parenthesis/brace/bracket balance checked after edits.
- No TODO/FIXME/UnimplementedError placeholders introduced.
- Final ZIP integrity check required before delivery.

## UNKNOWN
- Flutter/Dart SDK is not installed in this execution environment, so `flutter analyze` and Android release build cannot be honestly marked PASS here.
- Firebase rules deployment and real Android/Firebase runtime tests remain UNKNOWN until run in the user's Termux/device environment.
