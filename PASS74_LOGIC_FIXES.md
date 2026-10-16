# LEF_LEF PASS74 — Logic fixes

This pass continues from PASS73 with focused fixes in social actions and notifications.

## Fixed in source
- `markAllNotificationsRead` now marks every unread notification in batches of 450 instead of stopping after the first 100.
- `toggleLike` now reads the current post likes in a Firestore transaction and decides add/remove from the latest persisted state. This avoids stale feed state toggling incorrectly during concurrent use and only sends a like notification when the transaction actually adds a like.
- `addComment` now rejects empty or over-4000-character comments client-side, verifies the post exists before creating a comment, and reports invalid input rather than silently returning.

## Verification limits
- Source-level checks were run for the modified methods and ZIP integrity.
- Flutter analyze, APK build, Firestore emulator/security-rules tests, and real two-account Firebase runtime tests were not run in this container. Do not treat these changes as runtime-verified.
