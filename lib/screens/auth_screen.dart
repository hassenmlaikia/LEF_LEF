import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme.dart';
import '../services/firebase_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthed});
  final VoidCallback onAuthed;
  @override State<AuthScreen> createState() => _AuthState();
}

class _AuthState extends State<AuthScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  bool create = false, busy = false, obscure = true;
  String? error;

  @override
  void dispose() { email.dispose(); password.dispose(); name.dispose(); super.dispose(); }

  bool validEmail(String value) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  Future<void> submit() async {
    final mail = email.text.trim();
    if (!validEmail(mail) || password.text.length < 6) {
      setState(() => error = 'دخل إيميل صحيح ومودباس فيها 6 حروف على الأقل.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final credential = create
          ? await FirebaseAuth.instance.createUserWithEmailAndPassword(email: mail, password: password.text)
          : await FirebaseAuth.instance.signInWithEmailAndPassword(email: mail, password: password.text);
      if (credential.user != null) {
        if (create && name.text.trim().isNotEmpty) await credential.user!.updateDisplayName(name.text.trim());
        // Keep the authenticated session if profile creation needs a retry.
        // Signing out here strands a newly-created account and makes recovery harder.
        await FirebaseService.ensureProfile(credential.user!, name: name.text);
        widget.onAuthed();
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('LEF_LEF Auth failed: code=${e.code} message=${e.message}');
      if (mounted) setState(() => error = e.message ?? 'ما نجّمش نكمّل عملية الحساب.');
    } on FirebaseException catch (e, st) {
      debugPrint('LEF_LEF Firestore failed: code=${e.code} message=${e.message} plugin=${e.plugin}');
      debugPrintStack(stackTrace:st);
      if (mounted) setState(() => error = e.code == 'permission-denied'
          ? 'الحساب تسجّل، أمّا ما كملناش إعداد الحساب. عاود ادخل بنفس الإيميل وكلمة السر؛ كان المشكلة تتعاود اتصل بالدعم.'
          : 'الحساب تسجّل، أمّا إعداد الحساب ما كملش. عاود ادخل بنفس الإيميل وكلمة السر.');
    } catch (e, st) {
      debugPrint('LEF_LEF account flow failed: $e');
      debugPrintStack(stackTrace:st);
      if (mounted) setState(() => error = 'ما نجّمش نكمّل عملية الحساب.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resetPassword() async {
    final mail = email.text.trim();
    if (!validEmail(mail)) { setState(() => error = 'دخل الإيميل متاعك الأول.'); return; }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: mail);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('بعثنالك إيميل تبديل المودباس.')));
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => error = e.message ?? 'ما نجّمش نبعث إيميل تبديل المودباس.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Image.asset('assets/lef_logo_lockup.png', width: 190, height: 112, fit: BoxFit.contain)),
        const SizedBox(height: 8),
        Text(create ? 'اعمل حساب LEF_LEF' : 'مرحبا بيك من جديد', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        Text(create ? 'Move • Discover • Connect' : 'كمّل تجربتك مع LEF_LEF', style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 24),
        if (create) TextField(controller: name, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'الاسم')),
        if (create) const SizedBox(height: 12),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'الإيميل')),
        const SizedBox(height: 12),
        TextField(controller: password, obscureText: obscure, onSubmitted: (_) => busy ? null : submit(), decoration: InputDecoration(labelText: 'المودباس', suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 54, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: LefTheme.gold, foregroundColor: Colors.black), onPressed: busy ? null : submit, child: Text(busy ? 'استنى شوية…' : create ? 'اعمل الحساب' : 'ادخل', style: const TextStyle(fontWeight: FontWeight.w900)))),
        if (!create) Center(child: TextButton(onPressed: busy ? null : resetPassword, child: const Text('نسيت المودباس؟'))),
        Center(child: TextButton(onPressed: busy ? null : () => setState(() { create = !create; error = null; }), child: Text(create ? 'عندي حساب ديجا' : 'اعمل حساب جديد'))),
      ]),
    )))),
  );
}
