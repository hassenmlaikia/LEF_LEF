# LEF_LEF PASS25

Source: `LEF_LEF_CORE_COMPLETE_PASS24.zip` only.

## Product polish / readiness work
- Default UI language is now **تونسي** (Arabic/RTL) for a fresh install.
- Language selector offers تونسي, Français, English.
- Primary Auth, Home, Move, Provider, Explore, Social, Chat, Notifications, Profile, Settings and Owner-management UI is translated into Tunisian Arabic.
- Tunisian wording is used for service names, ride states, errors, confirmations and common empty/loading states.
- Existing English/French preference switching remains available.
- Real full-screen splash/onboarding photo assets from PASS24 remain the active assets; no small-card/2D onboarding replacement was introduced.
- Core Firebase flows from PASS24 remain preserved: first-account Owner bootstrap, subsequent Client accounts, role requests, provider matching constraints, ride states, offers/counter-offers, notifications, social posts/comments/likes, events, directory, support chat, saved places, moderation and Owner control center.
- Version updated to `1.0.0+25`, Android versionCode `25`.

## Source checks performed
- PASS24 extracted successfully and used as the sole source.
- No Dart bracket-count imbalance found after edits.
- No intentional placeholder/TODO/UnimplementedError markers introduced.
- Real assets referenced by `pubspec.yaml` are present.

## UNKNOWN before friend testing
- `flutter analyze` and `flutter build apk --release` cannot be executed in this container because Flutter/Dart SDK binaries are not installed.
- Firebase runtime, Firestore rules deployment, Google Sign-in/device auth and production network behavior still require an actual Android build/device test.
- Payment provider integration is intentionally not claimed as live; Wallet does not fake a balance.
