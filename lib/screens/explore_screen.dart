import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/firebase_service.dart';
import '../services/route_service.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override State<ExploreScreen> createState() => _ExploreState();
}

class _ExploreState extends State<ExploreScreen> {
  final search = TextEditingController();
  final globalSearch = TextEditingController();
  final peopleSearch = TextEditingController();
  List<PlaceResult> placeResults = const [];
  bool placeSearching = false;

  Future<void> searchPlaces() async { final q=search.text.trim(); if(q.isEmpty){setState(()=>placeResults=const []);return;} setState(()=>placeSearching=true); try{final r=await RouteService.searchPlaces(q);if(mounted)setState(()=>placeResults=r);}catch(e,st){debugPrint('LEF_LEF explore search failed: $e');debugPrintStack(stackTrace:st);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('البحث على البلايص موش متوفر توا.')));}finally{if(mounted)setState(()=>placeSearching=false);}}

  @override void dispose() { search.dispose(); globalSearch.dispose(); peopleSearch.dispose(); super.dispose(); }

  Future<void> save(String name, String description) async {
    final u = FirebaseService.user;
    if (u == null) return;
    try {
      await FirebaseService.db.collection('users').doc(u.uid).collection('savedPlaces')
          .doc(base64Url.encode(utf8.encode('${name.trim()}|${description.trim()}')).replaceAll('=', ''))
          .set({'name': name, 'description': description, 'createdAt': FieldValue.serverTimestamp()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name تضافت للبلايص المحفوظة.')));
    } catch (e, st) {
      debugPrint('LEF_LEF save place failed: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما نجّمش نحفظ البلاصة توا.')));
    }
  }

  Future<void> createEvent() async {
    final title = TextEditingController();
    final place = TextEditingController();
    final desc = TextEditingController();
    final capacity = TextEditingController();
    DateTime when = DateTime.now().add(const Duration(hours: 2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('اعمل مناسبة'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: title, onChanged: (_) => setDialog(() {}), maxLength: 100, decoration: const InputDecoration(labelText: 'اسم المناسبة')),
            TextField(controller: place, onChanged: (_) => setDialog(() {}), maxLength: 160, decoration: const InputDecoration(labelText: 'البلاصة')),
            TextField(controller: desc, maxLines: 2, maxLength: 1000, decoration: const InputDecoration(labelText: 'الوصف')),
            TextField(controller: capacity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعة القصوى (اختياري)')),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('التاريخ والوقت'),
              subtitle: Text(when.toLocal().toString().substring(0, 16)),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_month),
                onPressed: () async {
                  final d = await showDatePicker(context: dialogContext, initialDate: when, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (d == null) return;
                  final t = await showTimePicker(context: dialogContext, initialTime: TimeOfDay.fromDateTime(when));
                  if (t != null) setDialog(() => when = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                },
              ),
            ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: title.text.trim().isNotEmpty && place.text.trim().isNotEmpty && when.isAfter(DateTime.now()) ? () => Navigator.pop(dialogContext, true) : null, child: const Text('انشر')),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        final id = await FirebaseService.createEvent(title: title.text, place: place.text, description: desc.text, startsAt: when, capacity: capacity.text.trim().isEmpty ? null : int.tryParse(capacity.text.trim()));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(id == null ? 'راجع اسم المناسبة والبلاصة والتاريخ.' : 'المناسبة تضافت.')));
      } catch (e, st) {
        debugPrint('LEF_LEF event create failed: $e');
        debugPrintStack(stackTrace: st);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما نجّمش ننشر المناسبة توا.')));
      }
    }
    title.dispose(); place.dispose(); desc.dispose(); capacity.dispose();
  }


  Future<void> editEvent(String id,Map<String,dynamic> data) async {
    final title=TextEditingController(text:(data['title']??'').toString());final place=TextEditingController(text:(data['place']??'').toString());final desc=TextEditingController(text:(data['description']??'').toString());final capacity=TextEditingController(text:(data['capacity']??'').toString());
    DateTime when=((data['startsAt'] as Timestamp?)?.toDate()??DateTime.now().add(const Duration(hours:2)));
    final ok=await showDialog<bool>(context:context,builder:(dc)=>StatefulBuilder(builder:(dc,setDialog)=>AlertDialog(title:const Text('عدّل المناسبة'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:title,decoration:const InputDecoration(labelText:'اسم المناسبة')),TextField(controller:place,decoration:const InputDecoration(labelText:'البلاصة')),TextField(controller:desc,maxLines:2,decoration:const InputDecoration(labelText:'الوصف')),TextField(controller:capacity,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'السعة القصوى (اختياري)')),ListTile(title:const Text('التاريخ والوقت'),subtitle:Text(when.toLocal().toString().substring(0,16)),trailing:IconButton(icon:const Icon(Icons.calendar_month),onPressed:()async{final d=await showDatePicker(context:dc,initialDate:when.isBefore(DateTime.now())?DateTime.now():when,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)));if(d==null)return;final t=await showTimePicker(context:dc,initialTime:TimeOfDay.fromDateTime(when));if(t!=null)setDialog((){when=DateTime(d.year,d.month,d.day,t.hour,t.minute);});}))])),actions:[TextButton(onPressed:()=>Navigator.pop(dc,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(dc,title.text.trim().isNotEmpty&&place.text.trim().isNotEmpty&&when.isAfter(DateTime.now())),child:const Text('احفظ التعديل'))])));
    if(ok==true){try{await FirebaseService.updateEvent(id,title:title.text,place:place.text,description:desc.text,startsAt:when,capacity:capacity.text.trim().isEmpty?null:int.tryParse(capacity.text.trim()));if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('المناسبة تعدّلت.')));}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نعدّل المناسبة. تثبّت من التاريخ والصلاحيات.')));}}
    title.dispose();place.dispose();desc.dispose();capacity.dispose();
  }
  Future<void> deleteEvent(String id) async {final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('تحذف المناسبة؟'),content:const Text('الحذف نهائي.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('رجوع')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('احذف'))]));if(ok!=true)return;try{await FirebaseService.deleteEvent(id);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('المناسبة تحذفت.')));}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نحذف المناسبة.')));}}

  Future<void> editDirectoryEntry(String id,Map<String,dynamic> data) async {final name=TextEditingController(text:(data['name']??'').toString()),category=TextEditingController(text:(data['category']??'').toString()),description=TextEditingController(text:(data['description']??'').toString());final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('عدّل الخدمة'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'الاسم')),TextField(controller:category,decoration:const InputDecoration(labelText:'الصنف')),TextField(controller:description,maxLines:3,decoration:const InputDecoration(labelText:'الوصف'))])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,name.text.trim().isNotEmpty&&category.text.trim().isNotEmpty),child:const Text('احفظ'))]));if(ok==true){try{await FirebaseService.updateServiceDirectory(id,name:name.text,category:category.text,description:description.text);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('الخدمة تعدّلت.')));}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نعدّل الخدمة.')));}}name.dispose();category.dispose();description.dispose();}
  Future<void> deleteDirectoryEntry(String id) async {final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('تحذف الخدمة؟'),content:const Text('الحذف نهائي.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('رجوع')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('احذف'))]));if(ok!=true)return;try{await FirebaseService.deleteServiceDirectory(id);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('الخدمة تحذفت.')));}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نحذف الخدمة.')));}}

  Widget people() {
    final me = FirebaseService.user?.uid;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('الناس', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          TextField(
            controller: peopleSearch,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.person_search), hintText: 'لوج على اسم...'),
          ),
          if (peopleSearch.text.trim().isNotEmpty)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseService.searchUsers(peopleSearch.text),
              builder: (context, snap) {
                if (snap.hasError) return const Padding(padding: EdgeInsets.all(10), child: Text('البحث موش متوفر توا.'));
                if (!snap.hasData) return const Padding(padding: EdgeInsets.all(10), child: Center(child: CircularProgressIndicator()));
                final docs = snap.data!.docs.where((d) => d.id != me).toList();
                if (docs.isEmpty) return const Padding(padding: EdgeInsets.all(10), child: Text('ما لقيناش مستخدمين.'));
                return Column(children: docs.map((d) {
                  final x = d.data();
                  final role = (x['role'] ?? 'client').toString();
                  final roleLabel = switch (role) {
                    'driver' => 'السائق', 'deliveryProvider' => 'ديليفري', 'partner' => 'شريك خدمات',
                    'manager' => 'مسؤول', 'owner' => 'إدارة', 'employee' => 'موظف', _ => 'مستخدم',
                  };
                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: me == null ? const Stream.empty() : FirebaseService.db.collection('users').doc(me).collection('following').doc(d.id).snapshots(),
                    builder: (context, followSnap) => ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (x['photoUrl'] is String && (x['photoUrl'] as String).isNotEmpty) ? NetworkImage(x['photoUrl'] as String) : null,
                        child: (x['photoUrl'] is String && (x['photoUrl'] as String).isNotEmpty) ? null : const Icon(Icons.person),
                      ),
                      title: Text((x['displayName'] ?? 'مستخدم').toString()),
                      subtitle: Text(roleLabel),
                      trailing: OutlinedButton(
                        onPressed: me == null ? null : () async {
                          try {
                            if (followSnap.data?.exists == true) {
                              await FirebaseService.unfollowUser(d.id);
                            } else {
                              await FirebaseService.followUser(d.id);
                            }
                          } catch (e, st) {
                            debugPrint('LEF_LEF follow failed: $e');
                            debugPrintStack(stackTrace: st);
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما نجّمش نبدّل المتابعة توا.')));
                          }
                        },
                        child: Text(followSnap.data?.exists == true ? 'تتابعو' : 'تابع'),
                      ),
                    ),
                  );
                }).toList());
              },
            ),
        ]),
      ),
    );
  }

  Widget events() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseService.upcomingEvents(),
      builder: (context, snap) {
        if (snap.hasError) return const Text('المناسبات موش متوفرة توا.');
        if (!snap.hasData) return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
        final docs = snap.data!.docs.where((d) { final x=d.data(); final ts=x['startsAt']; return x['status']=='published' && ts is Timestamp && ts.toDate().isAfter(DateTime.now()); }).toList()..sort((a,b){final at=(a.data()['startsAt'] as Timestamp).toDate();final bt=(b.data()['startsAt'] as Timestamp).toDate();return at.compareTo(bt);});
        return Column(children: [
          Row(children: [
            const Expanded(child: Text('المناسبات الجاية', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
            TextButton.icon(onPressed: createEvent, icon: const Icon(Icons.add), label: const Text('اعمل')),
          ]),
          if (docs.isEmpty)
            const Card(child: ListTile(title: Text('ما فماش مناسبات جاية توا.')))
          else
            ...docs.map((doc) {
              final data = doc.data();
              final date = (data['startsAt'] as Timestamp?)?.toDate();
              final when = date == null ? '' : '\n${date.toLocal().toString().substring(0, 16)}';
              return StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(stream:FirebaseService.eventAttendance(doc.id),builder:(c,a)=>Card(child: ListTile(
                leading: const Icon(Icons.event, color: LefTheme.goldDark),
                title: Text((data['title'] ?? 'مناسبة').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${data['place'] ?? ''}$when'),
                trailing:Wrap(children:[OutlinedButton(onPressed:()async{try{if(a.data?.exists==true){await FirebaseService.eventUnrsvp(doc.id);}else{await FirebaseService.eventRsvp(doc.id);}}catch(e,st){debugPrint('LEF_LEF RSVP failed: $e');debugPrintStack(stackTrace:st);if(c.mounted)ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('المشاركة في المناسبة ما تسجّلتش توا.')));}},child:Text(a.data?.exists==true?'إلغاء المشاركة':'نشارك')),if((data['createdBy']??'').toString()==FirebaseService.user?.uid)PopupMenuButton<String>(onSelected:(v){if(v=='edit')editEvent(doc.id,data);if(v=='delete')deleteEvent(doc.id);},itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('عدّل المناسبة')),PopupMenuItem(value:'delete',child:Text('احذف المناسبة'))])]),
              )));
            }),
        ]);
      },
    );
  }

  Future<void> createDirectoryEntry() async {
    final name=TextEditingController(), category=TextEditingController(), description=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('زيد خدمة / شركة'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'الاسم')),TextField(controller:category,decoration:const InputDecoration(labelText:'الصنف')),TextField(controller:description,maxLines:3,decoration:const InputDecoration(labelText:'الوصف'))])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,name.text.trim().isNotEmpty&&category.text.trim().isNotEmpty),child:const Text('انشر'))]));
    if(ok==true){
      try {
        await FirebaseService.saveService(name:name.text,category:category.text,description:description.text);
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('الخدمة / الشركة تضافت.')));
      } catch(e,st) {
        debugPrint('LEF_LEF directory entry failed: $e');
        debugPrintStack(stackTrace:st);
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نضيف الخدمة توا.')));
      }
    }
    name.dispose();category.dispose();description.dispose();
  }

  Widget directory() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseService.serviceDirectory(),
      builder: (context, snap) {
        if (snap.hasError) return const Text('دليل الخدمات موش متوفر توا.');
        if (!snap.hasData) return const SizedBox(height: 70, child: Center(child: CircularProgressIndicator()));
        final docs = snap.data!.docs.where((d) {
          final x = d.data();
          return x['active'] == true;
        }).toList()
          ..sort((a, b) {
            final an = (a.data()['name'] ?? '').toString().toLowerCase();
            final bn = (b.data()['name'] ?? '').toString().toLowerCase();
            return an.compareTo(bn);
          });
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children:[const Expanded(child:Text('الخدمات والشركات', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),TextButton.icon(onPressed:createDirectoryEntry,icon:const Icon(Icons.add_business),label:const Text('زيد'))]),
          const SizedBox(height: 8),
          if (docs.isEmpty)
            const Card(child: ListTile(title: Text('دليل الخدمات والشركات حاضر للالسائقات والشركات.')))
          else
            ...docs.map((doc) {
              final data = doc.data();
              return Card(child: ListTile(
                leading: const Icon(Icons.business_center, color: LefTheme.goldDark),
                title: Text((data['name'] ?? 'الخدمة').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${data['category'] ?? ''}\n${data['description'] ?? ''}'),
                trailing:(data['createdBy']??'').toString()==FirebaseService.user?.uid?PopupMenuButton<String>(onSelected:(v){if(v=='edit')editDirectoryEntry(doc.id,data);if(v=='delete')deleteDirectoryEntry(doc.id);},itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('عدّل الخدمة')),PopupMenuItem(value:'delete',child:Text('احذف الخدمة'))]):null,
              ));
            }),
        ]);
      },
    );
  }

  Widget globalSearchResults() {
    final q = globalSearch.text.trim().toLowerCase();
    if (q.length < 2) return const SizedBox.shrink();
    bool matches(Map<String, dynamic> data, List<String> keys) => keys.any((key) => (data[key] ?? '').toString().toLowerCase().contains(q));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('نتائج البحث العام', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseService.db.collection('posts').orderBy('createdAt', descending: true).limit(60).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return const ListTile(title: Text('المنشورات: البحث موش متوفر توا.'));
          if (!snap.hasData) return const LinearProgressIndicator();
          final docs = snap.data!.docs.where((d) => matches(d.data(), ['text'])).take(5).toList();
          if (docs.isEmpty) return const SizedBox.shrink();
          return Card(child: Column(children: [const ListTile(leading: Icon(Icons.dynamic_feed), title: Text('منشورات المجتمع', style: TextStyle(fontWeight: FontWeight.w800))), ...docs.map((d) => ListTile(title: Text((d.data()['text'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis), subtitle: const Text('منشور'), onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('افتح المنشور من الرئيسية للتفاعل معاه.')))))]));
        },
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseService.db.collection('events').limit(100).snapshots(),
        builder: (context, snap) {
          if (snap.hasError || !snap.hasData) return const SizedBox.shrink();
          final docs = snap.data!.docs.where((d) => d.data()['status'] == 'published' && matches(d.data(), ['title', 'place', 'description'])).take(5).toList();
          if (docs.isEmpty) return const SizedBox.shrink();
          return Card(child: Column(children: [const ListTile(leading: Icon(Icons.event), title: Text('الأنشطة والمناسبات', style: TextStyle(fontWeight: FontWeight.w800))), ...docs.map((d) => ListTile(title: Text((d.data()['title'] ?? 'مناسبة').toString()), subtitle: Text((d.data()['place'] ?? '').toString())))]));
        },
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseService.serviceDirectory().asBroadcastStream(),
        builder: (context, snap) {
          if (snap.hasError || !snap.hasData) return const SizedBox.shrink();
          final docs = snap.data!.docs.where((d) => d.data()['active'] == true && matches(d.data(), ['name', 'category', 'description'])).take(5).toList();
          if (docs.isEmpty) return const SizedBox.shrink();
          return Card(child: Column(children: [const ListTile(leading: Icon(Icons.storefront), title: Text('الخدمات والشركات', style: TextStyle(fontWeight: FontWeight.w800))), ...docs.map((d) => ListTile(title: Text((d.data()['name'] ?? 'خدمة').toString()), subtitle: Text('${d.data()['category'] ?? ''} • ${d.data()['description'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis)))]));
        },
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 58, 16, 120),
      children: [
        const Text('اكتشف', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
        const Text('بلايص • ناس • أنشطة • مناسبات', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 18),
        TextField(controller: globalSearch, onChanged: (_) => setState(() {}), textInputAction: TextInputAction.search, decoration: const InputDecoration(prefixIcon: Icon(Icons.manage_search), hintText: 'لوج على منشورات، مناسبات، خدمات...')),
        const SizedBox(height: 8),
        globalSearchResults(),
        const SizedBox(height: 12),
        TextField(controller: search, onSubmitted: (_) => searchPlaces(), decoration: InputDecoration(prefixIcon: const Icon(Icons.location_searching), hintText: 'لوج على بلاصة في الخريطة...', suffixIcon: IconButton(tooltip: 'ابحث على بلاصة', onPressed: placeSearching ? null : searchPlaces, icon: placeSearching ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_forward)))),
        const SizedBox(height: 20),
        people(),
        const SizedBox(height: 18),
        ...placeResults.map((p) => Card(child: ListTile(leading: const Icon(Icons.location_on_outlined, color: LefTheme.goldDark), title: Text(p.displayName, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text([p.area,p.city].whereType<String>().where((x)=>x.isNotEmpty).join(' • ')), trailing: IconButton(onPressed: () => save(p.displayName, p.city ?? p.area ?? ''), icon: const Icon(Icons.bookmark_border))))),
        const SizedBox(height: 18),
        events(),
        const SizedBox(height: 22),
        directory(),
      ],
    );
  }
}
