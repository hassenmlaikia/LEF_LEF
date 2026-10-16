# LEF_LEF PASS24

Source: LEF_LEF_CORE_COMPLETE_PASS23.zip.

## Splash / onboarding background correction
- Replaced the previous 2D/illustrated splash backgrounds with full-screen 1080x1920 photographic scenes.
- Added separate light and dark splash assets.
- Replaced all three onboarding backgrounds with full-screen photographic mobility/discovery/connect scenes.
- The Flutter screens use the new assets directly with `BoxFit.cover`; no card/container is used around the background.
- Onboarding copy, pagination, Skip, Next and Get Started remain real controls layered above the photographic backgrounds.
- Existing logo/brand treatment remains available separately in the app assets.

## Verification
- All new background files are 1080x1920 JPEGs.
- References to the old onboarding/splash background files were removed from the splash/onboarding screens.
- Static Dart bracket balance checked.
- Flutter analyze/build remains UNKNOWN because Flutter SDK is unavailable in this execution environment.


PASS25 carries the PASS24 source forward with Tunisian Arabic as the default app language, RTL layout by default, and translated primary user-facing flows. Real splash/onboarding photo assets remain full-screen. Flutter analyze/build could not be executed in this container because Flutter/Dart SDK binaries are unavailable; this remains UNKNOWN until tested in the user's Termux environment.
