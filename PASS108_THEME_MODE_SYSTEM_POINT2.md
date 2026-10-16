# PASS108 — Point 2: Follow system appearance with manual override

## Scope
Implemented only the selected appearance behavior (choice C), building on the PASS107 design-system update. The original PASS106/PASS107 archives were not overwritten.

## Changes
- Theme preference now supports `system`, `light`, and `dark`.
- New installations default to `system`, so Flutter's `ThemeMode.system` follows the device appearance and updates when the platform brightness changes.
- Settings now offers three explicit choices in Tunisian Arabic: follow phone, daytime/light, and nighttime/dark.
- The selected preference is saved in SharedPreferences.
- Existing `dark_mode` boolean preferences are migrated to an explicit light/dark choice to preserve the user's previous selection; users can then switch to system mode manually.
- The splash screen uses the platform brightness when preference is `system`.
- Existing boolean preference helpers remain for compatibility, but the settings UI uses the three-mode preference.

## Scope protection
No ride pricing, booking logic, Firebase role logic, data schema, navigation, or other product features were intentionally changed.

## Verification
- `bash tool/lef_lef_static_audit.sh`: PASS.
- ZIP integrity test: to be run on the packaged archive.
- Flutter formatter/analyzer, APK build, and device-level light/dark switching tests: NOT RUN because Flutter/Dart executables are not available on PATH in this execution environment.
