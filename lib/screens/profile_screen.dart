import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/media_preview.dart';
import '../core/theme.dart';
import '../models/app_models.dart';
import '../services/firebase_service.dart';
import '../services/app_prefs.dart';
import 'settings_screen.dart';
import 'provider_screen.dart';
import 'provider_application_screen.dart';
import 'profile_tools.dart';
import 'owner_screen.dart';
import 'company_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.onSignOut, required this.onThemePreferenceChanged, required this.onLanguageChanged});
  final VoidCallback onSignOut;
  final ValueChanged<String> onThemePreferenceChanged;
  final ValueChanged<String> onLanguageChanged;

  Future<void> _showSavedItems(BuildContext context) async {
    var selected = 'all';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.78,
            child: Column(
              children: [
                const ListTile(
                  title: Text('المحفوظات', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                  subtitle: Text('منشورات وأماكن وخدمات ومناسبات حفظتهم'),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      ('all', 'الكل'),
                      ('post', 'منشورات'),
                      ('place', 'بلايص'),
                      ('service', 'خدمات'),
                      ('event', 'مناسبات'),
                    ].map((item) => Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ChoiceChip(
                        label: Text(item.$2),
                        selected: selected == item.$1,
                        onSelected: (_) => setSheetState(() => selected = item.$1),
                      ),
                    )).toList(),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseService.savedItems(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(child: Text('ما نجّمش نحمّل المحفوظات.'));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data!.docs.where((doc) {
                        return selected == 'all' || doc.data()['type'] == selected;
                      }).toList();
                      if (docs.isEmpty) {
                        return const Center(child: Text('ما فما حتى عنصر في القسم هذا.'));
                      }
                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data();
                          return ListTile(
                            leading: const Icon(Icons.bookmark_outline, color: LefTheme.goldDark),
                            title: Text(
                              data['title']?.toString() ?? 'عنصر محفوظ',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(data['type']?.toString() ?? ''),
                            trailing: IconButton(
                              tooltip: 'نحّي من المحفوظات',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                try {
                                  await FirebaseService.removeSavedItem(doc.id);
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('ما نجّمش ننحّي العنصر.')),
                                    );
                                  }
                                }
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final snap = await FirebaseService.db.collection('users').doc(u.uid).get();
    final data = snap.data() ?? <String, dynamic>{};
    final photoUrl = (u.photoURL?.isNotEmpty == true) ? u.photoURL! : (data['photoUrl']?.toString() ?? '');
    final name = TextEditingController(text: u.displayName ?? data['displayName']?.toString() ?? '');
    final bio = TextEditingController(text: data['bio']?.toString() ?? '');
    final phone = TextEditingController(text: data['phone']?.toString() ?? '');
    final city = TextEditingController(text: data['city']?.toString() ?? '');
    final interests = TextEditingController(text: data['interests']?.toString() ?? '');
    final coverUrl = data['coverUrl']?.toString() ?? '';
    File? avatar, cover;
    final picker = ImagePicker();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('تعديل البروفيل'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                if (cover != null || coverUrl.isNotEmpty) Container(height:88,width:double.infinity,margin:const EdgeInsets.only(bottom:10),decoration:BoxDecoration(borderRadius:BorderRadius.circular(12),image:DecorationImage(image:cover!=null?FileImage(cover!):NetworkImage(coverUrl) as ImageProvider,fit:BoxFit.cover))),
                OutlinedButton.icon(onPressed:()async{final f=await picker.pickImage(source:ImageSource.gallery,imageQuality:85);if(f!=null)setState(()=>cover=File(f.path));},icon:const Icon(Icons.panorama_outlined),label:const Text('اختار صورة الغلاف')),
                GestureDetector(
                  onTap: () async {
                    final f = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
                    if (f != null) setState(() => avatar = File(f.path));
                  },
                  child: CircleAvatar(
                    radius: 42,
                    backgroundImage: avatar != null
                        ? FileImage(avatar!)
                        : (photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null),
                    child: avatar == null && photoUrl.isEmpty ? const Icon(Icons.add_a_photo_outlined, size: 30) : null,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(controller: name, maxLength:80, decoration: const InputDecoration(labelText: 'الاسم')),
                const SizedBox(height: 10),
                TextField(controller: phone, keyboardType:TextInputType.phone, maxLength:32, decoration: const InputDecoration(labelText: 'رقم التواصل (خاص بالحساب)')),
                const SizedBox(height: 10),
                TextField(controller: bio, maxLines: 3, maxLength: 160, decoration: const InputDecoration(labelText: 'نبذة عليك', hintText: 'عرّف روحك...')),
                const SizedBox(height: 10),
                TextField(controller: city, maxLength: 100, decoration: const InputDecoration(labelText: 'المدينة / المنطقة')),
                const SizedBox(height: 10),
                TextField(controller: interests, maxLines: 2, maxLength: 500, decoration: const InputDecoration(labelText: 'الاهتمامات', hintText: 'مثال: سفر، رياضة، موسيقى — افصل بينهم بفاصلة')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (saved == true) {
      try {
        await FirebaseService.updateProfile(displayName: name.text, bio: bio.text, avatar: avatar, cover: cover, phone: phone.text, city: city.text, interests: interests.text);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('البروفيل تحدّث.')));
      } catch (e, st) {
        debugPrint('LEF_LEF profile update failed: $e');
        debugPrintStack(stackTrace: st);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما نجّمش نحدّث البروفيل توا.')));
      }
    }
    name.dispose();
    bio.dispose();
    phone.dispose();
    city.dispose();
    interests.dispose();
  }

  Future<void> _newPost(BuildContext context) async {
    final text = TextEditingController();
    File? media;
    String? mediaType;
    final picker = ImagePicker();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('منشور جديد'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: text, maxLines: 5, autofocus: true, decoration: const InputDecoration(hintText: 'شنوة تحب تشارك؟')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () async { final f = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88); if (f != null) setState(() { media = File(f.path); mediaType = 'image'; }); }, icon: const Icon(Icons.photo_outlined), label: const Text('صورة'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: () async { final f = await picker.pickVideo(source: ImageSource.gallery); if (f != null) setState(() { media = File(f.path); mediaType = 'video'; }); }, icon: const Icon(Icons.videocam_outlined), label: const Text('فيديو'))),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => text.text.trim().isNotEmpty || media != null ? Navigator.pop(dialogContext, true) : null, child: const Text('نشر')),
          ],
        ),
      ),
    );
    if (ok == true) {
      try { await FirebaseService.createPost(text.text, media: media, mediaType: mediaType); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المنشور تضاف.'))); }
      catch (e, st) { debugPrint('LEF_LEF post failed: $e'); debugPrintStack(stackTrace: st); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما نجّمش ننشر المنشور.'))); }
    }
    text.dispose();
  }

  Future<void> _newStory(BuildContext context) async {
    final text = TextEditingController();
    File? media;
    String? mediaType;
    final picker = ImagePicker();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('ستوري جديدة'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: text, maxLines: 3, decoration: const InputDecoration(hintText: 'شنوة تحب تشارك؟')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () async { final f = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88); if (f != null) setState(() { media = File(f.path); mediaType = 'image'; }); }, icon: const Icon(Icons.photo_outlined), label: const Text('صورة'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: () async { final f = await picker.pickVideo(source: ImageSource.gallery); if (f != null) setState(() { media = File(f.path); mediaType = 'video'; }); }, icon: const Icon(Icons.videocam_outlined), label: const Text('فيديو'))),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => text.text.trim().isNotEmpty || media != null ? Navigator.pop(dialogContext, true) : null, child: const Text('نشر')),
          ],
        ),
      ),
    );
    if (ok == true) {
      try { await FirebaseService.createStory(text.text, media: media, mediaType: mediaType); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الستوري تضافت.'))); }
      catch (e, st) { debugPrint('LEF_LEF story failed: $e'); debugPrintStack(stackTrace: st); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما نجّمش ننشر الستوري.'))); }
    }
    text.dispose();
  }

  Future<void> _requestRole(BuildContext context) async {
    final role = await showModalBottomSheet<AppRole>(context: context, showDragHandle: true, builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Padding(padding: EdgeInsets.fromLTRB(20, 8, 20, 12), child: Align(alignment: Alignment.centerLeft, child: Text('اطلب دور جديد', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)))),
      for (final r in [AppRole.driver, AppRole.deliveryProvider, AppRole.partner]) ListTile(title: Text(roleLabel(r), style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('معلومات ووسائق مطلوبة قبل المراجعة'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pop(c, r)),
    ])));
    if (role == null || !context.mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ProviderApplicationScreen(role: role)));
  }

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    final uid = u?.uid;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 58, 18, 120),
      children: [
        Row(children: [
          const Text('البروفايل', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
          const Spacer(),
          IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(onThemePreferenceChanged: onThemePreferenceChanged, onLanguageChanged: onLanguageChanged, onSignOut: onSignOut))), icon: const Icon(Icons.settings_outlined)),
        ]),
        const SizedBox(height: 8),
        Card(child:ListTile(leading:const Icon(Icons.bookmarks_outlined,color:LefTheme.goldDark),title:const Text('المحفوظات',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:const Text('ارجع للمنشورات والأماكن والخدمات اللي حفظتهم'),trailing:const Icon(Icons.chevron_right),onTap:()=>_showSavedItems(context))),
        const SizedBox(height: 10),
        if (uid != null) StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseService.db.collection('users').doc(uid).snapshots(),
          builder: (context, snap) {
            final d = snap.data?.data() ?? const <String, dynamic>{};
            final display = (d['displayName']?.toString().trim().isNotEmpty == true) ? d['displayName'].toString().trim() : (u?.displayName?.trim().isNotEmpty == true ? u!.displayName! : 'مستخدم LEF_LEF');
            final photo = (d['photoUrl']?.toString().trim().isNotEmpty == true) ? d['photoUrl'].toString().trim() : u?.photoURL;
            final role = AppRole.values.firstWhere((x) => x.name == (d['role']?.toString() ?? 'client'), orElse: () => AppRole.client);
            return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              if((d['coverUrl']??'').toString().isNotEmpty)ClipRRect(borderRadius:BorderRadius.circular(18),child:Image.network(d['coverUrl'].toString(),height:130,width:double.infinity,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox.shrink())),
              const SizedBox(height:8),
              Row(children: [
              CircleAvatar(radius: 43, backgroundColor: LefTheme.gold, backgroundImage: photo != null ? NetworkImage(photo) : null, child: photo == null ? const Icon(Icons.person, size: 45, color: Colors.white) : null),
              const SizedBox(width: 15),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(display, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900))), IconButton(onPressed: () => _editProfile(context), icon: const Icon(Icons.edit_outlined))]),
                Text(u?.email ?? '', style: const TextStyle(color: Colors.black54)),
                if ((d['bio']?.toString() ?? '').trim().isNotEmpty) Text(d['bio'].toString(), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54)),
                if ((d['city']?.toString() ?? '').trim().isNotEmpty) Text('📍 ${d['city']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54)),
                if ((d['interests']?.toString() ?? '').trim().isNotEmpty) Text('الاهتمامات: ${d['interests']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54)),
                Text(roleLabel(role), style: const TextStyle(color: LefTheme.goldDark, fontWeight: FontWeight.w800)),
                if (role == AppRole.owner || role == AppRole.manager || List<String>.from(d['capabilities'] ?? const <String>[]).contains(Capability.manageRides.name)) TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerScreen())), icon: const Icon(Icons.admin_panel_settings_outlined, size: 17), label: Text(role == AppRole.owner || role == AppRole.manager ? 'مركز الإدارة' : 'متابعة المشاوير')),
                if (role == AppRole.driver || role == AppRole.deliveryProvider) TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderScreen())), icon: const Icon(Icons.route_rounded, size: 17), label: Text(role == AppRole.deliveryProvider ? 'فضاء الديليفري' : 'فضاء السائق')),
                if (role == AppRole.partner || role == AppRole.employee) TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanyScreen())), icon: const Icon(Icons.business_outlined, size: 17), label: Text(role == AppRole.partner ? 'فضاء الخدمات' : 'فضاء الشركة')),
              ])),
              ]),
            ]);
          },
        ) else const SizedBox.shrink(),
        const SizedBox(height: 22),
        Container(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8), decoration: BoxDecoration(color: LefTheme.cream, borderRadius: BorderRadius.circular(18), border: Border.all(color: LefTheme.gold.withAlpha(90))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          if (uid != null) StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: FirebaseService.db.collection('posts').where('authorId', isEqualTo: uid).snapshots(), builder: (_, snap) => _stat('منشورات', '${snap.data?.size ?? 0}')) else _stat('منشورات', '0'),
          if (uid != null) StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: FirebaseService.followers(uid), builder: (_, snap) => _stat('متابعين', '${snap.data?.size ?? 0}')) else _stat('متابعين', '0'),
          if (uid != null) StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: FirebaseService.following(uid), builder: (_, snap) => _stat('يتابع في', '${snap.data?.size ?? 0}')) else _stat('يتابع في', '0'),
        ])),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: () => _newPost(context), icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('إنشاء منشور')),
        const SizedBox(height: 18),
        const Text('منشوراتي', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        _MyProfileFeed(uid: uid),
        const SizedBox(height: 20),
        Row(children: [const Expanded(child: Text('الستوريّات', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900))), TextButton.icon(onPressed: () => _newStory(context), icon: const Icon(Icons.add_circle_outline), label: const Text('ستوري'))]),
        const SizedBox(height: 8),
        _MyStories(uid: uid),
        const SizedBox(height: 18),
        Card(child: ListTile(leading: const Icon(Icons.grid_on), title: const Text('كل منشوراتي'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyPostsScreen())))),
        Card(child: ListTile(leading: const Icon(Icons.bookmark_outline), title: const Text('البلايص المحفوظة'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedPlacesScreen())))),
        Card(child: ListTile(leading: const Icon(Icons.receipt_long_outlined), title: const Text('طلباتي'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen())))),
        Card(child: ListTile(leading: const Icon(Icons.settings_outlined), title: const Text('الإعدادات والخصوصية واللغة'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(onThemePreferenceChanged: onThemePreferenceChanged, onLanguageChanged: onLanguageChanged, onSignOut: onSignOut))))),
        Card(child: ListTile(leading: const Icon(Icons.badge_outlined, color: LefTheme.goldDark), title: const Text('اطلب دور السائق / ديليفري / شريك'), trailing: const Icon(Icons.chevron_right), onTap: () => _requestRole(context))),
        Card(child: ListTile(leading: const Icon(Icons.help_outline), title: const Text('المساعدة والدعم'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())))),
        Card(child: ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('اخرج من الحساب'), onTap: () async { await FirebaseAuth.instance.signOut(); await AppPrefs.clearRole(); onSignOut(); })),
      ],
    );
  }

  static Widget _stat(String title, String value) => Column(mainAxisSize: MainAxisSize.min, children: [Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: LefTheme.green)), const SizedBox(height: 3), Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12))]);
}

class _MyProfileFeed extends StatelessWidget {
  const _MyProfileFeed({required this.uid});
  final String? uid;

  @override
  Widget build(BuildContext context) {
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseService.db.collection('posts').where('authorId', isEqualTo: uid).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const Text('المنشورات موش متوفرة توا.');
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = [...snap.data!.docs]
          ..sort((a, b) {
            final at = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final bt = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            return bt.compareTo(at);
          });
        if (docs.isEmpty) {
          return const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('ما نشرت حتى منشور. أول منشور ينجم يكون من هنا.')));
        }
        return Column(
          children: docs.take(10).map((d) {
            final x = d.data();
            final likes = List<String>.from(x['likes'] ?? const []);
            final liked = likes.contains(FirebaseService.user?.uid);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((x['text'] ?? '').toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    if ((x['mediaUrl'] ?? '').toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: MediaPreview(url:(x['mediaUrl']).toString(),type:(x['mediaType']??'image').toString(),height:220),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(onPressed: () => FirebaseService.toggleLike(d.id, likes), icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? Colors.red : null)),
                        Text('${likes.length}'),
                        const Spacer(),
                        TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyPostsScreen())), child: const Text('التفاصيل')),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _MyStories extends StatelessWidget {
  const _MyStories({required this.uid}); final String? uid;
  @override Widget build(BuildContext context){
    if(uid==null)return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream:FirebaseService.activeStories(),
      builder:(context,snap){
        if(snap.hasError)return const Card(child:Padding(padding:EdgeInsets.all(18),child:Text('الستوري موش متوفرة توا. جرّب من جديد بعد شوية.')));
        if(!snap.hasData)return const SizedBox(height:70,child:Center(child:CircularProgressIndicator()));
        final docs=snap.data!.docs.where((d)=>d.data()['authorId']==uid).toList()
          ..sort((a,b){
            final at=(a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch??0;
            final bt=(b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch??0;
            return bt.compareTo(at);
          });
        if(docs.isEmpty)return const Card(child:Padding(padding:EdgeInsets.all(18),child:Text('ما عندكش ستوري active توا.')));
        return SizedBox(
          height:115,
          child:ListView.separated(
            scrollDirection:Axis.horizontal,
            itemCount:docs.length,
            separatorBuilder:(_,__)=>const SizedBox(width:12),
            itemBuilder:(context,i){
              final data=docs[i].data();
              final text=(data['text']??'ستوري').toString().trim();
              final mediaUrl=(data['mediaUrl']??'').toString();
              final mediaType=(data['mediaType']??'image').toString();
              return InkWell(
                borderRadius:BorderRadius.circular(18),
                onTap:()=>showDialog<void>(
                  context:context,
                  builder:(_)=>AlertDialog(
                    title:const Text('ستوري'),
                    content:Column(mainAxisSize:MainAxisSize.min,children:[
                      if(mediaUrl.isNotEmpty) ClipRRect(borderRadius:BorderRadius.circular(16),child:MediaPreview(url:mediaUrl,type:mediaType,height:220)),
                      if(text.isNotEmpty) Padding(padding:const EdgeInsets.only(top:12),child:Text(text)),
                    ]),
                    actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('سكر'))],
                  ),
                ),
                child:SizedBox(
                  width:90,
                  child:Column(children:[
                    Container(
                      width:70,height:70,
                      decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:LefTheme.gold,width:2)),
                      child:mediaUrl.isNotEmpty&&mediaType=='image'
                        ?ClipOval(child:Image.network(mediaUrl,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image_outlined)))
                        :const CircleAvatar(backgroundColor:LefTheme.cream,child:Icon(Icons.auto_stories,color:LefTheme.goldDark)),
                    ),
                    const SizedBox(height:6),
                    Text(text.isEmpty?'ستوري':text,maxLines:2,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700)),
                  ]),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
