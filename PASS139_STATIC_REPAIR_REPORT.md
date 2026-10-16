# LEF_LEF PASS139 — static repair handoff

Input: LEF_LEF_PASS138_FINAL.zip and the user-provided Flutter analyzer output.

## Applied source repairs
- Fixed the missing closing delimiter in the chat screen expression.
- Corrected the saved-items ChoiceChip list construction in the profile screen.
- Corrected the legal-text Text widget style placement in settings.
- Corrected the owner review PopupMenuEntry list typing/structure.
- Removed unsupported `mainAxisSize` arguments from Wrap widgets.
- Added missing Home screen `stories()` and `iconFor()` widgets so the references resolve.
- Replaced Firestore `Transaction.get(Query)` calls with supported query reads outside transactions; attendee capacity uses a query snapshot.

## Important verification note
This repair package has not been run through `flutter analyze` or `flutter build apk` in this environment because the user's Termux/proot Flutter SDK is not available here. Do not treat this ZIP as build-verified. The query reads moved outside transactions can have race windows; if strict concurrent duplicate prevention is required, implement a transactional sentinel/lock document and corresponding security rules. Run the project's preflight and analyzer in the same Flutter environment before building.
