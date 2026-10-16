import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../models/app_models.dart';
import '../services/firebase_service.dart';
import '../widgets/section_title.dart';
import 'notifications_screen.dart';
import '../widgets/media_preview.dart';
class HomeScreen extends StatefulWidget{const HomeScreen({super.key,required this.onMove,this.onExplore,this.onMenu});final ValueChanged<ServiceKind> onMove;final VoidCallback? onExplore;final VoidCallback? onMenu;@override State<HomeScreen>createState()=>_HomeState();}
class _HomeState extends State<HomeScreen>{final composer=TextEditingController();@override void dispose(){composer.dispose();super.dispose();}
Future<void>post()async{final text=composer.text.trim();if(text.isEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('اكتب حاجة قبل ما تنشر.')));return;}try{await FirebaseService.createPost(text);composer.clear();if(mounted){setState((){});ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('المنشور تضاف.')));}}catch(e,st){debugPrint('LEF_LEF quick post failed: $e');debugPrintStack(stackTrace:st);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش ننشر المنشور. تثبّت من الإنترنت وحجم التصويرة/الفيديو (أقل من 50 ميغابايت) وعاود.')));}}
Future<void> newStory() async {
  final controller = TextEditingController();
  File? media;
  String? mediaType;
  final picker = ImagePicker();
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialog) => AlertDialog(
        title: const Text('ستوري جديدة'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: controller, onChanged: (_) => setDialog(() {}), maxLines: 3, maxLength: 500, decoration: const InputDecoration(hintText: 'شارك لحظة...')),
          const SizedBox(height: 10),
          if (media != null) ListTile(leading: Icon(mediaType == 'video' ? Icons.videocam : Icons.image), title: Text(media!.path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis), trailing: IconButton(onPressed: () => setDialog(() { media = null; mediaType = null; }), icon: const Icon(Icons.close))),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () async { final f = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88); if (f != null) setDialog(() { media = File(f.path); mediaType = 'image'; }); }, icon: const Icon(Icons.photo_outlined), label: const Text('صورة'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () async { final f = await picker.pickVideo(source: ImageSource.gallery); if (f != null) setDialog(() { media = File(f.path); mediaType = 'video'; }); }, icon: const Icon(Icons.videocam_outlined), label: const Text('فيديو'))),
          ]),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: controller.text.trim().isNotEmpty || media != null ? () => Navigator.pop(dialogContext, true) : null, child: const Text('انشر')),
        ],
      ),
    ),
  );
  if (ok == true) {
    try {
      await FirebaseService.createStory(controller.text, media: media, mediaType: mediaType);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الستوري تضافت.')));
    } catch (e, st) {
      debugPrint('LEF_LEF story publish failed: $e'); debugPrintStack(stackTrace: st);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما نجّمش ننشر الستوري توا.')));
    }
  }
  controller.dispose();
}
Future<void> editStory(Map<String,dynamic> story) async {
  final id=(story['id']??'').toString();if(id.isEmpty)return;
  final controller=TextEditingController(text:(story['text']??'').toString());File? media;String? mediaType;bool removeMedia=false;final picker=ImagePicker();
  final ok=await showDialog<bool>(context:context,builder:(dc)=>StatefulBuilder(builder:(dc,setDialog)=>AlertDialog(title:const Text('عدّل الستوري'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    TextField(controller:controller,onChanged:(_)=>setDialog((){}),maxLines:3,maxLength:500,decoration:const InputDecoration(hintText:'عدّل النص...')),
    if((story['mediaUrl']??'').toString().isNotEmpty&&!removeMedia&&media==null)ListTile(leading:const Icon(Icons.attach_file),title:Text((story['mediaType']??'image')=='video'?'فيديو مرفق':'تصويرة مرفقة'),trailing:IconButton(onPressed:()=>setDialog((){removeMedia=true;}),icon:const Icon(Icons.delete_outline))),
    if(media!=null)ListTile(title:Text(media!.path.split('/').last,maxLines:1,overflow:TextOverflow.ellipsis),trailing:IconButton(onPressed:()=>setDialog((){media=null;}),icon:const Icon(Icons.close))),
    Row(children:[Expanded(child:OutlinedButton.icon(onPressed:()async{final f=await picker.pickImage(source:ImageSource.gallery,imageQuality:88);if(f!=null)setDialog((){media=File(f.path);mediaType='image';removeMedia=false;});},icon:const Icon(Icons.photo_outlined),label:const Text('صورة'))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:()async{final f=await picker.pickVideo(source:ImageSource.gallery);if(f!=null)setDialog((){media=File(f.path);mediaType='video';removeMedia=false;});},icon:const Icon(Icons.videocam_outlined),label:const Text('فيديو')))]),
  ])),actions:[TextButton(onPressed:()=>Navigator.pop(dc,false),child:const Text('إلغاء')),FilledButton(onPressed:controller.text.trim().isNotEmpty||media!=null||(((story['mediaUrl']??'').toString().isNotEmpty)&&!removeMedia)?()=>Navigator.pop(dc,true):null,child:const Text('احفظ'))])));
  if(ok==true){try{await FirebaseService.updateStory(id,controller.text,media:media,mediaType:mediaType,removeMedia:removeMedia);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('الستوري تعدّلت.')));}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نعدّل الستوري. يمكن وفات مدّتها.')));}}
  controller.dispose();
}
Future<void> deleteStory(Map<String,dynamic> story) async {
  final id=(story['id']??'').toString();if(id.isEmpty)return;
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('تحذف الستوري؟'),content:const Text('ما عادش تظهر للناس بعد الحذف.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('رجوع')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('احذف'))]));
  if(ok!=true)return;try{await FirebaseService.deleteStory(id);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('الستوري تحذفت.')));}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نحذف الستوري.')));}
}
Future<void>viewStory(Map<String,dynamic> story) async {
  final storyId = (story['id'] ?? '').toString();
  final mediaUrl = (story['mediaUrl'] ?? '').toString();
  final text = (story['text'] ?? '').toString().trim();
  if (storyId.isNotEmpty) { try { await FirebaseService.markStoryViewed(storyId); } catch (e) { debugPrint('LEF_LEF story view failed: $e'); } }
  await showDialog<void>(context: context, builder: (dialogContext) => Dialog(
    backgroundColor: Colors.black,
    insetPadding: const EdgeInsets.all(12),
    child: SizedBox(
      width: double.infinity,
      height: MediaQuery.sizeOf(context).height * .72,
      child: Stack(children: [
        if (mediaUrl.isNotEmpty)
          Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(20), child: MediaPreview(url:mediaUrl,type:(story['mediaType']??'image').toString(),height:MediaQuery.sizeOf(context).height*.72))),
        if (text.isNotEmpty)
          Positioned(left: 18, right: 18, bottom: 24, child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.black.withAlpha(145), borderRadius: BorderRadius.circular(16)), child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, height: 1.4)))),
        Positioned(top: 8, right: 8, child: Row(children: [if((story['authorId']??'').toString()==FirebaseService.user?.uid)PopupMenuButton<String>(icon:const Icon(Icons.more_vert,color:Colors.white),onSelected:(v){Navigator.pop(dialogContext);if(v=='edit')editStory(story);if(v=='delete')deleteStory(story);},itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('عدّل الستوري')),PopupMenuItem(value:'delete',child:Text('احذف الستوري'))]),IconButton(onPressed: storyId.isEmpty ? null : () async { try { await FirebaseService.reactToStory(storyId, '❤️'); if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('تفاعلِك تسجّل.'))); } catch (e, st) { debugPrint('LEF_LEF story reaction failed: $e'); debugPrintStack(stackTrace: st); if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('التفاعل ما تسجّلش توا.'))); } }, icon: const Icon(Icons.favorite_border, color: Colors.white)), IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close, color: Colors.white))])),
      ]),
    ),
  ));
}

Future<void> newPost() async {
  final controller = TextEditingController();
  File? media;
  String? mediaType;
  final picker = ImagePicker();
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialog) => AlertDialog(
        title: const Text('بوست جديد'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: controller, onChanged: (_) => setDialog(() {}), maxLines: 4, maxLength: 4000, decoration: const InputDecoration(hintText: 'شنوة تحب تشارك؟')),
          const SizedBox(height: 10),
          if (media != null) ListTile(leading: Icon(mediaType == 'video' ? Icons.videocam : Icons.image), title: Text(media!.path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis), trailing: IconButton(onPressed: () => setDialog(() { media = null; mediaType = null; }), icon: const Icon(Icons.close))),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () async { final f = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88); if (f != null) setDialog(() { media = File(f.path); mediaType = 'image'; }); }, icon: const Icon(Icons.photo_outlined), label: const Text('صورة'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () async { final f = await picker.pickVideo(source: ImageSource.gallery); if (f != null) setDialog(() { media = File(f.path); mediaType = 'video'; }); }, icon: const Icon(Icons.videocam_outlined), label: const Text('فيديو'))),
          ]),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: controller.text.trim().isNotEmpty || media != null ? () => Navigator.pop(dialogContext, true) : null, child: const Text('انشر')),
        ],
      ),
    ),
  );
  if (ok == true) {
    try {
      await FirebaseService.createPost(controller.text, media: media, mediaType: mediaType);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المنشور تضاف.')));
    } catch (e, st) {
      debugPrint('LEF_LEF post publish failed: $e'); debugPrintStack(stackTrace: st);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما نجّمش ننشر المنشور توا.')));
    }
  }
  controller.dispose();
}
Future<void>editPost(String id,Map<String,dynamic> data)async{
  final controller=TextEditingController(text:(data['text']??'').toString());
  File? media; String? mediaType; bool removeMedia=false; final picker=ImagePicker();
  final ok=await showDialog<bool>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,setDialog)=>AlertDialog(
    title:const Text('عدّل المنشور'),
    content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:controller,onChanged:(_)=>setDialog((){}),maxLines:4,maxLength:4000,decoration:const InputDecoration(hintText:'عدّل كلامك...')),
      if(((data['mediaUrl']??'').toString().isNotEmpty)&&!removeMedia&&media==null) ListTile(leading:const Icon(Icons.attach_file),title:Text((data['mediaType']??'image')=='video'?'فيديو مرفق':'تصويرة مرفقة'),trailing:IconButton(tooltip:'نحّي المرفق',onPressed:()=>setDialog((){removeMedia=true;}),icon:const Icon(Icons.delete_outline))),
      if(media!=null)ListTile(leading:Icon(mediaType=='video'?Icons.videocam:Icons.image),title:Text(media!.path.split('/').last,maxLines:1,overflow:TextOverflow.ellipsis),trailing:IconButton(onPressed:()=>setDialog((){media=null;}),icon:const Icon(Icons.close))),
      Row(children:[Expanded(child:OutlinedButton.icon(onPressed:()async{final f=await picker.pickImage(source:ImageSource.gallery,imageQuality:88);if(f!=null)setDialog((){media=File(f.path);mediaType='image';removeMedia=false;});},icon:const Icon(Icons.photo_outlined),label:const Text('تصويرة'))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:()async{final f=await picker.pickVideo(source:ImageSource.gallery);if(f!=null)setDialog((){media=File(f.path);mediaType='video';removeMedia=false;});},icon:const Icon(Icons.videocam_outlined),label:const Text('فيديو')))]),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('إلغاء')),FilledButton(onPressed:controller.text.trim().isNotEmpty||media!=null||(((data['mediaUrl']??'').toString().isNotEmpty)&&!removeMedia)?()=>Navigator.pop(dialogContext,true):null,child:const Text('احفظ التعديل'))])));
  if(ok==true){try{await FirebaseService.updatePost(id,controller.text,media:media,mediaType:mediaType,removeMedia:removeMedia);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تعدّل المنشور.')));}catch(e,st){debugPrint('LEF_LEF post edit failed: $e');debugPrintStack(stackTrace:st);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نعدّل المنشور. تثبّت من الاتصال وعاود.')));}}
  controller.dispose();
}
Future<void>deletePost(String id)async{final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('تحذف المنشور؟'),content:const Text('الحذف نهائي وما تنجمش ترجّعو.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('رجوع')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('احذف'))]));if(ok!=true)return;try{await FirebaseService.deletePost(id);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('المنشور تحذف.')));}catch(e,st){debugPrint('LEF_LEF post delete failed: $e');debugPrintStack(stackTrace:st);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نحذف المنشور توا.')));}}
Future<void>comments(String id) async {
  final controller = TextEditingController();
  String? replyTo;
  String replyLabel = '';
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(builder: (context, setSheet) => Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: SizedBox(height: MediaQuery.sizeOf(context).height * .68, child: Column(children: [
        const Align(alignment: Alignment.centerLeft, child: Text('التعاليق والردود', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
        const SizedBox(height: 8),
        Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseService.db.collection('posts').doc(id).collection('comments').orderBy('createdAt').snapshots(),
          builder: (context, snap) {
            if (snap.hasError) return const Center(child: Text('التعاليق موش متوفرة توا.'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.docs.isEmpty) return const Center(child: Text('كون أوّل واحد يعلّق.'));
            return ListView(children: snap.data!.docs.map((d) {
              final data = d.data();
              final mine = data['authorId']?.toString() == FirebaseService.user?.uid;
              final isReply = (data['parentCommentId'] ?? '').toString().isNotEmpty;
              return Padding(padding: EdgeInsetsDirectional.only(start: isReply ? 24 : 0), child: Card(child: ListTile(
                leading: CircleAvatar(child: Icon(isReply ? Icons.subdirectory_arrow_right : Icons.person_outline)),
                title: Text((data['text'] ?? '').toString()),
                subtitle: Text(isReply ? 'ردّ على تعليق' : ((data['updatedAt'] != null) ? 'تعدّل' : 'تعليق')),
                trailing: Wrap(children: [
                  IconButton(tooltip: 'جاوب', onPressed: () => setSheet(() { replyTo = d.id; replyLabel = (data['text'] ?? '').toString(); }), icon: const Icon(Icons.reply)),
                  if (mine) PopupMenuButton<String>(onSelected: (action) async {
                    if (action == 'edit') {
                      final edit = TextEditingController(text: (data['text'] ?? '').toString());
                      final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('عدّل التعليق'), content: TextField(controller: edit, maxLines: 3, maxLength: 4000), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('احفظ'))]));
                      if (ok == true) { try { await FirebaseService.updateComment(id, d.id, edit.text); } catch (_) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما نجّمش نعدّل التعليق.'))); } }
                      edit.dispose();
                    } else if (action == 'delete') {
                      try { await FirebaseService.deleteComment(id, d.id); } catch (_) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما نجّمش نحذف التعليق.'))); }
                    }
                  }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('عدّل')), PopupMenuItem(value: 'delete', child: Text('احذف'))]),
                ]),
              )));
            }).toList());
          },
        )),
        if (replyTo != null) Container(width: double.infinity, padding: const EdgeInsets.all(8), color: LefTheme.cream, child: Row(children: [Expanded(child: Text('ردّ على: $replyLabel', maxLines: 1, overflow: TextOverflow.ellipsis)), IconButton(onPressed: () => setSheet(() { replyTo = null; replyLabel = ''; }), icon: const Icon(Icons.close))])),
        Row(children: [Expanded(child: TextField(controller: controller, maxLength: 4000, decoration: InputDecoration(hintText: replyTo == null ? 'اكتب تعليق...' : 'اكتب ردّ...'))), IconButton(onPressed: () async {
          try { await FirebaseService.addComment(id, controller.text, parentCommentId: replyTo); controller.clear(); setSheet(() { replyTo = null; replyLabel = ''; }); }
          catch (e, st) { debugPrint('LEF_LEF comment/reply failed: $e'); debugPrintStack(stackTrace: st); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('التعليق أو الردّ ما تسجّلش توا.'))); }
        }, icon: const Icon(Icons.send, color: LefTheme.goldDark))]),
      ])),
    )),
  );
  controller.dispose();
}
Future<void> _openServiceSearch() async {
  final controller = TextEditingController();
  String selectedCategory = 'الكل';
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final query = controller.text.trim().toLowerCase();
        final results = serviceOptions.where((option) {
          final matchesText = query.isEmpty || option.title.toLowerCase().contains(query) || option.subtitle.toLowerCase().contains(query);
          final matchesCategory = selectedCategory == 'الكل' || (selectedCategory == 'تنقّل' && {ServiceKind.taxiMoto, ServiceKind.carExpress}.contains(option.kind)) || (selectedCategory == 'ديليفري' && {ServiceKind.deliveryMoto, ServiceKind.deliveryVan, ServiceKind.deliveryTruck}.contains(option.kind)) || (selectedCategory == 'خدمات خاصة' && {ServiceKind.sos, ServiceKind.ambulance, ServiceKind.randonnee}.contains(option.kind));
          return matchesText && matchesCategory;
        }).toList();
        return SafeArea(child: Padding(
          padding: EdgeInsets.fromLTRB(18, 8, 18, MediaQuery.of(sheetContext).viewInsets.bottom + 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('شنوة تلوّج عليه؟', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            TextField(controller: controller, onChanged: (_) => setSheetState(() {}), autofocus: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'تاكسي، ديليفري، إسعاف…', suffixIcon: Icon(Icons.tune_rounded))),
            const SizedBox(height: 10),
            Wrap(spacing: 7, runSpacing: 7, children: [
              ChoiceChip(label: const Text('الكل'), selected: selectedCategory == 'الكل', onSelected: (_) => setSheetState(() => selectedCategory = 'الكل')),
              ChoiceChip(label: const Text('تنقّل'), selected: selectedCategory == 'تنقّل', onSelected: (_) => setSheetState(() => selectedCategory = 'تنقّل')),
              ChoiceChip(label: const Text('ديليفري'), selected: selectedCategory == 'ديليفري', onSelected: (_) => setSheetState(() => selectedCategory = 'ديليفري')),
              ChoiceChip(label: const Text('خدمات خاصة'), selected: selectedCategory == 'خدمات خاصة', onSelected: (_) => setSheetState(() => selectedCategory = 'خدمات خاصة'))
            ]),
            const SizedBox(height: 8),
            Flexible(child: results.isEmpty
              ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('ما لقيناش خدمة مطابقة. بدّل كلمة البحث وعاود.')))
              : ListView.separated(shrinkWrap: true, itemCount: results.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, index) {
                  final option = results[index];
                  return ListTile(leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: LefTheme.cream, borderRadius: BorderRadius.circular(12)), child: Center(child: iconFor(option.kind))),
                    title: Text(option.title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(option.subtitle), trailing: const Icon(Icons.chevron_right),
                    onTap: () { Navigator.pop(sheetContext); widget.onMove(option.kind); });
                })),
          ]),
        ));
      },
    ),
  );
  controller.dispose();
}

Widget iconFor(ServiceKind kind) {
  final icon = switch (kind) {
    ServiceKind.taxiMoto => Icons.two_wheeler,
    ServiceKind.carExpress => Icons.local_taxi,
    ServiceKind.deliveryMoto => Icons.delivery_dining,
    ServiceKind.deliveryVan => Icons.local_shipping,
    ServiceKind.deliveryTruck => Icons.local_shipping,
    ServiceKind.sos => Icons.emergency,
    ServiceKind.ambulance => Icons.medical_services,
    ServiceKind.randonnee => Icons.hiking,
  };
  return Icon(icon, color: LefTheme.goldDark, size: 27);
}
Widget stories() {
  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseService.db.collection('stories').orderBy('createdAt', descending: true).limit(30).snapshots(),
    builder: (context, snap) {
      if (snap.hasError) return const Text('الستوريّات موش متوفرة توا.');
      if (!snap.hasData) return const SizedBox(height: 90, child: Center(child: CircularProgressIndicator()));
      final docs = snap.data!.docs;
      if (docs.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('ما فماش ستوريّات توا. زيد أول ستوري.'));
      return SizedBox(height: 112, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: docs.length, separatorBuilder: (_, __) => const SizedBox(width: 10), itemBuilder: (context, index) {
        final data = docs[index].data();
        final owner = (data['authorName'] ?? data['displayName'] ?? 'LEF_LEF').toString();
        return InkWell(onTap: () => viewStory({...data, 'id': docs[index].id}), onLongPress: FirebaseService.user?.uid == data['authorId'] ? () => editStory({...data, 'id': docs[index].id}) : null, child: Container(width: 88, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: LefTheme.cream, borderRadius: BorderRadius.circular(18), border: Border.all(color: LefTheme.gold)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.auto_awesome, color: LefTheme.goldDark, size: 26), const SizedBox(height: 6), Text(owner, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11))])));
      }));
    },
  );
}
Widget feed(){return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseService.db.collection('posts').orderBy('createdAt',descending:true).limit(30).snapshots(),builder:(context,snap){if(snap.hasError)return const Text('الـfeed متاع المجتمع موش متوفر توا.');if(!snap.hasData)return const Center(child:CircularProgressIndicator());return FutureBuilder<Set<String>>(future:FirebaseService.blockedUserIds(),builder:(context,blockedSnap){if(!blockedSnap.hasData)return const SizedBox(height:80,child:Center(child:CircularProgressIndicator()));final blocked=blockedSnap.data!;final docs=snap.data!.docs.where((d)=>!blocked.contains(d.data()['authorId']?.toString())).toList();if(docs.isEmpty)return const Text('المنشورات متاع المجتمع باش يظهرو لهنا.');return Column(children:docs.map((d){final x=d.data();final authorId=x['authorId']?.toString()??'';final likes=List<String>.from(x['likes']??const[]);final liked=likes.contains(FirebaseService.user?.uid);return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[if((x['repostedFrom']??'').toString().isNotEmpty)const Padding(padding:EdgeInsets.only(bottom:6),child:Text('إعادة نشر',style:TextStyle(color:LefTheme.goldDark,fontWeight:FontWeight.w800))),Text((x['text']??'').toString(),style:const TextStyle(fontSize:16,fontWeight:FontWeight.w600)),if((x['mediaUrl']??'').toString().isNotEmpty)Padding(padding:const EdgeInsets.only(top:10),child:ClipRRect(borderRadius:BorderRadius.circular(16),child:MediaPreview(url:(x['mediaUrl']).toString(),type:(x['mediaType']??'image').toString(),height:240)),),Row(children:[IconButton(onPressed:()async{try{await FirebaseService.toggleLike(d.id,likes);}catch(e,st){debugPrint('LEF_LEF like failed: $e');debugPrintStack(stackTrace:st);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('التفاعل ما تسجّلش توا.')));}},icon:Icon(liked?Icons.favorite:Icons.favorite_border,color:liked?Colors.red:null)),Text('${likes.length}'),IconButton(onPressed:()=>comments(d.id),icon:const Icon(Icons.comment_outlined)),IconButton(tooltip:'احفظ المنشور',onPressed:()async{try{await FirebaseService.saveItem(type:'post',itemId:d.id,title:((x['text']??'').toString().trim().isEmpty?'منشور من LEF_LEF':(x['text']??'').toString().trim().substring(0,((x['text']??'').toString().trim().length>160)?160:(x['text']??'').toString().trim().length)),subtitle:authorId);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('المنشور تحفّظ في المحفوظات.')));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نحفظ المنشور توا.')));}},icon:const Icon(Icons.bookmark_border)),IconButton(onPressed:()async{try{await FirebaseService.repost(d.id);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تعاود نشر المنشور.')));}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نعاودوا ننشرو المنشور.')));}},icon:const Icon(Icons.repeat)),IconButton(onPressed:()async{final c=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(q)=>AlertDialog(title:const Text('بلّغ على البوست'),content:TextField(controller:c,maxLines:2,decoration:const InputDecoration(hintText:'السبب')),actions:[TextButton(onPressed:()=>Navigator.pop(q,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(q,true),child:const Text('بلّغ'))]));if(ok==true){try{await FirebaseService.reportPost(d.id,c.text);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('التبليغ تبعث.')));}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نبعث التبليغ توا.')));}}c.dispose();},icon:const Icon(Icons.flag_outlined)),if(authorId.isNotEmpty&&authorId!=FirebaseService.user?.uid)IconButton(onPressed:()async{try{await FirebaseService.blockUser(authorId);if(mounted)setState((){});}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نعمل حظر توا.')));}},icon:const Icon(Icons.block_outlined)),if(authorId==FirebaseService.user?.uid&&(x['repostedFrom']??'').toString().isEmpty)PopupMenuButton<String>(tooltip:'إدارة المنشور',onSelected:(v){if(v=='edit')editPost(d.id,x);if(v=='delete')deletePost(d.id);},itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('عدّل المنشور')),PopupMenuItem(value:'delete',child:Text('احذف المنشور'))],icon:const Icon(Icons.more_horiz)),const Spacer(),IconButton(onPressed:()async{final text=(x['text']??'').toString().trim();if(text.isEmpty)return;try{await const MethodChannel('com.leflef.app/share').invokeMethod<bool>('shareText',{'text':text});}catch(_){await Clipboard.setData(ClipboardData(text:text));if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تنسخت الحكاية، تنجم تشاركها.')));}},icon:const Icon(Icons.share_outlined))])])));}).toList());});});}
@override Widget build(BuildContext context){return CustomScrollView(slivers:[SliverAppBar(floating:true,title:Image.asset('assets/lef_logo_lockup.png',width:105,height:52,fit:BoxFit.contain),actions:[IconButton(tooltip:'الإشعارات',onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const NotificationsScreen())),icon:const Icon(Icons.notifications_none_rounded)),IconButton(tooltip:'القائمة',onPressed:widget.onMenu,icon:const Icon(Icons.menu_rounded))]),SliverPadding(padding:const EdgeInsets.fromLTRB(16,10,16,120),sliver:SliverList(delegate:SliverChildListDelegate([
const Text('نلفّ عليك.',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900)),const Text('تنقّل • اكتشف • تواصل',style:TextStyle(color:LefTheme.green,fontWeight:FontWeight.w600)),const SizedBox(height:18),InkWell(onTap:_openServiceSearch,borderRadius:BorderRadius.circular(18),child:Container(height:58,padding:const EdgeInsets.symmetric(horizontal:16),decoration:BoxDecoration(color:LefTheme.cream,borderRadius:BorderRadius.circular(18)),child:const Row(children:[Icon(Icons.search),SizedBox(width:10),Text('لوين تحب تمشي؟',style:TextStyle(color:Colors.black54)),Spacer(),Icon(Icons.tune_rounded)]))),const SizedBox(height:20),Row(children:[const Expanded(child:SectionTitle('ستوريّات')),IconButton(onPressed:newStory,icon:const Icon(Icons.add_circle_outline))]),stories(),const SizedBox(height:20),const SectionTitle('الخدمات'),const SizedBox(height:8),SizedBox(height:108,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:serviceOptions.length,separatorBuilder:(_,__)=>const SizedBox(width:10),itemBuilder:(_,i){final o=serviceOptions[i];return InkWell(onTap:()=>widget.onMove(o.kind),child:Container(width:125,padding:const EdgeInsets.all(12),decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),color:Colors.white,border:Border.all(color:LefTheme.gold.withAlpha(100))),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Container(width:42,height:42,decoration:BoxDecoration(color:LefTheme.cream,borderRadius:BorderRadius.circular(13)),child:Center(child:iconFor(o.kind))),const SizedBox(height:7),Text(o.title,textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:12))])));})),const SizedBox(height:22),InkWell(onTap:widget.onExplore,borderRadius:BorderRadius.circular(25),child:Container(height:145,padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[LefTheme.green,Color(0xFF245447)]),border:Border.all(color:LefTheme.gold.withAlpha(160)),borderRadius:BorderRadius.circular(22)),child:const Column(mainAxisAlignment:MainAxisAlignment.end,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('اكتشف',style:TextStyle(color:Colors.white,fontSize:27,fontWeight:FontWeight.w900)),SizedBox(height:5),Text('بلايص • ناس • أنشطة • مناسبات',style:TextStyle(color:Colors.white70))]))),const SizedBox(height:22),Row(children:[const Expanded(child:SectionTitle('المجتمع')),IconButton(onPressed:newPost,icon:const Icon(Icons.add_circle_outline))]),Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[Row(children:[const CircleAvatar(backgroundColor:LefTheme.gold,child:Icon(Icons.person,color:Colors.white)),const SizedBox(width:10),const Expanded(child:Text('شارك حاجة مع LEF_LEF',style:TextStyle(fontWeight:FontWeight.w800)))]),const SizedBox(height:10),TextField(controller:composer,maxLines:2,decoration:const InputDecoration(hintText:'شنوة اكتشفت اليوم؟')),const SizedBox(height:8),Align(alignment:Alignment.centerRight,child:FilledButton(onPressed:post,child:const Text('انشر')))]))),const SizedBox(height:10),feed()
])))]);}
}
