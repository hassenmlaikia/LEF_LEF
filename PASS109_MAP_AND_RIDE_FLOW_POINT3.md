# PASS109 — Map and ride flow (Point 3A)

## Scope
Changed only `lib/screens/map_screen.dart` for the selected map and ride-request point. The PASS108 archive remains untouched. No Firebase schema/rules, account roles, service prices, or unrelated screens were changed.

## Changes
- Removed the hardcoded Tunis city-level initial map view; the map opens at a broad Tunisia overview and does not preselect pickup/destination pins.
- Preserved tap-to-place behavior for pickup and destination, reverse geocoding, search-based place selection, current-location action, and road routing.
- If reverse geocoding fails, the selected point remains usable and the customer sees a neutral location label rather than raw coordinates.
- Added request-sequence protection for road-route requests so a slower old response cannot overwrite a newer route or clear its loading state.
- Corrected marker visibility checks to use valid-coordinate endpoint predicates rather than latitude-only checks.
- Customer map UI continues to show only the total estimate/final offer; no per-kilometre rate is rendered to customers. Existing tariff calculations and server-side price validation were not changed.

## Validation
- `tool/lef_lef_static_audit.sh`: PASS.
- Targeted source checks (no fixed Tunis view, no raw-coordinate label fallback, route response sequencing, no customer per-kilometre text, tap-to-place/search/road routing retained): PASS.
- ZIP integrity: PASS.
- Flutter formatting/analyzer, APK build, network-backed map/route testing, and device visual QA: not run in this execution environment because Flutter/Dart executables are unavailable on PATH.
