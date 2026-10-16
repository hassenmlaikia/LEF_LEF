import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'core/theme.dart';
import 'models/app_models.dart';
import 'services/firebase_service.dart';
import 'services/app_prefs.dart';
import 'screens/onboarding_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/map_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/owner_screen.dart';
import 'screens/provider_screen.dart';
import 'screens/company_screen.dart';

final Stopwatch _startupClock = Stopwatch()..start();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  Object? firebaseError;
  try {
    await FirebaseService.init();
  } catch (e) {
    firebaseError = e;
  }
  runApp(LefLefApp(startupError: firebaseError));
}

class LefLefApp extends StatefulWidget {
  const LefLefApp({super.key, this.startupError});
  final Object? startupError;
  @override State<LefLefApp> createState() => _AppState();
}

class _AppState extends State<LefLefApp> {
  bool loading = true, onboarded = false;
  String themePreference = 'system';
  User? user;
  String? role;
  String language = 'تونسي';
  double fontScale = 1.0;
  String? startupError;
  StreamSubscription<User?>? _authSub;

  @override void initState() { super.initState(); startupError = widget.startupError?.toString(); _load(); }
  @override void dispose() { _authSub?.cancel(); super.dispose(); }

  Future<void> _load() async {
    final o = await AppPrefs.onboardingDone();
    final mode = await AppPrefs.themeMode();
    final l = await AppPrefs.language();
    final fs = await AppPrefs.fontScale();
    if (mounted) setState(() { themePreference = mode; language = l; fontScale = fs; });
    if (startupError == null) {
      try {
        _authSub = FirebaseAuth.instance.authStateChanges().listen((u) async {
          if (u == null) {
            await AppPrefs.clearRole();
            if (mounted) setState(() { user = null; role = null; });
            return;
          }
          try {
            await FirebaseService.ensureProfile(u);
            final snap = await FirebaseService.db.collection('users').doc(u.uid).get();
            final data = snap.data() ?? <String, dynamic>{};
            final remote = data['role']?.toString();
            final selected = data['roleSelected'] != false;
            if (remote != null && selected) await AppPrefs.setRole(remote);
            if (mounted) setState(() { user = u; role = selected ? remote : null; });
          } on FirebaseException catch (e, st) {
            debugPrint('LEF_LEF authState profile failed: code=${e.code} message=${e.message} plugin=${e.plugin}');
            debugPrintStack(stackTrace:st);
            if (mounted) setState(() { user = u; role = null; });
          } catch (e, st) {
            debugPrint('LEF_LEF authState profile failed: $e');
            debugPrintStack(stackTrace:st);
            if (mounted) setState(() { user = u; role = null; });
          }
        });
      } catch (e) { startupError = e.toString(); }
    }
    final remainingSplash = const Duration(milliseconds: 3700) - _startupClock.elapsed;
    if (remainingSplash > Duration.zero) await Future<void>.delayed(remainingSplash);
    if (mounted) setState(() { onboarded = o; themePreference = mode; loading = false; });
  }

  void refresh() => setState(() {});
  void setThemePreference(String value) => setState(() => themePreference = value);
  bool get _effectiveDark => themePreference == 'dark' ||
      (themePreference == 'system' && WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
  void setLanguage(String v) => setState(() => language = v);
  void setFontScale(double v) => setState(() => fontScale = v.clamp(0.85,1.35).toDouble());

  @override Widget build(BuildContext c) {
    Widget page;
    if (loading) {
      page = _Splash(dark: _effectiveDark);
    } else if (startupError != null) {
      page = _StartupError(error: startupError!);
    } else if (!onboarded) {
      page = OnboardingScreen(onDone: () async { await AppPrefs.setOnboardingDone(); if (mounted) setState(() => onboarded = true); });
    } else if (user == null) {
      page = AuthScreen(onAuthed: refresh);
    } else {
      page = Shell(onSignOut: () { setState(() => user = null); }, onThemePreferenceChanged: setThemePreference, onLanguageChanged: setLanguage, onFontScaleChanged: setFontScale);
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: LefTheme.light(), darkTheme: LefTheme.dark(),
      themeMode: themePreference == 'system' ? ThemeMode.system : themePreference == 'dark' ? ThemeMode.dark : ThemeMode.light,
      locale: language == 'تونسي' ? const Locale('ar') : language == 'Français' ? const Locale('fr') : const Locale('en'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar', 'TN'), Locale('en'), Locale('fr')],
      localeResolutionCallback: (locale, supported) {
        if (locale == null) return const Locale('ar', 'TN');
        for (final item in supported) {
          if (item.languageCode == locale.languageCode && item.countryCode == locale.countryCode) return item;
        }
        for (final item in supported) {
          if (item.languageCode == locale.languageCode) return item;
        }
        return const Locale('ar', 'TN');
      },
      builder: (context, child) { final media=MediaQuery.of(context); return MediaQuery(data:media.copyWith(textScaler:TextScaler.linear(fontScale)),child:Directionality(textDirection: language == 'تونسي' ? TextDirection.rtl : TextDirection.ltr, child: child ?? const SizedBox.shrink())); },
      home: page,
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({required this.dark});
  final bool dark;
  @override Widget build(BuildContext context) => Scaffold(
    body: Stack(fit: StackFit.expand, children: [
      Image.asset(dark ? 'assets/splash_dark_real.jpg' : 'assets/splash_light_real.jpg', fit: BoxFit.cover),
      DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withAlpha(12), Colors.transparent, Colors.black.withAlpha(175)], stops: const [0, .45, 1]))),
      SafeArea(child: Column(children: [
        const Spacer(),
        // The real splash photo already contains the LEF_LEF lockup and tagline.
        // Do not paint another logo over it.
        const SizedBox(height: 30),
        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation<Color>(LefTheme.gold))),
        const SizedBox(height: 18),
        Text('LEF_LEF قاعدة تجهّز…', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white.withAlpha(220))),
        const SizedBox(height: 34),
      ])),
    ]),
  );
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error});
  final String error;
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: LefTheme.ink, body: SafeArea(child: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Image.asset('assets/lef_logo_mark.png', width: 92, height: 80),
    const SizedBox(height: 22),
    const Text('LEF_LEF ما كملتش الإقلاع', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
    const SizedBox(height: 10),
    const Text('صار مشكل في تهيئة الخدمة. الشاشة هاذي مقصودة باش ما تبقاش صفحة فارغة/خضراء.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, height: 1.5)),
    const SizedBox(height: 18),
    const Text('جرّب عاود بعد شوية. كان المشكل يتعاود، تواصل مع الدعم من داخل التطبيق.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5)),
  ])))));
}

class Shell extends StatefulWidget { const Shell({super.key, required this.onSignOut, required this.onThemePreferenceChanged, required this.onLanguageChanged, required this.onFontScaleChanged}); final VoidCallback onSignOut; final ValueChanged<String> onThemePreferenceChanged; final ValueChanged<String> onLanguageChanged; final ValueChanged<double> onFontScaleChanged; @override State<Shell> createState() => _ShellState(); }
class _ShellState extends State<Shell> {
  int index = 0;
  ServiceKind? selectedMoveKind;

  void _goTo(int destination) {
    if (!mounted) return;
    setState(() => index = destination);
  }

  Future<void> _showMainMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: false,
      builder: (sheetContext) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(12, 0, 12, 16), children: [
          const Padding(padding: EdgeInsets.fromLTRB(12, 4, 12, 12), child: Text('قائمة LEF_LEF', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
          ListTile(leading: const Icon(Icons.home_outlined), title: const Text('الرئيسية'), onTap: () => Navigator.pop(sheetContext, 'home')),
          ListTile(leading: const Icon(Icons.explore_outlined), title: const Text('اكتشف الأنشطة والبلايص'), onTap: () => Navigator.pop(sheetContext, 'explore')),
          ListTile(leading: const Icon(Icons.route_outlined), title: const Text('طلب مشوار أو خدمة'), onTap: () => Navigator.pop(sheetContext, 'ride')),
          ListTile(leading: const Icon(Icons.delivery_dining_outlined), title: const Text('التوصيل'), onTap: () => Navigator.pop(sheetContext, 'delivery')),
          ListTile(leading: const Icon(Icons.sos_outlined), title: const Text('SOS'), onTap: () => Navigator.pop(sheetContext, 'sos')),
          ListTile(leading: const Icon(Icons.medical_services_outlined), title: const Text('الإسعاف'), onTap: () => Navigator.pop(sheetContext, 'ambulance')),
          ListTile(leading: const Icon(Icons.chat_bubble_outline), title: const Text('المحادثات'), onTap: () => Navigator.pop(sheetContext, 'chat')),
          ListTile(leading: const Icon(Icons.notifications_none_rounded), title: const Text('الإشعارات'), onTap: () => Navigator.pop(sheetContext, 'notifications')),
          ListTile(leading: const Icon(Icons.person_outline), title: const Text('البروفايل'), onTap: () => Navigator.pop(sheetContext, 'profile')),
          ListTile(leading: const Icon(Icons.settings_outlined), title: const Text('الإعدادات والخصوصية واللغة'), onTap: () => Navigator.pop(sheetContext, 'settings')),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseService.user == null ? null : FirebaseService.db.collection('users').doc(FirebaseService.user!.uid).snapshots(),
            builder: (ctx, snap) {
              final data = snap.data?.data() ?? const <String, dynamic>{};
              final role = (data['role'] ?? '').toString();
              final caps = List<String>.from(data['capabilities'] ?? const <String>[]);
              if (role == 'owner' || role == 'manager' || caps.contains('manageRides')) {
                return ListTile(leading: const Icon(Icons.admin_panel_settings_outlined), title: const Text('مركز الإدارة'), onTap: () => Navigator.pop(sheetContext, 'admin'));
              }
              if (role == 'driver' || role == 'deliveryProvider') {
                return ListTile(leading: const Icon(Icons.work_outline), title: const Text('فضاء السائق والتوصيل'), onTap: () => Navigator.pop(sheetContext, 'provider'));
              }
              if (role == 'partner' || role == 'employee') {
                return ListTile(leading: const Icon(Icons.business_outlined), title: const Text('فضاء الخدمات والشركة'), onTap: () => Navigator.pop(sheetContext, 'company'));
              }
              return const SizedBox.shrink();
            },
          ),
        ]),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'home': _goTo(0); break;
      case 'explore': _goTo(1); break;
      case 'ride': setState(() { index = 2; selectedMoveKind = ServiceKind.taxiMoto; }); break;
      case 'delivery': setState(() { index = 2; selectedMoveKind = ServiceKind.deliveryMoto; }); break;
      case 'sos': setState(() { index = 2; selectedMoveKind = ServiceKind.sos; }); break;
      case 'ambulance': setState(() { index = 2; selectedMoveKind = ServiceKind.ambulance; }); break;
      case 'chat': _goTo(3); break;
      case 'profile': _goTo(4); break;
      case 'notifications': await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())); break;
      case 'settings': await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(onThemePreferenceChanged: widget.onThemePreferenceChanged, onLanguageChanged: widget.onLanguageChanged, onFontScaleChanged: widget.onFontScaleChanged, onSignOut: widget.onSignOut))); break;
      case 'admin': await Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerScreen())); break;
      case 'provider': await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderScreen())); break;
      case 'company': await Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanyScreen())); break;
    }
  }

  @override
  Widget build(BuildContext c) {
    final pages = <Widget>[
      HomeScreen(onMove: (kind) => setState(() { index = 2; selectedMoveKind = kind; }), onExplore: () => setState(() => index = 1), onMenu: _showMainMenu),
      const ExploreScreen(),
      MapScreen(key: ValueKey(selectedMoveKind), initialKind: selectedMoveKind),
      const ChatScreen(),
      ProfileScreen(onSignOut: widget.onSignOut, onThemePreferenceChanged: widget.onThemePreferenceChanged, onLanguageChanged: widget.onLanguageChanged),
    ];
    return Scaffold(
      body: Stack(children: [IndexedStack(index: index, children: pages), Positioned.fill(child: IgnorePointer(child: _ProviderRideAlert(key: ValueKey(FirebaseService.user?.uid))))]),
      bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: (v) => setState(() => index = v), destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'اكتشف'),
        NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route), label: 'تنقّل'),
        NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'محادثة'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'البروفايل'),
      ]),
    );
  }
}

/// Stays mounted across the bottom-navigation pages, so providers get live
/// in-app alerts even while looking at Home, Explore, Chat, or Profile.
class _ProviderRideAlert extends StatefulWidget { const _ProviderRideAlert({super.key}); @override State<_ProviderRideAlert> createState()=>_ProviderRideAlertState(); }
class _ProviderRideAlertState extends State<_ProviderRideAlert> {
  final Set<String> _seenIds=<String>{}; bool _firstSnapshot=true;
  @override Widget build(BuildContext context){
    final uid=FirebaseService.user?.uid;if(uid==null)return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(stream:FirebaseService.db.collection('users').doc(uid).snapshots(),builder:(context,profileSnap){
      final profile=profileSnap.data?.data()??const <String,dynamic>{};final role=profile['role']?.toString()??'';
      if(profileSnap.hasError||profile['providerVerified']!=true||profile['providerAvailable']!=true||!{'driver','deliveryProvider','partner'}.contains(role))return const SizedBox.shrink();
      return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseService.availableRidesForRole(role),builder:(context,ridesSnap){
        if(!ridesSnap.hasData||ridesSnap.hasError)return const SizedBox.shrink();
        final docs=ridesSnap.data!.docs;final ids=docs.map((d)=>d.id).toSet();
        if(_firstSnapshot){_firstSnapshot=false;_seenIds.addAll(ids);}
        else {final fresh=docs.where((d)=>!_seenIds.contains(d.id)).toList();_seenIds.addAll(ids);if(fresh.isNotEmpty){WidgetsBinding.instance.addPostFrameCallback((_){if(!mounted)return;final messenger=ScaffoldMessenger.maybeOf(context);if(messenger==null)return;final first=fresh.first.data();final name=serviceLabel(ServiceKind.values.firstWhere((k)=>k.name==first['kind']?.toString(),orElse:()=>ServiceKind.taxiMoto));messenger.showSnackBar(SnackBar(content:Text(fresh.length==1?'🚗 كورسة جديدة: $name':'🚗 وصلوك ${fresh.length} كورسات جديدة'),duration:const Duration(seconds:5)));});}}
        _seenIds.removeWhere((id)=>!ids.contains(id));
        return const SizedBox.shrink();
      });
    });
  }
}
