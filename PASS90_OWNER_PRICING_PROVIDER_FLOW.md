# PASS90 — Owner pricing and provider ride discovery

- Added owner-only live pricing settings in the management area for taxiMoto, carExpress, deliveryMoto and deliveryVan: base fare, daytime per-km and nighttime per-km.
- New ride estimates load saved pricing from `system/pricing`; the ride creation service validates against the current saved values.
- Firestore rules use owner-saved base/rates when validating new fixed-price rides. Only the owner can create/update pricing settings; signed-in users can read them.
- Drivers/delivery providers/partners continue to receive live `rides` query updates for available requests; the provider screen now alerts in-app when new compatible requests arrive and disables accept/offer actions until provider availability is enabled.
- Management access: only role `owner` sees the full admin console. Managers are limited to ride oversight in the UI and the effective `manageRides` capability in client logic and Firestore rules. Owner capability checks always grant the full capability set.
- Version bumped to 1.0.0+64 / Android versionCode 64.

Validation: static audit, ZIP integrity, and lightweight Dart delimiter checks pass. Flutter/Dart SDK was unavailable in this environment; no `flutter analyze`, APK build, device test, Firebase emulator test, or live rules deployment was performed. Firestore rules must be deployed to Firebase for server-side enforcement to take effect.
