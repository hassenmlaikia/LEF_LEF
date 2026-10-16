import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/firebase_service.dart';
import '../services/app_prefs.dart';
import 'owner_screen.dart';

class SettingsScreen extends StatefulWidget { const SettingsScreen({super.key,required this.onThemePreferenceChanged,this.onLanguageChanged,this.onFontScaleChanged,this.onSignOut}); final ValueChanged<String> onThemePreferenceChanged; final ValueChanged<String>? onLanguageChanged; final ValueChanged<double>? onFontScaleChanged; final VoidCallback? onSignOut; @override State<SettingsScreen> createState()=>_SettingsState(); }
class _SettingsState extends State<SettingsScreen>{ bool notifications=true,privacy=true,loading=true,rideNotifs=true,socialNotifs=true,eventNotifs=true,pricingNotifs=true,quietHoursEnabled=false; String quietStart='22:00',quietEnd='08:00'; String themePreference='system',language='تونسي',profileVisibility='public'; double fontScale=1.0;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{final n=await AppPrefs.notifications(),p=await AppPrefs.privacy(),m=await AppPrefs.themeMode(),l=await AppPrefs.language(),fs=await AppPrefs.fontScale();Map<String,dynamic> cloud=const {};final uid=FirebaseService.user?.uid;if(uid!=null){try{cloud=(await FirebaseService.db.collection('users').doc(uid).get()).data()??const {};}catch(e){debugPrint('LEF_LEF preferences load failed: $e');}}final prefs=cloud['notificationPreferences'];if(mounted)setState((){notifications=n;privacy=p;themePreference=m;language=l;fontScale=fs;rideNotifs=prefs is Map?prefs['rides']!=false:true;socialNotifs=prefs is Map?prefs['social']!=false:true;eventNotifs=prefs is Map?prefs['events']!=false:true;pricingNotifs=prefs is Map?prefs['pricing']!=false:true;quietHoursEnabled=prefs is Map?prefs['quietHoursEnabled']==true:false;quietStart=prefs is Map&&prefs['quietStart'] is String?prefs['quietStart'] as String:'22:00';quietEnd=prefs is Map&&prefs['quietEnd'] is String?prefs['quietEnd'] as String:'08:00';profileVisibility=const {'public','followers','private'}.contains(cloud['profileVisibility'])?cloud['profileVisibility'].toString():'public';loading=false;});}
  Future<void> _saveNotificationCategories()async{try{await FirebaseService.updateNotificationPreferences(rides:rideNotifs,social:socialNotifs,events:eventNotifs,pricing:pricingNotifs,quietHoursEnabled:quietHoursEnabled,quietStart:quietStart,quietEnd:quietEnd);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تفضيلات الإشعارات ما تسجّلتش.')));}}
  Future<void> _complaintCenter()async{
    final category=TextEditingController(text:'مشكلة في التطبيق'),subject=TextEditingController(),details=TextEditingController();
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,builder:(sheet)=>SafeArea(child:Padding(padding:EdgeInsets.fromLTRB(16,8,16,MediaQuery.of(sheet).viewInsets.bottom+16),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[const Text('مركز الشكاوي',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900)),const SizedBox(height:10),TextField(controller:category,decoration:const InputDecoration(labelText:'التصنيف')),TextField(controller:subject,maxLength:140,decoration:const InputDecoration(labelText:'عنوان الشكوى')),TextField(controller:details,maxLength:1500,maxLines:3,decoration:const InputDecoration(labelText:'التفاصيل')),FilledButton(onPressed:()async{try{await FirebaseService.submitComplaint(category:category.text,subject:subject.text,details:details.text);if(sheet.mounted)Navigator.pop(sheet);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('الشكوى تسجّلت، تنجم تتابع حالتها من نفس المركز.')));if(mounted)await _showMyComplaints();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('راجع التصنيف والعنوان والتفاصيل وعاود.')));}},child:const Text('ابعث الشكوى')),const SizedBox(height:6),TextButton(onPressed:()async{Navigator.pop(sheet);if(mounted)await _showMyComplaints();},child:const Text('تابع شكاويّ السابقة'))]))));category.dispose();subject.dispose();details.dispose();
  }
  Future<void> _showMyComplaints()async{await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,builder:(sheet)=>SafeArea(child:SizedBox(height:MediaQuery.of(sheet).size.height*0.65,child:Column(children:[const ListTile(title:Text('شكاويّ السابقة',style:TextStyle(fontWeight:FontWeight.w900))),Expanded(child:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseService.myComplaints(),builder:(c,s){if(s.hasError)return const Center(child:Text('ما نجّمش نحمّل الشكاوي.'));if(!s.hasData)return const Center(child:CircularProgressIndicator());if(s.data!.docs.isEmpty)return const Center(child:Text('ما عندك حتى شكوى مسجّلة.'));return ListView(children:s.data!.docs.map((d){final x=d.data();final status=x['status']?.toString()??'open';final due=x['slaDueAt'];final overdue=due is Timestamp&&due.toDate().isBefore(DateTime.now())&&!{'resolved','dismissed'}.contains(status);return ListTile(leading:Icon(status=='resolved'?Icons.check_circle_outline:status=='dismissed'?Icons.cancel_outlined:Icons.hourglass_top),title:Text(x['subject']?.toString()??'شكوى'),subtitle:Text('الحالة: ${status=='open'?'قيد المتابعة':status=='resolved'?'تمت المتابعة':status=='in_review'?'قيد المعالجة':'مغلقة'}${overdue?' • تعدّى أجل المتابعة':''}${(x['adminReply']??'').toString().isNotEmpty?'\nرد الإدارة: ${x['adminReply']}':''}'));}).toList());}))]))));}

  Future<void> _setProfileVisibility(String value) async {
    final old=profileVisibility;
    setState(()=>profileVisibility=value);
    try {
      await FirebaseService.updateProfileVisibility(value);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('إعداد ظهور البروفايل تسجّل.')));
    } catch(e) {
      if(mounted) setState(()=>profileVisibility=old);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نحفظ خصوصية البروفايل. جرّب من جديد.')));
    }
  }

  Future<void> _chooseQuietTime(bool start) async {
    final current=(start?quietStart:quietEnd).split(':');
    final initial=TimeOfDay(hour:int.parse(current[0]),minute:int.parse(current[1]));
    final picked=await showTimePicker(context:context,initialTime:initial,helpText:start?'بداية وقت الهدوء':'نهاية وقت الهدوء');
    if(picked==null)return;
    final value='${picked.hour.toString().padLeft(2,'0')}:${picked.minute.toString().padLeft(2,'0')}';
    final oldStart=quietStart,oldEnd=quietEnd;
    setState((){if(start)quietStart=value;else quietEnd=value;});
    try { await _saveNotificationCategories(); }
    catch (_) { if(mounted)setState((){quietStart=oldStart;quietEnd=oldEnd;}); }
  }

  Future<void> _accountDeletion() async {
    final pending=await FirebaseService.db.collection('accountDeletionRequests').doc(FirebaseService.user!.uid).get();
    final isPending=pending.data()?['status']=='pending';
    final confirm=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:Text(isPending?'إلغاء طلب حذف الحساب':'طلب حذف الحساب'),
      content:Text(isPending?'تنجم تلغي طلب الحذف ما دامت مهلة الثلاثين يوم ما وفاتش.':'الحساب يدخل في مهلة تراجع مدتها 30 يومًا. خلال المهلة تنجم تطلب إلغاء الحذف. الحذف النهائي يتطلب معالجة آمنة على الخادم، ومش مضمون يصير آليًا قبل إعداد خدمة الخادم.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('رجوع')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:Text(isPending?'إلغاء الطلب':'أكد الطلب'))]));
    if(confirm!=true)return;
    try {
      if(isPending){await FirebaseService.cancelAccountDeletionRequest();}
      else {await FirebaseService.requestAccountDeletion();}
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(isPending?'تلغى طلب الحذف.':'تسجّل طلب الحذف مع مهلة 30 يومًا.')));
    } catch(e) {
      final msg=e.toString().contains('owner_account_protected')?'حساب Owner محمي وما يتنحّاش من المسار هذا.':e.toString().contains('deletion_already_pending')?'عندك طلب حذف مسجّل بالفعل.':'ما نجّمش نسجّل العملية توا. عاود بعد شوية.';
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(msg)));
    }
  }

  Future<void> _showLegalDraft(bool terms) async {
    const termsText = 'هذه مسودة أولية وليست نصًا قانونيًا نهائيًا. باستخدام LEF_LEF، يلتزم المستخدم بتقديم معلومات صحيحة، واحترام الآخرين، وعدم إساءة استخدام الخدمات أو نشر محتوى غير قانوني. قد تختلف شروط الخدمات حسب نوعها. يمكن تعليق الوصول عند وجود خطر أمني أو مخالفة، مع توفير وسيلة للاعتراض عند الاقتضاء. لا تضمن المنصة توفر الخدمة دون انقطاع. أي أسعار أو عروض تظهر قبل التأكيد هي المرجع للعملية المعنية. لا يتم تفعيل الدفع الإلكتروني ضمن هذه المسودة. يجب إضافة بيانات الشركة المشغلة ووسائل الاتصال وآلية الشكاوى وتسوية النزاعات، وتحديد القانون والجهة المختصة بعد مراجعة محامٍ تونسي قبل النشر.';
    const privacyText = 'هذه مسودة أولية وليست ضمانًا للامتثال القانوني. ينبغي توضيح البيانات التي تجمعها المنصة، وأغراض استخدامها، وأساس المعالجة، ومدة الاحتفاظ، والجهات التي قد تستقبل البيانات، وحقوق المستخدم وطريقة ممارستها، ووسائل التواصل لطلبات الخصوصية. الموقع الجغرافي والرسائل والصور ووثائق مقدمي الخدمات قد تكون حساسة ويجب تقييد الوصول إليها وعدم استخدامها إلا للغرض المعلن. ينبغي إعداد جدول احتفاظ وحذف، وإجراءات للحوادث الأمنية، ومراجعة النقل إلى مزودي الخدمات. يلزم تخصيص النص وفق النشاط الفعلي والقانون التونسي المنطبق ومراجعته من محامٍ مختص قبل إطلاق التطبيق.';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.78,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  terms ? 'شروط الاستخدام — مسودة' : 'الخصوصية وحماية البيانات — مسودة',
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      terms ? termsText : privacyText,
                      style: const TextStyle(height: 1.55),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ملاحظة: يلزم استكمال بيانات الشركة ومراجعة قانونية محلية قبل اعتماد هذه النصوص.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _chooseTheme() async {
    const options = <(String, String, String)>[
      ('system', 'حسب إعداد الهاتف', 'يتبدّل آليًا مع مظهر الجهاز'),
      ('light', 'نهاري', 'واجهة فاتحة'),
      ('dark', 'ليلي', 'واجهة داكنة'),
    ];
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('مظهر التطبيق', style: TextStyle(fontWeight: FontWeight.w900))),
          for (final item in options)
            ListTile(
              leading: Icon(item.$1 == 'system'
                  ? Icons.brightness_auto_outlined
                  : item.$1 == 'light' ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
              title: Text(item.$2),
              subtitle: Text(item.$3),
              trailing: themePreference == item.$1
                  ? const Icon(Icons.check, color: LefTheme.goldDark)
                  : null,
              onTap: () => Navigator.pop(c, item.$1),
            ),
        ]),
      ),
    );
    if (value == null || value == themePreference) return;
    setState(() => themePreference = value);
    await AppPrefs.setThemeMode(value);
    widget.onThemePreferenceChanged(value);
  }
  Future<bool> _sync(String field,Object v)async{final u=FirebaseService.user;if(u==null)return true;try{await FirebaseService.db.collection('users').doc(u.uid).set({field:v,'updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));return true;}catch(e,st){debugPrint('LEF_LEF settings sync failed: $e');debugPrintStack(stackTrace:st);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('التغيير ما تسجّلش توا.')));return false;}}
  Future<void> _language()async{final v=await showModalBottomSheet<String>(context:context,showDragHandle:true,builder:(c)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[for(final x in ['تونسي','Français','English'])ListTile(title:Text(x),trailing:x==language?const Icon(Icons.check,color:LefTheme.goldDark):null,onTap:()=>Navigator.pop(c,x))])));if(v!=null){final old=language;setState(()=>language=v);await AppPrefs.setLanguage(v);if(await _sync('language',v)){widget.onLanguageChanged?.call(v);}else{if(mounted)setState(()=>language=old);await AppPrefs.setLanguage(old);}}}
  @override Widget build(BuildContext c){if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));final uid=FirebaseService.user?.uid;return Scaffold(appBar:AppBar(title:const Text('الإعدادات',style:TextStyle(fontWeight:FontWeight.w900))),body:ListView(padding:const EdgeInsets.all(16),children:[const Text('التفضيلات',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),Card(child:ListTile(leading:const Icon(Icons.contrast_outlined,color:LefTheme.goldDark),title:const Text('مظهر التطبيق'),subtitle:Text(themePreference=='system'?'حسب إعداد الهاتف':themePreference=='dark'?'الوضع الليلي':'الوضع النهاري'),trailing:const Icon(Icons.chevron_right),onTap:_chooseTheme)),Card(child:SwitchListTile(value:notifications,onChanged:(v)async{final old=notifications;setState(()=>notifications=v);await AppPrefs.setNotifications(v);if(!await _sync('notificationsEnabled',v)){if(mounted)setState(()=>notifications=old);await AppPrefs.setNotifications(old);}},title:const Text('الإشعارات'),subtitle:const Text('تنبيهات التنقل، الديليفري والمجتمع'),secondary:const Icon(Icons.notifications_none,color:LefTheme.goldDark))),Card(child:Column(children:[const ListTile(title:Text('نوع التنبيهات',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('اختار شنوة تحب يوصلك')),...[('مشاوير وديليفري',rideNotifs,(v)=>setState(()=>rideNotifs=v)),('رسائل وتفاعل اجتماعي',socialNotifs,(v)=>setState(()=>socialNotifs=v)),('أنشطة ومناسبات',eventNotifs,(v)=>setState(()=>eventNotifs=v)),('تغييرات الأسعار',pricingNotifs,(v)=>setState(()=>pricingNotifs=v))].map((x)=>SwitchListTile(title:Text(x.$1),value:x.$2,onChanged:(v)async{x.$3(v);await _saveNotificationCategories();})),const Divider(),SwitchListTile(title:const Text('وقت هدوء الإشعارات'),subtitle:const Text('تتسجّل تفضيلاتك؛ تفعيل الكتم على الإشعارات المرسلة يحتاج ضبط خدمة الإشعارات بالخادم'),value:quietHoursEnabled,onChanged:(v)async{setState(()=>quietHoursEnabled=v);await _saveNotificationCategories();}),if(quietHoursEnabled) ...[ListTile(title:const Text('بداية الهدوء'),subtitle:Text(quietStart),trailing:const Icon(Icons.schedule),onTap:()=>_chooseQuietTime(true)),ListTile(title:const Text('نهاية الهدوء'),subtitle:Text(quietEnd),trailing:const Icon(Icons.schedule),onTap:()=>_chooseQuietTime(false))]])),Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.visibility_outlined,color:LefTheme.goldDark),title:Text('ظهور البروفايل'),subtitle:Text('اختار شكون ينجم يلقى بروفايلك ويشوف المعلومات العامة')),RadioListTile<String>(contentPadding:EdgeInsets.zero,value:'public',groupValue:profileVisibility,title:const Text('عام'),subtitle:const Text('يظهر في البحث والاستكشاف'),onChanged:(v)=>_setProfileVisibility(v!)),RadioListTile<String>(contentPadding:EdgeInsets.zero,value:'followers',groupValue:profileVisibility,title:const Text('المتابعين'),subtitle:const Text('إنت ومتابعينك فقط'),onChanged:(v)=>_setProfileVisibility(v!)),RadioListTile<String>(contentPadding:EdgeInsets.zero,value:'private',groupValue:profileVisibility,title:const Text('خاص'),subtitle:const Text('إنت فقط، والإدارة المخوّلة عند الحاجة'),onChanged:(v)=>_setProfileVisibility(v!))]))),Card(child:SwitchListTile(value:privacy,onChanged:(v)async{final old=privacy;setState(()=>privacy=v);await AppPrefs.setPrivacy(v);if(!await _sync('privacyPersonalization',v)){if(mounted)setState(()=>privacy=old);await AppPrefs.setPrivacy(old);}},title:const Text('الخصوصية والتخصيص'),secondary:const Icon(Icons.lock_outline,color:LefTheme.goldDark))),Card(child:ListTile(leading:const Icon(Icons.language,color:LefTheme.goldDark),title:const Text('اللغة'),subtitle:Text(language),trailing:const Icon(Icons.chevron_right),onTap:_language)),Card(child:Padding(padding:const EdgeInsets.fromLTRB(16,12,16,12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.text_fields,color:LefTheme.goldDark),title:Text('حجم الكتابة'),subtitle:Text('يسهّل قراءة النصوص داخل التطبيق')),Slider(min:0.85,max:1.35,divisions:5,value:fontScale,label:'${(fontScale*100).round()}%',onChanged:(v)async{setState(()=>fontScale=v);await AppPrefs.setFontScale(v);widget.onFontScaleChanged?.call(v);if(FirebaseService.user!=null){try{await FirebaseService.db.collection('users').doc(FirebaseService.user!.uid).set({'fontScale':v},SetOptions(merge:true));}catch(e){debugPrint('LEF_LEF font preference cloud sync failed: $e');}}}),Align(alignment:AlignmentDirectional.centerEnd,child:Text('${(fontScale*100).round()}%'))]))) ,Card(child:ListTile(leading:const Icon(Icons.support_agent_outlined,color:LefTheme.goldDark),title:const Text('مركز الشكاوي'),subtitle:const Text('ابعث شكوى وتابع الحالة وردّ الإدارة'),trailing:const Icon(Icons.chevron_right),onTap:_complaintCenter)),if(uid!=null)StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(stream:FirebaseService.db.collection('users').doc(uid).snapshots(),builder:(c,s){final r=s.data?.data()?['role']?.toString();final data=s.data?.data()??const <String,dynamic>{};final caps=List<String>.from(data['capabilities']??const <String>[]);if(r!='owner'&&r!='manager'&&!caps.contains('manageRides'))return const SizedBox.shrink();return Card(child:ListTile(leading:const Icon(Icons.admin_panel_settings_outlined,color:LefTheme.goldDark),title:Text(r=='owner'||r=='manager'?'مركز الإدارة':'متابعة المشاوير'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>const OwnerScreen()))));}),Card(child:Column(children:[ListTile(leading:const Icon(Icons.gavel_outlined,color:LefTheme.goldDark),title:const Text('شروط الاستخدام'),subtitle:const Text('مسودة تحتاج مراجعة قانونية قبل النشر'),onTap:()=>_showLegalDraft(true)),ListTile(leading:const Icon(Icons.privacy_tip_outlined,color:LefTheme.goldDark),title:const Text('الخصوصية وحماية البيانات'),subtitle:const Text('مسودة سياسة الخصوصية'),onTap:()=>_showLegalDraft(false))])),if(uid!=null)Card(child:ListTile(leading:const Icon(Icons.delete_forever_outlined,color:Colors.red),title:const Text('حذف الحساب'),subtitle:const Text('طلب حذف مع مهلة تراجع 30 يومًا'),onTap:_accountDeletion)),Card(child:ListTile(leading:const Icon(Icons.logout,color:Colors.red),title:const Text('اخرج من الحساب'),onTap:()async{await FirebaseAuth.instance.signOut();await AppPrefs.clearRole();widget.onSignOut?.call();if(context.mounted)Navigator.pop(context);})),]));}
}
