# LEF_LEF PASS111 — Point 5: Driver lifecycle, assignment, and price consistency

## Scope
Source: `LEF_LEF_PASS110_ALL_SERVICE_PRICING_POINT4.zip` (PASS110). This pass changes only the driver/ride lifecycle and the requested service-pricing permission path. PASS110 remains unchanged.

## Changes made
- `firestore.rules`
  - Added a provider qualification helper for customer acceptance of a driver's offer: the assigned provider must still be verified, hold `manageRides`, and have a role allowed to serve that service kind.
  - A provider can only submit an offer for a ride configured as negotiable.
  - Client acceptance of a driver offer and client counter-offers are limited to genuinely negotiable rides.
  - A provider accepting a counter-offer must still be verified, available, eligible for the service kind, and the accepted `offerFare` must exactly equal the client's `clientCounterFare`.
  - Service managers can create/update the pricing document; updates are explicitly scoped to `system/pricing`, and deleting system documents remains Owner-only. Owner remains fully authorized.
  - Managers retain their existing `manageRides` permission and may use additional capabilities explicitly assigned by the Owner.
- `lib/services/firebase_service.dart`
  - Pricing writes are now permitted to Owner or a user with the explicit `manageServices` capability, matching the role-based requirement.
  - Existing transaction checks for provider verification, availability, service-kind eligibility, and one pending/active assignment are preserved for offer/fixed acceptance/counter acceptance.
- `lib/screens/owner_screen.dart`
  - Users with `manageServices` can open the pricing editor even if they do not have `manageRides`; users with `manageRides` (including Manager) can still see all rides.
  - The pricing editor remains within the existing role/capability gate; no general-user access was added.
- `lib/screens/provider_screen.dart`
  - A driver now sees their own pending offer (`offered`) instead of it disappearing from the active list.
  - The driver's ride card shows the sent offer, client's counter-offer, fixed estimate, or final accepted price according to the stored ride state.

## Price and state alignment
- Fixed-price acceptance stores `offerFare` equal to the ride's stored `estimatedFare`.
- Negotiated offer acceptance preserves the submitted `offerFare`.
- Counter acceptance stores the exact `clientCounterFare` as `offerFare`; Firestore rules now enforce this equality.
- The customer and Owner already read these same stored ride fields; the driver view now displays the same stored fare source.
- Existing lifecycle transitions and the existing transactional single-assignment check are retained.

## Checks actually run
- `bash tool/lef_lef_static_audit.sh` — PASS.
- 15 targeted structural assertions over app logic and Firestore rules — PASS.
- ZIP integrity check — run after archive creation.
- Change-scope comparison against a fresh PASS110 extraction — run after archive creation.

## Not run / limitations
- `flutter analyze`, `dart format`, Flutter unit/widget tests, and APK build were not run because neither `flutter` nor `dart` is available in this execution environment.
- Firebase CLI/rules compiler/emulator tests and live Firestore end-to-end tests were not run because `firebase` is unavailable and no live project test was executed.
- Static audit and source-structure assertions are not substitutes for compiling/deploying Firestore Rules or running the app. Deploy the updated `firestore.rules` to the Firebase project before relying on the new server-side restrictions and role-based pricing writes.
