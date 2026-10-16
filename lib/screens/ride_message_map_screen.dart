import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme.dart';
import '../services/firebase_service.dart';
import '../widgets/map_message_pin.dart';

class RideMessageMapScreen extends StatefulWidget {
  const RideMessageMapScreen({super.key, required this.rideId});
  final String rideId;
  @override State<RideMessageMapScreen> createState()=>_RideMessageMapScreenState();
}
class _RideMessageMapScreenState extends State<RideMessageMapScreen> {
  final map=MapController();
  bool sending=false;
  LatLng? selectedMessageLocation;
  Future<void> sendMessage(String text, Map<String,dynamic> ride) async {
    final controller=TextEditingController(text:text);
    final message=await showDialog<String>(context:context,builder:(c)=>AlertDialog(
      title:const Text('رسالة فوق الماب'),
      content:TextField(controller:controller,maxLength:180,maxLines:3,decoration:const InputDecoration(hintText:'مثال: أنا نستناك قدّام المدخل')),
      actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,controller.text.trim()),child:const Text('حطّ الدبوس'))],
    ));
    controller.dispose();
    if(message==null||message.trim().isEmpty)return;
    final uid=FirebaseService.user?.uid; if(uid==null)return;
    final pickupLat=(ride['pickupLat'] as num?)?.toDouble();
    final pickupLng=(ride['pickupLng'] as num?)?.toDouble();
    final providerLat=(ride['providerLat'] as num?)?.toDouble();
    final providerLng=(ride['providerLng'] as num?)?.toDouble();
    // A manually selected map point wins. Otherwise use the sender's real location;
    // never pretend that a driver's location is the client's pickup point.
    final LatLng? defaultLocation = uid==ride['providerId']
        ? (providerLat!=null&&providerLng!=null ? LatLng(providerLat,providerLng) : null)
        : (pickupLat!=null&&pickupLng!=null ? LatLng(pickupLat,pickupLng) : null);
    final chosen = selectedMessageLocation ?? defaultLocation;
    if(chosen==null||!chosen.latitude.isFinite||!chosen.longitude.isFinite||chosen.latitude < -90||chosen.latitude > 90||chosen.longitude < -180||chosen.longitude > 180){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(uid==ride['providerId']?'فعّل التتبّع وحدّد موقعك قبل ما تحطّ دبوس المساج.':'حدّد موقع الانطلاق قبل ما تحطّ دبوس المساج.')));
      return;
    }
    final lat=chosen.latitude;
    final lng=chosen.longitude;
    setState(()=>sending=true);
    try {
      await FirebaseService.sendRideMapMessage(widget.rideId,message,latitude:lat,longitude:lng);
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('الرسالة تحطّت على الماب عند الطرفين.')));
    } catch (_) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نحطّ الرسالة. تثبّت من حالة المشوار والاتصال.')));
    } finally { if(mounted)setState(()=>sending=false); }
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('رسائل المشوار على الماب')),
    body:StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(stream:FirebaseService.rideStream(widget.rideId),builder:(context,snap){
      if(snap.hasError)return const Center(child:Text('الماب موش متوفر توا.'));
      if(!snap.hasData)return const Center(child:CircularProgressIndicator());
      final x=snap.data!.data(); if(x==null)return const Center(child:Text('المشوار موش موجود.'));
      final plat=(x['pickupLat'] as num?)?.toDouble(), plng=(x['pickupLng'] as num?)?.toDouble();
      if(plat==null||plng==null||!plat.isFinite||!plng.isFinite||plat < -90||plat > 90||plng < -180||plng > 180){
        return const Center(child:Padding(padding:EdgeInsets.all(24),child:Text('موقع الانطلاق موش محفوظ في الطلب. ارجع للماب وحدّد الموقع الصحيح قبل استعمال رسائل الماب.',textAlign:TextAlign.center)));
      }
      final dlat=(x['destinationLat'] as num?)?.toDouble(), dlng=(x['destinationLng'] as num?)?.toDouble();
      final pLat=(x['providerLat'] as num?)?.toDouble(), pLng=(x['providerLng'] as num?)?.toDouble();
      final mLat=(x['mapMessageLat'] as num?)?.toDouble(), mLng=(x['mapMessageLng'] as num?)?.toDouble();
      final hasMessage=(x['mapMessage']??'').toString().trim().isNotEmpty&&mLat!=null&&mLng!=null;
      final uid=FirebaseService.user?.uid;
      final active=['accepted','arriving','arrived','active'].contains(x['status']?.toString());
      return Stack(children:[FlutterMap(mapController:map,options:MapOptions(initialCenter:LatLng(plat,plng),initialZoom:13,onTap:(tapPosition,point){setState(()=>selectedMessageLocation=point);}),children:[
        TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'com.leflef.app'),
        MarkerLayer(markers:[
          Marker(point:LatLng(plat,plng),width:42,height:48,child:const Icon(Icons.trip_origin,color:LefTheme.goldDark,size:38)),
          if(dlat!=null&&dlng!=null&&dlat.isFinite&&dlng.isFinite&&dlat>=-90&&dlat<=90&&dlng>=-180&&dlng<=180)Marker(point:LatLng(dlat,dlng),width:42,height:48,child:const Icon(Icons.flag_rounded,color:Colors.black87,size:36)),
          if(pLat!=null&&pLng!=null)Marker(point:LatLng(pLat,pLng),width:44,height:48,child:const Icon(Icons.local_taxi_rounded,color:LefTheme.goldDark,size:38)),
          if(selectedMessageLocation!=null)Marker(point:selectedMessageLocation!,width:42,height:48,child:const Icon(Icons.add_location_alt_rounded,color:Colors.blue,size:38)),
          if(hasMessage)Marker(point:LatLng(mLat,mLng),width:260,height:112,alignment:Alignment.bottomCenter,child:MapMessagePin(title:uid==x['mapMessageBy']?'رسالتك على الماب':'رسالة من الطرف الآخر',subtitle:x['mapMessage'].toString(),icon:Icons.chat_bubble_rounded,onTap:()=>showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const Text('رسالة المشوار'),content:Text(x['mapMessage'].toString()),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('سكر'))])))),
        ]),RichAttributionWidget(attributions:[TextSourceAttribution('مساهمي OpenStreetMap')])]),
        Positioned(left:16,right:16,bottom:20,child:SafeArea(child:Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(mainAxisSize:MainAxisSize.min,children:[
          Row(children:[const Icon(Icons.chat_bubble_rounded,color:LefTheme.goldDark),const SizedBox(width:8),Expanded(child:Text(selectedMessageLocation!=null?'الموقع المختار: ${selectedMessageLocation!.latitude.toStringAsFixed(5)}, ${selectedMessageLocation!.longitude.toStringAsFixed(5)}':hasMessage?x['mapMessage'].toString():'انقر على الماب لاختيار مكان دبوس المساج',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w700)))]),
          const SizedBox(height:8),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:active&&!sending&&plat.isFinite&&plng.isFinite?()=>sendMessage('',x):null,icon:const Icon(Icons.add_location_alt_rounded),label:Text(sending?'قاعدين نبعثو…':'حطّ دبوس مساج'))),
          if(!active)const Text('الرسائل على الماب متاحة بعد قبول المشوار.',style:TextStyle(fontSize:12,color:Colors.black54)),
        ]))))),
      ]);
    }),
  );
}
