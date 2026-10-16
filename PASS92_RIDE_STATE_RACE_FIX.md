# PASS92 — Atomic ride-state transitions

- Reworked provider ride progression (`accepted → arriving → arrived → active → completed`) to validate the current status and write the next status in one Firestore transaction.
- Prevents stale reads and rapid/repeated taps from racing to overwrite a newer ride state.
- Keeps notifications after the transaction succeeds, and only notifies the client ID read from the validated ride document.

Validation performed: static audit and ZIP integrity. Flutter/Dart SDK is not installed in this editing environment, so analyzer, APK build, device execution, and live Firebase tests remain unverified.
