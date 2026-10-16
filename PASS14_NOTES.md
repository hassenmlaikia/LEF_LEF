# LEF_LEF PASS14

Built directly from LEF_LEF_CORE_COMPLETE_PASS13.zip.

Changes:
- High-value (>200 TND) confirmation added to client offer acceptance and client counter-offers.
- High-value (>200 TND) confirmation added before provider offers are sent.
- Fare validation strengthened in Firestore rules for provider offers and client counters.
- Manager role updates can no longer change an existing Owner account role.
- Version bumped to 1.0.0+14.

Verification:
- ZIP/source integrity and static source scans were performed in this environment.
- Flutter analyze/build was not run because the Flutter SDK is not installed in this execution environment.
