# LEF_LEF PASS98 — Clear negotiated-price presentation

- Provider cards no longer show a misleading `0.00 TND` for negotiated requests; they state that the price is open to negotiation.
- The client map header shows the actual provider offer amount after an offer arrives or the ride is accepted, instead of continuing to say only “price by agreement”.
- Build metadata bumped to `1.0.0+69` / Android `versionCode 69`.

Validation: static audit and source smoke checks passed. Flutter/Dart compilation, Firebase Emulator tests, and APK build remain unverified because the Flutter SDK is not installed in this execution environment.
