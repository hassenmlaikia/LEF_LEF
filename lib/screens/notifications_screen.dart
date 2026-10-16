import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/firebase_service.dart';
import 'map_screen.dart';
import 'chat_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext c) {
    final uid = FirebaseService.user?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (uid != null)
            IconButton(
              tooltip: 'علّم الكل مقروء',
              onPressed: () async {
                try {
                  await FirebaseService.markAllNotificationsRead();
                  if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('الإشعارات الكل تقراو.')));
                } catch (e) { debugPrint('LEF_LEF operation failed: $e');
                  if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('ما نجّمش نعلّم الإشعارات الكل مقروءة.')));
                }
              },
              icon: const Icon(Icons.done_all),
            ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('يلزمك تكون داخل للحساب.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseService.db.collection('users').doc(uid).collection('notifications').orderBy('createdAt', descending: true).limit(50).snapshots(),
              builder: (c, s) {
                if (s.hasError) return const Center(child: Text('الإشعارات موش متوفرة توا.'));
                if (!s.hasData) return const Center(child: CircularProgressIndicator());
                final docs = s.data!.docs;
                if (docs.isEmpty) return const Center(child: Text('ما فماش إشعارات توا.'));
                return ListView(padding: const EdgeInsets.all(16), children: docs.map((d) {
                  final x = d.data();
                  final read = x['read'] == true;
                  return Card(
                    child: ListTile(
                      tileColor: read ? null : LefTheme.cream.withAlpha(110),
                      leading: CircleAvatar(backgroundColor: LefTheme.cream, child: Icon(read ? Icons.notifications_none : Icons.notifications_active, color: LefTheme.goldDark)),
                      title: Text((x['title'] ?? 'LEF_LEF').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text((x['message'] ?? x['body'] ?? '').toString()),
                      onTap: () async {
                        try {
                          await FirebaseService.markNotificationRead(d.id);
                        } catch (e) {
                          debugPrint('LEF_LEF mark notification read failed: $e');
                          if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('ما نجّمش نحدّث حالة الإشعار توا.')));
                        }
                        if (!c.mounted) return;
                        final type=x['type']?.toString();
                        if (type=='ride' && x['rideId'] is String) {
                          Navigator.push(c, MaterialPageRoute(builder: (_) => MapScreen(initialRideId: x['rideId'].toString())));
                        } else if (type=='chat' && x['conversationId'] is String) {
                          Navigator.push(c, MaterialPageRoute(builder: (_) => ConversationScreen(title:'محادثة',conversationId:x['conversationId'].toString())));
                        }
                      },
                    ),
                  );
                }).toList());
              },
            ),
    );
  }
}
