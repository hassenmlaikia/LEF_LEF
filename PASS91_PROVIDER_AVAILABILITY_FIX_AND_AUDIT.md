# PASS91 — Provider availability toggle repair and verification

## Concrete issue found and fixed

The provider profile's “متوفر للطلبات” switch previously changed local UI state and called `setProviderAvailability()` before saving the vehicle type and plate currently entered in the form. The service validates the already-saved Firestore profile, so a provider entering their first vehicle details and enabling availability in one pass could be rejected until they separately saved the profile. The UI also optimistically flipped the switch and then reverted it on failure.

The switch now calls `updateProviderProfile()` with the current vehicle type, model, plate, and requested availability. It updates the visible switch only after the save succeeds and gives separate success/failure feedback. The existing Save Profile button remains available.

## Checks performed in this environment

- ZIP archive opened and extracted successfully.
- `tool/lef_lef_static_audit.sh`: PASS after the change.
- `unzip -t`: PASS for the original archive before editing; the updated archive is separately integrity-tested during packaging.
- `tool/lef_lef_preflight.sh`: BLOCKED because `flutter` is not installed/on PATH in this environment (`flutter: command not found`).
- Java is present (OpenJDK 21), but Flutter/Dart SDK is absent.

## Not verified

- `flutter analyze`, Dart compilation, Android APK build, device/emulator interaction, Firebase emulator integration, and live Firestore/Storage rule deployment could not be run without Flutter/Dart and a configured live/test Firebase environment.
- This report does not claim the whole app is runtime-verified or that a new APK was built.

## Other known release dependencies/limitations

- PASS90 documents owner-configured pricing, provider live request streams/alerts, and role-scoped management; these require deployed Firestore rules and appropriate Firebase indexes/configuration to work against the live backend.
- PASS88 documents that no secured AI assistant/backend integration exists in this supplied project; a genuine AI feature requires a secured server endpoint/provider setup.
