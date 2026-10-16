import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/app_prefs.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;
  @override State<OnboardingScreen> createState() => _OnboardingState();
}

class _OnboardingState extends State<OnboardingScreen> {
  final page = PageController();
  int index = 0;
  bool finishing = false;
  final pages = const [
    ('onboarding_mobility_real.jpg', 'تنقّل أذكى.', 'تاكسي • Moto • ديليفري • خدمات • SOS'),
    ('onboarding_connect_real.jpg', 'اكتشف وتواصل.', 'بلايص • ناس • ستوريّات • منشورات • مناسبات'),
    ('onboarding_safe_real.jpg', 'كل شيء واضح.', 'تتبّع • تنبيهات • حالات مباشرة • تحكّم في الخصوصية'),
  ];
  @override void dispose() { page.dispose(); super.dispose(); }
  Future<void> finish() async {
    if (finishing) return;
    setState(() => finishing = true);
    await AppPrefs.setOnboardingDone();
    if (mounted) widget.onDone();
  }
  void next() { if (index < pages.length - 1) page.nextPage(duration: const Duration(milliseconds: 360), curve: Curves.easeOutCubic); else finish(); }

  @override Widget build(BuildContext context) {
    final current = pages[index];
    return Scaffold(body: Stack(fit: StackFit.expand, children: [
      PageView.builder(controller: page, itemCount: pages.length, onPageChanged: (v) => setState(() => index = v), itemBuilder: (_, i) => Image.asset('assets/${pages[i].$1}', fit: BoxFit.cover, filterQuality: FilterQuality.high)),
      IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withAlpha(35), Colors.transparent, Colors.black.withAlpha(220)], stops: const [0, .38, 1])))),
      SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 8), child: Row(children: [Image.asset('assets/lef_logo_mark.png', width: 48, height: 42, fit: BoxFit.contain), const Spacer(), TextButton(onPressed: finishing ? null : finish, child: const Text('تعدّى', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)))])),
        const Spacer(),
        Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 18), child: Align(alignment: Alignment.centerRight, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.black.withAlpha(80), borderRadius: BorderRadius.circular(30)), child: Text('${index + 1} / ${pages.length}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800))),
          const SizedBox(height: 10),
          Text(current.$2, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8), Text(current.$3, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.45)),
        ]))),
        Padding(padding: const EdgeInsets.fromLTRB(22, 6, 22, 20), child: Row(children: [
          Row(children: List.generate(pages.length, (i) => AnimatedContainer(duration: const Duration(milliseconds: 220), margin: const EdgeInsets.only(left: 6), width: i == index ? 25 : 7, height: 7, decoration: BoxDecoration(color: i == index ? LefTheme.gold : Colors.white60, borderRadius: BorderRadius.circular(8))))),
          const Spacer(),
          SizedBox(width: 158, height: 52, child: FilledButton(onPressed: finishing ? null : next, style: FilledButton.styleFrom(backgroundColor: LefTheme.gold, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LefTheme.radiusControl))), child: Text(index == pages.length - 1 ? 'يلا نبدأو' : 'التالي', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)))),
        ])),
      ])),
    ]));
  }
}
