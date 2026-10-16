# PASS123 — Security hardening

- Provider availability is now checked transactionally in the app and constrained by Firestore rules.
- Timed suspensions consistently expire based on `suspendedUntil`; permanent suspensions remain active.
- Chat media is stored under a conversation-scoped path and Storage rules check conversation membership.
- Legacy media migration and tokenized download URL privacy are documented in `PASS123_IMPLEMENTATION_REPORT.md`.
