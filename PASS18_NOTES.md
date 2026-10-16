# LEF_LEF PASS18

Source: LEF_LEF_PASS17.zip.

Completed:
- Closed a security/logic gap: users can no longer self-change from Client to provider roles through Firestore; provider roles must use the role-request workflow.
- Added real Events collection and Explore event creation/upcoming events flow.
- Added Services & Companies directory data flow and Firestore rules.
- Preserved Owner-first signup, role requests, capability model, map stage pins, GPS/provider tracking, rides, offers/counters, high-value confirmation, social report/block, splash/onboarding.
- Version 1.0.0+18.

Verification:
- Source scanned for TODO/FIXME/UnimplementedError/Colors.black10/placeholder/mock.
- Dart delimiter balance checked.
- ZIP integrity checked with unzip -t.
- Flutter analyze/build: UNKNOWN in this execution environment because Flutter SDK is unavailable.
