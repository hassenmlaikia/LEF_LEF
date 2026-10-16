# PASS75 — Settings, Home, Explore, Profile review

## Changes in this pass
- Explore people search now keeps its text controller between rebuilds; previously it created a new controller inside `StatefulBuilder`, causing the query to reset as the user typed.
- Explore place search now has a visible search action and loading indicator.
- Saved-place document IDs are URL-safe base64 encodings of the place name and description, so names containing `/` cannot break Firestore document paths and same-named places with different descriptions do not overwrite one another.
- Event creation now requires a non-empty title and place and a future date before enabling Publish; text fields have reasonable length limits.
- RSVP button now offers “إلغاء المشاركة” when already registered, matching its actual action.
- Profile editor falls back to the Firestore `photoUrl` if Firebase Auth has no `photoURL`.
- Removed a duplicate null guard in the profile feed and replaced duplicate Privacy/Language entries with one settings entry that opens the actual settings page.
- Home story/post dialogs now update after choosing media, show the selected filename with a remove action, cap text lengths, and prevent empty submissions until either text or media is present.

## Still not verified
- This environment does not have Flutter or Dart installed, so `flutter analyze`, APK build, Firebase runtime, Firestore rules, and Android media-picker behavior could not be tested here.
- Language choices currently change locale/direction but the app still has many hard-coded Arabic strings; full French/English translation is not completed in this pass.
- Notification and privacy preference semantics need end-to-end review; UI persistence is present, but every notification-producing path has not yet been checked against the notification toggle.
