# LEF_LEF — current product pass

This archive is the source of truth for this pass. It is intended to be opened and tested in the user's existing Flutter/Termux environment.

## Termux verification

```bash
cd /data/data/com.termux/files/home/LEF_LEF/lef_lef
bash tool/lef_lef_preflight.sh
flutter build apk --release
```

Package: `com.leflef.app`  •  Version: `1.0.0+71`

## Real product flows included

- Onboarding → Auth → authenticated app shell.
- First authenticated profile on an empty Firebase bootstrap becomes Owner; later profiles default to Client.
- Owner / Manager role management with Owner self-lock protection.
- Taxi Moto, Car/Express, Delivery Moto, Van, Isuzu/Camion, SOS and Ambulance request flows.
- Pricing: base + day/night per-km, with explicit high-value warning above 200 TND.
- Real OpenStreetMap route lookup and provider GPS updates through Firestore.
- Ride states: draft → searching → offered → countered/accepted → arriving → arrived → active → completed/cancelled.
- Provider offer + client counter-offer + provider acceptance.
- State notifications and notification read state.
- Stories, posts, likes, comments, sharing, chat/support.
- Profile, orders, saved places, wallet placeholder that explicitly does not fake a balance, help and settings.
- Light/dark mode, language preference, privacy and notification preferences.

No fake success response is used for the core Firebase ride/role/social operations.

## Final audit additions in this pass

- Dedicated branded native + Flutter splash assets for light/dark startup.
- Real onboarding artwork pages with Skip / Next / Get Started flow; completion is persisted.
- New accounts after the first Owner are Client by default; provider roles are requested and reviewed by an authorized capability holder.
- Capability-based authorization is persisted on user profiles and enforced in Firestore rules; Owner can delegate fine-grained management capabilities.
- Client cancellation is transaction-safe across active request states.
- Ride notifications are authorized for the actual client/provider involved in the ride.
- Community likes are writable by signed-in users without granting permission to edit post content.
- Support conversations can include the bootstrap Owner so support is not a dead self-chat.
- First-owner bootstrap creation is tied to the atomic Owner profile write.

Flutter SDK was not available in the audit container, so `flutter analyze` / `flutter build apk` are intentionally not claimed as passed here. The source-level structure, imports, asset references, Android resources, JSON and shell syntax were checked locally.
