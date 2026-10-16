import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/app_models.dart';
import '../services/firebase_service.dart';

class ProviderApplicationScreen extends StatefulWidget {
  const ProviderApplicationScreen({super.key, required this.role});
  final AppRole role;
  @override State<ProviderApplicationScreen> createState() => _ProviderApplicationScreenState();
}

class _ProviderApplicationScreenState extends State<ProviderApplicationScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _vehicleType = TextEditingController();
  final _vehicleModel = TextEditingController();
  final _plate = TextEditingController();
  final _company = TextEditingController();
  final _taxId = TextEditingController();
  final Map<String, XFile> _docs = {};
  bool _sending = false;
  final _picker = ImagePicker();
  bool get _companyRole => widget.role == AppRole.partner;

  @override void initState() { super.initState(); _loadProfile(); }
  Future<void> _loadProfile() async {
    final u = FirebaseService.user; if (u == null) return;
    try { final d = (await FirebaseService.db.collection('users').doc(u.uid).get()).data() ?? {};
      if (!mounted) return;
      _name.text = (d['displayName'] ?? u.displayName ?? '').toString();
      _phone.text = (d['phone'] ?? '').toString();
      _company.text = (d['companyName'] ?? '').toString();
    } catch (_) {}
  }
  Future<void> _pick(String key, String label) async {
    final f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 1800);
    if (f != null && mounted) setState(() => _docs[key] = f);
  }
  String? _required(String? v) => v == null || v.trim().isEmpty ? 'الخانة هاذي لازمة' : null;
  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final requiredDocs = _companyRole ? ['identity','companyRegistration'] : ['identity','license','vehicleRegistration','insurance'];
    final missing = requiredDocs.where((k) => !_docs.containsKey(k)).toList();
    if (missing.isNotEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كمّل الوثائق المطلوبة قبل الإرسال.'))); return; }
    setState(() => _sending = true);
    try {
      final ok = await FirebaseService.submitProviderApplication(
        role: widget.role, fullName: _name.text, phone: _phone.text,
        vehicleType: _vehicleType.text, vehicleModel: _vehicleModel.text, plate: _plate.text,
        companyName: _company.text, taxId: _taxId.text, documents: _docs,
      );
      if (!mounted) return;
      if (ok) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('طلبك والوثائق تبعثوا للمراجعة. ما تنجمش تخدم قبل الموافقة.'))); Navigator.pop(context); }
      else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('عندك طلب مازال يستنى المراجعة.'))); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما نجّمش نبعث الطلب. تثبّت من الإنترنت والوثائق وعاود.')));
    } finally { if (mounted) setState(() => _sending = false); }
  }
  Widget _field(String label, TextEditingController c, {String? Function(String?)? validator, TextInputType? keyboard}) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(controller: c, validator: validator ?? _required, keyboardType: keyboard, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true)));
  Widget _document(String key, String label, {bool required = true}) => Card(child: ListTile(leading: Icon(_docs.containsKey(key) ? Icons.verified_outlined : Icons.upload_file_outlined, color: _docs.containsKey(key) ? Colors.green : null), title: Text(label), subtitle: Text(_docs[key]?.name ?? (required ? 'مطلوبة' : 'اختيارية')), trailing: IconButton(onPressed: _sending ? null : () => _pick(key, label), icon: const Icon(Icons.attach_file))));

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('طلب الانضمام للخدمة')),
    body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('عمّر المعلومات وارفع الوثائق الواضحة. الطلب يبقى قيد المراجعة، وما يتفعّلش حساب الخدمة قبل الموافقة.', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 18),
      _field('الاسم واللقب', _name), _field('رقم الهاتف', _phone, keyboard: TextInputType.phone),
      if (!_companyRole) ...[
        DropdownButtonFormField<String>(value: null, decoration: const InputDecoration(labelText: 'نوع المركبة', border: OutlineInputBorder()), items: (widget.role == AppRole.deliveryProvider ? const ['deliveryMoto','deliveryVan','deliveryTruck'] : const ['Moto','Car']).map((v) => DropdownMenuItem(value: v, child: Text(v == 'Moto' ? 'دراجة نارية' : v == 'Car' ? 'سيارة' : v == 'deliveryMoto' ? 'موتو ديليفري' : v == 'deliveryVan' ? 'فورڨون' : 'شاحنة'))).toList(), onChanged: (v) { if (v != null) _vehicleType.text = v; }, validator: (_) => _vehicleType.text.trim().isEmpty ? 'اختار نوع المركبة' : null),
        const SizedBox(height: 12), _field('الماركة والموديل', _vehicleModel), _field('رقم الترقيم', _plate),
      ] else ...[_field('اسم الشركة', _company), _field('المعرف الجبائي / رقم التسجيل', _taxId)],
      const SizedBox(height: 8), const Text('الوثائق المطلوبة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      _document('identity', 'بطاقة التعريف'),
      if (!_companyRole) ...[_document('license', 'رخصة السياقة'), _document('vehicleRegistration', 'وثيقة تسجيل المركبة'), _document('insurance', 'شهادة التأمين')]
      else _document('companyRegistration', 'وثائق تسجيل الشركة'),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: _sending ? null : _submit, icon: _sending ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.send), label: Text(_sending ? 'قاعد يبعث...' : 'إرسال الطلب للمراجعة')),
    ])),
  );
  @override void dispose() { _name.dispose(); _phone.dispose(); _vehicleType.dispose(); _vehicleModel.dispose(); _plate.dispose(); _company.dispose(); _taxId.dispose(); super.dispose(); }
}
