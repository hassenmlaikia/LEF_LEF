# PASS89 — Ride oversight and user-facing copy

- Added a live, complete rides list to the administration area for the owner and accounts that have `manageRides` capability.
- Added ride-status filters with counts, newest-first ordering, and a detail view for route, service, client/provider identity where public profile data is available, distance, estimated/negotiated fare, offer/counter-offer, timestamps, and emergency/medical priority.
- Kept the full administration tools for owner/manager; a non-admin account with `manageRides` sees ride oversight only.
- Added the ride-oversight entry to Profile and Settings for accounts carrying the capability.
- Removed internal account bootstrap/testing explanation from the sign-up screen, replaced backend-specific error wording with user-facing recovery guidance, and translated Owner/Dashboard display labels.
- Bumped app build to 1.0.0+63 / Android versionCode 63.

Validation: static audit and archive integrity are run for this pass. Flutter/Dart SDK is not installed in the current editing environment, so `flutter analyze`, APK build, device run, and live Firebase permission checks remain unverified.
