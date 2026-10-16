# PASS88 — Whole-app follow-up repairs based on user feedback

## Changes in this pass
- Restyled map-message pins as raised 3D callouts with layered drop shadows, gold bevel/rim, gradient face, raised icon medallion, and a shadowed pointer. They are not flat cards.
- Added an atomic `sellProductUnit` transaction. It decrements stock only if stock is positive and cannot race below zero; exposed it in company stock UI alongside restock.
- Added owner-only product edit/delete actions with server-side ownership checks; employees can adjust stock only within their company.
- Added author-only story edit/delete actions; edits can replace or remove attached image/video and preserve unchanged media.
- Added author-only edit/delete actions for published events and service-directory entries, backed by ownership checks in FirebaseService.
- Increased Android versionCode/pub version from 61 to 62 for the next build.

## Checks
- Static project audit: PASS.
- JSON parse and ZIP integrity checks: PASS.
- Flutter analyze, APK build, Firebase emulator/device integration, and live rule deployment were not run because Flutter/Dart SDK and live Firebase access are unavailable in this environment.

## Remaining known limitation
- There is no actual AI assistant/backend integration in the supplied project. A real AI feature needs a secured server-side endpoint and provider configuration; embedding a secret AI API key in the APK would be unsafe. This pass does not pretend a local scripted responder is AI.
