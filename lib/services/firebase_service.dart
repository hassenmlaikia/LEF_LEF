import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import '../models/app_models.dart';

class FirebaseService {
  static Future<void> init() async { if (Firebase.apps.isEmpty) await Firebase.initializeApp(); }
  static User? get user => FirebaseAuth.instance.currentUser;
  static FirebaseFirestore get db => FirebaseFirestore.instance;
  static FirebaseStorage get storage => FirebaseStorage.instance;

  static bool _accountSuspended(Map<String,dynamic> profile) {
    final until=profile['suspendedUntil'];
    // Timed suspensions expire automatically even if the boolean flag remains true.
    if(until is Timestamp) return until.toDate().isAfter(DateTime.now());
    if(until is DateTime) return until.isAfter(DateTime.now());
    // A flag without an expiry is treated as a permanent suspension.
    return profile['accountSuspended']==true;
  }

  static bool _providerDocumentsExpired(Map<String,dynamic> profile) {
    final expiry=profile['providerDocumentsExpiry'] ?? profile['documentsExpiryAt'];
    return expiry is Timestamp && !expiry.toDate().isAfter(DateTime.now());
  }

  /// Sorts candidates by a combined proximity/performance score without
  /// returning or storing another provider's exact location.
  static List<Map<String,dynamic>> rankProvidersByDistanceAndScore(
    List<Map<String,dynamic>> candidates,{required double latitude,required double longitude}) {
    if(!latitude.isFinite||latitude < -90||latitude > 90||!longitude.isFinite||longitude < -180||longitude > 180) throw ArgumentError('invalid_coordinates');
    double distanceKm(double lat,double lon) {
      const r=6371.0; final dLat=(lat-latitude)*math.pi/180, dLon=(lon-longitude)*math.pi/180;
      final a=math.pow(math.sin(dLat/2),2)+math.cos(latitude*math.pi/180)*math.cos(lat*math.pi/180)*math.pow(math.sin(dLon/2),2);
      return r*2*math.atan2(math.sqrt(a),math.sqrt(math.max(0,1-a)));
    }
    final ranked=<Map<String,dynamic>>[];
    for(final raw in candidates) {
      final x=Map<String,dynamic>.from(raw); if(x['providerAvailable']!=true||x['providerVerified']!=true||_accountSuspended(x)||_providerDocumentsExpired(x)) continue;
      final lat=(x['latitude'] as num?)?.toDouble() ?? (x['providerLat'] as num?)?.toDouble();
      final lon=(x['longitude'] as num?)?.toDouble() ?? (x['providerLng'] as num?)?.toDouble();
      if(lat==null||lon==null||!lat.isFinite||!lon.isFinite||lat.abs()>90||lon.abs()>180) continue;
      final distance=distanceKm(lat,lon);
      final rawScore=(x['score'] as num?)?.toDouble()??50.0;
      final points=rawScore.isFinite?rawScore.clamp(0.0,100.0):50.0;
      // Distance has 70% weight (closer wins); performance contributes 30%.
      final combined=(1/(1+distance))*70+(points/100)*30;
      ranked.add({...x,'distanceKm':distance,'rankingScore':combined});
    }
    ranked.sort((a,b){
      final byScore=(b['rankingScore'] as double).compareTo(a['rankingScore'] as double);
      if(byScore!=0)return byScore;
      final byDistance=(a['distanceKm'] as double).compareTo(b['distanceKm'] as double);
      if(byDistance!=0)return byDistance;
      return (a['uid']??a['id']??'').toString().compareTo((b['uid']??b['id']??'').toString());
    });
    return ranked;
  }

  /// Re-check provider document validity and suspend accepting jobs when expired.
  static Future<bool> refreshProviderEligibility() async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    final ref=db.collection('users').doc(u.uid);final snap=await ref.get();final profile=snap.data()??const <String,dynamic>{};
    final expired=_providerDocumentsExpired(profile)||_accountSuspended(profile);
    if(expired&&profile['providerAvailable']==true) await ref.set({'providerAvailable':false,'providerUpdatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
    return !expired&&profile['providerVerified']==true;
  }

  static Future<void> reauthenticateCurrentUser(String password) async {
    final u=user;final email=u?.email; if(u==null||email==null||password.isEmpty)throw StateError('reauthentication_required');
    final credential=EmailAuthProvider.credential(email:email,password:password);
    await u.reauthenticateWithCredential(credential);
  }

  static Future<void> setAccountSuspension({required String targetUid,required DateTime until,required String reason}) async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    if(!(await hasCapability(Capability.manageUsers)))throw StateError('not_authorized');
    final target=targetUid.trim(),why=reason.trim();if(target.isEmpty||why.length<3||why.length>500||!until.isAfter(DateTime.now())||until.isAfter(DateTime.now().add(const Duration(days:365))))throw ArgumentError('invalid_suspension');
    final ref=db.collection('users').doc(target);final snap=await ref.get();if(!snap.exists||snap.data()?['role']=='owner')throw StateError('protected_user');
    await ref.set({'accountSuspended':true,'suspendedUntil':Timestamp.fromDate(until),'suspensionReason':why,'suspendedBy':u.uid,'updatedAt':FieldValue.serverTimestamp(),if(snap.data()?['providerAvailable']==true)'providerAvailable':false},SetOptions(merge:true));
    await _writeAudit('account_suspended',targetId:target,details:{'until':until.toIso8601String(),'reason':why});
  }

  static Future<void> clearAccountSuspension(String targetUid) async {
    final u=user;if(u==null)throw StateError('not_authenticated');if(!(await hasCapability(Capability.manageUsers)))throw StateError('not_authorized');
    final ref=db.collection('users').doc(targetUid);final snap=await ref.get();if(!snap.exists||snap.data()?['role']=='owner')throw StateError('protected_user');
    await ref.set({'accountSuspended':false,'suspendedUntil':FieldValue.delete(),'suspensionReason':FieldValue.delete(),'suspendedBy':FieldValue.delete(),'updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
    await _writeAudit('account_suspension_cleared',targetId:targetUid);
  }


  static Future<void> sendPasswordReset(String email) async {
    final value=email.trim().toLowerCase();
    if(!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) throw ArgumentError('invalid_email');
    await FirebaseAuth.instance.sendPasswordResetEmail(email:value);
  }

  static Future<void> saveItem({required String type, required String itemId, required String title, String? subtitle, String? imageUrl}) async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    const types={'post','event','service','place'};
    final id=itemId.trim(),name=title.trim();
    if(!types.contains(type)||id.isEmpty||id.contains('/')||id.length>180||name.isEmpty||name.length>180)throw ArgumentError('invalid_saved_item');
    await db.collection('users').doc(u.uid).collection('savedItems').doc('${type}_$id').set({
      'type':type,'itemId':id,'title':name,'subtitle':(subtitle??'').trim().substring(0,((subtitle??'').trim().length>240)?240:(subtitle??'').trim().length),
      if(imageUrl!=null&&imageUrl.startsWith('https://'))'imageUrl':imageUrl,
      'savedAt':FieldValue.serverTimestamp(),
    });
  }

  static Future<void> removeSavedItem(String savedItemId) async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    final cleanId=savedItemId.trim();
    if(cleanId.isEmpty||cleanId.contains('/')||cleanId.length>240)throw ArgumentError('invalid_saved_item_id');
    await db.collection('users').doc(u.uid).collection('savedItems').doc(cleanId).delete();
  }

  static Stream<QuerySnapshot<Map<String,dynamic>>> savedItems() {
    final u=user;if(u==null)throw StateError('not_authenticated');
    return db.collection('users').doc(u.uid).collection('savedItems').orderBy('savedAt',descending:true).limit(100).snapshots();
  }

  static Future<void> updateNotificationPreferences({required bool rides, required bool social, required bool events, required bool pricing, bool quietHoursEnabled=false, String quietStart='22:00', String quietEnd='08:00'}) async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    bool validTime(String value)=>RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$').hasMatch(value);
    if(!validTime(quietStart)||!validTime(quietEnd)||quietStart==quietEnd)throw ArgumentError('invalid_quiet_hours');
    await db.collection('users').doc(u.uid).set({'notificationPreferences':{'rides':rides,'social':social,'events':events,'pricing':pricing,'quietHoursEnabled':quietHoursEnabled,'quietStart':quietStart,'quietEnd':quietEnd},'updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
  }

  /// Creates a cancellable account deletion request with a 30-day grace period.
  /// A trusted backend job must perform final deletion at scheduledFor; the app
  /// deliberately does not delete Auth/Firestore data piecemeal on-device.
  static Future<void> requestAccountDeletion() async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    final userDoc=await db.collection('users').doc(u.uid).get();
    if(userDoc.data()?['role']=='owner')throw StateError('owner_account_protected');
    final ref=db.collection('accountDeletionRequests').doc(u.uid);
    final existing=await ref.get();
    if(existing.exists&&existing.data()?['status']=='pending')throw StateError('deletion_already_pending');
    final now=DateTime.now();
    await ref.set({'userId':u.uid,'email':u.email,'status':'pending','requestedAt':FieldValue.serverTimestamp(),'scheduledFor':Timestamp.fromDate(now.add(const Duration(days:30))),'policyVersion':'2026-10-v1'});
    await _writeAudit('account_deletion_requested',targetId:u.uid,details:{'scheduledFor':now.add(const Duration(days:30)).toIso8601String()});
  }

  static Future<void> cancelAccountDeletionRequest() async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    final ref=db.collection('accountDeletionRequests').doc(u.uid);final snap=await ref.get();
    if(!snap.exists||snap.data()?['status']!='pending')throw StateError('no_pending_deletion');
    final scheduled=snap.data()?['scheduledFor'];
    if(scheduled is Timestamp&&!scheduled.toDate().isAfter(DateTime.now()))throw StateError('deletion_grace_period_ended');
    await ref.update({'status':'cancelled','cancelledAt':FieldValue.serverTimestamp()});
    await _writeAudit('account_deletion_cancelled',targetId:u.uid);
  }

  static Future<void> _writeAudit(String action,{String? targetId,Map<String,Object?> details=const {}}) async {
    final u=user;if(u==null)return;
    try {
      await db.collection('auditLogs').add({'actorId':u.uid,'action':action,'targetId':targetId,'details':details,'createdAt':FieldValue.serverTimestamp()});
    } catch(e) { debugPrint('LEF_LEF audit write failed (non-blocking): $e'); }
  }

  /// A bounded, transparent driver score. Ratings and ride records are sourced
  /// from completed work only; pending/cancelled work never counts as success.
  static Future<Map<String,dynamic>> driverPerformanceSummary(String providerId) async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    if(providerId!=u.uid && !(await hasCapability(Capability.viewDashboard)))throw StateError('not_authorized');
    // Use a bounded history window, but never count a rating unless it belongs
    // to a completed ride by this provider. This avoids inflated points from
    // stale, duplicate, or unrelated rating documents.
    final ridesQuery=await db.collection('rides').where('providerId',isEqualTo:providerId).limit(300).get();
    final completedRideIds=ridesQuery.docs.where((d)=>d.data()['status']=='completed').map((d)=>d.id).toSet();
    final completed=completedRideIds.length;
    final cancelled=ridesQuery.docs.where((d)=>d.data()['status']=='cancelled').length;
    final ratingQuery=await db.collection('rideRatings').where('targetId',isEqualTo:providerId).limit(300).get();
    final scores=ratingQuery.docs.map((d)=>d.data()).where((r)=>completedRideIds.contains(r['rideId']?.toString())).map((r)=>r['score']).whereType<num>().map((v)=>v.toDouble()).where((v)=>v.isFinite&&v>=1&&v<=5).toList();
    final rated=scores.isEmpty?0.0:scores.reduce((a,b)=>a+b)/scores.length;
    final eligible=completed+cancelled;
    final completion=eligible==0?0.0:completed/eligible;
    // 50% rating, 30% completion rate, 20% completed experience (capped at 20 rides).
    // A new provider gets only a neutral rating baseline, not fake completed rides.
    final ratingPoints=scores.isEmpty?25.0:(rated/5)*50;
    final experiencePoints=(completed/20).clamp(0.0,1.0)*20;
    final score=ratingPoints+(completion*30)+experiencePoints;
    return {'score':score.clamp(0.0,100.0).roundToDouble(),'averageRating':rated,'ratingCount':scores.length,'completedRides':completed,'cancelledRides':cancelled,'completionRate':completion,'experiencePoints':experiencePoints,'ratingPoints':ratingPoints};
  }

  /// Aggregates only busy pickup cells; individual trip coordinates are never
  /// returned. A cell needs at least five recent requests before it is exposed.
  static Future<List<Map<String,dynamic>>> peakDemandZones({Duration lookback=const Duration(hours:6)}) async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    if(!(await hasCapability(Capability.manageRides)))throw StateError('manage_rides_required');
    // Bound the caller-controlled window to avoid unbounded historical scans.
    final safeLookback=Duration(seconds:lookback.inSeconds.clamp(15*60,24*60*60).toInt());
    final profile=(await db.collection('users').doc(u.uid).get()).data()??const <String,dynamic>{};
    final role=profile['role']?.toString()??'client';
    const allKinds=['taxiMoto','carExpress','deliveryMoto','deliveryVan','deliveryTruck','sos','ambulance','randonnee'];
    final kinds=switch(role){'driver'=>const ['taxiMoto','carExpress','sos','ambulance','randonnee'],'deliveryProvider'=>const ['deliveryMoto','deliveryVan','deliveryTruck'],'partner'=>allKinds,_=>allKinds};
    if(!{'owner','manager'}.contains(role)&&(profile['providerVerified']!=true||profile['providerAvailable']!=true))throw StateError('verified_available_provider_required');
    final snap=await db.collection('rides').where('status',isEqualTo:'searching').where('kind',whereIn:kinds).limit(250).get();
    final cutoff=DateTime.now().subtract(safeLookback);final cells=<String,Map<String,dynamic>>{};
    for(final doc in snap.docs){final x=doc.data();final created=x['createdAt'];if(created is! Timestamp||created.toDate().isBefore(cutoff))continue;final lat=(x['pickupLat'] as num?)?.toDouble(),lng=(x['pickupLng'] as num?)?.toDouble();if(lat==null||lng==null||!lat.isFinite||!lng.isFinite||lat.abs()>90||lng.abs()>180)continue;final a=(lat*50).round()/50,b=(lng*50).round()/50;final key='$a,$b';final cell=cells.putIfAbsent(key,()=>{'latitude':a,'longitude':b,'requestCount':0,'lastRequestAt':created});cell['requestCount']=(cell['requestCount'] as int)+1;if(created.compareTo(cell['lastRequestAt'] as Timestamp)>0)cell['lastRequestAt']=created;}
    final result=cells.values.where((x)=>(x['requestCount'] as int)>=5).toList()..sort((a,b)=>(b['requestCount'] as int).compareTo(a['requestCount'] as int));
    return result.take(20).toList();
  }

  static Future<void> submitComplaint({required String category,required String subject,required String details,String? rideId}) async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    final cleanCategory=category.trim(),cleanSubject=subject.trim(),cleanDetails=details.trim();
    if(cleanCategory.isEmpty||cleanCategory.length>80||cleanSubject.length<4||cleanSubject.length>140||cleanDetails.length<4||cleanDetails.length>1500)throw ArgumentError('invalid_complaint');
    if(rideId!=null){final ride=await db.collection('rides').doc(rideId).get();final x=ride.data();if(x==null||(x['clientId']!=u.uid&&x['providerId']!=u.uid))throw StateError('ride_not_accessible');}
    final ref=db.collection('users').doc(u.uid).collection('complaints').doc();
    await ref.set({'complaintId':ref.id,'userId':u.uid,'category':cleanCategory,'subject':cleanSubject,'details':cleanDetails,'rideId':rideId,'status':'open','priority':'normal','slaDueAt':Timestamp.fromDate(DateTime.now().add(const Duration(hours:48))),'createdAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()});
  }

  static Stream<QuerySnapshot<Map<String,dynamic>>> myComplaints() {
    final u=user;if(u==null)throw StateError('not_authenticated');
    return db.collection('users').doc(u.uid).collection('complaints').orderBy('createdAt',descending:true).limit(100).snapshots();
  }

  static Stream<QuerySnapshot<Map<String,dynamic>>> openComplaints()=>db.collectionGroup('complaints').where('status',whereIn:const ['open','in_review']).limit(100).snapshots();
  static Future<void> resolveComplaint({required String userId,required String complaintId,required String status,String adminReply=''}) async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    if(!(await hasCapability(Capability.moderateContent)))throw StateError('not_authorized');
    if(!{'resolved','dismissed','in_review'}.contains(status))throw ArgumentError('invalid_complaint_status');
    final ref=db.collection('users').doc(userId).collection('complaints').doc(complaintId);final snap=await ref.get();
    if(!snap.exists||!{'open','in_review'}.contains(snap.data()?['status']))throw StateError('complaint_not_open');
    final reply=adminReply.trim();if(reply.length>1000)throw ArgumentError('invalid_admin_reply');
    await ref.update({'status':status,'adminReply':reply,'updatedAt':FieldValue.serverTimestamp(),'resolvedBy':u.uid,if(status!='in_review')'resolvedAt':FieldValue.serverTimestamp()});
    await _writeAudit('complaint_reviewed',targetId:complaintId,details:{'status':status});
    // The complaint stream updates the screen while it is open, but the user
    // may not be looking at Settings when moderation responds. Add an in-app
    // notification (subject to the user's notification preferences).
    final message = reply.isNotEmpty
        ? 'ردّ فريق المتابعة على شكواك: $reply'
        : switch(status){
            'resolved' => 'تمت متابعة الشكوى متاعك وتسكّرت.',
            'dismissed' => 'تسكّرت الشكوى متاعك. افتح تفاصيلها للاطلاع على الحالة.',
            _ => 'الشكوى متاعك دخلت مرحلة المعالجة.',
          };
    await _notifyUser(userId,'complaint_update','تحديث الشكوى',message,targetId:complaintId,action:'complaint_update');
  }

  static Map<String, dynamic> defaultRidePricing() => {
    'baseFares': {'taxiMoto': 2.0, 'carExpress': 4.0, 'deliveryMoto': 2.0, 'deliveryVan': 4.0, 'deliveryTruck': 0.0, 'sos': 0.0, 'ambulance': 0.0, 'randonnee': 0.0},
    'dayRates': {'taxiMoto': 1.0, 'carExpress': 1.0, 'deliveryMoto': 1.0, 'deliveryVan': 1.0, 'deliveryTruck': 0.0, 'sos': 0.0, 'ambulance': 0.0, 'randonnee': 0.0},
    'nightRates': {'taxiMoto': 1.5, 'carExpress': 1.5, 'deliveryMoto': 1.5, 'deliveryVan': 1.5, 'deliveryTruck': 0.0, 'sos': 0.0, 'ambulance': 0.0, 'randonnee': 0.0},
    'negotiableKinds': ['deliveryTruck', 'sos', 'ambulance', 'randonnee'],
  };

  static Future<Map<String, dynamic>> getRidePricing() async {
    final snap = await db.collection('system').doc('pricing').get();
    final defaults = defaultRidePricing();
    final saved = snap.data() ?? const <String, dynamic>{};
    Map<String, dynamic> mergeMap(String key) {
      final result = Map<String, dynamic>.from(defaults[key] as Map);
      final raw = saved[key];
      if (raw is Map) {
        for (final entry in raw.entries) {
          final value = entry.value;
          if (result.containsKey(entry.key.toString()) && value is num && value.isFinite && value >= 0 && value <= 1000) {
            result[entry.key.toString()] = value.toDouble();
          }
        }
      }
      return result;
    }
    final rawNegotiable = saved['negotiableKinds'];
    final validKinds = serviceOptions.map((o) => o.kind.name).toSet();
    final negotiableKinds = rawNegotiable is List
        ? rawNegotiable.whereType<String>().where(validKinds.contains).toSet().toList()
        : List<String>.from(defaults['negotiableKinds'] as List);
    return {'baseFares': mergeMap('baseFares'), 'dayRates': mergeMap('dayRates'), 'nightRates': mergeMap('nightRates'), 'negotiableKinds': negotiableKinds};
  }

  static Future<void> saveRidePricing({required Map<String, double> baseFares, required Map<String, double> dayRates, required Map<String, double> nightRates, required Set<String> negotiableKinds}) async {
    final u = user;
    if (u == null) throw StateError('not_authenticated');
    final profile = await db.collection('users').doc(u.uid).get();
    final role = profile.data()?['role']?.toString();
    final capabilities = (profile.data()?['capabilities'] as List?)?.whereType<String>().toSet() ?? <String>{};
    if (role != 'owner' && !capabilities.contains(Capability.manageServices.name)) throw StateError('manage_services_required');
    const kinds = {'taxiMoto', 'carExpress', 'deliveryMoto', 'deliveryVan', 'deliveryTruck', 'sos', 'ambulance', 'randonnee'};
    bool valid(Map<String, double> values) => values.keys.toSet() == kinds && kinds.every((k) => values[k] != null && values[k]!.isFinite && values[k]! >= 0 && values[k]! <= 1000);
    if (!valid(baseFares) || !valid(dayRates) || !valid(nightRates) || !kinds.containsAll(negotiableKinds)) throw StateError('invalid_pricing');
    final pricingRef=db.collection('system').doc('pricing');
    final historyRef=pricingRef.collection('history').doc();
    await db.runTransaction<void>((tx) async {
      final before=await tx.get(pricingRef);
      final old=before.data()??defaultRidePricing();
      tx.set(historyRef,{'changedBy':u.uid,'changedAt':FieldValue.serverTimestamp(),'previous':old,'next':{'baseFares':baseFares,'dayRates':dayRates,'nightRates':nightRates,'negotiableKinds':negotiableKinds.toList()..sort()}});
      tx.set(pricingRef,{
        'baseFares': baseFares, 'dayRates': dayRates, 'nightRates': nightRates,
        'negotiableKinds': negotiableKinds.toList()..sort(),
        'updatedBy': u.uid, 'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    await _writeAudit('pricing_updated',targetId:historyRef.id,details:{'negotiableKinds':negotiableKinds.length,'historyId':historyRef.id});
    if(await hasCapability(Capability.manageNotifications)){
      // Page through every account; a single limit(200) silently skipped users
      // once the app grew beyond 200 accounts.
      try{
        QueryDocumentSnapshot<Map<String,dynamic>>? cursor;
        while(true){
          var query=db.collection('users').orderBy(FieldPath.documentId).limit(200);
          if(cursor!=null)query=query.startAfterDocument(cursor);
          final users=await query.get();
          if(users.docs.isEmpty)break;
          for(final doc in users.docs){
            if(doc.id==u.uid)continue;
            await _notifyUser(doc.id,'pricing','تحديث الأسعار','تبدّلت أسعار بعض الخدمات. راجع السعر النهائي قبل ما تأكّد أي طلب.');
          }
          cursor=users.docs.last;
          if(users.docs.length<200)break;
        }
      }catch(e){debugPrint('LEF_LEF pricing notification fanout incomplete (non-blocking): $e');}
    }
  }

  static Stream<QuerySnapshot<Map<String,dynamic>>> ridePricingHistory() {
    return db.collection('system').doc('pricing').collection('history').orderBy('changedAt',descending:true).limit(100).snapshots();
  }

  static Future<void> restoreRidePricingVersion(String historyId) async {
    final u=user;if(u==null)throw StateError('not_authenticated');if(!(await hasCapability(Capability.manageServices)))throw StateError('manage_services_required');
    final history=await db.collection('system').doc('pricing').collection('history').doc(historyId).get();final next=history.data()?['previous'];
    if(next is! Map)throw StateError('pricing_history_missing');
    final b=Map<String,dynamic>.from(next['baseFares'] as Map),d=Map<String,dynamic>.from(next['dayRates'] as Map),n=Map<String,dynamic>.from(next['nightRates'] as Map);final k=List<String>.from(next['negotiableKinds'] as List);
    doubleMap(Map<String,dynamic> m)=>m.map((key,value)=>MapEntry(key,(value as num).toDouble()));
    await saveRidePricing(baseFares:doubleMap(b),dayRates:doubleMap(d),nightRates:doubleMap(n),negotiableKinds:k.toSet());
    await _writeAudit('pricing_version_restored',targetId:historyId);
  }

  static Future<String> uploadUserMedia(File file,{required String folder}) async {
    final u=user; if(u==null) throw StateError('not_authenticated');
    if(folder!='posts'&&folder!='stories'&&folder!='profile') throw StateError('invalid_media_folder');
    final ext=file.path.contains('.')?file.path.split('.').last.toLowerCase():'';
    const imageExts={'jpg':'image/jpeg','jpeg':'image/jpeg','png':'image/png','webp':'image/webp','heic':'image/heic','heif':'image/heif'};
    const videoExts={'mp4':'video/mp4','mov':'video/quicktime','m4v':'video/x-m4v','webm':'video/webm'};
    // Profile photos must be actual image uploads; accepting a video here
    // can leave the avatar URL pointing at a file the profile UI cannot render.
    if(folder=='profile'&&!imageExts.containsKey(ext)) throw StateError('profile_image_required');
    final contentType=imageExts[ext]??videoExts[ext];
    if(contentType==null) throw StateError('unsupported_media_type');
    if(!await file.exists()) throw StateError('media_file_missing');
    final length=await file.length();
    final limit=folder=='profile'?10*1024*1024:50*1024*1024;
    if(length<=0||length>=limit) throw StateError('media_size_invalid');
    final ref=storage.ref().child('$folder/${u.uid}/${DateTime.now().microsecondsSinceEpoch}.$ext');
    final task=await ref.putFile(file,SettableMetadata(contentType:contentType));
    return task.ref.getDownloadURL();
  }

  static Future<void> updateProfileVisibility(String visibility) async {
    final u=user;
    if(u==null) throw StateError('not_authenticated');
    if(!{'public','followers','private'}.contains(visibility)) throw ArgumentError('invalid_profile_visibility');
    final ref=db.collection('users').doc(u.uid);
    await ref.set({'profileVisibility':visibility,'updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
    await db.collection('publicProfiles').doc(u.uid).set({'uid':u.uid,'visibility':visibility,'updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
  }

  static Future<void> updateProfile({required String displayName, required String bio, File? avatar, File? cover, String phone = '', String city = '', String interests = ''}) async {
    final u=user;
    if(u==null) throw StateError('not_authenticated');
    final name=displayName.trim();
    final cleanBio=bio.trim();
    if(name.length<2||name.length>80) throw StateError('invalid_display_name');
    if(cleanBio.length>160) throw StateError('invalid_bio');
    final cleanPhone=phone.trim();
    if(cleanPhone.length>32||cleanPhone.contains(RegExp(r'[^0-9+() .-]')))throw StateError('invalid_phone');
    final cleanCity=city.trim();
    final cleanInterests=interests.split(',').map((v)=>v.trim()).where((v)=>v.isNotEmpty).take(12).join(', ');
    if(cleanCity.length>100||cleanInterests.length>500)throw StateError('profile_details_too_long');
    final currentProfile=await db.collection('users').doc(u.uid).get();
    final visibility=(currentProfile.data()?['profileVisibility']?.toString()??'public');
    if(!{'public','followers','private'}.contains(visibility))throw StateError('invalid_profile_visibility');
    String? photoUrl,coverUrl;
    if(avatar!=null) photoUrl=await uploadUserMedia(avatar,folder:'profile');
    if(cover!=null) coverUrl=await uploadUserMedia(cover,folder:'profile');
    await u.updateDisplayName(name);
    if(photoUrl!=null) await u.updatePhotoURL(photoUrl);
    await db.collection('users').doc(u.uid).set({
      'displayName':name,
      'displayNameLower':name.toLowerCase(),
      'bio':cleanBio,
      'phone':cleanPhone,
      'city':cleanCity,
      'interests':cleanInterests,
      'profileVisibility':visibility,
      if(photoUrl!=null) 'photoUrl':photoUrl,
      if(coverUrl!=null) 'coverUrl':coverUrl,
      'updatedAt':FieldValue.serverTimestamp(),
    },SetOptions(merge:true));
    try {
      await db.collection('publicProfiles').doc(u.uid).set({
        'uid':u.uid,
        'displayName':name,
        'displayNameLower':name.toLowerCase(),
        'bio':cleanBio,
        'city':cleanCity,
        'interests':cleanInterests,
        'visibility':visibility,
        if(photoUrl!=null) 'photoUrl':photoUrl,
        if(coverUrl!=null) 'coverUrl':coverUrl,
        'updatedAt':FieldValue.serverTimestamp(),
      },SetOptions(merge:true));
    } on FirebaseException catch(e,st) {
      debugPrint('LEF_LEF public profile update failed: code=${e.code} message=${e.message}');
      debugPrintStack(stackTrace:st);
    }
  }

  static Future<void> ensureProfile(User u,{String? name}) async {
    final ref=db.collection('users').doc(u.uid);
    final bootstrap=db.collection('system').doc('bootstrap');

    try {
      final existing=await ref.get();
      if(existing.exists){
        final data=existing.data()??const <String,dynamic>{};
        if(data['role']=='owner'){
          try {
            final bootstrapSnap=await bootstrap.get();
            if(!bootstrapSnap.exists){
              await bootstrap.set({'ownerUid':u.uid,'createdAt':FieldValue.serverTimestamp()});
            }
          } on FirebaseException catch(e,st) {
            debugPrint('LEF_LEF bootstrap repair failed: code=${e.code} message=${e.message} plugin=${e.plugin}');
            debugPrintStack(stackTrace:st);
          }
        }
        if(data['capabilities']==null){
          final roleName=data['role']?.toString()??'client';
          final role=AppRole.values.firstWhere((r)=>r.name==roleName,orElse:()=>AppRole.client);
          try {
            // Keep the update inside the fields allowed to self-repair by rules.
            await ref.set({'capabilities':capabilityNames(defaultCapabilitiesForRole(role)),'updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
          } on FirebaseException catch(e,st) {
            debugPrint('LEF_LEF capabilities repair failed: code=${e.code} message=${e.message} plugin=${e.plugin}');
            debugPrintStack(stackTrace:st);
          }
        }
        await _writePublicProfile(u.uid,data);
        return;
      }

      debugPrint('LEF_LEF ensureProfile: creating users/${u.uid}');
      await db.runTransaction((tx) async {
        final userSnap=await tx.get(ref);
        if(userSnap.exists)return;
        final bs=await tx.get(bootstrap);
        final first=!bs.exists;
        final role=first?AppRole.owner:AppRole.client;
        final displayName=name?.trim().isNotEmpty==true?name!.trim():'مستخدم LEF_LEF';
        debugPrint('LEF_LEF profile transaction: bootstrapExists=${bs.exists} role=${role.name} uid=${u.uid}');
        if(first){
          tx.set(bootstrap,{'ownerUid':u.uid,'createdAt':FieldValue.serverTimestamp()});
        }
        tx.set(ref,{
          'uid':u.uid,'email':u.email,'displayName':displayName,'displayNameLower':displayName.toLowerCase(),
          'role':role.name,'roleSelected':true,'capabilities':capabilityNames(defaultCapabilitiesForRole(role)),
          'createdAt':FieldValue.serverTimestamp(),'notificationsEnabled':true,'privacyPersonalization':true,'profileVisibility':'public','city':'','interests':'',
        });
      });

      final created=await ref.get();
      if(!created.exists) throw StateError('profile_document_missing_after_transaction');
      final data=created.data()??const <String,dynamic>{};
      debugPrint('LEF_LEF ensureProfile: users/${u.uid} exists role=${data['role']}');
      await _writePublicProfile(u.uid,data);
    } on FirebaseException catch(e,st) {
      debugPrint('LEF_LEF ensureProfile FAILED: code=${e.code} message=${e.message} plugin=${e.plugin}');
      debugPrintStack(stackTrace:st);
      rethrow;
    } catch(e,st) {
      debugPrint('LEF_LEF ensureProfile FAILED: $e');
      debugPrintStack(stackTrace:st);
      rethrow;
    }
  }

  static Future<void> _writePublicProfile(String uid,Map<String,dynamic> data) async {
    final display=data['displayName']?.toString().trim().isNotEmpty==true?data['displayName'].toString().trim():'مستخدم LEF_LEF';
    try {
      await db.collection('publicProfiles').doc(uid).set({
        'uid':uid,'displayName':display,'displayNameLower':display.toLowerCase(),
        'role':data['role']?.toString()??'client',
        'visibility':data['profileVisibility']?.toString()??'public',
        if(data['city']!=null&&data['city'].toString().isNotEmpty) 'city':data['city'].toString(),
        if(data['interests']!=null&&data['interests'].toString().isNotEmpty) 'interests':data['interests'].toString(),
        if(data['bio']!=null) 'bio':data['bio'].toString(),
        if(data['photoUrl']!=null) 'photoUrl':data['photoUrl'].toString(),
        'updatedAt':FieldValue.serverTimestamp(),
      },SetOptions(merge:true));
    } on FirebaseException catch(e,st) {
      debugPrint('LEF_LEF publicProfiles write failed (non-blocking): code=${e.code} message=${e.message} plugin=${e.plugin}');
      debugPrintStack(stackTrace:st);
    }
  }

  static Future<Set<Capability>> currentCapabilities() async {
    final u=user; if(u==null)return <Capability>{};
    final snap=await db.collection('users').doc(u.uid).get();
    final data=snap.data()??const <String,dynamic>{};
    if(data['role']=='owner')return Capability.values.toSet();
    if(data['role']=='manager')return {Capability.manageRides};
    final raw=List<String>.from(data['capabilities']??const []);
    return raw.map((name){for(final c in Capability.values){if(c.name==name)return c;}return null;}).whereType<Capability>().toSet();
  }

  static Future<bool> hasCapability(Capability capability) async {
    final caps=await currentCapabilities();
    return caps.contains(capability);
  }

  static Future<void> setRole(AppRole role) async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    if(role!=AppRole.client)throw StateError('role_request_required');
    final ref=db.collection('users').doc(u.uid);
    final snap=await ref.get();
    final current=snap.data()?['role']?.toString();
    if(current!=null&&current!='client')throw StateError('protected_role');
    await ref.set({'role':'client','roleSelected':true,'capabilities':capabilityNames(defaultCapabilitiesForRole(AppRole.client)),'updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
    final display=snap.data()?['displayName']?.toString()??'مستخدم LEF_LEF';
    await db.collection('publicProfiles').doc(u.uid).set({'uid':u.uid,'displayName':display,'displayNameLower':display.toLowerCase(),'role':'client','visibility':snap.data()?['profileVisibility']?.toString()??'public','updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
  }

  static Future<void> updateUserRole(String uid,AppRole role) async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    if(!(await hasCapability(Capability.manageUsers)))throw StateError('not_authorized');
    if(role==AppRole.owner)throw StateError('owner_only_bootstrap');
    if(role!=AppRole.client && !(await hasCapability(Capability.manageRoles)))throw StateError('not_authorized');
    final target=await db.collection('users').doc(uid).get();
    if(!target.exists)throw StateError('user_not_found');
    if(target.data()?['role']=='owner')throw StateError('protected_role');
    final nextCaps=capabilityNames(defaultCapabilitiesForRole(role));
    await db.collection('users').doc(uid).update({'role':role.name,'roleSelected':true,'capabilities':nextCaps,'updatedAt':FieldValue.serverTimestamp()});
    await db.collection('publicProfiles').doc(uid).set({'uid':uid,'role':role.name,'visibility':target.data()?['profileVisibility']?.toString()??'public','updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
    await _writeAudit('user_role_updated',targetId:uid,details:{'role':role.name});
  }

  static Future<void> setUserCapabilities(String uid,Set<Capability> capabilities) async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    if(!(await hasCapability(Capability.manageRoles)))throw StateError('not_authorized');
    final meCaps=await currentCapabilities();
    final isOwner=(await db.collection('users').doc(user!.uid).get()).data()?['role']=='owner';
    if(!isOwner&&!capabilities.every(meCaps.contains))throw StateError('not_authorized');
    final target=await db.collection('users').doc(uid).get();
    if(!target.exists)throw StateError('user_not_found');
    if(target.data()?['role']=='owner')throw StateError('protected_role');
    await db.collection('users').doc(uid).update({'capabilities':capabilityNames(capabilities),'updatedAt':FieldValue.serverTimestamp()});
    await _writeAudit('user_capabilities_updated',targetId:uid,details:{'capabilityCount':capabilities.length});
  }

  static Future<String> createRide({required ServiceKind kind,required String pickup,required String destination,required double estimatedFare,required double distanceKm,required double baseFare,required double ratePerKm,required String pricingPeriod,required double pickupLat,required double pickupLng,required double destinationLat,required double destinationLng,String deliveryRecipientName='',String deliveryRecipientPhone='',String parcelCategory='',String parcelNotes=''}) async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    final requesterProfile=(await db.collection('users').doc(u.uid).get()).data()??const <String,dynamic>{};if(_accountSuspended(requesterProfile))throw StateError('account_suspended');
    if(!estimatedFare.isFinite||estimatedFare<0||!distanceKm.isFinite||distanceKm<0||!baseFare.isFinite||baseFare<0||!ratePerKm.isFinite||ratePerKm<0||!['day','night'].contains(pricingPeriod))throw StateError('invalid_pricing');
    if(!pickupLat.isFinite||pickupLat<-90||pickupLat>90||!pickupLng.isFinite||pickupLng<-180||pickupLng>180||!destinationLat.isFinite||destinationLat<-90||destinationLat>90||!destinationLng.isFinite||destinationLng<-180||destinationLng>180)throw StateError('invalid_coordinates');
    final option=serviceOptions.firstWhere((e)=>e.kind==kind);
    final isDelivery={ServiceKind.deliveryMoto,ServiceKind.deliveryVan,ServiceKind.deliveryTruck}.contains(kind);
    final recipientName=deliveryRecipientName.trim();
    final recipientPhone=deliveryRecipientPhone.trim();
    final category=parcelCategory.trim();
    final notes=parcelNotes.trim();
    if(isDelivery&&(recipientName.length<2||recipientName.length>120||recipientPhone.length<8||recipientPhone.length>24||category.isEmpty||category.length>80||notes.length>500))throw StateError('delivery_details_incomplete');
    final pricing = await getRidePricing();
    final negotiableKinds = Set<String>.from(pricing['negotiableKinds'] as List);
    final isNegotiable=negotiableKinds.contains(kind.name);
    final baseFares = Map<String, dynamic>.from(pricing['baseFares'] as Map);
    final dayRates = Map<String, dynamic>.from(pricing['dayRates'] as Map);
    final nightRates = Map<String, dynamic>.from(pricing['nightRates'] as Map);
    final configuredBase = (baseFares[kind.name] as num?)?.toDouble() ?? option.base;
    final configuredRate = ((pricingPeriod == 'night' ? nightRates : dayRates)[kind.name] as num?)?.toDouble() ?? (pricingPeriod == 'night' ? option.nightKm : option.dayKm);
    if(pickup.trim().isEmpty||destination.trim().isEmpty||distanceKm<=0)throw StateError('missing_route');
    if((pickupLat==0&&pickupLng==0)||(destinationLat==0&&destinationLng==0))throw StateError('missing_route_coordinates');
    if(isNegotiable){
      if(estimatedFare!=0||baseFare!=0||ratePerKm!=0)throw StateError('negotiable_pricing_mismatch');
    }else{
      final expected=configuredBase+distanceKm*configuredRate;
      if((estimatedFare-expected).abs()>0.01)throw StateError('pricing_mismatch');
      if((baseFare-configuredBase).abs()>0.01||(ratePerKm-configuredRate).abs()>0.01)throw StateError('service_pricing_mismatch');
    }
    final ref=db.collection('rides').doc();
    final rideData = {'id':ref.id,'clientId':u.uid,'kind':kind.name,'pickup':pickup,'destination':destination,'pickupLat':pickupLat,'pickupLng':pickupLng,'destinationLat':destinationLat,'destinationLng':destinationLng,'providerId':null,'distanceKm':distanceKm,'baseFare':isNegotiable?0:baseFare,'ratePerKm':isNegotiable?0:ratePerKm,'pricingPeriod':pricingPeriod,'estimatedFare':isNegotiable?0:estimatedFare,'negotiable':isNegotiable,'status':'searching','priority':kind==ServiceKind.sos?'emergency':kind==ServiceKind.ambulance?'medical':'normal',if(isDelivery)'delivery':{'recipientName':recipientName,'recipientPhone':recipientPhone,'parcelCategory':category,'parcelNotes':notes,'deliveryStatus':'requested'},'createdAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()};
    // Prevent duplicate active rides from double taps or multiple devices.
    final active = await db.collection('rides').where('clientId', isEqualTo: u.uid).where('status', whereIn: const ['searching','offered','countered','accepted','arriving','arrived','active']).limit(1).get();
    if (active.docs.isNotEmpty) throw StateError('active_ride_already_exists');
    await db.runTransaction<void>((tx) async { tx.set(ref, rideData); });
    final bootstrap = await db.collection('system').doc('bootstrap').get();
    final ownerUid = bootstrap.data()?['ownerUid']?.toString();
    if (ownerUid != null && ownerUid != u.uid) {
      try {
        await db.collection('users').doc(ownerUid).collection('notifications').add({
          'type':'ride','rideId':ref.id,'recipientId':ownerUid,'status':'searching',
          'requesterId':u.uid,'title':'طلب خدمة جديد','message':'جا طلب ${serviceLabel(kind)} جديد.',
          'createdAt':FieldValue.serverTimestamp(),'read':false,
        });
      } on FirebaseException catch(e) {
        debugPrint('LEF_LEF ride notification failed (non-blocking): code=${e.code} message=${e.message}');
      } catch(e) {
        debugPrint('LEF_LEF ride notification failed (non-blocking): $e');
      }
    }
    return ref.id;
  }
  static Future<DocumentSnapshot<Map<String,dynamic>>?> activeRideForClient() async {
    final u=user;
    if(u==null)return null;
    const active=['searching','offered','countered','accepted','arriving','arrived','active'];
    DocumentSnapshot<Map<String,dynamic>>? best;
    DateTime? bestTime;
    for(final status in active){
      final q=await db.collection('rides').where('clientId',isEqualTo:u.uid).where('status',isEqualTo:status).limit(20).get();
      for(final d in q.docs){
        final x=d.data();
        final raw=x['updatedAt'] is Timestamp ? x['updatedAt'] as Timestamp : (x['createdAt'] is Timestamp ? x['createdAt'] as Timestamp : null);
        final t=raw?.toDate();
        if(best==null || (t!=null && (bestTime==null || t.isAfter(bestTime!)))){best=d;bestTime=t;}
      }
    }
    return best;
  }

  static Future<void> sendRideMapMessage(String id, String message, {required double latitude, required double longitude}) async {
    final u=user;
    if(u==null) throw StateError('not_authenticated');
    final text=message.trim();
    if(text.isEmpty || text.length>180) throw ArgumentError('invalid_message');
    if(!latitude.isFinite || latitude < -90 || latitude > 90 || !longitude.isFinite || longitude < -180 || longitude > 180) throw ArgumentError('invalid_coordinates');
    final ref=db.collection('rides').doc(id);
    final snap=await ref.get(); final x=snap.data();
    const active={'accepted','arriving','arrived','active'};
    if(x==null || !(x['clientId']==u.uid || x['providerId']==u.uid) || !active.contains(x['status']?.toString())) throw StateError('not_authorized');
    await ref.update({'mapMessage':text,'mapMessageBy':u.uid,'mapMessageLat':latitude,'mapMessageLng':longitude,'mapMessageAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()});
  }

  static Stream<DocumentSnapshot<Map<String,dynamic>>> rideStream(String id)=>db.collection('rides').doc(id).snapshots();
  static Future<void> updateRide(String id,String status) async {
    final u=user;
    if(u==null) throw StateError('not_authenticated');
    const transitions=<String,Set<String>>{
      'accepted':{'arriving'},
      'arriving':{'arrived'},
      'arrived':{'active'},
      'active':{'completed'},
    };
    if(!transitions.values.any((states)=>states.contains(status))) {
      throw StateError('invalid_transition');
    }
    final ref=db.collection('rides').doc(id);
    String? clientId;
    // Validate and update in one transaction. A read-then-update sequence can
    // otherwise let two rapid taps overwrite a newer ride state.
    await db.runTransaction<void>((tx) async {
      final snap=await tx.get(ref);
      final data=snap.data();
      final current=data?['status']?.toString();
      if(data==null || data['providerId']?.toString()!=u.uid ||
          !(transitions[current]??const <String>{}).contains(status)) {
        throw StateError('not_authorized_or_stale_status');
      }
      // The driver cannot start the trip until the customer confirms the
      // pickup arrival in the customer app. This is rechecked atomically.
      if(status=='active' && data['clientArrivalConfirmed']!=true) {
        throw StateError('client_arrival_confirmation_required');
      }
      clientId=data['clientId']?.toString();
      final isDelivery={'deliveryMoto','deliveryVan','deliveryTruck'}.contains(data['kind']?.toString());
      final delivery=data['delivery'] is Map
          ? Map<String,dynamic>.from(data['delivery'] as Map)
          : <String,dynamic>{};
      final deliveryStage=switch(status){
        'arriving'=>'going_to_pickup',
        'arrived'=>'at_pickup',
        'active'=>'in_transit',
        'completed'=>'delivered',
        _=>null,
      };
      // When fresh GPS is available, reject an accidental completion far from
      // the destination. GPS is evidence, not a hard requirement when the
      // device cannot provide a recent fix; completion never requires a rating.
      Map<String,dynamic> completionEvidence=<String,dynamic>{};
      if(status=='completed') {
        final lat=(data['providerLat'] as num?)?.toDouble();
        final lng=(data['providerLng'] as num?)?.toDouble();
        final dlat=(data['destinationLat'] as num?)?.toDouble();
        final dlng=(data['destinationLng'] as num?)?.toDouble();
        final updated=data['locationUpdatedAt'];
        final fresh=updated is Timestamp && DateTime.now().difference(updated.toDate()).inMinutes<=10 && !updated.toDate().isAfter(DateTime.now().add(const Duration(minutes:1)));
        if(fresh && lat!=null && lng!=null && dlat!=null && dlng!=null) {
          const earthRadius=6371.0;
          final p1=lat*math.pi/180, p2=dlat*math.pi/180;
          final dp=(dlat-lat)*math.pi/180, dl=(dlng-lng)*math.pi/180;
          final a=math.pow(math.sin(dp/2),2)+math.cos(p1)*math.cos(p2)*math.pow(math.sin(dl/2),2);
          final distance=earthRadius*2*math.atan2(math.sqrt(a),math.sqrt(math.max(0,1-a)));
          if(distance>1.0) throw StateError('completion_too_far_from_destination');
          completionEvidence={'completionLatitude':lat,'completionLongitude':lng,'completionDistanceKm':distance,'completionGpsAt':updated};
        }
      }
      tx.update(ref,{
        'status':status,
        ...completionEvidence,
        if(isDelivery && deliveryStage!=null) 'delivery':{...delivery,'deliveryStatus':deliveryStage},
        'updatedAt':FieldValue.serverTimestamp(),
      });
    });
    if(clientId!=null) {
      await _notify(clientId!,id,status,'خدمة LEF_LEF',<String,String>{
        'arriving':'السائق في الثنية.',
        'arrived':'السائق وصل.',
        'active':'المشوار بدا.',
        'completed':'المشوار كمل.',
      }[status]??'تحدّثت حالة المشوار.');
    }
  }
  /// Customer-side confirmation that the assigned provider is physically at pickup.
  /// The transaction prevents stale confirmations after a ride changes state.
  static Future<void> confirmClientArrival(String rideId) async {
    final u=user;
    if(u==null) throw StateError('not_authenticated');
    final ref=db.collection('rides').doc(rideId);
    await db.runTransaction<void>((tx) async {
      final snap=await tx.get(ref);
      final data=snap.data();
      if(data==null || data['clientId']!=u.uid || data['status']!='arrived') {
        throw StateError('ride_not_waiting_for_arrival_confirmation');
      }
      if(data['clientArrivalConfirmed']==true) return;
      tx.update(ref,{
        'clientArrivalConfirmed':true,
        'clientArrivalConfirmedAt':FieldValue.serverTimestamp(),
        'updatedAt':FieldValue.serverTimestamp(),
      });
    });
    final ride=(await ref.get()).data();
    final providerId=ride?['providerId']?.toString();
    if(providerId!=null && providerId.isNotEmpty) {
      await _notify(providerId,rideId,'arrival_confirmed','تأكيد الوصول','الحريف أكد وصولك لنقطة الانطلاق.');
    }
  }

  static Future<bool> cancelRide(String id,{String reason='customer_cancelled'}) async {
    final u=user; if(u==null)return false;
    final ref=db.collection('rides').doc(id);
    final ok=await db.runTransaction<bool>((tx) async {
      final s=await tx.get(ref); final x=s.data();
      final current=x?['status']?.toString();
      const cancellable={'searching','offered','countered','accepted','arriving','arrived'};
      final why=reason.trim();if(x==null||x['clientId']!=u.uid||!cancellable.contains(current)||why.isEmpty||why.length>300)return false;
      tx.update(ref,{'status':'cancelled','cancellationReason':why,'cancelledBy':u.uid,'cancelledFromStatus':current,'updatedAt':FieldValue.serverTimestamp()}); return true;
    });
    if(ok){
      final x=(await ref.get()).data();final providerId=x?['providerId']?.toString();if(providerId!=null)await _notify(providerId,id,'cancelled','الخدمة تلغات','الحريف لغى الطلب هذا.');
      // Cancellation history is separate from the ride so repeated customer cancellations
      // can be reviewed without allowing the customer to edit their own counters.
      try {
        await db.collection('customerCancellationEvents').add({'clientId':u.uid,'rideId':id,'reason':reason.trim(),'fromStatus':x?['cancelledFromStatus'],'createdAt':FieldValue.serverTimestamp(),'reviewStatus':'pending'});
        final since=Timestamp.fromDate(DateTime.now().subtract(const Duration(days:7)));
        final recent=await db.collection('customerCancellationEvents').where('clientId',isEqualTo:u.uid).where('createdAt',isGreaterThanOrEqualTo:since).get();
        if(recent.docs.length>=3){
          final bootstrap=await db.collection('system').doc('bootstrap').get();
          final ownerUid=bootstrap.data()?['ownerUid']?.toString();
          if(ownerUid!=null&&ownerUid!=u.uid) await _notifyUser(ownerUid,'customer_cancellation_review','مراجعة إلغاءات حريف','حريف عنده 3 إلغاءات أو أكثر في 7 أيام؛ راجع السجل قبل أي إجراء.',targetId:u.uid,action:'customer_cancellation_review');
        }
      } catch(e) { debugPrint('LEF_LEF customer cancellation review logging failed (non-blocking): $e'); }
    }
    return ok;
  }

  static Future<bool> cancelRideAsProvider(String id,{String reason='provider_unavailable'}) async {
    final u=user;if(u==null)return false;
    final ref=db.collection('rides').doc(id);
    final ok=await db.runTransaction<bool>((tx) async {
      final s=await tx.get(ref);final x=s.data();final current=x?['status']?.toString();
      const cancellable={'accepted','arriving','arrived'};
      final why=reason.trim();if(x==null||x['providerId']!=u.uid||!cancellable.contains(current)||why.isEmpty||why.length>300)return false;
      tx.update(ref,{'status':'cancelled','cancellationReason':why,'cancelledBy':u.uid,'cancelledFromStatus':current,'updatedAt':FieldValue.serverTimestamp()});return true;
    });
    if(ok){
      final x=(await ref.get()).data();
      final clientId=x?['clientId']?.toString();
      if(clientId!=null)await _notify(clientId,id,'cancelled','الخدمة تلغات','السائق لغى الطلب هذا.');
      // Append-only cancellation event gives Owner a durable review trail;
      // the original ride also keeps cancelledBy/reason/from-status.
      try {
        await db.collection('providerCancellationEvents').add({
          'providerId':u.uid,'rideId':id,'clientId':clientId,
          'reason':reason.trim(),'fromStatus':x?['cancelledFromStatus'],
          'createdAt':FieldValue.serverTimestamp(),'reviewStatus':'pending',
        });
        final since=Timestamp.fromDate(DateTime.now().subtract(const Duration(days:7)));
        final recent=await db.collection('providerCancellationEvents').where('providerId',isEqualTo:u.uid).where('createdAt',isGreaterThanOrEqualTo:since).get();
        final bootstrap=await db.collection('system').doc('bootstrap').get();
        final ownerUid=bootstrap.data()?['ownerUid']?.toString();
        if(recent.docs.length>=2) {
          // Disable new offers after repeated cancellations; only Owner can reinstate.
          await db.collection('users').doc(u.uid).set({'providerAvailable':false,'providerUpdatedAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
        }
        if(ownerUid!=null && ownerUid!=u.uid) {
          await _notifyUser(ownerUid,'provider_cancellation_review','مراجعة إلغاء سائق',recent.docs.length>=2?'سائق ألغى رحلتين أو أكثر في 7 أيام؛ توقّف استقباله لطلبات جديدة ويلزم قرار Owner.':'سائق ألغى رحلة؛ يلزم مراجعة السبب والسجل.',targetId:id,action:'provider_cancellation_review');
        }
      } catch(e) { debugPrint('LEF_LEF cancellation review event failed (non-blocking): $e'); }
    }
    return ok;
  }

  /// Propose a destination change. The other trip participant must approve it;
  /// the current destination remains unchanged until approval succeeds.
  static Future<String> proposeRideDestinationChange({required String rideId, required String destination, required double destinationLat, required double destinationLng, required double distanceKm}) async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    final name=destination.trim();
    if(name.isEmpty||name.length>240||!destinationLat.isFinite||destinationLat < -90||destinationLat>90||!destinationLng.isFinite||destinationLng < -180||destinationLng>180||!distanceKm.isFinite||distanceKm<=0)throw StateError('invalid_destination_change');
    final rideRef=db.collection('rides').doc(rideId);final snap=await rideRef.get();final x=snap.data();
    if(x==null||!['accepted','arriving','arrived','active'].contains(x['status']))throw StateError('ride_not_changeable');
    final clientId=x['clientId']?.toString()??'';final providerId=x['providerId']?.toString()??'';
    if(u.uid!=clientId&&u.uid!=providerId)throw StateError('not_authorized');
    final approver=u.uid==clientId?providerId:clientId;if(approver.isEmpty)throw StateError('missing_other_party');
    final kind=x['kind']?.toString()??'';final negotiable=x['negotiable']==true;
    final period=DateTime.now().hour>=22||DateTime.now().hour<6?'night':'day';
    final pricing=await getRidePricing();
    final base=(Map<String,dynamic>.from(pricing['baseFares'] as Map)[kind] as num?)?.toDouble()??0;
    final rates=Map<String,dynamic>.from((period=='night'?pricing['nightRates']:pricing['dayRates']) as Map);
    final rate=(rates[kind] as num?)?.toDouble()??0;
    final fare=negotiable?0.0:base+distanceKm*rate;
    final changeRef=db.collection('rideDestinationChanges').doc();
    await changeRef.set({'id':changeRef.id,'rideId':rideId,'clientId':clientId,'providerId':providerId,'proposedBy':u.uid,'approverId':approver,'status':'pending','oldDestination':x['destination'],'oldDistanceKm':x['distanceKm'],'oldFare':x['finalFare']??x['estimatedFare']??0,'destination':name,'destinationLat':destinationLat,'destinationLng':destinationLng,'distanceKm':distanceKm,'pricingPeriod':period,'baseFare':negotiable?0:base,'ratePerKm':negotiable?0:rate,'estimatedFare':fare,'negotiable':negotiable,'createdAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()});
    await _notifyUser(approver,'destination_change','طلب تغيير الوجهة','الطرف الآخر اقترح وجهة جديدة. راجع المسافة والسعر ووافق أو ارفض.',targetId:changeRef.id,action:'destination_change');
    return changeRef.id;
  }

  /// Approve/reject a pending destination proposal. Approval and ride update are atomic.
  static Future<void> reviewRideDestinationChange({required String changeId, required bool approve}) async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    final changeRef=db.collection('rideDestinationChanges').doc(changeId);
    await db.runTransaction<void>((tx) async {
      final cs=await tx.get(changeRef);final c=cs.data();
      if(c==null||c['status']!='pending'||c['approverId']!=u.uid)throw StateError('destination_change_not_pending_for_user');
      final rideRef=db.collection('rides').doc(c['rideId'].toString());final rs=await tx.get(rideRef);final r=rs.data();
      if(r==null||!['accepted','arriving','arrived','active'].contains(r['status'])||r['clientId']!=c['clientId']||r['providerId']!=c['providerId'])throw StateError('ride_changed_before_destination_review');
      if(approve){
        final currentFare=r['finalFare']??r['estimatedFare']??0;
        tx.update(rideRef,{'destination':c['destination'],'destinationLat':c['destinationLat'],'destinationLng':c['destinationLng'],'distanceKm':c['distanceKm'],'pricingPeriod':c['pricingPeriod'],'baseFare':c['baseFare'],'ratePerKm':c['ratePerKm'],'estimatedFare':c['estimatedFare'],'destinationChangeCount':FieldValue.increment(1),'lastDestinationChangeId':changeId,'lastDestinationChangeOldFare':currentFare,'lastDestinationChangeApprovedBy':u.uid,'lastDestinationChangeApprovedAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()});
      }
      tx.update(changeRef,{'status':approve?'approved':'rejected','reviewedBy':u.uid,'reviewedAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()});
    });
    final c=(await changeRef.get()).data()??const <String,dynamic>{};
    final other=(c['proposedBy']??'').toString();if(other.isNotEmpty)await _notifyUser(other,'destination_change_result',approve?'تمت الموافقة على تغيير الوجهة':'تم رفض تغيير الوجهة',approve?'تم اعتماد الوجهة الجديدة وتحديث السعر حسب التسعيرة الحالية. بقي سجل التغيير محفوظًا.':'الوجهة الأصلية والسعر الحالي بقيا كما هما.',targetId:changeId,action:'destination_change_result');
  }

  static Stream<QuerySnapshot<Map<String,dynamic>>> pendingDestinationChanges()=>db.collection('rideDestinationChanges').where('approverId',isEqualTo:user?.uid).where('status',isEqualTo:'pending').orderBy('createdAt',descending:true).limit(50).snapshots();

  /// Delivery provider reports a failed attempt; client instructions are requested without falsely marking delivered.
  static Future<void> reportDeliveryAttemptFailure({required String rideId, required String reason}) async {
    final u=user; if(u==null)throw StateError('not_authenticated');
    final why=reason.trim();if(why.length<3||why.length>500)throw StateError('delivery_failure_reason_required');
    final ref=db.collection('rides').doc(rideId);String? clientId;
    await db.runTransaction<void>((tx)async{
      final snap=await tx.get(ref);final x=snap.data();
      if(x==null||x['providerId']!=u.uid||!['accepted','arriving','arrived','active'].contains(x['status'])||!{'deliveryMoto','deliveryVan','deliveryTruck'}.contains(x['kind']))throw StateError('not_authorized_delivery_failure');
      final delivery=x['delivery'] is Map?Map<String,dynamic>.from(x['delivery'] as Map):<String,dynamic>{};
      clientId=x['clientId']?.toString();
      tx.update(ref,{'delivery':{...delivery,'deliveryStatus':'delivery_failed_pending_instructions','lastFailedAttemptReason':why,'failedAttemptAt':FieldValue.serverTimestamp(),'instructionStatus':'waiting_for_client'},'updatedAt':FieldValue.serverTimestamp()});
    });
    if(clientId!=null)await _notifyUser(clientId!,'delivery_failed','تعذّر تسليم الطرد','تعذّر التسليم: $why. ابعث تعليمات جديدة أو اختار إعادة المحاولة.',targetId:rideId,action:'delivery_instructions');
  }

  static Future<void> submitDeliveryInstructions({required String rideId, required String instructions, bool requestRetry=true}) async {
    final u=user;if(u==null)throw StateError('not_authenticated');final text=instructions.trim();
    if(text.length<3||text.length>800)throw StateError('delivery_instructions_required');
    final ref=db.collection('rides').doc(rideId);
    await db.runTransaction<void>((tx)async{
      final snap=await tx.get(ref);final x=snap.data();final delivery=x?['delivery'] is Map?Map<String,dynamic>.from(x!['delivery'] as Map):<String,dynamic>{};
      if(x==null||x['clientId']!=u.uid||delivery['deliveryStatus']!='delivery_failed_pending_instructions')throw StateError('delivery_not_waiting_for_instructions');
      tx.update(ref,{'delivery':{...delivery,'clientInstructions':text,'instructionStatus':'submitted','retryRequested':requestRetry,'deliveryStatus':requestRetry?'retry_requested':'instructions_submitted','instructionsAt':FieldValue.serverTimestamp()},'updatedAt':FieldValue.serverTimestamp()});
    });
    final x=(await ref.get()).data();final providerId=x?['providerId']?.toString();if(providerId!=null&&providerId.isNotEmpty)await _notifyUser(providerId,'delivery_instructions','تعليمات جديدة للتسليم',requestRetry?'الحريف بعث تعليمات وطلب إعادة المحاولة.':'الحريف بعث تعليمات جديدة.',targetId:rideId,action:'delivery_instructions');
  }

  static Stream<QuerySnapshot<Map<String,dynamic>>> providerCancellationEvents()=>db.collection('providerCancellationEvents').orderBy('createdAt',descending:true).limit(200).snapshots();

  static Future<void> updateRideLocation(String id,{required double latitude,required double longitude}) async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    if(!latitude.isFinite||latitude<-90||latitude>90||!longitude.isFinite||longitude<-180||longitude>180)throw StateError('invalid_coordinates');
    final ref=db.collection('rides').doc(id);
    await db.runTransaction<void>((tx) async {
      final snap=await tx.get(ref);final data=snap.data();
      if(data?['providerId']?.toString()!=u.uid||!['accepted','arriving','arrived','active'].contains(data?['status']?.toString()))throw StateError('not_authorized_or_ride_inactive');
      tx.update(ref,{'providerLat':latitude,'providerLng':longitude,'locationUpdatedAt':FieldValue.serverTimestamp()});
    });
  }
  static Stream<QuerySnapshot<Map<String,dynamic>>> availableRidesForRole(String role){
    final kinds=switch(role){
      'driver'=>['taxiMoto','carExpress','sos','ambulance','randonnee'],
      'deliveryProvider'=>['deliveryMoto','deliveryVan','deliveryTruck'],
      'partner'=>['taxiMoto','carExpress','deliveryMoto','deliveryVan','deliveryTruck','sos','ambulance','randonnee'],
      _=><String>[],
    };
    if(kinds.isEmpty)return const Stream.empty();
    return db.collection('rides').where('status',isEqualTo:'searching').where('kind',whereIn:kinds).limit(100).snapshots();
  }
  static Stream<QuerySnapshot<Map<String,dynamic>>> availableRides()=>db.collection('rides').where('status',isEqualTo:'searching').limit(50).snapshots();
  static Stream<QuerySnapshot<Map<String,dynamic>>> providerRides(String id)=>db.collection('rides').where('providerId',isEqualTo:id).limit(50).snapshots();
  static Map<String,dynamic> _rideProviderInfo(Map<String,dynamic> profile, String uid) => <String,dynamic>{'uid':uid,'displayName':(profile['displayName']??'السائق LEF_LEF').toString(),'vehicleType':(profile['vehicleType']??'').toString(),'vehicleModel':(profile['vehicleModel']??'').toString(),'vehiclePlate':(profile['vehiclePlate']??'').toString()};

  static bool _providerCanServe(Map<String,dynamic> profile, String? kind) {
    if (profile['providerAvailable'] != true || profile['providerVerified'] != true || _accountSuspended(profile) || _providerDocumentsExpired(profile)) return false;
    final role = profile['role']?.toString();
    const driverKinds = {'taxiMoto','carExpress','sos','ambulance','randonnee'};
    const deliveryKinds = {'deliveryMoto','deliveryVan','deliveryTruck'};
    if (role == 'partner') return driverKinds.contains(kind) || deliveryKinds.contains(kind);
    if (role == 'driver') return driverKinds.contains(kind);
    if (role == 'deliveryProvider') return deliveryKinds.contains(kind);
    return false;
  }

  // A provider may hold only one pending offer or active assignment at a time.
  // Run this query inside the transaction so concurrent taps are rechecked.
  static Future<bool> _hasOtherProviderAssignment(
    String providerId, String exceptRideId,
  ) async {
    final snap = await db.collection('rides')
        .where('providerId', isEqualTo: providerId)
        .where('status', whereIn: const [
          'offered', 'countered', 'accepted', 'arriving', 'arrived', 'active',
        ]).get();
    return snap.docs.any((doc) => doc.id != exceptRideId);
  }

  static Future<bool> sendOffer(String id, String providerId, double fare) async {
    final u = user;
    if (u == null || providerId != u.uid || !fare.isFinite || fare <= 0 || fare > 100000) return false;
    final ref = db.collection('rides').doc(id);
    final providerRef = db.collection('users').doc(u.uid);
    final ok = await db.runTransaction<bool>((tx) async {
      final rideSnap = await tx.get(ref);
      final providerSnap = await tx.get(providerRef);
      final ride = rideSnap.data();
      final profile = providerSnap.data() ?? const <String, dynamic>{};
      if (ride == null || ride['status'] != 'searching' || ride['negotiable'] != true || ride['clientId'] == u.uid || !_providerCanServe(profile, ride['kind']?.toString())) return false;
      if (await _hasOtherProviderAssignment(u.uid, id)) return false;
      tx.update(ref, {'status': 'offered', 'providerId': u.uid, 'providerInfo': _rideProviderInfo(profile, u.uid), 'offerFare': fare, 'updatedAt': FieldValue.serverTimestamp()});
      return true;
    });
    if (ok) {
      final ride = (await ref.get()).data();
      final clientId = ride?['clientId']?.toString();
      if (clientId != null) await _notify(clientId, id, 'offered', 'عرض جديد من LEF_LEF', 'جاك عرض جديد من السائق.');
    }
    return ok;
  }

  static Future<bool> acceptFixedRide(String id) async {
    final u = user;
    if (u == null) return false;
    final ref = db.collection('rides').doc(id);
    final providerRef = db.collection('users').doc(u.uid);
    final ok = await db.runTransaction<bool>((tx) async {
      final rideSnap = await tx.get(ref);
      final providerSnap = await tx.get(providerRef);
      final ride = rideSnap.data();
      final profile = providerSnap.data() ?? const <String, dynamic>{};
      final price = (ride?['estimatedFare'] as num?)?.toDouble();
      if (ride == null || ride['status'] != 'searching' || ride['negotiable'] == true || ride['clientId'] == u.uid || price == null || !price.isFinite || price <= 0 || !_providerCanServe(profile, ride['kind']?.toString())) return false;
      if (await _hasOtherProviderAssignment(u.uid, id)) return false;
      tx.update(ref, {'status': 'accepted', 'providerId': u.uid, 'providerInfo': _rideProviderInfo(profile, u.uid), 'offerFare': price, 'finalFare':price, 'priceApproved':true, 'priceApprovedAt':FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
      return true;
    });
    if (ok) {
      final ride = (await ref.get()).data();
      final clientId = ride?['clientId']?.toString();
      if (clientId != null) await _notify(clientId, id, 'accepted', 'الطلب تقبل', 'السائق قبل بالسعر المحدد.');
    }
    return ok;
  }
  static Future<bool> acceptOffer(String id) async {
    final u = user;
    if (u == null) return false;
    final ref = db.collection('rides').doc(id);
    String? providerId;
    final ok = await db.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      final ride = snap.data();
      if (ride == null || ride['clientId'] != u.uid || ride['status'] != 'offered' || ride['offerFare'] is! num) return false;
      final candidateId = ride['providerId']?.toString();
      if (candidateId == null || candidateId.isEmpty) return false;
      final providerSnap = await tx.get(db.collection('users').doc(candidateId));
      final profile = providerSnap.data() ?? const <String, dynamic>{};
      final fare = (ride['offerFare'] as num).toDouble();
      if (!fare.isFinite || fare <= 0 || !_providerCanServe(profile, ride['kind']?.toString())) return false;
      if (await _hasOtherProviderAssignment(candidateId, id)) return false;
      providerId = candidateId;
      tx.update(ref, {'status': 'accepted', 'finalFare':(ride['offerFare'] as num).toDouble(), 'priceApproved':true, 'priceApprovedAt':FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
      return true;
    });
    if (ok && providerId != null) await _notify(providerId!, id, 'accepted', 'الطلب تقبل', 'الالحريف قبل العرض متاعك.');
    return ok;
  }
  static Future<bool> sendClientCounter(String id,double fare) async {
    final u=user; if(u==null||!fare.isFinite||fare<=0||fare>100000)return false; final ref=db.collection('rides').doc(id);
    final ok=await db.runTransaction<bool>((tx)async{final s=await tx.get(ref);final x=s.data();if(x==null||x['clientId']!=u.uid||x['status']!='offered'||x['negotiable']!=true||fare<=0)return false;tx.update(ref,{'status':'countered','clientCounterFare':fare,'updatedAt':FieldValue.serverTimestamp()});return true;});
    if(ok){final x=(await ref.get()).data();final providerId=x?['providerId']?.toString();if(providerId!=null)await _notify(providerId,id,'countered','عرض مضاد جديد','الالحريف بعث عرض مضاد.');}
    return ok;
  }
  static Future<bool> acceptCounter(String id) async {final u=user;if(u==null)return false;final ref=db.collection('rides').doc(id);final ok=await db.runTransaction<bool>((tx)async{final s=await tx.get(ref);final x=s.data();final fare=(x?['clientCounterFare'] as num?)?.toDouble();if(x==null||x['providerId']!=u.uid||x['status']!='countered'||x['negotiable']!=true||fare==null||!fare.isFinite||fare<=0)return false;final profileSnap=await tx.get(db.collection('users').doc(u.uid));final profile=profileSnap.data()??const <String,dynamic>{};if(!_providerCanServe(profile,x['kind']?.toString()))return false;if(await _hasOtherProviderAssignment(u.uid,id))return false;tx.update(ref,{'status':'accepted','offerFare':fare,'finalFare':fare,'priceApproved':true,'priceApprovedAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()});return true;});if(ok){final x=(await ref.get()).data();final uid=x?['clientId']?.toString();if(uid!=null)await _notify(uid,id,'accepted','العرض المضاد تقبل.','السائق قبل العرض المضاد متاعك.');}return ok;}
  static Future<bool> submitProviderApplication({required AppRole role, required String fullName, required String phone, required String vehicleType, required String vehicleModel, required String plate, required String companyName, required String taxId, required Map<String, XFile> documents}) async {
    final u = user;
    if (u == null || !{AppRole.driver, AppRole.deliveryProvider, AppRole.partner}.contains(role)) throw StateError('invalid_application');
    final name = fullName.trim(), mobile = phone.trim();
    if (name.length < 3 || mobile.length < 8) throw StateError('invalid_contact');
    final isCompany = role == AppRole.partner;
    if (isCompany ? (companyName.trim().isEmpty || taxId.trim().isEmpty) : (vehicleType.trim().isEmpty || plate.trim().isEmpty)) throw StateError('missing_details');
    final requiredDocs = isCompany ? ['identity', 'companyRegistration'] : ['identity', 'license', 'vehicleRegistration', 'insurance'];
    if (!requiredDocs.every(documents.containsKey)) throw StateError('missing_documents');
    final existing = await db.collection('roleRequests').where('userId', isEqualTo: u.uid).where('status', isEqualTo: 'pending').limit(1).get();
    if (existing.docs.isNotEmpty) return false;
    final ref = db.collection('roleRequests').doc();
    final uploaded = <String, String>{};
    for (final entry in documents.entries) {
      if (!requiredDocs.contains(entry.key)) continue;
      final file = entry.value;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) throw StateError('document_too_large');
      final path = 'roleApplications/${u.uid}/${ref.id}/${entry.key}.jpg';
      await storage.ref(path).putData(bytes, SettableMetadata(contentType: file.mimeType ?? 'image/jpeg'));
      uploaded[entry.key] = path;
    }
    if (!requiredDocs.every(uploaded.containsKey)) throw StateError('missing_documents');
    final requestData = {
      'userId': u.uid, 'email': u.email, 'requestedRole': role.name,
      'applicantName': name, 'phone': mobile,
      'vehicleType': vehicleType.trim(), 'vehicleModel': vehicleModel.trim(), 'vehiclePlate': plate.trim().toUpperCase(),
      'companyName': companyName.trim(), 'taxId': taxId.trim(), 'documentPaths': uploaded,
      'status': 'pending', 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
    };
    try {
      await db.runTransaction<void>((tx) async { tx.set(ref, requestData); });
    } catch (_) {
      // Avoid orphaning private identity documents when another device submits
      // an application first or the final Firestore commit is rejected.
      for (final path in uploaded.values) {
        try { await storage.ref(path).delete(); } catch (_) {}
      }
      rethrow;
    }
    final bootstrap = await db.collection('system').doc('bootstrap').get();
    final ownerUid = bootstrap.data()?['ownerUid']?.toString();
    if (ownerUid != null && ownerUid != u.uid) {
      try {
        await db.collection('users').doc(ownerUid).collection('notifications').add({
          'type':'role_request','roleRequestId':ref.id,'recipientId':ownerUid,'requesterId':u.uid,
          'requestedRole':role.name,'title':'طلب انضمام جديد','message':'وصل طلب خدمة جديد مع الوثائق للمراجعة.',
          'createdAt':FieldValue.serverTimestamp(),'read':false,
        });
      } catch (e) {
        // The application is already saved; a notification failure must not
        // make the applicant believe submission failed and retry a duplicate.
        debugPrint('LEF_LEF application notification failed (non-blocking): $e');
      }
    }
    return true;
  }

  static Future<void> reviewRoleRequest(String id,{required bool approve,required String userId,required AppRole requestedRole}) async {
    final u=user; if(u==null)throw StateError('not_authenticated');
    if(!(await hasCapability(Capability.manageRoles)))throw StateError('not_authorized');
    final ref=db.collection('roleRequests').doc(id);
    String? reviewedUserId;
    AppRole? reviewedRole;
    await db.runTransaction((tx) async {
      final req=await tx.get(ref); if(!req.exists||req.data()?['status']!='pending')throw StateError('request_closed');
      final reqData=req.data()??const <String,dynamic>{};
      final actualUserId=reqData['userId']?.toString();
      final roleName=reqData['requestedRole']?.toString();
      final actualRole=AppRole.values.firstWhere((r)=>r.name==roleName,orElse:()=>AppRole.client);
      if(actualUserId==null||!{AppRole.driver,AppRole.deliveryProvider,AppRole.partner}.contains(actualRole))throw StateError('invalid_request');
      reviewedUserId = actualUserId;
      reviewedRole = actualRole;
      if (approve) {
        final requiredDocs = actualRole == AppRole.partner
            ? const ['identity', 'companyRegistration']
            : const ['identity', 'license', 'vehicleRegistration', 'insurance'];
        final paths = reqData['documentPaths'];
        if (paths is! Map || !requiredDocs.every((key) => paths[key] is String && (paths[key] as String).startsWith('roleApplications/$actualUserId/$id/'))) {
          throw StateError('application_documents_incomplete');
        }
        if ((reqData['applicantName']?.toString().trim() ?? '').length < 3 || (reqData['phone']?.toString().trim() ?? '').length < 8) throw StateError('application_contact_incomplete');
        if (actualRole == AppRole.partner && ((reqData['companyName']?.toString().trim() ?? '').isEmpty || (reqData['taxId']?.toString().trim() ?? '').isEmpty)) throw StateError('application_company_incomplete');
        if (actualRole != AppRole.partner && ((reqData['vehicleType']?.toString().trim() ?? '').isEmpty || (reqData['vehiclePlate']?.toString().trim() ?? '').isEmpty)) throw StateError('application_vehicle_incomplete');
      }
      final target=await tx.get(db.collection('users').doc(actualUserId));
      final targetRole=target.data()?['role']?.toString()??'client';
      if(targetRole=='owner')throw StateError('protected_role');
      if(approve){
        final requestData = req.data() ?? const <String,dynamic>{};
        final verifiedProfile = <String,dynamic>{'role':actualRole.name,'roleSelected':true,'capabilities':capabilityNames(defaultCapabilitiesForRole(actualRole)),'providerVerified':true,'providerAvailable':false,'displayName':requestData['applicantName'],'phone':requestData['phone'],'updatedAt':FieldValue.serverTimestamp()};
        if (actualRole == AppRole.partner) { verifiedProfile['companyName'] = requestData['companyName']; verifiedProfile['taxId'] = requestData['taxId']; }
        else { verifiedProfile['vehicleType'] = requestData['vehicleType']; verifiedProfile['vehicleModel'] = requestData['vehicleModel']; verifiedProfile['vehiclePlate'] = requestData['vehiclePlate']; }
        tx.update(db.collection('users').doc(actualUserId),verifiedProfile);
        final applicantName = (requestData['applicantName'] ?? '').toString().trim();
        tx.set(db.collection('publicProfiles').doc(actualUserId),{'uid':actualUserId,'role':actualRole.name,'displayName':applicantName,'displayNameLower':applicantName.toLowerCase(),'visibility':'public','updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
      }
      tx.update(ref,{'status':approve?'approved':'rejected','reviewedBy':u.uid,'reviewedAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()});
    });
    final finalUserId = reviewedUserId ?? userId;
    final finalRole = reviewedRole ?? requestedRole;
    final msg = approve ? 'طلب الدور متاعك (${roleLabel(finalRole)}) تقبل.' : 'طلب الدور متاعك (${roleLabel(finalRole)}) ترفض.';
    try {
      await _notifyUser(finalUserId, 'role_request', 'طلب دور', msg, roleRequestId:id);
    } catch (e) {
      // Approval/rejection is already committed; notification failure must not
      // make the reviewer retry a completed decision.
      debugPrint('LEF_LEF role-review notification failed (non-blocking): $e');
    }
  }

  /// One immutable rating per ride and reviewer. The Firestore rules independently
  /// verify the ride is completed and that the reviewer is a participant.
  static Future<void> submitRideRating({required String rideId, required int score, String comment = ''}) async {
    final u = user;
    if (u == null) throw StateError('not_authenticated');
    if (score < 1 || score > 5 || comment.trim().length > 600) throw ArgumentError('invalid_rating');
    final rideRef = db.collection('rides').doc(rideId);
    final ratingRef = db.collection('rideRatings').doc('${rideId}_${u.uid}');
    await db.runTransaction<void>((tx) async {
      final rideSnap = await tx.get(rideRef);
      final ride = rideSnap.data();
      if (ride == null || ride['status'] != 'completed' ||
          (ride['clientId'] != u.uid && ride['providerId'] != u.uid)) {
        throw StateError('ride_not_rateable');
      }
      final target = ride['clientId'] == u.uid ? ride['providerId'] : ride['clientId'];
      if (target is! String || target.isEmpty || target == u.uid) throw StateError('invalid_rating_target');
      final existing = await tx.get(ratingRef);
      if (existing.exists) throw StateError('ride_already_rated');
      tx.set(ratingRef, {
        'rideId': rideId, 'reviewerId': u.uid, 'targetId': target,
        'score': score, 'comment': comment.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> reportRide({required String rideId, required String reason, String details = ''}) async {
    final u = user;
    if (u == null) throw StateError('not_authenticated');
    final cleanReason = reason.trim();
    final cleanDetails = details.trim();
    if (cleanReason.length < 3 || cleanReason.length > 120 || cleanDetails.length > 1200) {
      throw ArgumentError('invalid_ride_report');
    }
    final ride = await db.collection('rides').doc(rideId).get();
    final data = ride.data();
    if (data == null || (data['clientId'] != u.uid && data['providerId'] != u.uid)) {
      throw StateError('ride_not_accessible');
    }
    await db.collection('reports').add({
      'type': 'ride', 'targetId': rideId, 'rideId': rideId,
      'reporterId': u.uid, 'reason': cleanReason, 'details': cleanDetails,
      'status': 'open', 'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot<Map<String,dynamic>>> openReports()=>db.collection('reports').where('status',isEqualTo:'open').limit(50).snapshots();
  static Future<void> resolveReport(String id,{String status='resolved'}) async { final u=user;if(u==null)throw StateError('not_authenticated');if(!{'resolved','dismissed'}.contains(status))throw StateError('invalid_report_status');if(!(await hasCapability(Capability.moderateContent)))throw StateError('not_authorized');final ref=db.collection('reports').doc(id);final snap=await ref.get();if(!snap.exists)throw StateError('report_not_found');if(snap.data()?['status']!='open')throw StateError('report_already_closed');await ref.update({'status':status,'resolvedBy':u.uid,'resolvedAt':FieldValue.serverTimestamp()}); }
  static Stream<QuerySnapshot<Map<String,dynamic>>> subscriptions()=>db.collection('subscriptions').limit(100).snapshots();
  static Future<void> setSubscriptionPlan(String uid,String plan) async { final u=user;if(u==null)throw StateError('not_authenticated');if(!['free','plus','business'].contains(plan))throw StateError('invalid_plan');if(!(await hasCapability(Capability.manageSubscriptions)))throw StateError('not_authorized');await db.collection('subscriptions').doc(uid).set({'uid':uid,'plan':plan,'status':plan=='free'?'active':'pending','updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true)); }

  static Future<bool> _notificationsEnabledFor(String uid) async {
    try {
      final snap = await db.collection('users').doc(uid).get();
      // Older profiles have no preference yet, so keep notifications enabled.
      final data=snap.data()??const <String,dynamic>{};
      if(data['notificationsEnabled']==false)return false;
      return true;
    } catch (e) {
      // A temporary preference-read failure must not break the main action.
      debugPrint('LEF_LEF notification preference read failed: $e');
      return true;
    }
  }

  static Future<void> _notify(String uid,String rideId,String status,String title,String message) async {
    if (!await _notificationsEnabledFor(uid)) return;
    try {
      final prefs=(await db.collection('users').doc(uid).get()).data()?['notificationPreferences'];
      if(prefs is Map && prefs['rides']==false)return;
      await db.collection('users').doc(uid).collection('notifications').add({'type':'ride','rideId':rideId,'recipientId':uid,'status':status,'title':title,'message':message,'createdAt':FieldValue.serverTimestamp(),'read':false});
    } on FirebaseException catch(e) { debugPrint('LEF_LEF notification write failed: code=${e.code} message=${e.message}'); } catch(e) { debugPrint('LEF_LEF notification write failed: $e'); }
  }
  static Future<void> _notifyUser(String uid,String type,String title,String message,{String? roleRequestId,String? targetId,String? sourceId,String? action,String? conversationId,String? senderId}) async {
    if (!await _notificationsEnabledFor(uid)) return;
    try {
      final prefs=(await db.collection('users').doc(uid).get()).data()?['notificationPreferences'];
      final category=(type=='ride'||type=='provider_cancellation_review')?'rides':type=='event'?'events':type=='pricing'?'pricing':'social';
      if(prefs is Map && prefs[category]==false)return;
      await db.collection('users').doc(uid).collection('notifications').add({'type':type,'recipientId':uid,'title':title,'message':message,if(roleRequestId!=null)'roleRequestId':roleRequestId,if(targetId!=null)'targetId':targetId,if(sourceId!=null)'sourceId':sourceId,if(action!=null)'action':action,if(conversationId!=null)'conversationId':conversationId,if(senderId!=null)'senderId':senderId,'createdAt':FieldValue.serverTimestamp(),'read':false});
    } on FirebaseException catch(e) { debugPrint('LEF_LEF user notification write failed: code=${e.code} message=${e.message}'); } catch(e) { debugPrint('LEF_LEF user notification write failed: $e'); }
  }
  static Future<void> markNotificationRead(String id) async {
    final u=user;if(u==null)return;
    final cleanId=id.trim();if(cleanId.isEmpty||cleanId.contains('/')||cleanId.length>180)throw ArgumentError('invalid_notification_id');
    final ref=db.collection('users').doc(u.uid).collection('notifications').doc(cleanId);
    await db.runTransaction<void>((tx)async{
      final snap=await tx.get(ref);if(!snap.exists)return;
      if(snap.data()?['read']!=true)tx.update(ref,{'read':true,'updatedAt':FieldValue.serverTimestamp()});
    });
  }
  static Future<void> markAllNotificationsRead() async {
    final u = user;
    if (u == null) return;
    final collection = db.collection('users').doc(u.uid).collection('notifications');
    // Firestore batches are limited to 500 writes. Use smaller chunks and keep
    // querying until there are no unread notifications left (not just the first 100).
    while (true) {
      final page = await collection.where('read', isEqualTo: false).limit(450).get();
      if (page.docs.isEmpty) return;
      final batch = db.batch();
      for (final doc in page.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
      if (page.docs.length < 450) return;
    }
  }
  static Stream<QuerySnapshot<Map<String,dynamic>>> unreadNotifications()=>user==null?const Stream.empty():db.collection('users').doc(user!.uid).collection('notifications').where('read',isEqualTo:false).snapshots();
  // Read only the signed-in user's block list (other users' private block lists
  // are intentionally not client-readable). Firestore rules enforce both ways.
  static Future<bool> _isBlockedEitherWay(String firstUid, String secondUid) async {
    if (firstUid.isEmpty || secondUid.isEmpty || firstUid == secondUid) return false;
    final blocked = await db.collection('users').doc(firstUid).collection('blockedUsers').doc(secondUid).get();
    return blocked.exists;
  }

  static Future<void> ensureConversation(String id,String title) async {
    final u=user;
    if(u==null)throw StateError('not_authenticated');
    final cleanId=id.trim(), cleanTitle=title.trim();
    if(cleanId.isEmpty||cleanTitle.isEmpty)throw StateError('invalid_conversation');
    final ref=db.collection('conversations').doc(cleanId);
    await db.runTransaction((tx) async {
      final snap=await tx.get(ref);
      if(!snap.exists){
        final members=<String>[u.uid];
        if(cleanId=='support_${u.uid}'||cleanTitle=='مساعدة LEF_LEF'){
          final bs=await tx.get(db.collection('system').doc('bootstrap'));
          final ownerUid=bs.data()?['ownerUid']?.toString();
          if(ownerUid!=null&&ownerUid.isNotEmpty&&ownerUid!=u.uid)members.add(ownerUid);
        }
        tx.set(ref,{'title':cleanTitle,'members':members,'createdAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()});
        return;
      }
      final membersRaw=snap.data()?['members'];
      if(membersRaw is! List || !membersRaw.whereType<String>().contains(u.uid)) {
        throw StateError('conversation_not_allowed');
      }
      tx.update(ref,{'updatedAt':FieldValue.serverTimestamp()});
    });
  }
  static Future<void> sendImageMessage(String conversationId,File image) async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    if(conversationId.trim().isEmpty||conversationId.contains('/'))throw ArgumentError('invalid_conversation_id');
    if(!await image.exists())throw StateError('media_file_missing');
    final ext=image.path.split('.').last.toLowerCase();
    const allowed={'jpg','jpeg','png','webp','heic','heif'};
    if(!allowed.contains(ext))throw StateError('chat_image_type_invalid');
    final length=await image.length();if(length<=0||length>10*1024*1024)throw StateError('chat_image_size_invalid');
    final ref=db.collection('conversations').doc(conversationId);
    final snap=await ref.get();final members=List<String>.from(snap.data()?['members']??const <String>[]);
    if(!snap.exists||!members.contains(u.uid))throw StateError('conversation_not_allowed');
    for(final recipient in members.where((id)=>id!=u.uid)){if(await _isBlockedEitherWay(u.uid,recipient))throw StateError('messaging_blocked');}
    final path='chatMedia/$conversationId/${u.uid}/${DateTime.now().microsecondsSinceEpoch}.$ext';
    final contentType=ext=='png'?'image/png':ext=='webp'?'image/webp':(ext=='heic'?'image/heic':ext=='heif'?'image/heif':'image/jpeg');
    final task=await storage.ref().child(path).putFile(image,SettableMetadata(contentType:contentType));
    try {
      // Store a storage path, not a token-bearing download URL. Every display
      // now goes through the authenticated Storage SDK and its membership rules.
      await ref.collection('messages').add({'senderId':u.uid,'text':'صورة','mediaPath':path,'mediaType':'image','createdAt':FieldValue.serverTimestamp()});
    } catch (_) {
      // Avoid leaving private orphaned uploads if the message write fails.
      try { await task.ref.delete(); } catch (cleanupError) { debugPrint('LEF_LEF orphan chat media cleanup failed: $cleanupError'); }
      rethrow;
    }
    for(final recipient in members.where((id)=>id!=u.uid)){await _notifyUser(recipient,'chat','صورة جديدة','بعثولك صورة في المحادثة.',conversationId:conversationId,senderId:u.uid);}
  }

  static Future<void> sendMessage(String conversationId,String text,{String? clientMessageId}) async {
    final u=user;
    final v=text.trim();
    final cleanConversationId=conversationId.trim();
    if(u==null)throw StateError('not_authenticated');
    if(v.isEmpty||v.length>4000)throw StateError('invalid_message');
    if(cleanConversationId.isEmpty||cleanConversationId.contains('/'))throw ArgumentError('invalid_conversation_id');
    final ref=db.collection('conversations').doc(cleanConversationId);
    final snap=await ref.get();
    final members=List<String>.from(snap.data()?['members']??const <String>[]);
    if(!snap.exists||!members.contains(u.uid))throw StateError('conversation_not_allowed');
    for (final recipient in members.where((id)=>id!=u.uid)) {
      if (await _isBlockedEitherWay(u.uid, recipient)) throw StateError('messaging_blocked');
    }
    // A stable client ID makes a retry after a timeout idempotent. If the same
    // ID is reused with different content, fail closed rather than overwrite.
    final id=(clientMessageId??ref.collection('messages').doc().id).trim();
    if(id.isEmpty||id.contains('/')||id.length>128)throw ArgumentError('invalid_client_message_id');
    final messageRef=ref.collection('messages').doc(id);
    final created=await db.runTransaction<bool>((tx) async {
      final existing=await tx.get(messageRef);
      if(existing.exists){
        final old=existing.data()??const <String,dynamic>{};
        if(old['senderId']!=u.uid||old['text']!=v)throw StateError('message_id_conflict');
        return false;
      }
      tx.set(messageRef,{'senderId':u.uid,'text':v,'clientMessageId':id,'createdAt':FieldValue.serverTimestamp()});
      return true;
    });
    if(!created)return;
    for(final recipient in members.where((id)=>id!=u.uid)){
      await _notifyUser(recipient,'chat','مساج جديد','جاك مساج جديد.',conversationId:cleanConversationId,senderId:u.uid);
    }
  }
  static Future<void> reportPost(String postId,String reason) async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    final id=postId.trim(),why=reason.trim();
    if(id.isEmpty||id.contains('/')||id.length>180||why.length<3||why.length>1000)throw ArgumentError('invalid_report');
    final postRef=db.collection('posts').doc(id);final post=await postRef.get();
    if(!post.exists)throw StateError('post_not_found');
    if(post.data()?['authorId']?.toString()==u.uid)throw StateError('cannot_report_own_post');
    // One report per user/post avoids accidental double taps creating duplicates.
    final reportRef=db.collection('reports').doc('post_${id}_${u.uid}');
    await db.runTransaction<void>((tx)async{
      final existing=await tx.get(reportRef);
      if(existing.exists)throw StateError('post_already_reported');
      tx.set(reportRef,{'type':'post','targetId':id,'reporterId':u.uid,'reason':why,'status':'open','createdAt':FieldValue.serverTimestamp()});
    });
  }
  static Future<void> blockUser(String targetUid) async { final u=user;if(u==null)throw StateError('not_authenticated');final target=targetUid.trim();if(target.isEmpty||u.uid==target)throw ArgumentError('invalid_block_target');await db.collection('users').doc(u.uid).collection('blockedUsers').doc(target).set({'blockedAt':FieldValue.serverTimestamp()},SetOptions(merge:true)); }
  static Stream<QuerySnapshot<Map<String,dynamic>>> blockedUsers() { final u=user; if(u==null)return const Stream.empty(); return db.collection('users').doc(u.uid).collection('blockedUsers').snapshots(); }
  static Future<Set<String>> blockedUserIds() async { final u=user; if(u==null)return <String>{}; final snap=await db.collection('users').doc(u.uid).collection('blockedUsers').get(); return snap.docs.map((d)=>d.id).toSet(); }

  static Future<void> followUser(String targetUid) async {
    final u=user;if(u==null||targetUid.trim().isEmpty||targetUid==u.uid)throw StateError('invalid_target');
    if (await _isBlockedEitherWay(u.uid, targetUid)) throw StateError('follow_blocked');
    final batch=db.batch();
    batch.set(db.collection('users').doc(targetUid).collection('followers').doc(u.uid),{'uid':u.uid,'createdAt':FieldValue.serverTimestamp()});
    batch.set(db.collection('users').doc(u.uid).collection('following').doc(targetUid),{'uid':targetUid,'createdAt':FieldValue.serverTimestamp()});
    await batch.commit();
    await _notifyUser(targetUid,'follow','متابع جديد','مستخدم تابع البروفايل متاعك.',targetId:targetUid,senderId:u.uid);
  }
  static Future<void> unfollowUser(String targetUid) async {
    final u=user;if(u==null||targetUid.isEmpty||targetUid==u.uid)return;
    final batch=db.batch();
    batch.delete(db.collection('users').doc(targetUid).collection('followers').doc(u.uid));
    batch.delete(db.collection('users').doc(u.uid).collection('following').doc(targetUid));
    await batch.commit();
  }
  static Future<bool> isFollowing(String targetUid) async {final u=user;if(u==null||targetUid.isEmpty||targetUid==u.uid)return false;return (await db.collection('users').doc(u.uid).collection('following').doc(targetUid).get()).exists;}
  static Stream<QuerySnapshot<Map<String,dynamic>>> followers(String uid)=>db.collection('users').doc(uid).collection('followers').snapshots();
  static Stream<QuerySnapshot<Map<String,dynamic>>> following(String uid)=>db.collection('users').doc(uid).collection('following').snapshots();

  static Future<void> createPost(String text,{File? media, String? mediaType}) async {
    final u=user; final v=text.trim();
    if(u==null)throw StateError('not_authenticated');
    if(v.length>4000|| (v.isEmpty&&media==null))throw StateError('invalid_post');
    if(media!=null && !{'image','video'}.contains(mediaType))throw StateError('invalid_media_type');
    String? mediaUrl;
    if(media!=null) mediaUrl=await uploadUserMedia(media,folder:'posts');
    await db.collection('posts').add({'authorId':u.uid,'text':v,'likes':<String>[],'createdAt':FieldValue.serverTimestamp(),if(mediaUrl!=null)'mediaUrl':mediaUrl,if(mediaUrl!=null)'mediaType':mediaType});
  }
  static Future<void> updatePost(String postId,String text,{File? media,String? mediaType,bool removeMedia=false}) async {
    final u=user; final id=postId.trim(); final value=text.trim();
    if(u==null)throw StateError('not_authenticated');
    if(id.isEmpty||value.length>4000)throw StateError('invalid_post');
    final ref=db.collection('posts').doc(id); final snap=await ref.get(); final data=snap.data();
    if(data==null)throw StateError('post_not_found');
    if(data['authorId']?.toString()!=u.uid)throw StateError('not_post_owner');
    if((data['repostedFrom']??'').toString().isNotEmpty)throw StateError('repost_not_editable');
    final keepsExistingMedia=(data['mediaUrl']?.toString().isNotEmpty??false)&&!removeMedia&&media==null;
    if(value.isEmpty&&media==null&&!keepsExistingMedia)throw StateError('invalid_post');
    String? url;
    if(media!=null){if(!{'image','video'}.contains(mediaType))throw StateError('invalid_media_type');url=await uploadUserMedia(media,folder:'posts');}
    await ref.update({'text':value,'updatedAt':FieldValue.serverTimestamp(),if(url!=null)'mediaUrl':url,if(url!=null)'mediaType':mediaType,if(removeMedia)...{'mediaUrl':FieldValue.delete(),'mediaType':FieldValue.delete()}});
  }
  static Future<void> deletePost(String postId) async {
    final u=user; final id=postId.trim(); if(u==null)throw StateError('not_authenticated'); if(id.isEmpty)throw ArgumentError('invalid_post_id');
    final ref=db.collection('posts').doc(id); final snap=await ref.get(); final data=snap.data();
    if(data==null)throw StateError('post_not_found'); if(data['authorId']?.toString()!=u.uid)throw StateError('not_post_owner');
    await ref.delete();
  }
  static Future<void> toggleLike(String postId, List<String> likes) async {
    final u = user;
    if (u == null) throw StateError('not_authenticated');
    final ref = db.collection('posts').doc(postId.trim());
    final initialPost = await ref.get();
    if (!initialPost.exists) throw StateError('post_not_found');
    final initialAuthor = initialPost.data()?['authorId']?.toString();
    if (initialAuthor != null && await _isBlockedEitherWay(u.uid, initialAuthor)) throw StateError('social_action_blocked');
    final added = await db.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) throw StateError('post_not_found');
      final current = List<String>.from(data['likes'] ?? const <String>[]);
      if (current.contains(u.uid)) {
        tx.update(ref, {'likes': FieldValue.arrayRemove([u.uid])});
        return false;
      }
      tx.update(ref, {'likes': FieldValue.arrayUnion([u.uid])});
      return true;
    });
    // Decide whether to notify from the transaction's actual state, not a stale
    // list captured by a feed widget before another device changed the likes.
    if (added) {
      final post = await ref.get();
      final author = post.data()?['authorId']?.toString();
      if (author != null && author != u.uid) {
        await _notifyUser(author, 'social', 'إعجاب جديد', 'عندك إعجاب جديد على منشورك.', targetId: postId, action: 'like', senderId: u.uid);
      }
    }
  }
  static Future<void> addComment(String postId, String text, {String? parentCommentId}) async {
    final u = user;
    final value = text.trim();
    if (u == null) throw StateError('not_authenticated');
    if (value.isEmpty || value.length > 4000) throw ArgumentError('invalid_comment');
    final postRef = db.collection('posts').doc(postId);
    final post = await postRef.get();
    if (!post.exists) throw StateError('post_not_found');
    final postAuthor = post.data()?['authorId']?.toString();
    if (postAuthor != null && await _isBlockedEitherWay(u.uid, postAuthor)) throw StateError('social_action_blocked');
    final comment = await postRef.collection('comments').add({
      'authorId': u.uid,
      'text': value,
      if (parentCommentId != null && parentCommentId.trim().isNotEmpty) 'parentCommentId': parentCommentId.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    final author = post.data()?['authorId']?.toString();
    if (author != null && author != u.uid) {
      await _notifyUser(author, 'social', 'تعليق جديد', 'عندك تعليق جديد على منشورك.', targetId: postId, action: 'comment', sourceId: comment.id, senderId: u.uid);
    }
  }
  static Future<void> updateComment(String postId, String commentId, String text) async {
    final u = user;
    final value = text.trim();
    if (u == null) throw StateError('not_authenticated');
    if (value.isEmpty || value.length > 4000) throw ArgumentError('invalid_comment');
    final ref = db.collection('posts').doc(postId).collection('comments').doc(commentId);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('comment_not_found');
    if (snap.data()?['authorId']?.toString() != u.uid && !(await hasCapability(Capability.moderateContent))) throw StateError('not_comment_owner');
    await ref.update({'text': value, 'updatedAt': FieldValue.serverTimestamp()});
  }

  static Future<void> deleteComment(String postId, String commentId) async {
    final u = user;
    if (u == null) throw StateError('not_authenticated');
    final ref = db.collection('posts').doc(postId).collection('comments').doc(commentId);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('comment_not_found');
    if (snap.data()?['authorId']?.toString() != u.uid && !(await hasCapability(Capability.moderateContent))) throw StateError('not_comment_owner');
    await ref.delete();
  }

  static Future<String?> repost(String postId) async { final u=user;if(u==null)throw StateError('not_authenticated');final id=postId.trim();if(id.isEmpty)throw ArgumentError('invalid_post_id');final original=await db.collection('posts').doc(id).get();if(!original.exists)throw StateError('post_not_found');final x=original.data()!;final originalAuthor=x['authorId']?.toString();if(originalAuthor!=null&&await _isBlockedEitherWay(u.uid,originalAuthor))throw StateError('social_action_blocked');final ref=db.collection('posts').doc();await ref.set({'authorId':u.uid,'text':x['text']?.toString()??'','likes':<String>[],'createdAt':FieldValue.serverTimestamp(),'repostedFrom':postId,'originalAuthorId':x['authorId']?.toString(),if(x['mediaUrl']!=null)'mediaUrl':x['mediaUrl'],'mediaType':x['mediaType']?.toString()});final author=x['authorId']?.toString();if(author!=null&&author!=u.uid)await _notifyUser(author,'social','إعادة نشر','منشورك تعاود نشره مستخدم.',targetId:postId,action:'repost',sourceId:ref.id,senderId:u.uid);return ref.id; }
  static Future<String?> createEvent({required String title, required String place, required DateTime startsAt, String description = '', int? capacity}) async {
    final u=user; final t=title.trim(); final p=place.trim();
    if(u==null)throw StateError('not_authenticated');
    if(t.isEmpty||p.isEmpty||t.length>160||p.length>300||description.trim().length>4000||!startsAt.isAfter(DateTime.now())||(capacity!=null&&capacity<1))throw ArgumentError('invalid_event');
    final ref=db.collection('events').doc();
    await ref.set({'id':ref.id,'title':t,'place':p,'description':description.trim(),'startsAt':Timestamp.fromDate(startsAt),'createdBy':u.uid,'createdAt':FieldValue.serverTimestamp(),'status':'published','capacity':capacity,'reminderPolicy':{'weekBefore':true,'daily':true,'everyTwoHoursLastDay':true}});
    return ref.id;
  }
  static Stream<QuerySnapshot<Map<String,dynamic>>> upcomingEvents() => db.collection('events').where('status',isEqualTo:'published').limit(50).snapshots();
  static Future<void> updateEvent(String eventId,{required String title,required String place,required String description,required DateTime startsAt,int? capacity}) async {
    final u=user;if(u==null)throw StateError('not_authenticated');final t=title.trim(),p=place.trim(),d=description.trim();
    if(t.isEmpty||p.isEmpty||t.length>160||p.length>300||d.length>4000||!startsAt.isAfter(DateTime.now())||(capacity!=null&&capacity<1))throw ArgumentError('invalid_event');
    final ref=db.collection('events').doc(eventId);final snap=await ref.get();if(!snap.exists)throw StateError('event_not_found');if(snap.data()?['createdBy']?.toString()!=u.uid&&!(await hasCapability(Capability.manageServices)))throw StateError('not_event_owner');
    await ref.update({'title':t,'place':p,'description':d,'startsAt':Timestamp.fromDate(startsAt),'capacity':capacity,'updatedAt':FieldValue.serverTimestamp()});
  }
  static Future<void> deleteEvent(String eventId) async {final u=user;if(u==null)throw StateError('not_authenticated');final ref=db.collection('events').doc(eventId);final snap=await ref.get();if(!snap.exists)throw StateError('event_not_found');if(snap.data()?['createdBy']?.toString()!=u.uid&&!(await hasCapability(Capability.manageServices)))throw StateError('not_event_owner');await ref.delete();}

  static Future<void> saveService({required String name, required String category, required String description}) async {
    final u = user;
    if (u == null) throw StateError('not_authenticated');
    final n = name.trim(), c = category.trim(), d = description.trim();
    if (n.isEmpty || c.isEmpty || n.length > 160 || c.length > 100 || d.length > 2000) throw StateError('invalid_service');
    final profile = await db.collection('users').doc(u.uid).get();
    final data = profile.data() ?? const <String, dynamic>{};
    final verifiedProvider = data['providerVerified'] == true && {'driver','deliveryProvider','partner'}.contains(data['role']);
    if (!verifiedProvider && !(await hasCapability(Capability.manageServices))) throw StateError('verified_provider_or_service_manager_required');
    await db.collection('serviceDirectory').doc().set({'name': n, 'category': c, 'description': d, 'createdBy': u.uid, 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(), 'active': true});
  }
  static Stream<QuerySnapshot<Map<String,dynamic>>> serviceDirectory() => db.collection('serviceDirectory').where('active',isEqualTo:true).limit(50).snapshots();
  static Future<void> updateServiceDirectory(String serviceId,{required String name,required String category,required String description}) async {final u=user;if(u==null)throw StateError('not_authenticated');final n=name.trim(),c=category.trim(),d=description.trim();if(n.isEmpty||c.isEmpty||n.length>160||c.length>100||d.length>2000)throw ArgumentError('invalid_service');final ref=db.collection('serviceDirectory').doc(serviceId);final snap=await ref.get();if(!snap.exists)throw StateError('service_not_found');if(snap.data()?['createdBy']?.toString()!=u.uid&&!(await hasCapability(Capability.manageServices)))throw StateError('not_service_owner');await ref.update({'name':n,'category':c,'description':d,'updatedAt':FieldValue.serverTimestamp()});}
  static Future<void> deleteServiceDirectory(String serviceId) async {final u=user;if(u==null)throw StateError('not_authenticated');final ref=db.collection('serviceDirectory').doc(serviceId);final snap=await ref.get();if(!snap.exists)throw StateError('service_not_found');if(snap.data()?['createdBy']?.toString()!=u.uid&&!(await hasCapability(Capability.manageServices)))throw StateError('not_service_owner');await ref.delete();}


  static Future<void> createStory(String text, {File? media, String? mediaType}) async {
    final u = user;
    final value = text.trim();
    if (u == null) throw StateError('not_authenticated');
    if (value.length > 500 || (value.isEmpty && media == null)) throw StateError('invalid_story');
    if (media != null && !{'image', 'video'}.contains(mediaType)) throw StateError('invalid_media_type');
    if (media == null && mediaType != null) throw StateError('media_file_required');
    String? mediaUrl;
    if (media != null) mediaUrl = await uploadUserMedia(media, folder: 'stories');
    await db.collection('stories').add({'authorId': u.uid, 'text': value, 'createdAt': FieldValue.serverTimestamp(), 'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))), if (mediaUrl != null) 'mediaUrl': mediaUrl, if (mediaUrl != null) 'mediaType': mediaType});
  }
  static Stream<QuerySnapshot<Map<String,dynamic>>> activeStories()=>db.collection('stories').where('expiresAt',isGreaterThan:Timestamp.now()).orderBy('expiresAt',descending:true).limit(30).snapshots();
  static Future<void> updateStory(String storyId,String text,{File? media,String? mediaType,bool removeMedia=false}) async {
    final u=user;final id=storyId.trim();final value=text.trim();if(u==null)throw StateError('not_authenticated');if(id.isEmpty||value.length>500)throw StateError('invalid_story');
    final ref=db.collection('stories').doc(id);final snap=await ref.get();final d=snap.data();if(d==null)throw StateError('story_not_found');if(d['authorId']?.toString()!=u.uid)throw StateError('not_story_owner');
    final expires=d['expiresAt'];if(expires is Timestamp&&!expires.toDate().isAfter(DateTime.now()))throw StateError('story_expired');
    final keeps=(d['mediaUrl']?.toString().isNotEmpty??false)&&!removeMedia&&media==null;if(value.isEmpty&&media==null&&!keeps)throw StateError('empty_story');
    String? url;if(media!=null){if(!{'image','video'}.contains(mediaType))throw StateError('invalid_media_type');url=await uploadUserMedia(media,folder:'stories');}
    await ref.update({'text':value,'updatedAt':FieldValue.serverTimestamp(),if(url!=null)'mediaUrl':url,if(url!=null)'mediaType':mediaType,if(removeMedia)...{'mediaUrl':FieldValue.delete(),'mediaType':FieldValue.delete()}});
  }
  static Future<void> deleteStory(String storyId) async {final u=user;final id=storyId.trim();if(u==null)throw StateError('not_authenticated');if(id.isEmpty)throw StateError('invalid_story_id');final ref=db.collection('stories').doc(id);final snap=await ref.get();if(!snap.exists)throw StateError('story_not_found');if(snap.data()?['authorId']?.toString()!=u.uid)throw StateError('not_story_owner');await ref.delete();}

  static Future<void> markStoryViewed(String storyId) async {
    final u = user;
    if (u == null) throw StateError('not_authenticated');
    final id = storyId.trim();
    if (id.isEmpty) throw ArgumentError('invalid_story_id');
    final story = await db.collection('stories').doc(id).get();
    if (!story.exists) throw StateError('story_not_found');
    final data = story.data() ?? const <String, dynamic>{};
    final authorId = data['authorId']?.toString() ?? '';
    final expires = data['expiresAt'];
    if (expires is Timestamp && !expires.toDate().isAfter(DateTime.now())) throw StateError('story_expired');
    if (authorId.isNotEmpty && authorId != u.uid && await _isBlockedEitherWay(u.uid, authorId)) throw StateError('social_action_blocked');
    await db.collection('stories').doc(id).collection('viewers').doc(u.uid).set({'uid': u.uid, 'viewedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }
  static Future<void> reactToStory(String storyId,String reaction) async {
    final u=user;
    if(u==null)throw StateError('not_authenticated');
    final id=storyId.trim(),value=reaction.trim();
    if(id.isEmpty||!const {'❤️'}.contains(value))throw ArgumentError('invalid_story_reaction');
    final story=await db.collection('stories').doc(id).get();
    if(!story.exists)throw StateError('story_not_found');
    final data=story.data()??const <String,dynamic>{};
    final authorId=data['authorId']?.toString()??'';
    final expires=data['expiresAt'];
    if(expires is Timestamp&&!expires.toDate().isAfter(DateTime.now()))throw StateError('story_expired');
    if(authorId.isNotEmpty&&authorId!=u.uid&&await _isBlockedEitherWay(u.uid,authorId))throw StateError('social_action_blocked');
    await db.collection('stories').doc(id).collection('reactions').doc(u.uid).set({'uid':u.uid,'reaction':value,'createdAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
  }

  static Future<void> updateProviderProfile({required String vehicleType,required String vehicleModel,required String plate,required bool available}) async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    final type=vehicleType.trim(),model=vehicleModel.trim(),p=plate.trim().toUpperCase();
    if(type.isEmpty||type.length>80||model.length>80||p.isEmpty||p.length>24)throw StateError('invalid_provider_profile');
    final ref=db.collection('users').doc(u.uid);
    await db.runTransaction<void>((tx)async{
      final snap=await tx.get(ref);final data=snap.data()??const <String,dynamic>{};final role=data['role']?.toString();
      if(!{'driver','deliveryProvider','partner'}.contains(role))throw StateError('not_provider');
      if(available){
        if(_accountSuspended(data))throw StateError('account_suspended');
        if(_providerDocumentsExpired(data))throw StateError('provider_documents_expired');
        if(data['providerVerified']!=true)throw StateError('provider_not_verified');
      }
      tx.set(ref,{'vehicleType':type,'vehicleModel':model,'vehiclePlate':p,'providerAvailable':available,'providerUpdatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
    });
  }
  static Future<void> setProviderAvailability(bool available) async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    final ref=db.collection('users').doc(u.uid);
    await db.runTransaction<void>((tx) async {
      final snap=await tx.get(ref);final d=snap.data()??const <String,dynamic>{};final role=d['role']?.toString();
      if(!{'driver','deliveryProvider','partner'}.contains(role))throw StateError('not_provider');
      if(available){
        if(_accountSuspended(d))throw StateError('account_suspended');
        if(_providerDocumentsExpired(d))throw StateError('provider_documents_expired');
        if(d['providerVerified']!=true)throw StateError('provider_not_verified');
        if(role!='partner'&&((d['vehicleType']?.toString().trim()??'').isEmpty||(d['vehiclePlate']?.toString().trim()??'').isEmpty))throw StateError('provider_profile_required');
      }
      tx.set(ref,{'providerAvailable':available,'providerUpdatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
    });
  }
  static Future<void> eventRsvp(String eventId) async {
    final u = user;
    if (u == null) throw StateError('not_authenticated');
    final id = eventId.trim();
    if (id.isEmpty) throw ArgumentError('invalid_event_id');
    final eventRef = db.collection('events').doc(id);
    final attendeeRef = eventRef.collection('attendees').doc(u.uid);
    await db.runTransaction<void>((tx) async {
      final eventSnap = await tx.get(eventRef);
      final attendeeSnap = await tx.get(attendeeRef);
      if (!eventSnap.exists) throw StateError('event_not_found');
      final event = eventSnap.data() ?? const <String, dynamic>{};
      if (event['status'] != 'published') throw StateError('event_not_open');
      final startsAt = event['startsAt'];
      if (startsAt is Timestamp && !startsAt.toDate().isAfter(DateTime.now())) throw StateError('event_already_started');
      if (!attendeeSnap.exists) {
        final capacity = (event['capacity'] as num?)?.toInt();
        if (capacity != null) {
          final attendees = await eventRef.collection('attendees').get();
          if (attendees.size >= capacity) throw StateError('event_full');
        }
        tx.set(attendeeRef, {'uid': u.uid, 'createdAt': FieldValue.serverTimestamp(), 'status': 'confirmed'});
      }
    });
  }
  static Future<void> eventUnrsvp(String eventId) async {
    final u = user;
    if (u == null) throw StateError('not_authenticated');
    final id = eventId.trim();
    if (id.isEmpty) throw ArgumentError('invalid_event_id');
    await db.collection('events').doc(id).collection('attendees').doc(u.uid).delete();
  }
  static Stream<DocumentSnapshot<Map<String,dynamic>>> eventAttendance(String eventId) => user==null?const Stream.empty():db.collection('events').doc(eventId).collection('attendees').doc(user!.uid).snapshots();
  static Stream<QuerySnapshot<Map<String,dynamic>>> searchUsers(String term) {final q=term.trim().toLowerCase();if(q.isEmpty)return const Stream.empty();return db.collection('publicProfiles').where('visibility',isEqualTo:'public').orderBy('displayNameLower').startAt([q]).endAt(['$q\uf8ff']).limit(20).snapshots();}

  // Company operations: branch-specific hours and service coverage are editable data, not UI placeholders.
  static Future<void> _requireCompanyOwner(String companyId) async {
    final u=user; if(u==null) throw StateError('not_authenticated');
    final snap=await db.collection('companies').doc(companyId).get();
    if(!snap.exists) throw StateError('company_not_found');
    if(snap.data()?['ownerId']!=u.uid && !(await hasCapability(Capability.manageServices))) throw StateError('not_company_owner');
  }
  static Stream<QuerySnapshot<Map<String,dynamic>>> companyBranches(String companyId) => db.collection('companies').doc(companyId).collection('branches').orderBy('name').snapshots();
  static Future<String> saveCompanyBranch(String companyId,{String? branchId,required String name,required String address,required Map<String,String> openingHours,required List<String> serviceAreas}) async {
    await _requireCompanyOwner(companyId); final n=name.trim(),a=address.trim();
    if(n.isEmpty||n.length>120||a.isEmpty||a.length>300||openingHours.length>7||serviceAreas.length>100||openingHours.values.any((v)=>v.length>80)||serviceAreas.any((v)=>v.trim().isEmpty||v.trim().length>100)) throw ArgumentError('invalid_branch');
    final ref=db.collection('companies').doc(companyId).collection('branches').doc(branchId);
    final data=<String,dynamic>{'name':n,'address':a,'openingHours':openingHours,'serviceAreas':serviceAreas.map((e)=>e.trim()).toSet().toList(),'active':true,'updatedAt':FieldValue.serverTimestamp()};
    if(branchId==null){final created=db.collection('companies').doc(companyId).collection('branches').doc();data['createdAt']=FieldValue.serverTimestamp();await created.set(data);return created.id;} await ref.set(data,SetOptions(merge:true));return ref.id;
  }
  static Future<void> setCompanyBranchActive(String companyId,String branchId,bool active) async {await _requireCompanyOwner(companyId);await db.collection('companies').doc(companyId).collection('branches').doc(branchId).update({'active':active,'updatedAt':FieldValue.serverTimestamp()});}
  static Stream<QuerySnapshot<Map<String,dynamic>>> companyAppointments(String companyId) => db.collection('companies').doc(companyId).collection('appointments').orderBy('requestedAt',descending:true).limit(100).snapshots();
  static Future<String> requestCompanyAppointment(String companyId,{String? branchId,required DateTime startsAt,required String service, String note=''}) async {
    final u=user;if(u==null)throw StateError('not_authenticated');final s=service.trim(),n=note.trim();
    if(s.isEmpty||s.length>160||n.length>1000||!startsAt.isAfter(DateTime.now()))throw ArgumentError('invalid_appointment');
    final company=await db.collection('companies').doc(companyId).get();if(!company.exists||company.data()?['active']==false)throw StateError('company_unavailable');
    final ref=db.collection('companies').doc(companyId).collection('appointments').doc();
    await ref.set({'userId':u.uid,'branchId':branchId,'service':s,'note':n,'startsAt':Timestamp.fromDate(startsAt),'status':'requested','requestedAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()});return ref.id;
  }
  static Future<void> updateCompanyAppointmentStatus(String companyId,String appointmentId,String status) async {
    await _requireCompanyOwner(companyId);if(!{'confirmed','rejected','completed','cancelled','waitlisted'}.contains(status))throw ArgumentError('invalid_appointment_status');
    await db.collection('companies').doc(companyId).collection('appointments').doc(appointmentId).update({'status':status,'updatedAt':FieldValue.serverTimestamp()});
  }
  static Future<String> joinCompanyWaitlist(String companyId,{String? branchId,required String service}) async {
    final u=user;if(u==null)throw StateError('not_authenticated');final s=service.trim();if(s.isEmpty||s.length>160)throw ArgumentError('invalid_service');
    final ref=db.collection('companies').doc(companyId).collection('waitlist').doc();await ref.set({'userId':u.uid,'branchId':branchId,'service':s,'status':'waiting','createdAt':FieldValue.serverTimestamp()});return ref.id;
  }
  static Stream<QuerySnapshot<Map<String,dynamic>>> companyWaitlist(String companyId) => db.collection('companies').doc(companyId).collection('waitlist').orderBy('createdAt').limit(100).snapshots();
  static Future<void> updateWaitlistStatus(String companyId,String entryId,String status) async {await _requireCompanyOwner(companyId);if(!{'waiting','notified','served','cancelled'}.contains(status))throw ArgumentError('invalid_waitlist_status');await db.collection('companies').doc(companyId).collection('waitlist').doc(entryId).update({'status':status,'updatedAt':FieldValue.serverTimestamp()});}

  static Future<String> createCompany(String name, String category) async {
    final u = user;
    final n = name.trim(), c = category.trim();
    if (u == null) throw StateError('not_authenticated');
    if (n.isEmpty || n.length > 160 || c.isEmpty || c.length > 100) throw StateError('invalid_company');
    final profile = await db.collection('users').doc(u.uid).get();
    final data = profile.data() ?? const <String, dynamic>{};
    if (data['role'] != 'partner' || data['providerVerified'] != true) throw StateError('verified_partner_required');
    final ref = db.collection('companies').doc();
    await ref.set({'name': n, 'category': c, 'ownerId': u.uid, 'createdAt': FieldValue.serverTimestamp(), 'active': true});
    return ref.id;
  }
  static Stream<QuerySnapshot<Map<String,dynamic>>> companyEmployees(String companyId)=>db.collection('employees').where('companyId',isEqualTo:companyId).snapshots();
  static Future<void> claimEmployeeProfile() async {
    final u=user;if(u==null||u.email==null)throw StateError('not_authenticated');
    final q=await db.collection('employees').where('email',isEqualTo:u.email!.trim().toLowerCase()).where('status',isEqualTo:'pending').limit(1).get();
    if(q.docs.isEmpty)throw StateError('employee_invite_not_found');
    await acceptEmployeeInvite(q.docs.first.id);
  }
  static Stream<QuerySnapshot<Map<String,dynamic>>> companyProducts(String companyId)=>db.collection('companies').doc(companyId).collection('products').orderBy('name').snapshots();
  static Future<void> addEmployee(String companyId, String email, String name) async {
    final u = user;
    if (u == null) throw StateError('not_authenticated');
    final company = companyId.trim(), e = email.trim().toLowerCase(), n = name.trim();
    if (company.isEmpty || e.length < 5 || !e.contains('@') || n.isEmpty || n.length > 120) throw StateError('invalid_employee');
    final companyRef = db.collection('companies').doc(company);
    final companySnap = await companyRef.get();
    if (!companySnap.exists) throw StateError('company_not_found');
    if (companySnap.data()?['ownerId'] != u.uid) throw StateError('not_company_owner');
    final invites = db.collection('employees');
    final duplicate = await invites.where('companyId', isEqualTo: company).where('email', isEqualTo: e).where('status', isEqualTo: 'pending').limit(1).get();
    if (duplicate.docs.isNotEmpty) throw StateError('employee_invite_already_pending');
    final ref = invites.doc();
    await ref.set({'companyId': company, 'email': e, 'displayName': n, 'status': 'pending', 'userId': null, 'createdBy': u.uid, 'createdAt': FieldValue.serverTimestamp()});
  }
  static Stream<QuerySnapshot<Map<String,dynamic>>> pendingEmployeeInvites() { final u=user;if(u==null||u.email==null)return const Stream.empty();return db.collection('employees').where('email',isEqualTo:u.email!.trim().toLowerCase()).where('status',isEqualTo:'pending').snapshots(); }
  static Future<void> acceptEmployeeInvite(String employeeId) async {
    final u = user;
    final email = u?.email?.trim().toLowerCase();
    if (u == null || email == null || email.isEmpty) throw StateError('not_authenticated');
    final inviteRef = db.collection('employees').doc(employeeId.trim());
    final userRef = db.collection('users').doc(u.uid);
    final employeeProfileRef = db.collection('employeeProfiles').doc(u.uid);
    String displayName = 'مستخدم LEF_LEF';
    await db.runTransaction<void>((tx) async {
      final inviteSnap = await tx.get(inviteRef);
      final userSnap = await tx.get(userRef);
      if (!inviteSnap.exists) throw StateError('invite_not_found');
      final invite = inviteSnap.data() ?? const <String, dynamic>{};
      if (invite['email']?.toString().trim().toLowerCase() != email || invite['status'] != 'pending' || (invite['userId'] != null && invite['userId'] != u.uid)) throw StateError('invite_not_allowed');
      final userData = userSnap.data() ?? const <String, dynamic>{};
      final role = userData['role']?.toString() ?? 'client';
      if (role != 'client') throw StateError('account_role_conflict');
      final companyId = invite['companyId']?.toString() ?? '';
      if (companyId.isEmpty) throw StateError('invite_company_missing');
      displayName = userData['displayName']?.toString() ?? 'مستخدم LEF_LEF';
      tx.update(inviteRef, {'userId': u.uid, 'status': 'active', 'activatedAt': FieldValue.serverTimestamp()});
      tx.set(employeeProfileRef, {'uid': u.uid, 'companyId': companyId, 'employeeId': inviteRef.id, 'updatedAt': FieldValue.serverTimestamp()});
      tx.update(userRef, {'role': 'employee', 'roleSelected': true, 'capabilities': <String>[], 'updatedAt': FieldValue.serverTimestamp()});
    });
    try {
      await db.collection('publicProfiles').doc(u.uid).set({'uid': u.uid, 'displayName': displayName, 'displayNameLower': displayName.toLowerCase(), 'role': 'employee', 'visibility':'public', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      debugPrint('LEF_LEF employee public-profile sync failed: ${e.code} ${e.message}');
    }
  }
  static Future<void> rejectEmployeeInvite(String employeeId) async {
    final u = user;
    final email = u?.email?.trim().toLowerCase();
    if (u == null || email == null || email.isEmpty) throw StateError('not_authenticated');
    final ref = db.collection('employees').doc(employeeId.trim());
    await db.runTransaction<void>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('invite_not_found');
      final d = snap.data() ?? const <String, dynamic>{};
      if (d['email']?.toString().trim().toLowerCase() != email || d['status'] != 'pending') throw StateError('invite_not_allowed');
      tx.update(ref, {'status': 'rejected', 'rejectedAt': FieldValue.serverTimestamp()});
    });
  }
  static Future<void> addProduct(String companyId,String name,double price,int stock) async { final u=user;if(u==null||name.trim().isEmpty||!price.isFinite||price<0||stock<0)throw StateError('invalid_product');final c=await db.collection('companies').doc(companyId).get();if(!c.exists||c.data()?['ownerId']!=u.uid){final ep=await db.collection('employeeProfiles').doc(u.uid).get();if(ep.data()?['companyId']!=companyId)throw StateError('not_company_member');}await db.collection('companies').doc(companyId).collection('products').add({'name':name.trim(),'price':price,'stock':stock,'active':true,'createdBy':u.uid,'createdAt':FieldValue.serverTimestamp()}); }
  static Future<bool> sellProductUnit(String companyId,String productId) async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    final companyRef=db.collection('companies').doc(companyId);
    final productRef=companyRef.collection('products').doc(productId);
    final company=await companyRef.get();if(!company.exists)throw StateError('company_not_found');
    final owner=company.data()?['ownerId']==u.uid;
    if(!owner){final ep=await db.collection('employeeProfiles').doc(u.uid).get();if(ep.data()?['companyId']!=companyId)throw StateError('not_company_member');}
    return db.runTransaction<bool>((tx) async {
      final snap=await tx.get(productRef);final d=snap.data();
      if(d==null)throw StateError('product_not_found');
      if(d['active']==false)throw StateError('product_inactive');
      final stock=(d['stock'] as num?)?.toInt()??0;
      if(stock<=0)return false;
      tx.update(productRef,{'stock':stock-1,'updatedAt':FieldValue.serverTimestamp()});
      return true;
    });
  }
  static Future<void> changeProductStock(String companyId,String productId,int stock) async { final u=user;if(u==null)throw StateError('not_authenticated');if(stock<0)throw StateError('invalid_stock');final c=await db.collection('companies').doc(companyId).get();if(!c.exists)throw StateError('company_not_found');final owner=c.data()?['ownerId']==u.uid;if(!owner){final ep=await db.collection('employeeProfiles').doc(u.uid).get();if(ep.data()?['companyId']!=companyId)throw StateError('not_company_member');}await db.collection('companies').doc(companyId).collection('products').doc(productId).update({'stock':stock,'updatedAt':FieldValue.serverTimestamp()}); }
  static Future<void> updateProduct(String companyId,String productId,String name,double price) async {
    final u=user;if(u==null)throw StateError('not_authenticated');final n=name.trim();
    if(n.isEmpty||n.length>120||!price.isFinite||price<0)throw StateError('invalid_product');
    final c=await db.collection('companies').doc(companyId).get();if(!c.exists)throw StateError('company_not_found');
    if(c.data()?['ownerId']!=u.uid)throw StateError('not_company_owner');
    await c.reference.collection('products').doc(productId).update({'name':n,'price':price,'updatedAt':FieldValue.serverTimestamp()});
  }
  static Future<void> deleteProduct(String companyId,String productId) async {
    final u=user;if(u==null)throw StateError('not_authenticated');
    final c=await db.collection('companies').doc(companyId).get();if(!c.exists)throw StateError('company_not_found');
    if(c.data()?['ownerId']!=u.uid)throw StateError('not_company_owner');
    await c.reference.collection('products').doc(productId).delete();
  }
}
