# PASS45 — hardening continuation from PASS44

Payments remain intentionally deferred.

Completed:
- Fixed employee company-product authorization to use `employeeProfiles/{uid}` instead of assuming employee document ID equals Firebase UID.
- Provider offer authorization now requires the provider profile to have `providerAvailable == true`.
- Notification center now has a visible “mark all as read” action and unread visual state.
- Version synchronized to 1.0.0+45 / Android versionCode 45.

Still requires real-device/Firebase validation:
- Flutter pub get/analyze/build in the user's proot environment.
- Firebase Rules Emulator tests.
- Production Firebase indexes/queries and actual multi-account flows.
