#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path
import json, sys
root=Path('.')
required=[
 'assets/lef_logo_mark.png','assets/lef_logo_lockup.png',
 'assets/splash_light_real.jpg','assets/splash_dark_real.jpg',
 'assets/onboarding_mobility_real.jpg','assets/onboarding_connect_real.jpg','assets/onboarding_safe_real.jpg',
 'android/app/google-services.json','firestore.rules','firestore.indexes.json','android/gradlew'
]
missing=[p for p in required if not (root/p).exists()]
if missing: raise SystemExit('MISSING: '+', '.join(missing))
json.load(open(root/'android/app/google-services.json'))
json.load(open(root/'firestore.indexes.json'))

# Release metadata must stay synchronized.
pub=(root/'pubspec.yaml').read_text()
gradle=(root/'android/app/build.gradle').read_text()
if 'version: 1.0.0+78' not in pub or 'versionCode 78' not in gradle: raise SystemExit('VERSION MISMATCH')
preflight=(root/'tool/lef_lef_preflight.sh').read_text()
if 'versionCode 78' not in preflight or 'version: 1.0.0+78' not in preflight: raise SystemExit('STALE PREFLIGHT VERSION')
if 'com.leflef.app' not in (root/'android/app/google-services.json').read_text(): raise SystemExit('FIREBASE PACKAGE MISMATCH')
# Syntax balance is delegated to `flutter analyze`; this audit only checks
# source/package invariants that can be validated without the Flutter SDK.
for p in root.glob('lib/**/*.dart'):
    raw=p.read_text()
    if any(x in raw for x in ('UnimplementedError','Colors.black10')):
        raise SystemExit(f'BLOCKER {p}')
for p in root.glob('lib/**/*.dart'):
    s=p.read_text()
    for old in ('assets/splash_light.png','assets/splash_dark.png','assets/onboarding_mobility.png','assets/onboarding_connect.png','assets/onboarding_safe.png'):
        if old in s:
            raise SystemExit(f'STALE ASSET REF {p}: {old}')
map_source=(root/'lib/screens/map_screen.dart').read_text()
service_source=(root/'lib/services/firebase_service.dart').read_text()
provider_source=(root/'lib/screens/provider_screen.dart').read_text()
route_source=(root/'lib/services/route_service.dart').read_text()
rules_source=(root/'firestore.rules').read_text()
if 'if(status==RideStatus.draft) _recalc();' not in map_source: raise SystemExit('ACTIVE RIDE FARE RESTORE REGRESSION')
if 'if(_hasRouteEndpoints)await _loadRoute();' not in map_source: raise SystemExit('LOCATION PLACEHOLDER ROUTE REGRESSION')
if 'negotiable_pricing_mismatch' not in service_source or 'service_pricing_mismatch' not in service_source: raise SystemExit('RIDE PRICING VALIDATION MISSING')
if "bool available=d['providerAvailable']==true;" not in provider_source: raise SystemExit('PROVIDER AVAILABILITY DEFAULT REGRESSION')
if 'request.resource.data.pickup.size()>0' not in rules_source or 'request.resource.data.distanceKm>0' not in rules_source: raise SystemExit('RIDE RULE ENDPOINT VALIDATION MISSING')
if 'invalid_route_coordinates' not in route_source or 'route_points_are_identical' not in route_source: raise SystemExit('ROUTE INPUT VALIDATION MISSING')
if 'invalid_route_geometry' not in route_source or 'invalid_route_metrics' not in route_source: raise SystemExit('ROUTE RESPONSE VALIDATION MISSING')
# Cross-screen logic regressions: pricing, notifications, and conversation access.
if 'final configuredRate' not in service_source or 'rateFor(request.resource.data.kind,request.resource.data.pricingPeriod)' not in rules_source: raise SystemExit('OWNER CONFIGURABLE PRICING BINDING MISSING')
if "throw StateError('conversation_not_allowed')" not in service_source: raise SystemExit('CONVERSATION MEMBERSHIP GUARD MISSING')
if "initialRideId: x['rideId'].toString()" not in (root/'lib/screens/notifications_screen.dart').read_text(): raise SystemExit('RIDE NOTIFICATION DEEP LINK MISSING')
if 'final requestedId=widget.initialRideId?.trim();' not in map_source: raise SystemExit('MAP RIDE DEEP LINK RESTORE MISSING')
if 'privilegedViewer' not in map_source or "x['clientId']?.toString()!=uid" not in map_source: raise SystemExit('MAP DEEP LINK AUTHORIZATION MISSING')
if 'final from=pickup, to=destination;' not in map_source or 'stillCurrent' not in map_source: raise SystemExit('STALE ROUTE RESPONSE GUARD MISSING')
if 'static bool _providerCanServe' not in service_source or "!_providerCanServe(profile,x['kind']?.toString())" not in service_source: raise SystemExit('PROVIDER SERVICE COMPATIBILITY GUARD MISSING')
if 'fare<=0' not in service_source: raise SystemExit('ZERO-PRICE OFFER GUARD MISSING')
if 'invalid_report' not in service_source or 'cannot_report_own_post' not in service_source: raise SystemExit('REPORT INPUT VALIDATION MISSING')
if "if(v.isEmpty||v.length>4000)throw StateError('invalid_message');" not in service_source: raise SystemExit('CHAT MESSAGE LENGTH VALIDATION MISSING')
company_source=(root/'lib/screens/company_screen.dart').read_text()
if 'LEF_LEF company load failed' not in company_source or 'loadError=null' not in company_source: raise SystemExit('COMPANY LOAD ERROR RECOVERY MISSING')
if 'lat.isFinite' not in route_source or 'lon.isFinite' not in route_source: raise SystemExit('PLACE SEARCH COORDINATE VALIDATION MISSING')
if "const cancellable={'searching','offered','countered','accepted','arriving','arrived','active'}" in service_source or "const cancellable={'accepted','arriving','arrived','active'}" in service_source: raise SystemExit('ACTIVE RIDE CANCELLATION REGRESSION')
if "resource.data.status in ['searching','offered','countered','accepted','arriving','arrived','active']&&request.resource.data.status=='cancelled'" in rules_source: raise SystemExit('FIRESTORE ACTIVE RIDE CANCELLATION REGRESSION')
if 'static Future<void> updatePost(' not in service_source or 'static Future<void> deletePost(' not in service_source: raise SystemExit('POST EDIT/DELETE ACTIONS MISSING')
if "PopupMenuItem(value:'edit'" not in (root/'lib/screens/home_screen.dart').read_text(): raise SystemExit('POST EDIT UI MISSING')
if '..._stageMarkers()' in map_source: raise SystemExit('AUTOMATIC STAGE MAP BUBBLES REGRESSION')
if 'elevation: 12' in (root/'lib/widgets/map_message_pin.dart').read_text(): raise SystemExit('MAP MESSAGE PIN 3D ELEVATION REGRESSION')
if 'SelectableText(error' in (root/'lib/main.dart').read_text(): raise SystemExit('RAW STARTUP ERROR VISIBLE TO USER')
if 'ridePricingEditor(context)' not in (root/'lib/screens/owner_screen.dart').read_text(): raise SystemExit('OWNER PRICING EDITOR MISSING')
if '_ProviderRideAlert' not in (root/'lib/main.dart').read_text() or 'كورسة جديدة' not in (root/'lib/main.dart').read_text(): raise SystemExit('LIVE PROVIDER RIDE ALERT MISSING')
if "final admin = role == 'owner';" not in (root/'lib/screens/owner_screen.dart').read_text(): raise SystemExit('MANAGER ADMIN SCOPE REGRESSION')
# PASS94 regression checks: approval/profile consistency and offer validation.
if 'application_documents_incomplete' not in service_source or 'companyName' not in service_source or "'providerAvailable':false" not in service_source: raise SystemExit('PROVIDER APPLICATION APPROVAL VALIDATION MISSING')
if "final providerSnap = await tx.get(db.collection('users').doc(candidateId));" not in service_source: raise SystemExit('CLIENT OFFER ACCEPTANCE PROVIDER RECHECK MISSING')
if "request.resource.data.clientCounterFare>0" not in rules_source: raise SystemExit('COUNTER OFFER ZERO-FARE RULE REGRESSION')
if "hasCapability('manageRoles')&&request.resource.data.uid==uid" not in rules_source: raise SystemExit('ADMIN PUBLIC PROFILE ROLE SYNC PERMISSION MISSING')
if '_mapTapSequence' not in map_source: raise SystemExit('STALE REVERSE-GEOCODE RESPONSE GUARD MISSING')
if "profile['providerAvailable'] != true" not in provider_source or "data.providerAvailable==true&&resource.data.status in ['searching','countered']" not in rules_source: raise SystemExit('OFFLINE PROVIDER REQUEST VISIBILITY REGRESSION')

# PASS98 service workflow regression checks.
if 'static Future<bool> _isBlockedEitherWay' not in service_source: raise SystemExit('SOCIAL BLOCK ACTION GUARD MISSING')
if 'messaging_blocked' not in service_source or 'social_action_blocked' not in service_source: raise SystemExit('BLOCK ACTION VALIDATION MISSING')
if 'notBlocked(' not in rules_source: raise SystemExit('FIRESTORE BLOCK POLICY HELPER MISSING')
if 'verified_provider_or_service_manager_required' not in service_source: raise SystemExit('SERVICE DIRECTORY PROVIDER VALIDATION MISSING')
if 'not_authorized_or_ride_inactive' not in service_source: raise SystemExit('TRANSACTIONAL LIVE LOCATION GUARD MISSING')
if '1.0.0+78' not in pub or 'versionCode 78' not in gradle: raise SystemExit('PASS99 VERSION METADATA MISSING')
if '/كم' in map_source or 'نهار ${_configuredRate' in map_source or 'ليل ${_configuredRate' in map_source: raise SystemExit('CUSTOMER PER-KM PRICING LEAK')
if 'providerInfo' not in map_source or 'السعر النهائي' not in map_source or '_driverEtaMinutes' not in map_source: raise SystemExit('CUSTOMER ASSIGNED DRIVER SUMMARY MISSING')
if '_ProviderRideAlert' not in (root/'lib/main.dart').read_text() or 'availableRidesForRole(role)' not in (root/'lib/main.dart').read_text(): raise SystemExit('GLOBAL LIVE PROVIDER ALERT MISSING')
if "'providerInfo': _rideProviderInfo(profile, u.uid)" not in service_source: raise SystemExit('RIDE DRIVER INFO SNAPSHOT MISSING')
if 'request.resource.data.providerInfo.uid==request.auth.uid' not in rules_source: raise SystemExit('DRIVER INFO WRITE RULE MISSING')
if 'delivery_details_incomplete' not in service_source or 'deliveryRecipientPhone:_recipientPhone.text' not in map_source: raise SystemExit('STRUCTURED DELIVERY REQUEST MISSING')
if 'request.resource.data.delivery.recipientPhone.size()>=8' not in rules_source: raise SystemExit('DELIVERY FIRESTORE VALIDATION MISSING')
if 'not_authorized_or_ride_inactive' not in service_source: raise SystemExit('LIVE LOCATION STATE GUARD MISSING')

# PASS95 action-logic regression checks.
if "active_ride_already_exists" not in service_source or "where('status', whereIn: const ['searching','offered','countered','accepted','arriving','arrived','active'])" not in service_source: raise SystemExit('ACTIVE RIDE DUPLICATE GUARD MISSING')
if "final providerSnap = await tx.get(providerRef);" not in service_source: raise SystemExit('TRANSACTIONAL PROVIDER RECHECK MISSING')
if "await db.runTransaction<void>((tx) async {" not in service_source[service_source.find('static Future<void> acceptEmployeeInvite'):service_source.find('static Future<void> rejectEmployeeInvite')]: raise SystemExit('ATOMIC EMPLOYEE INVITE ACTIVATION MISSING')
if 'event_already_started' not in service_source or "get(/databases/$(database)/documents/events/$(eventId)).data.startsAt>request.time" not in rules_source: raise SystemExit('EVENT RSVP VALIDATION MISSING')
if 'product_inactive' not in service_source: raise SystemExit('INACTIVE PRODUCT SALE GUARD MISSING')
if 'request.resource.data.offerFare>0' not in rules_source or 'request.resource.data.clientCounterFare<=100000' not in rules_source: raise SystemExit('OFFER PRICE BOUNDS MISSING')
if 'existsAfter(/databases/$(database)/documents/employeeProfiles/$(uid))' not in rules_source: raise SystemExit('EMPLOYEE ACTIVATION ATOMIC RULE MISSING')
if "request.resource.data.expiresAt<=request.time+duration.value(24,'h')" not in rules_source: raise SystemExit('STORY MAX-LIFETIME RULE MISSING')
if "request.resource.data.startsAt>request.time" not in rules_source: raise SystemExit('EVENT FUTURE-TIME RULE MISSING')
if 'pending_application_exists' not in service_source or "where('status', isEqualTo: 'pending')" not in service_source: raise SystemExit('ATOMIC PROVIDER APPLICATION DEDUPE MISSING')
if 'employee_invite_already_pending' not in service_source: raise SystemExit('DUPLICATE EMPLOYEE INVITE GUARD MISSING')
# PASS105 media destination safety: profile avatars must not accept video files.
if "folder=='profile'&&!imageExts.containsKey(ext)" not in service_source: raise SystemExit('PROFILE VIDEO UPLOAD REGRESSION')
if 'confirmClientArrival' not in service_source or 'client_arrival_confirmation_required' not in service_source: raise SystemExit('TWO-PARTY ARRIVAL CONFIRMATION MISSING')
if 'clientArrivalConfirmed==true' not in rules_source or "clientArrivalConfirmedAt==request.time" not in rules_source: raise SystemExit('FIRESTORE ARRIVAL CONFIRMATION GUARD MISSING')
if "clientArrivalConfirmed?'أكدت وصول السائق'" not in map_source: raise SystemExit('CUSTOMER ARRIVAL CONFIRMATION UI MISSING')
# PASS118 whole-app search and social comment workflow checks.
explore_source=(root/'lib/screens/explore_screen.dart').read_text()
home_source=(root/'lib/screens/home_screen.dart').read_text()
if 'globalSearchResults()' not in explore_source or "collection('posts')" not in explore_source or "collection('events')" not in explore_source or 'serviceDirectory()' not in explore_source: raise SystemExit('GLOBAL SEARCH COVERAGE MISSING')
if 'parentCommentId' not in home_source or 'updateComment' not in home_source or 'deleteComment' not in home_source: raise SystemExit('COMMENT REPLY/EDIT/DELETE UI MISSING')
if 'Future<void> updateComment' not in service_source or 'Future<void> deleteComment' not in service_source: raise SystemExit('COMMENT EDIT/DELETE SERVICE MISSING')
# PASS120 regression checks: verified ride scoring, complete notification pagination, and profile input bounds.
if "completedRideIds.contains(r['rideId']?.toString())" not in service_source: raise SystemExit('DRIVER SCORE MUST USE COMPLETED RIDES ONLY')
if 'final ratingPoints=scores.isEmpty?25.0:(rated/5)*50;' not in service_source or 'final experiencePoints=(completed/20).clamp(0.0,1.0)*20;' not in service_source: raise SystemExit('DRIVER SCORE COMPONENTS MISSING')
if 'query.startAfterDocument(cursor)' not in service_source or 'if(users.docs.length<200)break;' not in service_source: raise SystemExit('PRICING NOTIFICATION PAGINATION MISSING')
if "cleanPhone.contains(RegExp(r'[^0-9+() .-]'))" not in service_source or 'cleanBio.length>160' not in service_source: raise SystemExit('PROFILE INPUT VALIDATION MISSING')
# PASS119 regression checks.
settings_source=(root/'lib/screens/settings_screen.dart').read_text()
profile_source=(root/'lib/screens/profile_screen.dart').read_text()
owner_source=(root/'lib/screens/owner_screen.dart').read_text()
if 'notificationPreferences' not in service_source or 'pricing' not in service_source: raise SystemExit('CATEGORY NOTIFICATION PREFERENCES MISSING')
if 'savedItems' not in service_source or 'removeSavedItem' not in profile_source: raise SystemExit('SAVED ITEMS WORKFLOW MISSING')
if 'coverUrl' not in service_source or 'phone: phone.text' not in profile_source: raise SystemExit('PROFILE COVER/CONTACT WORKFLOW MISSING')
if 'submitComplaint' not in settings_source or 'myComplaints' not in settings_source or 'resolveComplaint' not in owner_source: raise SystemExit('COMPLAINT TRACKING WORKFLOW MISSING')
if 'driverPerformanceSummary' not in service_source or 'peakDemandZones' not in service_source: raise SystemExit('DRIVER SCORE/PEAK ZONE LOGIC MISSING')
if "match /auditLogs/{logId}" not in rules_source or 'pricing_updated' not in service_source: raise SystemExit('OWNER AUDIT TRAIL MISSING')
if "whereIn:const ['open','in_review']" not in service_source: raise SystemExit('COMPLAINT IN-REVIEW LIFECYCLE MISSING')
# PASS121: timed suspension, document expiry, immutable price approval/history, ranking and cancellation reason.
if 'rankProvidersByDistanceAndScore' not in service_source or 'rankingScore' not in service_source: raise SystemExit('PROVIDER DISTANCE/PERFORMANCE RANKING MISSING')
if 'providerDocumentsExpiry' not in service_source or 'provider_documents_expired' not in service_source: raise SystemExit('EXPIRED PROVIDER DOCUMENT GUARD MISSING')
if 'setAccountSuspension' not in service_source or 'suspendedUntil' not in rules_source: raise SystemExit('TIMED ACCOUNT SUSPENSION MISSING')
if 'ridePricingHistory' not in service_source or 'restoreRidePricingVersion' not in service_source or '/history/{historyId}' not in rules_source: raise SystemExit('PRICE HISTORY/RESTORE MISSING')
if "'finalFare':price" not in service_source or "'priceApproved':true" not in service_source or 'request.resource.data.priceApproved==true' not in rules_source: raise SystemExit('FINAL PRICE APPROVAL LOCK MISSING')
if 'cancellationReason' not in service_source or 'cancelledFromStatus' not in rules_source: raise SystemExit('RIDE CANCELLATION REASON/PHASE AUDIT MISSING')
if 'reauthenticateCurrentUser' not in service_source or 'EmailAuthProvider.credential' not in service_source: raise SystemExit('SENSITIVE ACTION REAUTHENTICATION HELPER MISSING')
if 'slaDueAt' not in service_source: raise SystemExit('COMPLAINT SLA DEADLINE MISSING')
if 'finalFare' not in (root/'lib/screens/map_screen.dart').read_text() or 'سبب الإلغاء' not in (root/'lib/screens/map_screen.dart').read_text(): raise SystemExit('CUSTOMER FINAL PRICE/CANCELLATION UI MISSING')
if 'سجل تغييرات الأسعار' not in owner_source or 'restoreRidePricingVersion' not in owner_source: raise SystemExit('OWNER PRICE HISTORY UI MISSING')
owner_source=(root/'lib/screens/owner_screen.dart').read_text()
settings_source=(root/'lib/screens/settings_screen.dart').read_text()

# PASS122 checks: expiring timed suspensions, accessibility scale, saved tabs, image chat, and re-authenticated price restore.
if 'if(until is Timestamp) return until.toDate().isAfter(DateTime.now());' not in service_source: raise SystemExit('TIMED SUSPENSION EXPIRY REGRESSION')
if 'rankProvidersByDistanceAndScore' not in service_source or 'final byDistance=' not in service_source: raise SystemExit('DETERMINISTIC PROVIDER RANKING MISSING')
if 'sendImageMessage' not in service_source or 'chatMedia/' not in service_source: raise SystemExit('CHAT IMAGE SERVICE MISSING')
if 'fontScale' not in (root/'lib/services/app_prefs.dart').read_text() or 'TextScaler.linear(fontScale)' not in (root/'lib/main.dart').read_text(): raise SystemExit('ACCESSIBILITY FONT SCALING MISSING')
if "('service','خدمات')" not in (root/'lib/screens/profile_screen.dart').read_text() or 'ChoiceChip' not in (root/'lib/screens/profile_screen.dart').read_text(): raise SystemExit('SAVED ITEMS FILTER TABS MISSING')
if 'reauthenticateCurrentUser(password.text)' not in owner_source: raise SystemExit('PRICE RESTORE REAUTHENTICATION MISSING')
if 'تعدّى أجل المتابعة' not in settings_source: raise SystemExit('COMPLAINT SLA VISIBILITY MISSING')
if 'match /chatMedia/{conversationId}/{uid}/{fileName}' not in (root/'storage.rules').read_text(): raise SystemExit('CONVERSATION-SCOPED CHAT MEDIA STORAGE POLICY MISSING')
# PASS123 security regression checks.
if "request.resource.data.providerAvailable!=true" not in rules_source or "resource.data.providerVerified==true" not in rules_source: raise SystemExit('PROVIDER AVAILABILITY ELIGIBILITY RULE MISSING')
if "('suspendedUntil' in p&&p.suspendedUntil<=request.time)" not in rules_source: raise SystemExit('TIMED SUSPENSION RULE CONSISTENCY MISSING')
if "chatMedia/$conversationId/${u.uid}/" not in service_source: raise SystemExit('CONVERSATION-SCOPED CHAT UPLOAD PATH MISSING')
if "request.auth.uid in members() && uid in members()" not in (root/'storage.rules').read_text(): raise SystemExit('CHAT MEDIA MEMBERSHIP READ GUARD MISSING')
if 'await db.runTransaction<void>((tx) async {' not in service_source[service_source.find('static Future<void> setProviderAvailability') :]: raise SystemExit('ATOMIC PROVIDER AVAILABILITY CHECK MISSING')
# PASS124: private chat images use authenticated Storage SDK paths, not new token URLs.
chat_screen=(root/'lib/screens/chat_screen.dart').read_text()
storage_source=(root/'storage.rules').read_text()
if "'mediaPath':path" not in service_source or "getDownloadURL()" in service_source[service_source.find('static Future<void> sendImageMessage'):service_source.find('static Future<void> sendMessage')]: raise SystemExit('CHAT MEDIA TOKEN URL REGRESSION')
if "mediaPath.matches('chatMedia/'+conversationId+'/'+request.auth.uid+'/[^/]+')" not in rules_source: raise SystemExit('CHAT MESSAGE PATH VALIDATION MISSING')
if 'getData(10 * 1024 * 1024)' not in chat_screen or 'Image.memory(snapshot.data!' not in chat_screen: raise SystemExit('AUTHENTICATED CHAT IMAGE RENDERING MISSING')
if 'request.auth.uid in members() && uid in members()' not in storage_source: raise SystemExit('CHAT MEDIA MEMBERSHIP POLICY MISSING')

# PASS125: idempotent text-message retries must use stable IDs and reject ID reuse with changed content.
if 'clientMessageId' not in service_source or 'message_id_conflict' not in service_source: raise SystemExit('CHAT MESSAGE IDEMPOTENCY MISSING')
if 'pendingMessageId' not in chat_screen or 'clientMessageId:operationId' not in chat_screen: raise SystemExit('CHAT RETRY ID NOT PRESERVED IN UI')
if "await ref.collection('messages').add" in service_source[service_source.find('static Future<void> sendMessage'):service_source.find('static Future<void> reportPost')]: raise SystemExit('CHAT TEXT MESSAGE STILL USES NON-IDEMPOTENT ADD')
# PASS125: story views and reactions must respect block relationships both client-side and in rules.
if "throw StateError('social_action_blocked')" not in service_source[service_source.find('static Future<void> markStoryViewed'):service_source.find('static Future<void> updateProviderProfile')]: raise SystemExit('STORY BLOCK GUARD MISSING')
if "notBlocked(request.auth.uid,get(/databases/$(database)/documents/stories/$(storyId)).data.authorId)" not in rules_source: raise SystemExit('STORY BLOCK RULE MISSING')
# PASS126 hardening: provider profile availability checks, bounded/private peak zones,
# duplicate report prevention, notification idempotency, and story reaction allow-list.
if 'final safeLookback=Duration(seconds:lookback.inSeconds.clamp(15*60,24*60*60).toInt())' not in service_source: raise SystemExit('PEAK ZONE LOOKBACK BOUNDS MISSING')
if "(x['requestCount'] as int)>=5" not in service_source: raise SystemExit('PEAK ZONE PRIVACY THRESHOLD MISSING')
if 'post_${id}_${u.uid}' not in service_source or 'post_already_reported' not in service_source: raise SystemExit('DUPLICATE POST REPORT GUARD MISSING')
if 'cannot_report_own_post' not in service_source: raise SystemExit('OWN POST REPORT GUARD MISSING')
if 'invalid_notification_id' not in service_source or "'updatedAt':FieldValue.serverTimestamp()" not in service_source[service_source.find('static Future<void> markNotificationRead'):service_source.find('static Future<void> markAllNotificationsRead')]: raise SystemExit('NOTIFICATION READ VALIDATION MISSING')
if "!const {'❤️'}.contains(value)" not in service_source: raise SystemExit('STORY REACTION ALLOW-LIST MISSING')
if "request.resource.data.reaction=='❤️'" not in rules_source: raise SystemExit('STORY REACTION RULE ALLOW-LIST MISSING')
if "orderBy('expiresAt',descending:true).limit(30)" not in service_source: raise SystemExit('LATEST ACTIVE STORIES ORDERING MISSING')
if 'media_file_required' not in service_source: raise SystemExit('STORY MEDIA TYPE WITHOUT FILE GUARD MISSING')
# PASS128: complaint status/reply updates must notify the complaint owner, and
# Firestore must permit only a moderator to send that notification for their case.
if "_notifyUser(userId,'complaint_update'" not in service_source: raise SystemExit('COMPLAINT UPDATE NOTIFICATION MISSING')
if "request.resource.data.type=='complaint_update'&&hasCapability('moderateContent')" not in rules_source: raise SystemExit('COMPLAINT NOTIFICATION MODERATOR RULE MISSING')
if "get(/databases/$(database)/documents/users/$(uid)/complaints/$(request.resource.data.targetId)).data.userId==uid" not in rules_source: raise SystemExit('COMPLAINT NOTIFICATION RECIPIENT OWNERSHIP GUARD MISSING')
# PASS127: provider request ordering and privacy-conscious demand zones.
provider_screen=(root/'lib/screens/provider_screen.dart').read_text()
if "final pa=xa['priority']=='emergency'?0:xa['priority']=='medical'?1:2" not in provider_screen: raise SystemExit('PROVIDER PRIORITY TIE-BREAK MISSING')
if "final pb=xb['priority']=='emergency'?0:xb['priority']=='medical'?1:2" not in provider_screen: raise SystemExit('PROVIDER PRIORITY COMPARISON MISSING')
if 'final byTime=tb.compareTo(ta)' not in provider_screen: raise SystemExit('PROVIDER NEWEST-REQUEST TIE-BREAK MISSING')
if 'zones.entries.where((e)=>e.value>=3)' not in provider_screen: raise SystemExit('DEMAND ZONE MINIMUM COUNT MISSING')
if 'مناطق فيها طلبات أكثر توا (تقريبية)' not in provider_screen: raise SystemExit('DEMAND ZONE UI LABEL MISSING')
provider_update=service_source[service_source.find('static Future<void> updateProviderProfile'):service_source.find('static Future<void> setProviderAvailability')]
if 'await db.runTransaction<void>' not in provider_update or '_providerDocumentsExpired(data)' not in provider_update or '_accountSuspended(data)' not in provider_update: raise SystemExit('ATOMIC PROVIDER PROFILE ELIGIBILITY GUARD MISSING')
# PASS129: repeated provider cancellations leave a review event and require a reason.
if 'providerCancellationEvents' not in service_source or "'reviewStatus':'pending'" not in service_source: raise SystemExit('PROVIDER CANCELLATION REVIEW EVENT MISSING')
if 'provider_cancellation_review' not in rules_source or 'match /providerCancellationEvents/{eventId}' not in rules_source: raise SystemExit('PROVIDER CANCELLATION REVIEW RULE MISSING')
if 'سبب إلغاء الرحلة' not in provider_source or 'reason:why' not in provider_source: raise SystemExit('PROVIDER CANCELLATION REASON UI MISSING')
if 'completionDistanceKm' not in service_source or 'completion_too_far_from_destination' not in service_source: raise SystemExit('GPS COMPLETION EVIDENCE CHECK MISSING')

# PASS132: profile completeness and enforceable profile visibility.
if 'String city = ' not in service_source or 'String interests = ' not in service_source: raise SystemExit('PROFILE CITY/INTERESTS EDITING MISSING')
if 'static Future<void> updateProfileVisibility' not in service_source: raise SystemExit('PROFILE VISIBILITY UPDATE SERVICE MISSING')
if "where('visibility',isEqualTo:'public')" not in service_source: raise SystemExit('PUBLIC PROFILE SEARCH FILTER MISSING')
if "resource.data.visibility=='public'" not in rules_source or "resource.data.visibility=='followers'" not in rules_source: raise SystemExit('PROFILE VISIBILITY FIRESTORE READ RULE MISSING')
if 'الاهتمامات' not in (root/'lib/screens/profile_screen.dart').read_text() or 'ظهور البروفايل' not in settings_source: raise SystemExit('PROFILE EDITOR/PRIVACY UI MISSING')


if "SnackBarAction(label:'عاود'" not in chat_screen: raise SystemExit('VISIBLE CHAT RETRY ACTION MISSING')
idx=json.load(open(root/'firestore.indexes.json'))
if not any(x.get('collectionGroup')=='publicProfiles' and [f.get('fieldPath') for f in x.get('fields',[])]==['visibility','displayNameLower'] for x in idx['indexes']): raise SystemExit('PUBLIC PROFILE SEARCH INDEX MISSING')


if "role=='manager'&&get(/databases/$(database)/documents/users/$(request.auth.uid)).data.capabilities is list&&cap in get(/databases/$(database)/documents/users/$(request.auth.uid)).data.capabilities" not in rules_source: raise SystemExit('MANAGER OWNER-CONTROLLED CAPABILITY GATE MISSING')
if "final editableCapabilities=Capability.values.toSet()" not in owner_source: raise SystemExit('OWNER MANAGER CAPABILITY CONTROLS INCOMPLETE')

if "'visibility','updatedAt'" not in rules_source: raise SystemExit('ADMIN PUBLIC PROFILE VISIBILITY SYNC RULE MISSING')

# PASS133: account deletion is a cancellable 30-day request, legal drafts are clearly marked,
# and notification quiet hours remain user-controlled and validated.
settings_source=(root/'lib/screens/settings_screen.dart').read_text()
if 'requestAccountDeletion' not in service_source or 'cancelAccountDeletionRequest' not in service_source: raise SystemExit('ACCOUNT DELETION REQUEST/CANCEL FLOW MISSING')
if 'accountDeletionRequests' not in rules_source or "resource.data.status=='pending'" not in rules_source: raise SystemExit('ACCOUNT DELETION SECURITY RULE MISSING')
if 'مهلة تراجع 30 يومًا' not in settings_source or 'حذف الحساب' not in settings_source: raise SystemExit('ACCOUNT DELETION UI MISSING')
if 'مسودة أولية وليست نصًا قانونيًا نهائيًا' not in settings_source or 'مراجعة قانونية' not in settings_source: raise SystemExit('LEGAL REVIEW WARNING MISSING')
if 'quietHoursEnabled' not in settings_source or 'quietStart' not in service_source or 'quietEnd' not in rules_source: raise SystemExit('QUIET HOURS USER CONTROL MISSING')
if 'version: 1.0.0+78' not in pub or 'versionCode 78' not in gradle: raise SystemExit('PASS133 VERSION METADATA MISSING')

# PASS134: branch management, hours/coverage, appointment/waitlist and capacity controls.
service_source=(root/'lib/services/firebase_service.dart').read_text()
company_source=(root/'lib/screens/company_screen.dart').read_text()
for token in ('saveCompanyBranch','companyBranches','requestCompanyAppointment','updateCompanyAppointmentStatus','joinCompanyWaitlist','companyWaitlist','event_full','reminderPolicy'):
    if token not in service_source: raise SystemExit('PASS134 SERVICE LOGIC MISSING: '+token)
for token in ('الفروع ومناطق الخدمة','المواعيد وقائمة الانتظار','_addBranch'):
    if token not in company_source: raise SystemExit('PASS134 COMPANY UI MISSING: '+token)
for token in ('match /branches/{branchId}','match /appointments/{appointmentId}','match /waitlist/{entryId}'):
    if token not in rules_source: raise SystemExit('PASS134 FIRESTORE RULE MISSING: '+token)
if 'version: 1.0.0+78' not in pub or 'versionCode 78' not in gradle: raise SystemExit('PASS134 VERSION METADATA MISSING')

print('LEF_LEF STATIC AUDIT: PASS')
PY
