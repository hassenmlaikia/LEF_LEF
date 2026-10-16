# LEF_LEF — cumulative `n.zip`

This archive continues the latest LEF_LEF snapshot. It is intended to be the next complete working project ZIP, not a separate redesign.

## Product foundation
- Premium white/gold LEF_LEF identity using the supplied logo assets.
- Onboarding → Auth → Role selection → App shell flow.
- Firebase project: `lef-lef` / Android package: `com.leflef.app`.
- Home, Stories, Social posts, likes, comments and share-to-clipboard.
- Explore + saved places.
- Chat + per-user support conversation.
- Profile, settings, orders, wallet placeholder without fake balance, and help/support.
- Owner/Manager control center and role management.
- Provider workspace for Driver / Delivery Provider / Partner.

## Mobility foundation
- Taxi Moto, Car/Express, Delivery Moto, Delivery Van, Isuzu/Camion, SOS and Ambulance service options.
- Pricing foundation: Moto 2.00 TND base; Car/Express 4.00 TND base; day 1.00 TND/km; night 22:00–06:00 at 1.50 TND/km.
- Ride state machine: draft → searching → offered → accepted → arriving → arrived → active → completed/cancelled.
- Provider offer uses a Firestore transaction so only one provider can take a searching request.
- OpenStreetMap tiles + OSRM road routing with distance and ETA when routing is available.
- GPS permission/current-location marker.
- Provider GPS heartbeat while an assigned ride is arriving/active; client receives provider coordinates through the ride document in real time.
- Draggable map sheet.
- Contextual 3D-style message pin inside the map for each important service state.
- High-value warning for requests above 200 TND.

## Reliability/security work in this pass
- Firestore ride transition rules restrict who can perform each state transition.
- Provider location updates are restricted to location fields on the provider's own assigned ride.
- Client offer acceptance/cancellation is restricted to the allowed state and fields.
- Provider offer is restricted to `searching` requests and the authenticated provider.
- Sign-out clears the device's locally cached role so another account on the same phone does not inherit the previous account's role.
- Notification UI is real Firestore-backed UI; no fake notification is inserted.
- Settings toggles persist locally and to the user's Firestore profile.
- Home notification and community add buttons now have real actions.

## Honest limitations
- A production payment provider is not connected, so Wallet does not invent balances or successful payments.
- Live driver discovery/matching is Firestore-based provider availability; it is not a simulated fleet.
- OSRM/OpenStreetMap are external network services; if unavailable, the app does not pretend a routed road path exists.
- Flutter SDK is not installed in this container, so `flutter analyze`/APK compilation cannot be truthfully claimed as executed here. The ZIP is structurally validated.

## Latest pass
- Auth session listener is lifecycle-safe and synchronizes the operational role from Firestore after login.
- Local cached role is cleared on sign-out so another account on the same device cannot inherit it.
- Ride status changes now create user-scoped Firestore notifications for offer/accept/arrival/active/completed/cancelled events.
- Existing transactional provider offer, provider GPS heartbeat, routing, map message pin, social feed, stories, owner controls and profile tools are preserved.


## Latest continuation — PASS54 (2026-10-08)
- Added the missing place-search implementation used by Explore and Map.
- Release metadata is synchronized to `1.0.0+61` / Android `versionCode 61`.
- Static audit delimiter checking now ignores Dart literals/comments to avoid false failures.
- Flutter analyze/APK build remain runtime UNKNOWN in this container because the Flutter SDK is unavailable.


## PASS59 — functional-depth continuation
- Employee invitation acceptance/claim now completes the account role transition to `employee` and synchronizes `publicProfiles`.
- Firestore rules permit only a verified active employee profile to perform the one-way `client -> employee` transition with zero capabilities.
- Company invitation screen exposes the activation action before an employee profile exists.
- Provider/company/profile flows were rechecked for dead entry points and role mismatch.
- Flutter SDK is not installed in this execution environment; Flutter analyze/build remain UNKNOWN and are not claimed as PASS.

## PASS60 — ride recovery + role consistency (2026-10-08)
- Active client rides are now recoverable when Map is reopened: the latest non-terminal ride is loaded from Firestore, its service/route/coordinates/status are restored, and its live stream resumes.
- Active ride ID is also kept in local preferences and cleared when the ride is cancelled/completed, preventing stale local state after a terminal ride.
- Orders now exposes an actionable continuation entry for active rides and returns the user to the live Map flow instead of leaving the order as a dead list item.
- Ride notifications now open the live Map flow after being marked read.
- Manual Owner/Manager role changes now synchronize the target's `publicProfiles.role`, preventing stale public role data after an admin change.
- Removed an unused map import and unused local active-ride getter during the cleanup audit.
- Source delimiter audit and ZIP integrity checks pass. Flutter SDK is still unavailable in this container, so `flutter analyze` and APK compilation remain UNKNOWN and are not claimed as executed.

## PASS61 — end-to-end notification/chat/security closure
- Active client ride recovery now checks each active status separately instead of a single unordered 50-document window, reducing the chance of missing an active ride after history grows.
- Social/follow notifications now have explicit, rules-validated provenance instead of being silently rejected by Firestore rules.
- Chat sending now goes through a service method that validates conversation membership and notifies the other participant.
- Notifications can open the related ride or chat conversation directly.
- Company employees can update stock only; product creation/deletion/full edits remain restricted to company owners or authorized service managers.
