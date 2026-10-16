import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/app_models.dart';
import '../services/firebase_service.dart';

class OwnerScreen extends StatelessWidget {
  const OwnerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseService.user?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('يلزمك تكون داخل للحساب.')));
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseService.db.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? const <String, dynamic>{};
        final role = data['role']?.toString() ?? 'client';
        final caps = List<String>.from(data['capabilities'] ?? const <String>[]);
        final admin = role == 'owner';
        final canManageRides = admin || role == 'manager' || caps.contains(Capability.manageRides.name);
        final canManageServices = admin || caps.contains(Capability.manageServices.name);
        if (!admin && !canManageRides && !canManageServices) {
          return const Scaffold(body: Center(child: Text('ما عندكش صلاحية لمتابعة المشاوير أو إعداد الخدمات.')));
        }
        return _OwnerBody(showAdmin: admin, canManageRides: canManageRides, canManageServices: canManageServices);
      },
    );
  }
}

class _OwnerBody extends StatelessWidget {
  const _OwnerBody({required this.showAdmin, required this.canManageRides, required this.canManageServices});
  final bool showAdmin;
  final bool canManageRides;
  final bool canManageServices;

  Widget cancellationReviews(BuildContext context) {
    Widget listFor(String collection, String title) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream: FirebaseService.db.collection(collection).orderBy('createdAt', descending: true).limit(100).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return const ListTile(title: Text('سجلّ الإلغاءات غير متاح'), subtitle: Text('تثبّت من صلاحيات الإدارة واتصال Firebase.'));
          if (!snap.hasData) return const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator());
          final docs = snap.data!.docs.where((d) => d.data()['reviewStatus'] == 'pending').toList();
          if (docs.isEmpty) return const ListTile(leading: Icon(Icons.check_circle_outline), title: Text('ما فماش إلغاءات تستنى المراجعة.'));
          return Column(children: docs.map((doc) {
            final x = doc.data();
            final actor = (x[collection == 'providerCancellationEvents' ? 'providerId' : 'clientId'] ?? '').toString();
            final ride = (x['rideId'] ?? '').toString();
            return Card(child: ListTile(
              leading: Icon(collection == 'providerCancellationEvents' ? Icons.drive_eta_outlined : Icons.person_off_outlined, color: LefTheme.goldDark),
              title: Text(collection == 'providerCancellationEvents' ? 'إلغاء من سائق' : 'إلغاء من حريف'),
              subtitle: Text('الحساب: $actor\nالرحلة: $ride\nالسبب: ${x['reason'] ?? 'غير محدد'}', maxLines: 5), isThreeLine: true,
              trailing: PopupMenuButton<String>(tooltip: 'مراجعة', onSelected: (v) async {
                try {
                  await doc.reference.update({'reviewStatus': v, 'reviewedBy': FirebaseService.user?.uid, 'reviewedAt': FieldValue.serverTimestamp()});
                  if (v == 'suspension_recommended' && collection == 'providerCancellationEvents' && actor.isNotEmpty) {
                    await FirebaseService.db.collection('users').doc(actor).set({'providerAvailable': false, 'providerUpdatedAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                  }
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تسجّلت نتيجة المراجعة.')));
                } catch (_) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما نجّمش نسجّل المراجعة.'))); }
              }, itemBuilder: (_) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(value: 'reviewed', child: Text('تمت المراجعة')),
                if (collection == 'providerCancellationEvents') const PopupMenuItem<String>(value: 'suspension_recommended', child: Text('تعليق استقبال الطلبات')),
                const PopupMenuItem<String>(value: 'dismissed', child: Text('إغلاق دون إجراء')),
              ]),
            ));
          }).toList());
        },
      ), const SizedBox(height: 14),
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [listFor('providerCancellationEvents', 'مراجعة إلغاءات السائقين'), listFor('customerCancellationEvents', 'مراجعة إلغاءات الحرفاء')]);
  }

  Widget metric(String label, Stream<QuerySnapshot<Map<String, dynamic>>> stream) {
    return Card(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.black54)),
            Text('${snap.data?.size ?? 0}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: LefTheme.goldDark)),
          ]),
        ),
      ),
    );
  }

  Future<void> review(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc, bool approve) async {
    final data = doc.data();
    final roleName = data['requestedRole']?.toString() ?? 'client';
    final requested = AppRole.values.firstWhere((r) => r.name == roleName, orElse: () => AppRole.client);
    final name = (data['email'] ?? data['userId'] ?? 'مستخدم').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(approve ? 'تقبل طلب الدور؟' : 'ترفض طلب الدور؟'),
        content: Text('${approve ? 'اعطي' : 'ارفض'} ${roleLabel(requested)} للمستخدم $name.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(approve ? 'اقبل' : 'ارفض')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseService.reviewRoleRequest(
        doc.id,
        approve: approve,
        userId: data['userId'].toString(),
        requestedRole: requested,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? 'الدور تقبل.' : 'الطلب ترفض.')));
      }
    } catch (e) { debugPrint('LEF_LEF operation failed: $e');
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما نجّمش نراجع الطلب هذا.')));
    }
  }

  Widget ridePricingEditor(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: FirebaseService.getRidePricing(),
      builder: (context, snap) {
        if (snap.hasError) return const Text('ما نجّمش نجيبوا إعدادات الأسعار الحالية.');
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final current = snap.data!;
        final bases = Map<String, dynamic>.from(current['baseFares'] as Map);
        final days = Map<String, dynamic>.from(current['dayRates'] as Map);
        final nights = Map<String, dynamic>.from(current['nightRates'] as Map);
        final negotiated = Set<String>.from(current['negotiableKinds'] as List);
        final controllers = <String, TextEditingController>{};
        for (final o in serviceOptions) {
          controllers['${o.kind.name}_base'] = TextEditingController(text: ((bases[o.kind.name] as num?)?.toDouble() ?? o.base).toStringAsFixed(2));
          controllers['${o.kind.name}_day'] = TextEditingController(text: ((days[o.kind.name] as num?)?.toDouble() ?? o.dayKm).toStringAsFixed(2));
          controllers['${o.kind.name}_night'] = TextEditingController(text: ((nights[o.kind.name] as num?)?.toDouble() ?? o.nightKm).toStringAsFixed(2));
        }
        return StatefulBuilder(builder: (context, setLocal) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('إعدادات أسعار الخدمات', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('المالك وحده يبدّل القواعد. الأسعار الجديدة تتطبّق على الطلبات الجديدة؛ الطلبات الموجودة تحتفظ بالسعر المتفق عليه.', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          for (final o in serviceOptions) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: negotiated.contains(o.kind.name),
                  title: const Text('السوم بالتفاهم'),
                  subtitle: const Text('مفعّل: السائق يقدّم عرضًا. معطّل: يتحسب السعر آليًا.'),
                  onChanged: (value) => setLocal(() { if (value) { negotiated.add(o.kind.name); } else { negotiated.remove(o.kind.name); } }),
                ),
                if (!negotiated.contains(o.kind.name)) ...[
                  Row(children: [
                    Expanded(child: TextField(controller: controllers['${o.kind.name}_base'], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'المبلغ الأساسي (د.ت)'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: controllers['${o.kind.name}_day'], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'نهار / كم'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: controllers['${o.kind.name}_night'], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'ليل / كم'))),
                  ]),
                ] else
                  const Text('ما يظهرش مبلغ تقديري للحريف قبل العرض؛ يتفاوض مع صاحب الخدمة.', style: TextStyle(color: Colors.black54)),
              ]),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(width: double.infinity, child: FilledButton.icon(icon: const Icon(Icons.save_outlined), label: const Text('حفظ إعدادات الأسعار'), onPressed: () async {
            double? read(String key) => double.tryParse(controllers[key]!.text.trim().replaceAll(',', '.'));
            final newBases = <String, double>{}, newDays = <String, double>{}, newNights = <String, double>{};
            for (final o in serviceOptions) {
              final b = read('${o.kind.name}_base'), d = read('${o.kind.name}_day'), n = read('${o.kind.name}_night');
              if (b == null || d == null || n == null || !b.isFinite || !d.isFinite || !n.isFinite || b < 0 || d < 0 || n < 0 || b > 1000 || d > 1000 || n > 1000) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('راجع الإعدادات: يلزم أرقام بين 0 و1000.'))); return;
              }
              if (!negotiated.contains(o.kind.name) && (b + d <= 0 || b + n <= 0)) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدّد سعرًا موجبًا للنهار والليل في خدمة ${o.title}.'))); return;
              }
              newBases[o.kind.name] = b; newDays[o.kind.name] = d; newNights[o.kind.name] = n;
            }
            try {
              await FirebaseService.saveRidePricing(baseFares: newBases, dayRates: newDays, nightRates: newNights, negotiableKinds: negotiated);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('إعدادات الأسعار تحفظت وتطبّق على الطلبات الجديدة.')));
            } catch (_) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما نجّمش نحفظ إعدادات الأسعار. تثبّت من صلاحية المالك والإنترنت وقواعد Firebase.')));
            }
          })),
        ]))));
      },
    );
  }

  Widget requests(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseService.db.collection('roleRequests').where('status', isEqualTo: 'pending').limit(30).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const Text('طلبات الأدوار موش متوفرة توا.');
        if (!snap.hasData) return const CircularProgressIndicator();
        if (snap.data!.docs.isEmpty) return const Card(child: ListTile(title: Text('ما فماش طلبات مستنية.')));
        return Column(
          children: snap.data!.docs.map((doc) {
            final data = doc.data();
            final requested = AppRole.values.firstWhere((r) => r.name == data['requestedRole'], orElse: () => AppRole.client);
            return Card(
              child: ListTile(
                title: Text(roleLabel(requested), style: const TextStyle(fontWeight: FontWeight.w800)),
                onTap: () => _showRoleApplication(context, data),
                subtitle: Text([ (data['applicantName'] ?? data['email'] ?? data['userId'] ?? '').toString(), (data['phone'] ?? '').toString(), (data['vehicleType'] != null ? '${data['vehicleType']} • ${data['vehicleModel'] ?? ''} • ${data['vehiclePlate'] ?? ''}' : '${data['companyName'] ?? ''} • ${data['taxId'] ?? ''}') ].where((v) => v.trim().isNotEmpty).join('\n')),
                isThreeLine: true,
                trailing: Wrap(spacing: 4, children: [
                  IconButton(onPressed: () => review(context, doc, false), icon: const Icon(Icons.close)),
                  IconButton(onPressed: () => review(context, doc, true), icon: const Icon(Icons.check, color: LefTheme.goldDark)),
                ]),
              ),
            );
          }).toList(),
        );
      },
    );
  }


  Future<void> _showRoleApplication(BuildContext context, Map<String, dynamic> data) async {
    final docs = Map<String, dynamic>.from(data['documentPaths'] is Map ? data['documentPaths'] as Map : const {});
    String label(String key) => switch (key) { 'identity' => 'بطاقة التعريف', 'license' => 'رخصة السياقة', 'vehicleRegistration' => 'تسجيل المركبة', 'insurance' => 'التأمين', 'companyRegistration' => 'تسجيل الشركة', _ => key };
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('ملف طالب الخدمة'),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('الاسم: ${data['applicantName'] ?? '—'}'), Text('الهاتف: ${data['phone'] ?? '—'}'),
        Text('المركبة: ${data['vehicleType'] ?? '—'} ${data['vehicleModel'] ?? ''} ${data['vehiclePlate'] ?? ''}'),
        Text('الشركة: ${data['companyName'] ?? '—'}'), Text('المعرف: ${data['taxId'] ?? '—'}'),
        const SizedBox(height: 12), const Text('الوثائق المرفوعة', style: TextStyle(fontWeight: FontWeight.w900)),
        for (final entry in docs.entries) ListTile(contentPadding: EdgeInsets.zero, title: Text(label(entry.key)), subtitle: Text('وثيقة خاصة — العرض للمسؤول المخوّل فقط'), trailing: IconButton(icon: const Icon(Icons.visibility_outlined), onPressed: () async {
          try { final url = await FirebaseStorage.instance.ref(entry.value.toString()).getDownloadURL(); if (!dialogContext.mounted) return; await showDialog<void>(context: dialogContext, builder: (c) => AlertDialog(title: Text(label(entry.key)), content: InteractiveViewer(child: Image.network(url, errorBuilder: (_, __, ___) => const Text('ما نجّمش نعرض الوثيقة.'))), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('سكر'))])); }
          catch (_) { if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('الوثيقة موش متاحة. تثبّت من صلاحيات Storage.'))); }
        })),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('سكر'))],
    ));
  }

  Future<void> editCapabilities(BuildContext context, QueryDocumentSnapshot<Map<String,dynamic>> doc) async {
    final data=doc.data();
    final current=Set<String>.from(List<String>.from(data['capabilities']??const []));
    final selected=Set<Capability>.from(Capability.values.where((c)=>current.contains(c.name)));
    final targetRole=data['role']?.toString()??'client';
    final editableCapabilities=Capability.values.toSet();
    final result=await showDialog<Set<Capability>>(
      context:context,
      builder:(c)=>StatefulBuilder(builder:(c,setDialog)=>AlertDialog(
        title:Text('صلاحيات ${(data['displayName']??data['email']??doc.id).toString()}'),
        content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          for(final capability in editableCapabilities) CheckboxListTile(value:selected.contains(capability),onChanged:(v)=>setDialog(()=>v==true?selected.add(capability):selected.remove(capability)),title:Text(capabilityLabel(capability)),dense:true),
        ]))),
        actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,Set<Capability>.from(selected)),child:const Text('احفظ'))],
      )),
    );
    if(result==null)return;
    try{await FirebaseService.setUserCapabilities(doc.id,result);if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('الصلاحيات تبدّلت.')));}catch(_){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نبدّل الصلاحيات.')));}
  }

  Widget capabilities(BuildContext context) {
    return Card(child:ListTile(
      leading:const Icon(Icons.tune_rounded,color:LefTheme.goldDark),
      title:const Text('تفويض الصلاحيات',style:TextStyle(fontWeight:FontWeight.w800)),
      subtitle:const Text('اختار شكون ينجم يدير المستخدمين، الأدوار، الخدمات، المشاوير والمحتوى.'),
      trailing:const Icon(Icons.chevron_right),
      onTap:()async{
        final uid=FirebaseService.user?.uid;if(uid==null)return;
        final snap=await FirebaseService.db.collection('users').limit(50).get();
        final choices=snap.docs.where((d)=>d.id!=uid&&d.data()['role']!='owner').toList();
        if(!context.mounted)return;
        if(choices.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما فماش مستخدمين للتفويض توا.')));return;}
        await showModalBottomSheet(context:context,showDragHandle:true,builder:(c)=>SafeArea(child:ListView(shrinkWrap:true,children:[for(final doc in choices)ListTile(title:Text((doc.data()['displayName']??doc.data()['email']??doc.id).toString()),subtitle:Text(roleLabel(AppRole.values.firstWhere((r)=>r.name==doc.data()['role'],orElse:()=>AppRole.client))),trailing:const Icon(Icons.tune),onTap:(){Navigator.pop(c);editCapabilities(context,doc);} )])));
      },
    ));
  }

  Widget reports(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseService.openReports(),
      builder: (context, snap) {
        if (snap.hasError) return const Text('التبليغات موش متوفرة توا.');
        if (!snap.hasData) return const CircularProgressIndicator();
        if (snap.data!.docs.isEmpty) return const Card(child: ListTile(title: Text('ما فماش تبليغات مفتوحة.')));
        return Column(children: snap.data!.docs.map((doc) {
          final x = doc.data();
          return Card(child: ListTile(
            leading: const Icon(Icons.flag_outlined, color: LefTheme.goldDark),
            title: Text('${x['type'] ?? 'بلّغ'} • ${x['targetId'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('السبب: ${(x['reason'] ?? '').toString()}\nالتفاصيل: ${(x['details'] ?? 'ما فماش تفاصيل إضافية').toString()}\nالمبلّغ: ${(x['reporterId'] ?? '').toString()}'),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(tooltip: 'إجراء على الشكوى', onSelected: (choice) async { try { await FirebaseService.resolveReport(doc.id, status: choice); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(choice == 'resolved' ? 'الشكوى تسكّرت بعد المتابعة.' : 'الشكوى تسكّرت كغير مثبتة.'))); } catch (e) { debugPrint('LEF_LEF operation failed: $e'); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما نجّمش نسكّر الشكوى توا.'))); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'resolved', child: Text('تمت المتابعة')), PopupMenuItem(value: 'dismissed', child: Text('غير مثبتة / مرفوضة'))]),
          ));
        }).toList());
      },
    );
  }

  Widget complaints(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseService.openComplaints(),builder:(context,snap){
      if(snap.hasError)return const Text('الشكاوي موش متوفرة توا.');
      if(!snap.hasData)return const CircularProgressIndicator();
      if(snap.data!.docs.isEmpty)return const Card(child:ListTile(title:Text('ما فماش شكاوي مفتوحة.')));
      return Column(children:snap.data!.docs.map((doc){final x=doc.data();final userId=x['userId']?.toString()??'';return Card(child:ListTile(leading:const Icon(Icons.support_agent_outlined,color:LefTheme.goldDark),title:Text(x['subject']?.toString()??'شكوى'),subtitle:Text('${x['category']??''} • ${x['details']??''}\nالمستخدم: $userId'),isThreeLine:true,trailing:PopupMenuButton<String>(tooltip:'متابعة الشكوى',onSelected:(choice)async{final reply=TextEditingController();if(choice=='resolved'){final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('ردّ الإدارة'),content:TextField(controller:reply,maxLines:3,maxLength:1000,decoration:const InputDecoration(hintText:'اكتب الردّ أو النتيجة')),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حفظ وإغلاق'))]));if(ok!=true){reply.dispose();return;}}try{await FirebaseService.resolveComplaint(userId:userId,complaintId:doc.id,status:choice,adminReply:reply.text);if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('حالة الشكوى تحدّثت.')));}catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نحدّث الشكوى.')));}reply.dispose();},itemBuilder:(_)=>const [PopupMenuItem(value:'in_review',child:Text('قيد المتابعة')),PopupMenuItem(value:'resolved',child:Text('تمت المتابعة وإغلاقها')),PopupMenuItem(value:'dismissed',child:Text('غير مثبتة / مرفوضة'))])));}).toList());
    });
  }

  Widget subscriptions(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseService.subscriptions(),
      builder: (context, snap) {
        if (snap.hasError) return const Text('الاشتراكات موش متوفرة توا.');
        if (!snap.hasData) return const CircularProgressIndicator();
        return Column(children: snap.data!.docs.map((doc) {
          final x = doc.data(); final plan = (x['plan'] ?? 'free').toString();
          return Card(child: ListTile(
            title: Text((x['uid'] ?? doc.id).toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('الخطة: $plan • ${x['status'] ?? 'active'}'),
            trailing: DropdownButton<String>(value: ['free','plus','business'].contains(plan) ? plan : 'free', items: const [DropdownMenuItem(value:'free',child:Text('مجاني')),DropdownMenuItem(value:'plus',child:Text('Plus')),DropdownMenuItem(value:'business',child:Text('شركة'))], onChanged: (v) async { if(v==null)return; try{await FirebaseService.setSubscriptionPlan(doc.id,v); }catch(_){ if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نبدّل الاشتراك.'))); } }),
          ));
        }).toList());
      },
    );
  }

  Widget users(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseService.db.collection('users').limit(50).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const Text('المستخدمين موش متوفرين توا.');
        if (!snap.hasData) return const CircularProgressIndicator();
        final me = FirebaseService.user?.uid;
        return Column(
          children: snap.data!.docs.map((doc) {
            final data = doc.data();
            final current = data['role']?.toString() ?? 'client';
            final locked = doc.id == me && current == 'owner';
            final display = (data['displayName'] ?? data['email'] ?? doc.id).toString();
            return Card(
              child: ListTile(
                onLongPress: locked ? null : () => editCapabilities(context, doc),
                title: Text(display),
                subtitle: Text((data['email'] ?? '').toString()),
                trailing: DropdownButton<String>(
                  value: AppRole.values.any((r) => r.name == current) ? current : 'client',
                  items: AppRole.values.where((r) => current == 'owner' || r != AppRole.owner).map((r) => DropdownMenuItem(value: r.name, child: Text(roleLabel(r)))).toList(),
                  onChanged: locked
                      ? null
                      : (value) async {
                          if (value == null || value == current) return;
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('تبدّل الدور؟'),
                              content: Text('تبدّل $display لـ ${roleLabel(AppRole.values.firstWhere((r) => r.name == value))}؟'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('خليه كيف ما هو')),
                                FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('أكد')),
                              ],
                            ),
                          );
                          if (ok != true) return;
                          try {
                            await FirebaseService.updateUserRole(doc.id, AppRole.values.firstWhere((r)=>r.name==value));
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الدور تبدّل.')));
                          } catch (e) { debugPrint('LEF_LEF operation failed: $e');
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما نجّمش نبدّل الدور.')));
                          }
                        },
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _dateLabel(dynamic value) {
    DateTime? date;
    if (value is Timestamp) date = value.toDate();
    if (value is DateTime) date = value;
    if (date == null) return 'الوقت موش متوفر';
    final d = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} • ${two(d.hour)}:${two(d.minute)}';
  }

  String _money(dynamic value) {
    if (value is num && value.isFinite && value > 0) return '${value.toStringAsFixed(2)} د.ت';
    return 'بالتفاهم';
  }

  String _kindLabel(dynamic value) {
    final raw = value?.toString() ?? '';
    for (final option in serviceOptions) {
      if (option.kind.name == raw) return option.title;
    }
    return raw.isEmpty ? 'خدمة' : raw;
  }

  Future<void> _rideDetails(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final x = doc.data();
    Future<String> userLabel(String key) async {
      final value = x[key]?.toString();
      if (value == null || value.isEmpty || value == 'null') return 'ما تعيّنش';
      try {
        final profile = await FirebaseService.db.collection('publicProfiles').doc(value).get();
        final data = profile.data() ?? const <String, dynamic>{};
        final name = (data['displayName'] ?? data['name'] ?? data['email'])?.toString().trim();
        return name == null || name.isEmpty ? value : '$name ($value)';
      } catch (_) { return value; }
    }
    final clientLabel = await userLabel('clientId');
    final providerLabel = await userLabel('providerId');
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('تفاصيل ${_kindLabel(x['kind'])}'),
        content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _detailLine('رقم الطلب', doc.id),
          _detailLine('الحالة', rideStageLabel(x['status']?.toString() ?? '')),
          _detailLine('الانطلاق', (x['pickup'] ?? 'موش محدّد').toString()),
          _detailLine('الوصول', (x['destination'] ?? 'موش محدّد').toString()),
          _detailLine('الحريف', clientLabel),
          _detailLine('السائق / صاحب الخدمة', providerLabel),
          _detailLine('المسافة', x['distanceKm'] is num ? '${(x['distanceKm'] as num).toStringAsFixed(2)} كم' : 'موش متوفرة'),
          _detailLine('السوم التقديري', x['negotiable'] == true ? 'بالتفاهم' : _money(x['estimatedFare'])),
          if (x['offerFare'] is num) _detailLine('العرض الحالي', _money(x['offerFare'])),
          if (x['clientCounterFare'] is num) _detailLine('عرض الحريف', _money(x['clientCounterFare'])),
          _detailLine('وقت الطلب', _dateLabel(x['createdAt'])),
          _detailLine('آخر تحديث', _dateLabel(x['updatedAt'])),
          if (x['priority'] == 'emergency') _detailLine('تنبيه', 'طلب استعجالي'),
          if (x['priority'] == 'medical') _detailLine('تنبيه', 'طلب إسعاف'),
        ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('سكر'))],
      ),
    );
  }

  Widget _detailLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 135, child: Text(label, style: const TextStyle(color: Colors.black54))), Expanded(child: SelectableText(value, style: const TextStyle(fontWeight: FontWeight.w700)))]),
  );

  Widget rides(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseService.db.collection('rides').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const Card(child: ListTile(title: Text('المشاوير موش متاحة توا'), subtitle: Text('تثبّت من الاتصال والصلاحيات.')));
        if (!snap.hasData) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
        final docs = snap.data!.docs.toList()..sort((a, b) {
          final av = a.data()['createdAt']; final bv = b.data()['createdAt'];
          final at = av is Timestamp ? av.millisecondsSinceEpoch : 0;
          final bt = bv is Timestamp ? bv.millisecondsSinceEpoch : 0;
          return bt.compareTo(at);
        });
        const filters = <String, String>{'all':'الكل','searching':'تستنى السائق','offered':'عروض','countered':'تفاوض','accepted':'مقبول','arriving':'في الثنية','arrived':'وصل','active':'قاعد يصير','completed':'كمل','cancelled':'تلغى'};
        return _RideList(docs: docs, dateLabel: _dateLabel, kindLabel: _kindLabel, money: _money, details: _rideDetails, filters: filters);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(showAdmin ? 'مركز الإدارة' : canManageRides ? 'متابعة المشاوير' : 'إعداد الخدمات والأسعار', style: const TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (showAdmin) ...[
          const Text('ملخّص الخدمة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: metric('المستخدمين', FirebaseService.db.collection('users').snapshots())), const SizedBox(width: 10), Expanded(child: metric('كلّ المشاوير', FirebaseService.db.collection('rides').snapshots()))]),
          const SizedBox(height: 22),
          const Text('طلبات الأدوار المستنية', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8), requests(context),
          const SizedBox(height: 22),
          const Text('الأدوار والصلاحيات', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8), capabilities(context),
          const SizedBox(height: 16),
          const Text('التبليغات والمراقبة', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8), reports(context),
          const SizedBox(height: 8), complaints(context),
          const SizedBox(height: 18), cancellationReviews(context),
          const SizedBox(height: 22),
          if (FirebaseService.user != null)
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseService.db.collection('users').doc(FirebaseService.user!.uid).snapshots(),
              builder: (context, roleSnap) {
                if (roleSnap.data?.data()?['role']?.toString() != 'owner') return const SizedBox.shrink();
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('الاشتراكات', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8), subscriptions(context), const SizedBox(height: 22),
                ]);
              },
            ),
          const Text('المستخدمين', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8), users(context),
          const SizedBox(height: 22),
        ],
        if (canManageServices) ...[
          const Text('إعداد الخدمات والأسعار', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ridePricingEditor(context),
          const SizedBox(height: 8),
          const Text('سجل تغييرات الأسعار',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
          StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
            stream:FirebaseService.ridePricingHistory(),
            builder:(context,historySnap){
              if(historySnap.hasError)return const ListTile(title:Text('سجل الأسعار موش متوفر توا.'));
              if(!historySnap.hasData)return const Padding(padding:EdgeInsets.all(12),child:Center(child:CircularProgressIndicator()));
              final docs=historySnap.data!.docs;
              if(docs.isEmpty)return const ListTile(title:Text('ما فماش تغييرات أسعار محفوظة بعد.'));
              return Column(children:docs.map((doc){
                final x=doc.data();final stamp=x['changedAt'];final when=stamp is Timestamp?stamp.toDate().toLocal().toString().substring(0,16):'وقت غير متوفر';
                return Card(child:ListTile(leading:const Icon(Icons.history,color:LefTheme.goldDark),title:Text('تغيير أسعار • $when'),subtitle:Text('معرّف التغيير: ${doc.id.substring(0,doc.id.length>8?8:doc.id.length)}'),trailing:TextButton(onPressed:()async{
                  final confirm=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('ترجّع الأسعار القديمة؟'),content:const Text('باش نرجّعو القيم السابقة ونسجّلو عملية الاسترجاع في السجل.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('رجّع'))]));
                  if(confirm!=true)return;
                  final password=TextEditingController();
                  final verified=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('تأكيد الهوية'),content:TextField(controller:password,obscureText:true,autofocus:true,decoration:const InputDecoration(labelText:'كلمة المرور الحالية')),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('تحقّق وواصل'))]));
                  if(verified!=true){password.dispose();return;}
                  try{await FirebaseService.reauthenticateCurrentUser(password.text);await FirebaseService.restoreRidePricingVersion(doc.id);if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('الأسعار السابقة ترجعت وتوثّقت العملية.')));}catch(e){debugPrint('LEF_LEF pricing restore failed: $e');if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تعذّر التحقق أو استرجاع الأسعار. تثبّت من كلمة المرور والصلاحيات.')));}finally{password.dispose();}
                },child:const Text('استرجاع'))));
              }).toList());
            },
          ),
          const SizedBox(height: 22),
        ],
        if (canManageRides) ...[
          const Text('كلّ المشاوير', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('اختار أي مشوار باش تشوف تفاصيله كاملة.', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 10),
          rides(context),
        ],
      ]),
    );
  }
}

class _RideList extends StatefulWidget {
  const _RideList({required this.docs, required this.dateLabel, required this.kindLabel, required this.money, required this.details, required this.filters});
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final String Function(dynamic) dateLabel;
  final String Function(dynamic) kindLabel;
  final String Function(dynamic) money;
  final Future<void> Function(BuildContext, QueryDocumentSnapshot<Map<String, dynamic>>) details;
  final Map<String, String> filters;
  @override State<_RideList> createState() => _RideListState();
}

class _RideListState extends State<_RideList> {
  String selected = 'all';
  @override Widget build(BuildContext context) {
    final filtered = widget.docs.where((d) => selected == 'all' || d.data()['status']?.toString() == selected).toList();
    final counts = <String, int>{'all': widget.docs.length};
    for (final d in widget.docs) { final s = d.data()['status']?.toString() ?? ''; counts[s] = (counts[s] ?? 0) + 1; }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 7, runSpacing: 7, children: [for (final f in widget.filters.entries) ChoiceChip(label: Text('${f.value} (${counts[f.key] ?? 0})'), selected: selected == f.key, onSelected: (_) => setState(() => selected = f.key))]),
      const SizedBox(height: 10),
      if (filtered.isEmpty) const Card(child: ListTile(leading: Icon(Icons.route_outlined), title: Text('ما فماش مشاوير في الحالة هاذي.'))),
      for (final doc in filtered) ...[
        Card(child: ListTile(
          leading: CircleAvatar(backgroundColor: const Color(0xFFFFF2CC), child: Icon(doc.data()['priority'] == 'emergency' ? Icons.emergency : Icons.route_rounded, color: LefTheme.goldDark)),
          title: Text('${widget.kindLabel(doc.data()['kind'])} • ${rideStageLabel(doc.data()['status']?.toString() ?? '')}', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${doc.data()['pickup'] ?? 'انطلاق غير محدّد'} ← ${doc.data()['destination'] ?? 'وصول غير محدّد'}\n${widget.dateLabel(doc.data()['createdAt'])} • ${doc.data()['negotiable'] == true ? 'بالتفاهم' : widget.money(doc.data()['estimatedFare'])}', maxLines: 3, overflow: TextOverflow.ellipsis),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => widget.details(context, doc),
        )),
      ],
    ]);
  }
}
