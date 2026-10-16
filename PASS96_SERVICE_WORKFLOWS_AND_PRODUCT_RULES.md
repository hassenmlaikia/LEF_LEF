# LEF_LEF PASS96 — Service workflows and product rules

## Product direction
Use common, proven interaction patterns seen in mobility and delivery apps without copying their branding: simple booking, clear price before confirmation, provider eligibility, transparent offer/counter-offer, live trip stages, delivery details, and clear cancellation/error states. LEF_LEF keeps its own Tunisian Arabic-first identity and gold/white visual language.

## Repairs in this pass
- Ride location writes now re-check ride ownership and active status inside a Firestore transaction, preventing stale location updates after a ride is closed or reassigned.
- Social actions (follow, like, comment, repost) now check block relationships before writing. Direct messages check blocks for every other conversation member before sending. Firestore rules should still be treated as the final authorization boundary.
- Service directory creation now requires a verified service provider or a user with `manageServices`; update/delete permits the creator or a service manager, matching the intended administration workflow.
- Event update/delete permits the owner or a user with `manageServices`, matching the service administration capability.
- Build metadata bumped to `1.0.0+67` / Android `versionCode 67`.

## Required service flows before release
### Mobility (Bolt-like clarity)
1. Pickup and destination must be selected, named, and routed; never silently prefill fake endpoints.
2. Show service type, route distance/time estimate, pricing basis, and final fixed estimate before request submission.
3. A request is visible only to verified, available providers compatible with that service type.
4. Provider assignment must be exclusive; status transitions are ordered and actor-authorized.
5. Show cancellation policy/reason and keep both sides synchronized.

### Negotiated services (inDrive-like clarity)
1. Negotiable services start without a fake fixed fare.
2. Provider offers and client counters must be positive, bounded, tied to the current ride, and visible to both parties.
3. Only the current assigned provider may accept a counter; only the client may accept a provider offer.
4. Stale offers cannot revive cancelled or completed rides.

### Delivery (Glovo-like clarity)
1. Before release, add structured pickup contact, recipient name/phone, parcel category/size, handling notes, and proof-of-delivery status. The request now captures recipient name/phone, parcel category, and notes. Remaining delivery gaps: parcel dimensions/weight limits, sender contact, driver pickup confirmation, recipient OTP/signature/photo proof, failed-delivery exceptions, and end-to-end delivery status tracking.
2. Do not mark delivery complete without an explicit completion action and recipient confirmation or documented exception.
3. Stock/orders and transport jobs must be distinct: decrementing product stock is not the same as creating a delivery order or recording payment.

## Release blockers not solved by source-only changes
- Run `flutter pub get`, `flutter analyze`, tests, and a release APK build using the project's supported Flutter/Gradle toolchain.
- Repair the custom `android/gradlew` into a standard reproducible Gradle wrapper.
- Deploy and test Firestore/Storage rules and indexes against the intended Firebase project.
- Add emulator tests for role escalation, provider approval, duplicate active rides, two providers accepting one ride, block enforcement, stock races, and event RSVP.
- Electronic payments, refunds, cash collection/reconciliation, secure AI backend, push notification delivery, and delivery proof-of-delivery are not claimed as complete.
