import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../core/theme.dart';
import '../models/app_models.dart';
import '../services/firebase_service.dart';
import '../services/app_prefs.dart';
import '../services/route_service.dart';
import '../widgets/map_message_pin.dart';
import 'ride_message_map_screen.dart';

class MapScreen extends StatefulWidget { const MapScreen({super.key, this.initialKind, this.initialRideId}); final ServiceKind? initialKind; final String? initialRideId; @override State<MapScreen> createState()=>_MapState(); }
class _MapState extends State<MapScreen> {
  final map=MapController();
  final _recipientName=TextEditingController();
  final _recipientPhone=TextEditingController();
  final _parcelCategory=TextEditingController(text:'طرد عادي');
  final _parcelNotes=TextEditingController();
  double panel=.38; ServiceKind selected=ServiceKind.taxiMoto; RideStatus status=RideStatus.draft; String? rideId; String? providerId; Map<String,dynamic> providerInfo={}; double fare=0,distanceKm=0; bool? activeRideNegotiable; bool clientArrivalConfirmed=false; int routeMinutes=0; DateTime? providerLocationUpdatedAt; bool routing=false; bool mapPickingPickup=true; bool resolvingPlace=false; int _mapTapSequence=0; int _routeRequestSequence=0; String? liveMapMessage; LatLng? liveMapMessageLocation; LatLng? currentLocation; LatLng? providerLocation; List<LatLng> routePoints=[]; StreamSubscription? rideSub; Map<String, dynamic> ridePricing = FirebaseService.defaultRidePricing(); bool pricingLoading = true;
  LatLng pickup=const LatLng(0,0); LatLng destination=const LatLng(0,0); String place='حط نقطة الانطلاق على الخريطة'; String destinationName='حط الوجهة على الخريطة';
  ServiceOption get option=>serviceOptions.firstWhere((e)=>e.kind==selected);
  @override void initState(){super.initState(); if(widget.initialKind!=null) selected=widget.initialKind!; _loadRidePricing(); WidgetsBinding.instance.addPostFrameCallback((_)=>_restoreActiveRide());}
  Future<void> _loadRidePricing() async { try { final loaded = await FirebaseService.getRidePricing(); if(!mounted)return; setState(() { ridePricing = loaded; pricingLoading = false; if(status==RideStatus.draft) _recalc(); }); } catch(e) { debugPrint('LEF_LEF pricing load failed; using defaults: $e'); if(mounted)setState(()=>pricingLoading=false); } }
  bool _isNegotiable(ServiceOption o) => Set<String>.from(ridePricing['negotiableKinds'] as List? ?? const <String>[]).contains(o.kind.name);
  bool get _currentRideIsNegotiable => status == RideStatus.draft ? _isNegotiable(option) : (activeRideNegotiable ?? _isNegotiable(option));
  double _configuredBase(ServiceOption o) => ((ridePricing['baseFares'] as Map?)?[o.kind.name] as num?)?.toDouble() ?? o.base;
  double _configuredRate(ServiceOption o, bool night) => (((ridePricing[night ? 'nightRates' : 'dayRates'] as Map?)?[o.kind.name]) as num?)?.toDouble() ?? (night ? o.nightKm : o.dayKm);
  Future<void> _restoreActiveRide() async {
    try {
      final requestedId=widget.initialRideId?.trim();
      final doc=(requestedId!=null&&requestedId.isNotEmpty)
          ? await FirebaseService.db.collection('rides').doc(requestedId).get()
          : await FirebaseService.activeRideForClient();
      if(!mounted||doc==null||!doc.exists)return;
      final x=doc.data()??const <String,dynamic>{};
      final uid=FirebaseService.user?.uid;
      final viewerProfile=uid==null?null:(await FirebaseService.db.collection('users').doc(uid).get()).data();
      final privilegedViewer={'owner','manager'}.contains(viewerProfile?['role']?.toString());
      if(uid==null || (!privilegedViewer && x['clientId']?.toString()!=uid && x['providerId']?.toString()!=uid)) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما عندكش صلاحية تشوف الطلب هذا.')));
        return;
      }
      final parsed=RideStatus.values.where((e)=>e.name==x['status']?.toString());
      final kind=ServiceKind.values.where((e)=>e.name==x['kind']?.toString());
      final plat=(x['pickupLat'] as num?)?.toDouble(), plng=(x['pickupLng'] as num?)?.toDouble();
      final dlat=(x['destinationLat'] as num?)?.toDouble(), dlng=(x['destinationLng'] as num?)?.toDouble();
      if(parsed.isEmpty||kind.isEmpty||plat==null||plng==null||dlat==null||dlng==null||!plat.isFinite||!plng.isFinite||!dlat.isFinite||!dlng.isFinite||plat < -90||plat > 90||dlat < -90||dlat > 90||plng < -180||plng > 180||dlng < -180||dlng > 180||(plat==0&&plng==0)||(dlat==0&&dlng==0))return;
      final pLat=(x['providerLat'] as num?)?.toDouble(), pLng=(x['providerLng'] as num?)?.toDouble();
      setState((){
        rideId=doc.id; status=parsed.first; selected=kind.first; activeRideNegotiable=x['negotiable']==true; pickup=LatLng(plat,plng); destination=LatLng(dlat,dlng);
        place=(x['pickup']??'نقطة الانطلاق').toString(); destinationName=(x['destination']??'الوجهة').toString();
        fare=(((x['status']?.toString()=='countered' ? x['clientCounterFare'] : null) as num?)?.toDouble()??(x['finalFare'] as num?)?.toDouble()??(x['offerFare'] as num?)?.toDouble()??(x['estimatedFare'] as num?)?.toDouble()??0); distanceKm=((x['distanceKm'] as num?)?.toDouble()??0); providerId=x['providerId']?.toString(); providerInfo=Map<String,dynamic>.from(x['providerInfo'] is Map ? x['providerInfo'] as Map : const {});
        providerLocation=pLat!=null&&pLng!=null?LatLng(pLat,pLng):null; providerLocationUpdatedAt=x['locationUpdatedAt'] is Timestamp ? (x['locationUpdatedAt'] as Timestamp).toDate() : null; final ml=(x['mapMessageLat'] as num?)?.toDouble(), mn=(x['mapMessageLng'] as num?)?.toDouble(); liveMapMessage=(x['mapMessage']??'').toString().trim().isEmpty?null:x['mapMessage'].toString(); liveMapMessageLocation=ml!=null&&mn!=null?LatLng(ml,mn):null;
      });
      await AppPrefs.setActiveRide(doc.id);
      _watchRide(doc.id);
      if(_hasRouteEndpoints)await _loadRoute();
    } catch(e,st){debugPrint('LEF_LEF active ride restore failed: $e');debugPrintStack(stackTrace:st);}
  }
  @override void dispose(){rideSub?.cancel();_recipientName.dispose();_recipientPhone.dispose();_parcelCategory.dispose();_parcelNotes.dispose();super.dispose();}
  Future<void> _rateCompletedRide() async {
    final id=rideId;
    if(id==null||id.isEmpty)return;
    int score=5; final comment=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(
      title:const Text('قيّم الخدمة'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        const Text('تقييمك يعاوننا نحسّنوا الخدمة.'),
        DropdownButtonFormField<int>(value:score,decoration:const InputDecoration(labelText:'النجوم'),items:[1,2,3,4,5].map((v)=>DropdownMenuItem(value:v,child:Text('$v / 5'))).toList(),onChanged:(v){if(v!=null)setD(()=>score=v);}),
        TextField(controller:comment,maxLength:600,maxLines:3,decoration:const InputDecoration(labelText:'ملاحظة (اختيارية)')),
      ]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ابعث التقييم'))])));
    if(ok==true){try{await FirebaseService.submitRideRating(rideId:id,score:score,comment:comment.text);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('التقييم تسجّل.')));}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما تسجّلش التقييم: يمكن سبق وقيّمت الخدمة.')));}}
    comment.dispose();
  }
  Future<void> _reportCompletedRide() async {
    final id=rideId;if(id==null||id.isEmpty)return;
    final reason=TextEditingController(),details=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('شكوى على الخدمة'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:reason,maxLength:120,decoration:const InputDecoration(labelText:'سبب الشكوى')),TextField(controller:details,maxLength:1200,maxLines:3,decoration:const InputDecoration(labelText:'التفاصيل (اختيارية)'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ابعث للمتابعة'))]));
    if(ok==true){try{await FirebaseService.reportRide(rideId:id,reason:reason.text,details:details.text);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('الشكوى تبعثت للمتابعة.')));}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما تبعثتش الشكوى. تثبّت من السبب والإنترنت.')));}}
    reason.dispose();details.dispose();
  }
  bool get _hasPickup => pickup.latitude != 0 && pickup.longitude != 0;
  bool get _hasDestination => destination.latitude != 0 && destination.longitude != 0;
  bool get _hasRouteEndpoints => _hasPickup && _hasDestination;

  Future<void> _loadRoute() async {
    final requestId = ++_routeRequestSequence;
    if (!_hasRouteEndpoints) {
      if (mounted) setState(() { routePoints=[]; routeMinutes=0; distanceKm=0; if(status==RideStatus.draft) fare=0; routing=false; });
      return;
    }
    final from=pickup, to=destination;
    if (mounted) setState(()=>routing=true);
    try {
      final r=await RouteService.roadRoute(from,to);
      if(!mounted || requestId != _routeRequestSequence)return;
      final stillCurrent=pickup.latitude==from.latitude&&pickup.longitude==from.longitude&&destination.latitude==to.latitude&&destination.longitude==to.longitude;
      if(!stillCurrent)return;
      setState(() { routePoints=r.points; distanceKm=r.distanceKm; routeMinutes=r.durationMinutes; if(status==RideStatus.draft) _recalc(); });
    } catch(e) {
      debugPrint('LEF_LEF route calculation failed: $e');
      final stillCurrent=pickup.latitude==from.latitude&&pickup.longitude==from.longitude&&destination.latitude==to.latitude&&destination.longitude==to.longitude;
      if(mounted&&requestId==_routeRequestSequence&&stillCurrent)setState(() { routePoints=[]; routeMinutes=0; distanceKm=0; if(status==RideStatus.draft) fare=0; });
    } finally {
      if(mounted&&requestId==_routeRequestSequence)setState(()=>routing=false);
    }
  }
  Future<void> locate() async {
    try {
      if(!await Geolocator.isLocationServiceEnabled()){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('الموقع مطفّي في التليفون.')));return;}
      var p=await Geolocator.checkPermission(); if(p==LocationPermission.denied)p=await Geolocator.requestPermission();
      if(p==LocationPermission.denied||p==LocationPermission.deniedForever){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('يلزم إذن الموقع باش نخدمو التتبع المباشر.')));return;}
      final pos=await Geolocator.getCurrentPosition(); final here=LatLng(pos.latitude,pos.longitude); if(!mounted)return;
      map.move(here,15); setState(()=>currentLocation=here);
      if(status==RideStatus.draft){setState((){pickup=here;place='بلاصتك توا';routePoints=[];routeMinutes=0;distanceKm=0;fare=0;});if(_hasRouteEndpoints)await _loadRoute();}
    } catch(e){debugPrint('LEF_LEF current location failed: $e');if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نجيب بلاصتك توا.')));}
  }
  void _recalc(){if(_isNegotiable(option)||distanceKm<=0||!_hasRouteEndpoints){fare=0;return;}final night=DateTime.now().hour>=22||DateTime.now().hour<6;fare=_configuredBase(option)+distanceKm*_configuredRate(option,night);}
  int? _driverEtaMinutes(){final p=providerLocation;final updated=providerLocationUpdatedAt;if(p==null||updated==null||DateTime.now().difference(updated)>const Duration(minutes:2)||!_hasPickup)return null;final meters=Geolocator.distanceBetween(p.latitude,p.longitude,pickup.latitude,pickup.longitude);if(!meters.isFinite||meters<0)return null;return ((meters/1000*1.35/22*60)+2).ceil().clamp(1,180).toInt();}
  String _ridePriceLabel(){if(status==RideStatus.offered)return 'عرض السائق';if(status==RideStatus.countered)return 'عرضك المضاد';if({RideStatus.accepted,RideStatus.arriving,RideStatus.arrived,RideStatus.active,RideStatus.completed}.contains(status))return 'السعر النهائي';return 'السعر الحالي';}
  Future<void> _handleMapTap(LatLng point) async {
    if (status != RideStatus.draft) return;
    final tapSequence = ++_mapTapSequence;
    if (mounted) setState(() => resolvingPlace = true);
    final isPickup = mapPickingPickup;
    String label = 'موقع على الخريطة';
    try {
      final result = await RouteService.reverseGeocode(point);
      final name = result?.displayName.trim();
      if (name != null && name.isNotEmpty) label = name;
    } catch (e) {
      debugPrint('LEF_LEF reverse geocoding failed: $e');
    }
    if (!mounted || tapSequence != _mapTapSequence) return;
    setState(() {
      if (isPickup) { pickup = point; place = label; }
      else { destination = point; destinationName = label; }
      routePoints = []; routeMinutes = 0; distanceKm = 0; fare = 0; providerLocation = null;
      resolvingPlace = false;
    });
    if (_hasRouteEndpoints && (pickup.latitude != destination.latitude || pickup.longitude != destination.longitude)) await _loadRoute();
  }
  void _watchRide(String id){rideSub?.cancel();rideSub=FirebaseService.rideStream(id).listen((snap){final x=snap.data();if(x==null||!mounted)return;final raw=x['status']?.toString();final p=RideStatus.values.where((e)=>e.name==raw);if(p.isNotEmpty){final next=p.first;if(next==RideStatus.completed||next==RideStatus.cancelled)AppPrefs.clearActiveRide();setState((){status=next;activeRideNegotiable=x['negotiable']==true;clientArrivalConfirmed=x['clientArrivalConfirmed']==true;final counter=(x['clientCounterFare'] as num?)?.toDouble();final finalFare=(x['finalFare'] as num?)?.toDouble();final of=(x['offerFare'] as num?)?.toDouble();if(next==RideStatus.countered&&counter!=null)fare=counter;else if(finalFare!=null)fare=finalFare;else if(of!=null)fare=of; providerId=x['providerId']?.toString(); providerInfo=Map<String,dynamic>.from(x['providerInfo'] is Map ? x['providerInfo'] as Map : const {}); final lat=(x['providerLat'] as num?)?.toDouble(); final lng=(x['providerLng'] as num?)?.toDouble(); if(lat!=null&&lng!=null)providerLocation=LatLng(lat,lng); providerLocationUpdatedAt=x['locationUpdatedAt'] is Timestamp ? (x['locationUpdatedAt'] as Timestamp).toDate() : null; final ml=(x['mapMessageLat'] as num?)?.toDouble(), mn=(x['mapMessageLng'] as num?)?.toDouble(); liveMapMessage=(x['mapMessage']??'').toString().trim().isEmpty?null:x['mapMessage'].toString(); liveMapMessageLocation=ml!=null&&mn!=null?LatLng(ml,mn):null;});}});}
  Future<void> start() async {
    try {
      if(status==RideStatus.draft){if({ServiceKind.deliveryMoto,ServiceKind.deliveryVan,ServiceKind.deliveryTruck}.contains(selected)&&(_recipientName.text.trim().length<2||_recipientPhone.text.trim().length<8||_parcelCategory.text.trim().isEmpty)){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('كمّل اسم المستلِم وتليفونو ونوع الطرد قبل ما تبعث الطلب.')));return;}if(!_hasPickup||!_hasDestination||(pickup.latitude==destination.latitude&&pickup.longitude==destination.longitude)||routePoints.length<2||!distanceKm.isFinite||distanceKm<=0){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('اختار الانطلاق والوجهة واستنى حساب الثنية.')));return;}providerLocation=null;providerId=null;providerInfo={};providerLocationUpdatedAt=null;final pricingNow=DateTime.now();final isNight=pricingNow.hour>=22||pricingNow.hour<6;final pricingRate=_isNegotiable(option)?0.0:_configuredRate(option,isNight);final pricingBase=_isNegotiable(option)?0.0:_configuredBase(option);if(_isNegotiable(option)){fare=0;}else{fare=pricingBase+distanceKm*pricingRate;}if(fare>200){final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('طلب بقيمة كبيرة'),content:Text('السعر التقديري ${fare.toStringAsFixed(2)} د.ت. ثبّت قبل ما تبعث الطلب.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('راجع')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('أكد'))]));if(ok!=true)return;}rideId=await FirebaseService.createRide(kind:selected,pickup:place,destination:destinationName,estimatedFare:fare,distanceKm:distanceKm,baseFare:pricingBase,ratePerKm:pricingRate,pricingPeriod:isNight?'night':'day',pickupLat:pickup.latitude,pickupLng:pickup.longitude,destinationLat:destination.latitude,destinationLng:destination.longitude,deliveryRecipientName:_recipientName.text,deliveryRecipientPhone:_recipientPhone.text,parcelCategory:_parcelCategory.text,parcelNotes:_parcelNotes.text);activeRideNegotiable=_isNegotiable(option);await AppPrefs.setActiveRide(rideId!);_watchRide(rideId!);status=RideStatus.searching;}
      else if(status==RideStatus.offered){await _reviewOffer();}
      else if(status==RideStatus.completed||status==RideStatus.cancelled){await AppPrefs.clearActiveRide();status=RideStatus.draft;rideId=null;activeRideNegotiable=null;fare=option.base;providerLocation=null;providerId=null;providerInfo={};providerLocationUpdatedAt=null;}
      if(mounted)setState((){});
    } catch (e) { debugPrint('LEF_LEF map operation failed: $e'); if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نعمل ولا نحدّث الطلب.'))); }
  }
  Future<void> cancel() async {
    if(rideId==null)return;
    final reason=TextEditingController();
    final confirmed=await showDialog<String>(context:context,builder:(c)=>AlertDialog(
      title:const Text('تلغي الطلب؟'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        const Text('اختار سبب الإلغاء باش يكون واضح للحريف/السائق.'),
        const SizedBox(height:10),
        TextField(controller:reason,maxLength:300,maxLines:2,decoration:const InputDecoration(labelText:'سبب الإلغاء',hintText:'مثال: تبدّلت الخطة أو الموقع موش صحيح')),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,null),child:const Text('خليه كيف ما هو')),
        FilledButton(onPressed:()=>Navigator.pop(c,reason.text.trim().isEmpty?'إلغاء من الحريف':reason.text.trim()),child:const Text('إلغي الطلب'))],
    ));
    reason.dispose();
    if(confirmed==null)return;
    final ok=await FirebaseService.cancelRide(rideId!,reason:confirmed);
    if(ok)await AppPrefs.clearActiveRide();
    if(mounted)setState(()=>status=ok?RideStatus.cancelled:status);
    if(mounted&&!ok)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('الطلب هذا ما عادش ينجم يتلغى.')));
  }

  Future<void> _reviewOffer() async {
    final id=rideId;if(id==null)return;
    final action=await showDialog<String>(context:context,builder:(c)=>AlertDialog(title:const Text('عرض السائق'),content:Text('العرض الحالي: ${fare.toStringAsFixed(2)} د.ت'),actions:[if(_currentRideIsNegotiable)TextButton(onPressed:()=>Navigator.pop(c,'counter'),child:const Text('عرض مضاد')),FilledButton(onPressed:()=>Navigator.pop(c,'accept'),child:const Text('اقبل'))]));
    if(action=='accept'){if(fare>200){final confirm=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('قبول طلب بقيمة كبيرة'),content:Text('العرض هذا ${fare.toStringAsFixed(2)} د.ت. ثبّت قبل القبول.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('راجع')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('اقبل'))]));if(confirm!=true)return;}final ok=await FirebaseService.acceptOffer(id); if(!ok&&mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('العرض ما عادش متاح.')));}
    else if(action=='counter'){
      final ctl=TextEditingController(text:fare.toStringAsFixed(2));
      final v=await showDialog<double>(context:context,builder:(c)=>AlertDialog(title:const Text('عرض مضاد'),content:TextField(controller:ctl,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'السعر (د.ت)')),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,double.tryParse(ctl.text.replaceAll(',','.'))),child:const Text('ابعث'))]));
      ctl.dispose();if(v!=null&&v.isFinite&&v>0){if(v>200){final confirm=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('عرض مضاد بقيمة كبيرة'),content:Text('العرض المضاد متاعك ${v.toStringAsFixed(2)} د.ت. ثبّت قبل الإرسال.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('راجع')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('أكد'))]));if(confirm!=true)return;}final ok=await FirebaseService.sendClientCounter(id,v); if(!ok&&mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نبعث العرض المضاد.')));}
    }
  }
  Future<void> _choosePlace({required bool pickupMode}) async {
    final controller=TextEditingController();
    final chosen=await showDialog<PlaceResult>(context:context,builder:(dialogContext)=>AlertDialog(title:Text(pickupMode?'اختار نقطة الانطلاق':'اختار الوجهة'),content:TextField(controller:controller,autofocus:true,textInputAction:TextInputAction.search,decoration:const InputDecoration(hintText:'اكتب اسم البلاصة')),actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('إلغاء')),FilledButton(onPressed:()async{final q=controller.text.trim();if(q.isEmpty)return;try{final results=await RouteService.searchPlaces(q);if(!mounted)return;if(results.isEmpty){if(dialogContext.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما لقيناش البلاصة. جرّب اسم أوضح.')));return;}final selected=await showModalBottomSheet<PlaceResult>(context:context,showDragHandle:true,builder:(c)=>SafeArea(child:ListView(shrinkWrap:true,children:results.map((r)=>ListTile(title:Text(r.displayName),subtitle:Text([r.area,r.city].whereType<String>().where((x)=>x.isNotEmpty).join(' • ')),onTap:()=>Navigator.pop(c,r))).toList())));if(selected!=null&&dialogContext.mounted)Navigator.pop(dialogContext,selected);}catch(e,st){debugPrint('LEF_LEF place search failed: $e');debugPrintStack(stackTrace:st);}},child:const Text('لوج'))]));
    controller.dispose();
    if(chosen==null||chosen.latitude==null||chosen.longitude==null)return;
    final point=LatLng(chosen.latitude!,chosen.longitude!);
    setState((){if(pickupMode){pickup=point;place=chosen.displayName;}else{destination=point;destinationName=chosen.displayName;}providerLocation=null;distanceKm=0;routePoints=[];routeMinutes=0;fare=0;});
    map.move(point,14);
    if(_hasRouteEndpoints)await _loadRoute();
  }
  LatLng _routePoint(double fraction) {
    if (routePoints.isEmpty) {
      return LatLng(
        pickup.latitude + (destination.latitude - pickup.latitude) * fraction,
        pickup.longitude + (destination.longitude - pickup.longitude) * fraction,
      );
    }
    final i = (fraction.clamp(0.0, 1.0) * (routePoints.length - 1)).round();
    return routePoints[i.clamp(0, routePoints.length - 1)];
  }

  void _showStageMessage(String title,String subtitle) {
    showModalBottomSheet<void>(context:context,showDragHandle:true,builder:(c)=>SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(20,8,20,24),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:6),Text(subtitle,style:const TextStyle(color:Colors.black54)),const SizedBox(height:14),Text('الحالة الحالية: ${rideStageLabel(status.name)}',style:const TextStyle(fontWeight:FontWeight.w700))]))));
  }

  List<Marker> _stageMarkers(){
    // Stage bubbles must be anchored to the real road route, never a straight-line guess.
    if(status==RideStatus.draft || routePoints.length < 2) return [];
    final stages = <({RideStatus status, double fraction, String title, String subtitle, IconData icon})>[
      (status:RideStatus.searching,fraction:0.08,title:'قاعدين نلوجو',subtitle:'نلوجو على السائق مناسب',icon:Icons.radar_rounded),
      (status:RideStatus.offered,fraction:0.08,title:'عرض',subtitle:'عرض السائق جاهز للمراجعة',icon:Icons.local_offer_rounded),
      (status:RideStatus.countered,fraction:0.18,title:'عرض مضاد',subtitle:'مستنيين ردّ السائق',icon:Icons.swap_horiz_rounded),
      (status:RideStatus.accepted,fraction:0.28,title:'تقبل',subtitle:'تعيّن السائق',icon:Icons.check_circle_outline),
      (status:RideStatus.arriving,fraction:0.42,title:'السائق جاي',subtitle:'السائق جاي لنقطة الانطلاق',icon:Icons.directions_car_rounded),
      (status:RideStatus.arrived,fraction:0.50,title:'وصل',subtitle:'السائق وصل',icon:Icons.place_rounded),
      (status:RideStatus.active,fraction:0.72,title:'المشوار بدا',subtitle:'الخدمة قاعد تصير',icon:Icons.route_rounded),
      (status:RideStatus.completed,fraction:0.98,title:'كمل',subtitle:'الخدمة كملت',icon:Icons.flag_circle_rounded),
      (status:RideStatus.cancelled,fraction:0.50,title:'تلغى',subtitle:'الطلب هذا تسكّر',icon:Icons.cancel_outlined),
    ];
    final current = stages.firstWhere((s)=>s.status==status, orElse:()=>stages.first);
    return [Marker(point:_routePoint(current.fraction),width:240,height:96,alignment:Alignment.bottomCenter,child:MapMessagePin(title:current.title,subtitle:current.subtitle,icon:current.icon,onTap:()=>_showStageMessage(current.title,current.subtitle)))];
  }
  String title()=>switch(status){RideStatus.draft=>'اختار خدمة',RideStatus.searching=>'نلوجو على السائق قريب',RideStatus.offered=>'عرض جديد وصل',RideStatus.countered=>'بعثنا العرض المضاد',RideStatus.accepted=>'الطلب تقبل',RideStatus.arriving=>'السائق في الثنية',RideStatus.arrived=>'السائق وصل',RideStatus.active=>'المشوار قاعد يصير',RideStatus.completed=>'المشوار كمل',RideStatus.cancelled=>'المشوار تلغى'};
  String sub()=>switch(status){RideStatus.draft=>'اختار خدمة باش نكملو',RideStatus.searching=>'نلوجو على السائق قريب',RideStatus.offered=>'راجع عرض السائق قبل القبول',RideStatus.countered=>'مستنيين ردّ السائق',RideStatus.accepted=>'السائق جاي ليك',RideStatus.arriving=>'حالة الخدمة توا',RideStatus.arrived=>'تثبت في الكرهبة وكمل',RideStatus.active=>'$place → $destinationName',RideStatus.completed=>'المشوار تسكّر',RideStatus.cancelled=>'ما فماش طلب نشيط'};
  @override Widget build(BuildContext c)=>Stack(children:[FlutterMap(mapController:map,options:MapOptions(initialCenter:const LatLng(34.0,9.0),initialZoom:6.2,onTap:(tapPosition,point)=>_handleMapTap(point)),children:[TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'com.leflef.app'),PolylineLayer(polylines:[if(routePoints.isNotEmpty)Polyline(points:routePoints,strokeWidth:5,color:LefTheme.gold)]),RichAttributionWidget(attributions:[TextSourceAttribution('مساهمي OpenStreetMap')]),MarkerLayer(markers:[if(liveMapMessage!=null&&liveMapMessageLocation!=null)Marker(point:liveMapMessageLocation!,width:250,height:100,alignment:Alignment.bottomCenter,child:MapMessagePin(title:'رسالة على الماب',subtitle:liveMapMessage!,icon:Icons.chat_bubble_rounded,onTap:()=>_showStageMessage('رسالة على الماب',liveMapMessage!))),if(providerLocation!=null)Marker(point:providerLocation!,width:54,height:54,child:Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),boxShadow:const[BoxShadow(blurRadius:12,color:Color(0x30000000))]),child:const Icon(Icons.directions_car_rounded,color:LefTheme.goldDark,size:32))),if(currentLocation!=null)Marker(point:currentLocation!,width:46,height:46,child:const Icon(Icons.my_location,color:Colors.blue,size:35)),if(_hasPickup)Marker(point:pickup,width:50,height:50,child:const Icon(Icons.location_on_rounded,color:LefTheme.goldDark,size:45)),if(_hasDestination)Marker(point:destination,width:50,height:50,child:const Icon(Icons.location_on_rounded,color:Colors.black,size:45))])]),Positioned(top:50,left:16,right:16,child:Row(children:[Expanded(child:Container(height:52,padding:const EdgeInsets.symmetric(horizontal:15),decoration:BoxDecoration(color:Colors.white.withAlpha(245),borderRadius:BorderRadius.circular(18)),child:Row(children:[const Icon(Icons.search),const SizedBox(width:8),Expanded(child:Text('$place → $destinationName',overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w700)))]))),const SizedBox(width:8),FloatingActionButton.small(heroTag:'locate',backgroundColor:Colors.white,foregroundColor:LefTheme.goldDark,onPressed:locate,child:const Icon(Icons.my_location)),if(rideId!=null&&status!=RideStatus.draft)Padding(padding:const EdgeInsets.only(left:6),child:FloatingActionButton.small(heroTag:'rideMapMessages',backgroundColor:Colors.white,foregroundColor:LefTheme.goldDark,onPressed:()=>Navigator.of(c).push(MaterialPageRoute(builder:(_)=>RideMessageMapScreen(rideId:rideId!))),child:const Icon(Icons.chat_bubble_rounded)))])),Positioned(left:0,right:0,bottom:0,height:MediaQuery.sizeOf(c).height*panel,child:GestureDetector(onVerticalDragUpdate:(d)=>setState(()=>panel=(panel-d.delta.dy/MediaQuery.sizeOf(c).height).clamp(.28,.78)),child:Container(decoration:const BoxDecoration(color:Colors.white,borderRadius:BorderRadius.vertical(top:Radius.circular(30)),boxShadow:[BoxShadow(blurRadius:25,color:Color(0x22000000))]),child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(18,10,18,25),child:Column(children:[Container(width:42,height:5,decoration:BoxDecoration(color:Colors.black12,borderRadius:BorderRadius.circular(5))),const SizedBox(height:14),Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title(),style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),Text(sub(),style:const TextStyle(color:Colors.black54))])),Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(_currentRideIsNegotiable && !{RideStatus.offered,RideStatus.countered,RideStatus.accepted,RideStatus.arriving,RideStatus.arrived,RideStatus.active,RideStatus.completed}.contains(status) ? 'السوم بالتفاهم' : '${fare.toStringAsFixed(2)} د.ت',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:LefTheme.goldDark)),Text('${distanceKm.toStringAsFixed(1)} كم${routeMinutes>0?' • $routeMinutes د':''}${routing?' • نحسبو في الثنية…':routePoints.isEmpty?' • الثنية موش متوفرة':''}',style:const TextStyle(fontSize:10,color:Colors.black54))])]),if(rideId!=null&&status!=RideStatus.draft&&providerId!=null&&providerId!.isNotEmpty)...[const SizedBox(height:10),Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('معلومات السائق',style:TextStyle(fontWeight:FontWeight.w900,fontSize:16,color:LefTheme.goldDark)),const SizedBox(height:8),Row(children:[const CircleAvatar(child:Icon(Icons.person_rounded)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text((providerInfo['displayName']??'السائق LEF_LEF').toString(),style:const TextStyle(fontWeight:FontWeight.w900)),Text([providerInfo['vehicleType'],providerInfo['vehicleModel']].whereType<String>().map((v)=>v.trim()).where((v)=>v.isNotEmpty).join(' • ').isEmpty?'معلومات المركبة تتحمّل…':[providerInfo['vehicleType'],providerInfo['vehicleModel']].whereType<String>().map((v)=>v.trim()).where((v)=>v.isNotEmpty).join(' • ')),if((providerInfo['vehiclePlate']??'').toString().trim().isNotEmpty)Text('الترقيم: ${providerInfo['vehiclePlate']}')]))]),const SizedBox(height:8),Text('${_ridePriceLabel()}: ${fare.toStringAsFixed(2)} د.ت',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),if(_driverEtaMinutes()!=null)Text('وصول السائق تقريبًا في ${_driverEtaMinutes()} دقايق',style:const TextStyle(fontWeight:FontWeight.w700)) else if(status==RideStatus.accepted||status==RideStatus.arriving)const Text('نستناو تحديث موقع السائق لحساب وقت الوصول.',style:TextStyle(color:Colors.black54)),if({RideStatus.accepted,RideStatus.arriving,RideStatus.arrived,RideStatus.active}.contains(status)&&(providerLocationUpdatedAt==null||DateTime.now().difference(providerLocationUpdatedAt!)>const Duration(minutes:2)))const Padding(padding:EdgeInsets.only(top:6),child:Text('تحديث GPS متأخر. آخر موقع محفوظ يبقى للمتابعة، والوقت والمسافة ينجموا ما يكونوش دقيقين حتى يرجع الاتصال.',style:TextStyle(color:Colors.deepOrange,fontWeight:FontWeight.w700))),if(routeMinutes>0)Text('وقت الثنية للوجهة تقريبًا $routeMinutes دقايق',style:const TextStyle(color:Colors.black54))]))),],if(status==RideStatus.draft)...[const SizedBox(height:14),...serviceOptions.map((o)=>RadioListTile<ServiceKind>(value:o.kind,groupValue:selected,onChanged:(v){if(v!=null)setState((){selected=v;_recalc();});},title:Text(o.title,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(_isNegotiable(o) ? 'السوم بالتفاهم مع صاحب الخدمة' : (distanceKm>0&&routePoints.length>1 ? 'السعر الجملي: ${(_configuredBase(o)+distanceKm*_configuredRate(o,DateTime.now().hour>=22||DateTime.now().hour<6)).toStringAsFixed(2)} د.ت' : 'احسب الثنية باش يظهر السوم الجملي'))))],if(status==RideStatus.draft)...[Align(alignment:Alignment.centerRight,child:Text(resolvingPlace?'قاعدين نحدّدوا اسم البلاصة…':'حرّك الخريطة واضغط باش تحدّد البلاصة',style:const TextStyle(fontWeight:FontWeight.w700,color:LefTheme.goldDark))),const SizedBox(height:6),Wrap(spacing:8,children:[ChoiceChip(label:const Text('الدبوس: الانطلاق'),selected:mapPickingPickup,onSelected:(v){if(v)setState(()=>mapPickingPickup=true);}),ChoiceChip(label:const Text('الدبوس: الوجهة'),selected:!mapPickingPickup,onSelected:(v){if(v)setState(()=>mapPickingPickup=false);})]),Card(child:ListTile(leading:const Icon(Icons.trip_origin,color:LefTheme.goldDark),title:const Text('نقطة الانطلاق'),subtitle:Text(place),trailing:const Icon(Icons.chevron_right),onTap:()=>_choosePlace(pickupMode:true))),Card(child:ListTile(leading:const Icon(Icons.location_on,color:LefTheme.goldDark),title:const Text('الوجهة'),subtitle:Text(destinationName),trailing:const Icon(Icons.chevron_right),onTap:()=>_choosePlace(pickupMode:false))),if({ServiceKind.deliveryMoto,ServiceKind.deliveryVan,ServiceKind.deliveryTruck}.contains(selected))...[
const SizedBox(height:8),Align(alignment:Alignment.centerRight,child:Text('تفاصيل التوصيل',style:TextStyle(fontWeight:FontWeight.w900,fontSize:16,color:LefTheme.goldDark))),
TextField(controller:_recipientName,decoration:const InputDecoration(labelText:'اسم المستلِم',prefixIcon:Icon(Icons.person_outline),border:OutlineInputBorder())),
const SizedBox(height:8),TextField(controller:_recipientPhone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'تليفون المستلِم',prefixIcon:Icon(Icons.phone_outlined),border:OutlineInputBorder())),
const SizedBox(height:8),TextField(controller:_parcelCategory,decoration:const InputDecoration(labelText:'نوع الطرد (مثال: وثائق، أكل، أغراض)',prefixIcon:Icon(Icons.inventory_2_outlined),border:OutlineInputBorder())),
const SizedBox(height:8),TextField(controller:_parcelNotes,maxLines:2,maxLength:500,decoration:const InputDecoration(labelText:'ملاحظات للالسائق (اختياري)',prefixIcon:Icon(Icons.notes),border:OutlineInputBorder())),
]],if(status!=RideStatus.draft)...[ListTile(leading:const Icon(Icons.trip_origin,color:LefTheme.goldDark),title:const Text('نقطة الانطلاق'),subtitle:Text(place)),ListTile(leading:const Icon(Icons.location_on),title:const Text('الوجهة'),subtitle:Text(destinationName))],if(fare>200)const Padding(padding:EdgeInsets.only(top:8),child:Text('طلب بقيمة كبيرة: السعر فوق 200 د.ت. تأكد قبل ما تثبّت.',style:TextStyle(color:Colors.deepOrange,fontWeight:FontWeight.w700))),if(status==RideStatus.arrived)...[const SizedBox(height:8),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:clientArrivalConfirmed?null:()async{try{await FirebaseService.confirmClientArrival(rideId!);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('أكدت وصول السائق. ينجم يبدأ المشوار بعد التأكيد.')));}catch(e){debugPrint('LEF_LEF arrival confirmation failed: $e');if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نأكد الوصول توا. تثبّت من حالة الطلب وعاود.')));}},icon:Icon(clientArrivalConfirmed?Icons.check_circle:Icons.location_on),label:Text(clientArrivalConfirmed?'أكدت وصول السائق':'أكد اللي السائق وصل لنقطة الانطلاق')))],const SizedBox(height:8),SizedBox(width:double.infinity,height:54,child:FilledButton(style:FilledButton.styleFrom(backgroundColor:LefTheme.gold,foregroundColor:Colors.black),onPressed:(!pricingLoading&&(status==RideStatus.draft||status==RideStatus.offered||status==RideStatus.completed||status==RideStatus.cancelled))?start:null,child:Text(pricingLoading?'نحمّلوا التسعيرة…':status==RideStatus.draft?'أكد الطلب':status==RideStatus.offered?'راجع العرض':status==RideStatus.completed||status==RideStatus.cancelled?'طلب جديد':'مستنيين السائق',style:const TextStyle(fontWeight:FontWeight.w900)))),if(status==RideStatus.completed)...[TextButton.icon(onPressed:_rateCompletedRide,icon:const Icon(Icons.star_outline),label:const Text('قيّم الخدمة')),TextButton.icon(onPressed:_reportCompletedRide,icon:const Icon(Icons.flag_outlined),label:const Text('شكوى'))],if(status!=RideStatus.draft&&status!=RideStatus.completed&&status!=RideStatus.cancelled&&status!=RideStatus.active)TextButton(onPressed:cancel,child:const Text('إلغي الطلب'))]))))) ]);
}
