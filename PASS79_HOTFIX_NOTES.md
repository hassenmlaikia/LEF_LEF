# PASS79 hotfix notes

- Auth/profile setup failure no longer signs the newly-created user out automatically. This avoids stranding the user after Firebase Authentication has already created the account.
- Firestore permission-denied errors now explain that the account may already exist and advise retrying sign-in after Firebase rules/configuration are corrected.
- Reduced the lockup image size on the auth screen to avoid oversized branding.
- Splash and onboarding backgrounds now use BoxFit.fill so the full designed artwork is visible rather than aggressively cropped/zoomed on differing phone aspect ratios.

Important: this hotfix does not prove the Firestore rules/project configuration are correct. If profile creation still fails with permission-denied, deploy/review the matching firestore.rules in the Firebase project and inspect Logcat for `LEF_LEF ensureProfile FAILED`.
Flutter analyze/build was not run in this environment.
