import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/firebase_service.dart';
import 'chat_screen.dart';
import 'map_screen.dart';

class MyPostsScreen extends StatelessWidget {
  const MyPostsScreen({super.key});
  @override Widget build(BuildContext context) {
    final uid=FirebaseService.user?.uid;
    return Scaffold(appBar:AppBar(title:const Text('بوستاتي')),body:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream:FirebaseService.db.collection('posts').where('authorId',isEqualTo:uid).limit(50).snapshots(),
      builder:(context,snap){
        if(snap.hasError)return const Center(child:Text('البوستات موش متوفرة توا.'));
        if(!snap.hasData)return const Center(child:CircularProgressIndicator());
        if(snap.data!.docs.isEmpty)return const Center(child:Text('ما نشرت حتى بوست توا.'));
        return ListView(padding:const EdgeInsets.all(16),children:snap.data!.docs.map((d){return Card(child:Padding(padding:const EdgeInsets.all(14),child:Text((d.data()['text']??'').toString())));}).toList());
      },
    ));
  }
}
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});
  @override Widget build(BuildContext context){
    final uid=FirebaseService.user?.uid;
    return Scaffold(appBar:AppBar(title:const Text('طلباتي')),body:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream:FirebaseService.db.collection('rides').where('clientId',isEqualTo:uid).limit(50).snapshots(),
      builder:(context,snap){
        if(snap.hasError)return const Center(child:Text('الطلبات موش متوفرة توا.'));
        if(!snap.hasData)return const Center(child:CircularProgressIndicator());
        if(snap.data!.docs.isEmpty)return const Center(child:Text('ما عندك حتى طلب خدمة توا.'));
        return ListView(padding:const EdgeInsets.all(16),children:snap.data!.docs.map((d){final x=d.data();final active={'searching','offered','countered','accepted','arriving','arrived','active'}.contains(x['status']);return Card(child:ListTile(leading:const Icon(Icons.route,color:LefTheme.goldDark),title:Text('${x['pickup']??''} → ${x['destination']??''}'),subtitle:Text('${(x['kind']??'الخدمة').toString()} • ${(x['status']??'').toString()}'),trailing:active?const Icon(Icons.play_arrow_rounded,color:LefTheme.goldDark):const Icon(Icons.history),onTap:active?()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const MapScreen())):null));}).toList());
      },
    ));
  }
}
class SavedPlacesScreen extends StatelessWidget {
  const SavedPlacesScreen({super.key});
  @override Widget build(BuildContext context){
    final uid=FirebaseService.user?.uid;
    final stream=uid==null?Stream<QuerySnapshot<Map<String,dynamic>>>.empty():FirebaseService.db.collection('users').doc(uid).collection('savedPlaces').limit(50).snapshots();
    return Scaffold(appBar:AppBar(title:const Text('البلايص المحفوظة')),body:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream:stream,builder:(context,snap){
        if(snap.hasError)return const Center(child:Text('البلايص المحفوظة موش متوفرة توا.'));
        if(!snap.hasData)return const Center(child:CircularProgressIndicator());
        if(snap.data!.docs.isEmpty)return const Center(child:Text('ما حفظت حتى بلاصة توا.'));
        return ListView(padding:const EdgeInsets.all(16),children:snap.data!.docs.map((d){final x=d.data();return Card(child:ListTile(leading:const Icon(Icons.bookmark,color:LefTheme.goldDark),title:Text((x['name']??'البلاصة').toString()),subtitle:Text((x['description']??'').toString())));}).toList());
      },
    ));
  }
}
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('المساعدة والدعم')),body:ListView(padding:const EdgeInsets.all(16),children:[Card(child:ListTile(leading:const Icon(Icons.support_agent,color:LefTheme.goldDark),title:const Text('مساعدة LEF_LEF'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const ConversationScreen(title:'مساعدة LEF_LEF',conversationId:'support'))))),const Card(child:ListTile(title:Text('حالات الخدمة'),subtitle:Text('SOS والإسعاف عندهم حالات طلب واضحة داخل التطبيق.')))]));
}
