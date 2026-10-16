# LEF_LEF PASS26 — logic hardening

Source of truth: `LEF_LEF_CORE_COMPLETE_PASS25.zip` only.

## Logic fixed / completed
- Persisted capability/action authorization on user profiles; Owner has all capabilities, provider roles receive `manageRides`, and delegated permissions are enforced in Firestore rules.
- Added real capability delegation from the Owner Control Center and capability-aware role/user management.
- Role requests are no longer trapped behind the initial onboarding choice: a normal Client can request Driver / Delivery Provider / Partner from the Profile. Approval/rejection remains restricted to users with `manageRoles`.
- Role approval assigns the correct default capabilities.
- Existing profiles missing the new capability field are initialized to the default capabilities for their existing role without changing the role.
- Direct role changes now go through an authorization-checked service method; Owner can never be created through normal role management.
- Ride pricing is now persisted with distance, base fare, rate and day/night period. Client-side pricing is checked before write and Firestore validates the service base/rate and fare calculation.
- Added provider-side cancellation with an atomic state transition and client notification.
- Ride state transitions remain transaction-protected; provider offer acceptance/counter-offer/cancellation cannot overwrite a request already taken by another provider.
- Map stage message pins are tappable and open the matching live stage/status message.
- Added real Android share intent for social posts; clipboard remains a fallback if the native share action cannot launch.
- Added real follower/following storage and live counts on Profile.
- Updated preflight script to validate PASS26 assets/version and JSON files; removed stale references to old splash/onboarding assets.
- Kept Tunisian Arabic as the default language and preserved the real full-screen splash/onboarding photographs.

## Static verification performed
- ZIP source extracted and audited from PASS25.
- 22 Dart source files inspected.
- Parentheses/braces/brackets balanced across all Dart files.
- `google-services.json` and `firestore.indexes.json` parse correctly.
- Required real splash/onboarding assets exist and old asset references are absent from the active source/preflight.
- `bash -n tool/lef_lef_preflight.sh` passes.
- No intentional TODO/FIXME/UnimplementedError markers were found in the source.

## Still UNKNOWN until actual Android/Firebase runtime test
- `flutter analyze` and release APK build could not be executed in this container because the Flutter/Dart SDK is not installed here.
- Firestore rules have been updated for the new capability and pricing logic, but deployment/emulator execution was not possible in this environment.
- Real device GPS, Firebase Auth, Firestore runtime, OSM routing and multi-device ride flow still require the actual Termux/Android test run.
