import 'package:flutter/material.dart';
import '../core/theme.dart';

/// A deliberately raised, tactile callout used for messages anchored to the map.
/// Layered shadows, a bevel and a gold edge make the bubble visibly float above tiles.
class MapMessagePin extends StatelessWidget {
  const MapMessagePin({super.key, required this.title, required this.subtitle, this.icon = Icons.navigation_rounded, this.onTap});
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            boxShadow: const [
              BoxShadow(color: Color(0x55000000), blurRadius: 18, spreadRadius: 1, offset: Offset(0, 8)),
              BoxShadow(color: Color(0x22B8860B), blurRadius: 3, spreadRadius: 1, offset: Offset(0, 2)),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFFFFE9A3), LefTheme.gold, Color(0xFF8C6418)]),
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.white, Color(0xFFFFFBF0), Color(0xFFF2E6C9)]),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFFFFE9A3), LefTheme.gold, Color(0xFFB17A16)]),
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
                    border: Border.all(color: Colors.white, width: 1.5)),
                  child: Icon(icon, color: const Color(0xFF63450D), size: 23)),
                const SizedBox(width: 10),
                Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF30240B), fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, height: 1.2, color: Color(0xFF5B513C))),
                ])),
                const SizedBox(width: 3),
                const Icon(Icons.touch_app_rounded, size: 15, color: LefTheme.goldDark),
              ]),
            ),
          ),
        ),
        CustomPaint(size: const Size(24, 13), painter: _RaisedTail()),
      ]),
    );
  }
}

class _RaisedTail extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(1, 0)..lineTo(size.width - 1, 0)..lineTo(size.width / 2, size.height)..close();
    canvas.drawPath(path.shift(const Offset(0, 2)), Paint()..color = const Color(0x44000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawPath(path, Paint()..shader = const LinearGradient(colors: [Color(0xFFFFE9A3), Color(0xFFB17A16)]).createShader(Offset.zero & size));
    final inner = Path()..moveTo(4, 0)..lineTo(size.width - 4, 0)..lineTo(size.width / 2, size.height - 3)..close();
    canvas.drawPath(inner, Paint()..color = const Color(0xFFF2E6C9));
  }
  @override
  bool shouldRepaint(covariant _RaisedTail oldDelegate) => false;
}
