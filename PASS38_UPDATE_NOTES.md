# PASS38 update audit

Source: `LEF_LEF_CORE_COMPLETE_PASS38.zip`

Verified/fixed in this update:
- Firestore role-request notifications: role approval/rejection notifications can now be created by an authorized `manageRoles` reviewer for the requesting user's notification subcollection.
- Existing requester-side role-request notification path remains restricted to the bootstrap Owner.
- Existing ride/social/provider rules were reviewed against the Dart Firestore paths present in the source.

Validation performed:
- Static audit script: PASS.
- ZIP structure and required Firebase/Android/config assets: present.
- Flutter analyze/APK build: NOT executed in this environment because Flutter SDK is unavailable here.
