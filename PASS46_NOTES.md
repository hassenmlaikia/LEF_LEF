# PASS46 — media upload hardening from PASS45

Payments remain intentionally deferred.

Completed:
- Media upload now accepts only the intended posts/stories folders.
- Image/video extensions are validated before upload and Firebase Storage receives an explicit MIME contentType.
- Storage rules now reject uploads that are not image/* or video/* and retain the 50 MB limit.
- Version synchronized to 1.0.0+46 / Android versionCode 46.
- Static/source structure checks re-run after the changes.

Still requires real-device/Firebase validation:
- Flutter pub get/analyze/build in the user's proot environment.
- Firebase Rules Emulator tests.
- Production Firebase indexes/queries and actual multi-account/media flows.
