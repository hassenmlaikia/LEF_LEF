# LEF_LEF PASS17

Source: PASS16 only.

- Blocked users are now actually excluded from the community feed.
- Posts now expose a block action for other authors; block state is persisted in Firestore.
- The Discover banner is no longer decorative-only: it gives a clear action cue toward Explore.
- Tightened users Firestore update rules so a signed-in user cannot rewrite the immutable profile uid while updating their own profile fields.
- Verified google-services.json is present under android/app in the source ZIP.
- Version 1.0.0+17.

Flutter analyze/build remains UNKNOWN unless a Flutter SDK is available in the execution environment.
