# LEF_LEF PASS106 — Tunisian terminology cleanup

## User-facing terminology
- Replaced the disliked generic label «كابتور» with context-specific Tunisian wording: «السائق» / «سائق تاكسي» for passenger rides and «ليفرور» for delivery.
- Replaced «مقدم الخدمة» with «صاحب الخدمة» where the wording refers to negotiable services such as trucks, SOS and ambulance.
- Replaced «كليون» with «الحريف» in visible app copy.
- Updated ride status, offer, arrival, tracking, parcel-note, profile/role and owner oversight copy across the Dart UI/model/service sources. Internal enum names, Firestore field names, role IDs, and security rules remain unchanged to avoid breaking stored data or authorization.

## Validation
- This pass changes labels only; it does not claim to fix outstanding runtime/build limitations.
- Run `tool/lef_lef_preflight.sh`, `tool/lef_lef_static_audit.sh`, `flutter analyze`, and an Android APK build from the extracted project in Termux/Ubuntu.
