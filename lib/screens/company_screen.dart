import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/firebase_service.dart';

class CompanyScreen extends StatefulWidget {
  const CompanyScreen({super.key});
  @override State<CompanyScreen> createState()=>_CompanyScreenState();
}
class _CompanyScreenState extends State<CompanyScreen> {
  String? companyId;
  String? loadError;
  bool loading=true; bool isPartner=false; bool isCompanyOwner=false;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    final u=FirebaseService.user;
    if(u==null){if(mounted)setState(()=>loading=false);return;}
    companyId=null;isCompanyOwner=false;
    try {
      final us=await FirebaseService.db.collection('users').doc(u.uid).get();
      isPartner=us.data()?['role']=='partner';
      final q=await FirebaseService.db.collection('companies').where('ownerId',isEqualTo:u.uid).limit(1).get();
      if(q.docs.isNotEmpty){companyId=q.docs.first.id;isCompanyOwner=true;}
      else {final emp=await FirebaseService.db.collection('employeeProfiles').doc(u.uid).get();if(emp.exists)companyId=emp.data()?['companyId']?.toString();}
      if(mounted)setState(() {loading=false;loadError=null;});
    } catch(e,st) {
      debugPrint('LEF_LEF company load failed: $e');
      debugPrintStack(stackTrace:st);
      if(mounted)setState(() {loading=false;loadError='ما نجّمش نحمّل فضاء الشركة توا.';});
    }
  }
  Future<void> _createCompany() async {
    final name=TextEditingController(),cat=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('شركة / شريك جديد'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'اسم الشركة')),TextField(controller:cat,decoration:const InputDecoration(labelText:'النشاط'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,name.text.trim().isNotEmpty),child:const Text('إنشاء'))]));
    if(ok==true){
      try {companyId=await FirebaseService.createCompany(name.text,cat.text);if(mounted){setState(()=>loadError=null);await _load();}}
      catch(e,st){debugPrint('LEF_LEF company create failed: $e');debugPrintStack(stackTrace:st);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش ننشئ الشركة. تثبّت من الدور والإنترنت.')));}
    }
    name.dispose();cat.dispose();
  }
  Future<void> _addEmployee() async {
    if(companyId==null)return; final email=TextEditingController(),name=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('إضافة موظف'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'الاسم')),TextField(controller:email,decoration:const InputDecoration(labelText:'Email الموظف'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,email.text.trim().isNotEmpty),child:const Text('إضافة'))]));
    if(ok==true){ try { await FirebaseService.addEmployee(companyId!,email.text,name.text); } catch(_){ if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نضيف الموظف.'))); } } name.dispose();email.dispose(); if(mounted)setState((){});
  }
  Future<void> _addBranch() async {
    if(companyId==null||!isCompanyOwner)return;
    final name=TextEditingController(),address=TextEditingController(),areas=TextEditingController(),hours=TextEditingController(text:'الإثنين-الجمعة 09:00-17:00؛ السبت 09:00-13:00؛ الأحد مغلق');
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('إضافة فرع'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'اسم الفرع')),TextField(controller:address,decoration:const InputDecoration(labelText:'العنوان')),TextField(controller:hours,decoration:const InputDecoration(labelText:'أوقات العمل'),maxLines:2),TextField(controller:areas,decoration:const InputDecoration(labelText:'مناطق الخدمة (افصل بينها بفاصلة)'))])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,name.text.trim().isNotEmpty&&address.text.trim().isNotEmpty),child:const Text('حفظ الفرع'))]));
    if(ok==true){try{await FirebaseService.saveCompanyBranch(companyId!,name:name.text,address:address.text,openingHours:{'schedule':hours.text.trim()},serviceAreas:areas.text.split(',').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList());if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('الفرع تسجّل. تنجم تراجع أوقات العمل من إدارة الفروع.')));}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نحفظ الفرع. تثبّت من البيانات والصلاحيات.')));}}
    name.dispose();address.dispose();areas.dispose();hours.dispose();
  }
  Future<void> _updateAppointment(String id,String status) async {try{await FirebaseService.updateCompanyAppointmentStatus(companyId!,id,status);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('حالة الموعد تبدّلت.')));}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نبدّل حالة الموعد.')));}}

  Future<void> _addProduct() async {
    if(companyId==null)return; final name=TextEditingController(),price=TextEditingController(),stock=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('منتوج جديد'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'المنتوج')),TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'السعر')),TextField(controller:stock,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'المخزون'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,name.text.trim().isNotEmpty),child:const Text('حفظ'))]));
    if(ok==true){ try { await FirebaseService.addProduct(companyId!,name.text,double.tryParse(price.text)??-1,int.tryParse(stock.text)??-1); } catch(_){ if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('راجع اسم المنتوج والسعر والمخزون.'))); } } name.dispose();price.dispose();stock.dispose(); if(mounted)setState((){});
  }
  Future<void> _editProduct(String productId, Map<String,dynamic> product) async {
    final name=TextEditingController(text:(product['name']??'').toString());
    final price=TextEditingController(text:((product['price'] as num?)??0).toString());
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('تعديل المنتوج'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'اسم المنتوج')),TextField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'السعر بالدينار'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,name.text.trim().isNotEmpty&&double.tryParse(price.text.replaceAll(',','.'))!=null),child:const Text('احفظ'))]));
    if(ok==true){try{await FirebaseService.updateProduct(companyId!,productId,name.text,double.parse(price.text.replaceAll(',','.')));if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('المنتوج تعدّل.')));}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نعدّل المنتوج. تثبّت من الصلاحيات والسعر.')));}}
    name.dispose();price.dispose();
  }
  Future<void> _deleteProduct(String productId) async {
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('حذف المنتوج؟'),content:const Text('العملية تحذف المنتوج من القائمة نهائياً.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('رجوع')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('احذف'))]));
    if(ok!=true)return;try{await FirebaseService.deleteProduct(companyId!,productId);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('المنتوج تحذف.')));}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نحذف المنتوج.')));}
  }
  @override Widget build(BuildContext context){
    if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    if(loadError!=null)return Scaffold(appBar:AppBar(title:const Text('الشركة والخدمات')),body:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[Text(loadError!,textAlign:TextAlign.center),const SizedBox(height:12),FilledButton(onPressed:(){setState(()=>loading=true);_load();},child:const Text('عاود حاول'))]))));
    return Scaffold(appBar:AppBar(title:const Text('الشركة والخدمات',style:TextStyle(fontWeight:FontWeight.w900))),body:companyId==null?ListView(padding:const EdgeInsets.all(16),children:[
      if(isPartner) Center(child:FilledButton.icon(onPressed:_createCompany,icon:const Icon(Icons.business),label:const Text('أنشئ الشركة'))),
      if(!isPartner) ...[
        Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:()async{try{await FirebaseService.claimEmployeeProfile();await _load();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('دعوة الموظف تفعّلت.')));}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما فماش دعوة موظف بنفس الإيميل.')));}},icon:const Icon(Icons.verified_user_outlined),label:const Text('تفعيل دعوة الموظف'))),
        StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream:FirebaseService.pendingEmployeeInvites(),
        builder:(c,s)=>Column(children:[
          const Text('دعوات الموظفين',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),
          if(!s.hasData)const Padding(padding:EdgeInsets.all(20),child:CircularProgressIndicator()),
          for(final d in s.data?.docs??const <QueryDocumentSnapshot<Map<String,dynamic>>>[])
            Card(child:ListTile(
              title:Text((d.data()['displayName']??'دعوة موظف').toString(),style:const TextStyle(fontWeight:FontWeight.w800)),
              subtitle:Text('شركة: ${(d.data()['companyId']??'').toString()}'),
              trailing:Wrap(spacing:4,children:[
                IconButton(onPressed:()async{try{await FirebaseService.rejectEmployeeInvite(d.id);if(mounted)setState((){});}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نرفض الدعوة توا.')));}},icon:const Icon(Icons.close)),
                IconButton(onPressed:()async{try{await FirebaseService.acceptEmployeeInvite(d.id);await _load();if(mounted)setState((){});}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نقبل الدعوة توا.')));}},icon:const Icon(Icons.check,color:LefTheme.goldDark)),
              ]),
            )),
        ]),
      ),
      ],
    ]):ListView(padding:const EdgeInsets.all(16),children:[
      Card(child:ListTile(leading:const Icon(Icons.business,color:LefTheme.goldDark),title:const Text('فضاء الشركة'),subtitle:Text(companyId!),trailing:isCompanyOwner?IconButton(onPressed:_addProduct,icon:const Icon(Icons.add_box_outlined)):null)),
      const SizedBox(height:10),
      if(FirebaseService.user!=null) Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:()async{try{await FirebaseService.claimEmployeeProfile();await _load();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('الموظف تفعّل.')));}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما فماش دعوة موظف بنفس الإيميل.')));}},icon:const Icon(Icons.verified_user_outlined),label:const Text('تفعيل دعوة الموظف'))),
      Row(children:[const Expanded(child:Text('الموظفين',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900))),if(isCompanyOwner)IconButton(onPressed:_addEmployee,icon:const Icon(Icons.person_add_alt_1))]),
      StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseService.companyEmployees(companyId!),builder:(c,s)=>Column(children:[for(final d in s.data?.docs??[])Card(child:ListTile(leading:const Icon(Icons.badge_outlined),title:Text((d.data()['displayName']??'موظف').toString()),subtitle:Text((d.data()['email']??'').toString()),trailing:Text((d.data()['status']??'pending').toString()))) ])),
      const SizedBox(height:18),
      Row(children:[const Expanded(child:Text('الفروع ومناطق الخدمة',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900))),if(isCompanyOwner)IconButton(tooltip:'إضافة فرع',onPressed:_addBranch,icon:const Icon(Icons.add_business))]),
      StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseService.companyBranches(companyId!),builder:(c,s){if(s.hasError)return const Text('ما نجّمش نحمّل الفروع.');if(!s.hasData)return const Center(child:CircularProgressIndicator());if(s.data!.docs.isEmpty)return const Text('مازال ما فما حتى فرع.');return Column(children:[for(final d in s.data!.docs)Card(child:ListTile(leading:const Icon(Icons.storefront),title:Text((d.data()['name']??'فرع').toString()),subtitle:Text('${d.data()['address']??''}\nمناطق الخدمة: ${((d.data()['serviceAreas'] as List?)??const []).join('، ')}\nأوقات العمل: ${(d.data()['openingHours'] as Map?)?.values.join(' • ')??'غير محددة'}'),isThreeLine:true,trailing:isCompanyOwner?IconButton(tooltip:'إيقاف/تفعيل الفرع',onPressed:()async{try{await FirebaseService.setCompanyBranchActive(companyId!,d.id,d.data()['active']!=true);}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نبدّل حالة الفرع.')));}},icon:Icon(d.data()['active']==true?Icons.toggle_on:Icons.toggle_off)):null))]);}),
      const SizedBox(height:18),const Text('المواعيد وقائمة الانتظار',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
      StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseService.companyAppointments(companyId!),builder:(c,s){if(s.hasError)return const Text('ما نجّمش نحمّل المواعيد.');if(!s.hasData)return const Center(child:CircularProgressIndicator());if(s.data!.docs.isEmpty)return const Text('ما فماش مواعيد مطلوبة توا.');return Column(children:[for(final d in s.data!.docs)Card(child:ListTile(title:Text((d.data()['service']??'موعد').toString()),subtitle:Text('الحالة: ${d.data()['status']??'requested'} • الحريف: ${d.data()['userId']??''}'),trailing:isCompanyOwner?PopupMenuButton<String>(onSelected:(v)=>_updateAppointment(d.id,v),itemBuilder:(_)=>const [PopupMenuItem(value:'confirmed',child:Text('تأكيد')),PopupMenuItem(value:'rejected',child:Text('رفض')),PopupMenuItem(value:'waitlisted',child:Text('قائمة الانتظار')),PopupMenuItem(value:'completed',child:Text('مكتمل')),PopupMenuItem(value:'cancelled',child:Text('إلغاء'))]):null))]);}),
      StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseService.companyWaitlist(companyId!),builder:(c,s){if(!s.hasData||s.data!.docs.isEmpty)return const SizedBox.shrink();return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Padding(padding:EdgeInsets.symmetric(vertical:8),child:Text('قائمة الانتظار',style:TextStyle(fontWeight:FontWeight.w800))),for(final d in s.data!.docs)ListTile(leading:const Icon(Icons.hourglass_bottom),title:Text((d.data()['service']??'خدمة').toString()),subtitle:Text('الحالة: ${d.data()['status']??'waiting'}'))]);}),
      const SizedBox(height:18),const Text('المنتجات والمخزون',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
      StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseService.companyProducts(companyId!),builder:(c,s){
        if(s.hasError)return const Padding(padding:EdgeInsets.all(12),child:Text('ما نجّمش نحمّل المنتجات. تثبّت من الاتصال والصلاحيات.'));
        if(!s.hasData)return const Padding(padding:EdgeInsets.all(16),child:Center(child:CircularProgressIndicator()));
        if(s.data!.docs.isEmpty)return const Padding(padding:EdgeInsets.all(12),child:Text('ما فما حتى منتوج. استعمل + باش تزيد أول منتوج.'));
        return Column(children:[for(final d in s.data!.docs) Builder(builder:(context){final x=d.data();final stock=(x['stock'] as num?)?.toInt()??0;return Card(child:Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Column(children:[
          ListTile(title:Text((x['name']??'منتوج').toString(),style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('السعر: ${(x['price']??0)} د.ت • المخزون: $stock${stock==0?' • وفى المخزون':''}'),
            trailing:isCompanyOwner?PopupMenuButton<String>(tooltip:'إدارة المنتوج',onSelected:(v){if(v=='edit')_editProduct(d.id,x);if(v=='delete')_deleteProduct(d.id);},itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('تعديل المنتوج')),PopupMenuItem(value:'delete',child:Text('حذف المنتوج'))]):null,
          ),
          Padding(padding:const EdgeInsets.fromLTRB(12,0,12,8),child:Row(children:[
            Expanded(child:OutlinedButton.icon(onPressed:stock<=0?null:()async{try{final sold=await FirebaseService.sellProductUnit(companyId!,d.id);if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(sold?'تسجّل بيع وحدة ونقص المخزون.':'المخزون وفى.')));}catch(_){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نسجّل البيع.')));}},icon:const Icon(Icons.point_of_sale_outlined),label:const Text('تسجيل بيع'))),
            const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:()async{try{await FirebaseService.changeProductStock(companyId!,d.id,stock+1);}catch(_){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ما نجّمش نبدّل المخزون توا.')));}},icon:const Icon(Icons.add_circle_outline),label:const Text('زيد للمخزون'))),
          ])),
        ])));})]);
      }),
    ]));
  }
}
