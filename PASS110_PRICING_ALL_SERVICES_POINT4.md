# PASS110 — Pricing and services review (Point 4 only)

## Scope
Applied to PASS109 only. The original PASS109 archive remains unchanged. Changes are limited to:
- `lib/models/app_models.dart`
- `lib/services/firebase_service.dart`
- `lib/screens/map_screen.dart`
- `lib/screens/owner_screen.dart`
- `firestore.rules`
- this report

## Changes
- Preserved the agreed defaults for taxiMoto (2 TND base), carExpress (4 TND base), deliveryMoto (2 TND base), deliveryVan (4 TND base), day rate 1 TND/km, night rate 1.5 TND/km from 22:00 to 06:00.
- Added configuration entries for all eight service kinds: taxiMoto, carExpress, deliveryMoto, deliveryVan, deliveryTruck, SOS, ambulance, and randonnee.
- Expanded Owner pricing settings to edit base/day/night values per service and choose fixed automatic pricing or negotiation per service.
- Added app-side validation: all configured values must be finite and between 0 and 1000; a fixed-price service must not be free in either day or night period.
- Ride creation checks the current Owner-configured pricing mode and amounts; an active ride keeps the pricing mode recorded on that ride even if the Owner later changes settings.
- Firestore ride-create validation now checks the same configured negotiation mode and rates, with legacy defaults when the pricing document or an individual key is absent.
- Removed per-kilometre rates from customer-facing service subtitles. Fixed-price services show the total estimate only; negotiated services show that the fare is agreed with the provider.
- Preserved the existing over-200 TND confirmation prompt and the existing policy that new pricing affects new requests, not rides already in progress.

## Checks actually run
- `bash tool/lef_lef_static_audit.sh`: PASS.
- Custom structural checks: PASS for eight-service configuration coverage, Owner editor coverage, pricing-mode wiring, customer-facing rate-label removal, app-side pricing validation wiring, Firestore rule wiring, and the over-200 TND confirmation prompt.
- ZIP integrity check: to be performed after packaging.

## Not run / limitations
- `flutter analyze`, `dart format`, Flutter tests, APK build, Firebase Rules compiler/emulator tests, and real Firestore end-to-end tests were not run because Flutter, Dart, and Firebase CLI/emulator are unavailable in this execution environment.
- The Owner-controlled settings are client UI and Firestore rule changes; deploy `firestore.rules` to Firebase for server-side validation to match the app. Do not assume deployed Firebase rules changed automatically by downloading this ZIP.
- The exact rates for truck, SOS, ambulance, and randonnee remain zero in the default rate tables while those services remain negotiable. If the Owner switches one to fixed pricing, the UI requires a nonzero total for both day and night before saving.
