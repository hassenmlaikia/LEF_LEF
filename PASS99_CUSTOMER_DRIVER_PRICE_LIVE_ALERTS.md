# PASS99 — Customer ride summary and live provider alerts

## Changes
- Customer service choices no longer display base fare or per-kilometre rates. Fixed-price options show only the total estimate for the selected route; negotiable options say that the provider will quote a total.
- When a provider makes an offer or accepts a fixed-price ride, the ride stores a minimal `providerInfo` snapshot: display name, vehicle type/model, and plate. It deliberately excludes phone, email, and other private account data.
- Firestore rules permit `providerInfo` to be written only in the corresponding provider assignment/offer transition, and require the snapshot UID to match the signed-in provider.
- The customer ride screen displays the assigned provider details, the current final/offer price, approximate trip duration, and a clearly approximate pickup ETA only while a fresh provider location is available.
- A shell-level live listener watches suitable searching rides while a verified provider is marked available. A snackbar alert appears even if the provider is looking at Home, Explore, Chat, or Profile rather than the provider request list. The request list itself remains backed by Firestore snapshots and refreshes live.
- Version bumped to `1.0.0+70` / Android versionCode `70`.

## Limitations / release checks
- ETA is a rough estimate from live GPS distance with a city-speed assumption, not a traffic-aware navigation ETA. It is labelled approximate and withheld when location is stale.
- This foreground in-app alert is not an Android background/push notification. Reliable alerts when the app is backgrounded or closed need Firebase Cloud Messaging plus a trusted server/Cloud Function sender and device token handling; no such backend is claimed here.
- No Flutter SDK is available in this execution environment, so `flutter analyze`, Android build, emulator tests, and live Firebase rules tests could not be run. Run them before releasing.
