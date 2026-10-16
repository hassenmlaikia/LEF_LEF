# PASS47

Source: PASS46.
Focus: complete logical cleanup and close identified gaps.

## Completed
- Fixed stale preflight version checks to 1.0.0+47 / versionCode 47.
- Added publicProfiles search index so signed-in people discovery does not query protected user documents.
- Synced public profile records on profile creation/repair.
- Added employee invite accept/reject flow for pending email-matched invitations.
- Hardened employee invite update rule to only allow the invited account to activate/reject a pending invite.
- Added social repost/re-share as a first-class post record with notification to original author.
- Preserved native Android share intent.
- Kept payments deferred.

## Runtime UNKNOWN
- Flutter analyze/build/APK and Firebase emulator/device tests require the user environment.


## Latest repair
- Fixed `ServiceKind` import in `lib/main.dart` so the Shell compiles against the shared model.
- Restored the `HomeScreen.onExplore` callback used by the Shell and kept the Home → Explore navigation path active.
- Hardened profile story loading: Firestore errors no longer leave an infinite loading spinner; active stories are sorted and can be opened with their text/media.
- Static audit passes after these changes.
- Flutter analyze/build remain UNKNOWN in this environment because Flutter SDK is not installed in the execution container.

## Latest continuation fixes — 2026-10-08
- Continued from latest repaired ZIP only.
- Added Flutter foundation logging import to Firebase service.
- Provider profile fields (`vehicleType`, `vehicleModel`, `vehiclePlate`, `providerAvailable`, `providerUpdatedAt`) are now permitted by Firestore self-update rules.
- Public profile repair now preserves/synchronizes bio and photo URL.
- Home/profile post and story publishing now surface success/failure feedback instead of silent failure.
- Video stories use a video thumbnail icon instead of treating the video URL as an image.
- Release version synchronized to `1.0.0+47` / Android `versionCode 47` across pubspec, Android build, preflight and static audit.
- Static audit: PASS.
- Flutter analyze/build could not be executed in this environment because Flutter SDK is unavailable here; run them in the Termux Flutter environment.
