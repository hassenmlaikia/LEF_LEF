# PASS44 — continuation from PASS43

Payments remain intentionally deferred.

Completed:
- Provider profile: vehicle type/model/plate and availability state.
- Provider availability toggle persisted in user profile.
- Social discovery: user search and follow/unfollow UI.
- Social notifications for new follower, like and comment.
- Notification center bulk mark-as-read support.
- Event participation (RSVP / cancel RSVP) with Firestore rules.
- Public signed-in company/product catalogue reads while preserving write authorization.
- Employee invite lookup by matching email is readable to the invited account.

Still requires real-device/Firebase validation:
- Flutter analyze/build in the user's proot environment.
- Firebase Rules Emulator tests.
- Production Firebase behavior and indexes.
