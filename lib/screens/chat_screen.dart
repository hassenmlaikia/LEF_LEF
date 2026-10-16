import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/firebase_service.dart';
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});
  @override Widget build(BuildContext context) { final uid=FirebaseService.user?.uid; return ListView(padding:const EdgeInsets.fromLTRB(16,58,16,120),children:[const Text('محادثة',style:TextStyle(fontSize:32,fontWeight:FontWeight.w900)),const Text('ناس • خدمات • مساعدة',style:TextStyle(color:Colors.black54)),const SizedBox(height:18),if(uid!=null)Card(child:ListTile(leading:const CircleAvatar(backgroundColor:LefTheme.gold,child:Icon(Icons.support_agent,color:Colors.white)),title:const Text('مساعدة LEF_LEF'),subtitle:const Text('مساعدة في التنقل، الديليفري ولا الحساب'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const ConversationScreen(title:'مساعدة LEF_LEF',conversationId:'support'))))),if(uid!=null)StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseService.db.collection('conversations').where('members',arrayContains:uid).limit(30).snapshots(),builder:(context,snap){if(!snap.hasData)return const SizedBox.shrink();return Column(children:snap.data!.docs.map((d){final title=(d.data()['title']??'محادثة').toString();return Card(child:ListTile(title:Text(title),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ConversationScreen(title:title,conversationId:d.id)))));}).toList());})]); }
}
class ConversationScreen extends StatefulWidget { const ConversationScreen({super.key,required this.title,required this.conversationId}); final String title,conversationId; @override State<ConversationScreen> createState()=>_ConversationState(); }
class _ConversationState extends State<ConversationScreen> {
  final input = TextEditingController();
  bool sendingImage = false;
  String? pendingMessageId;
  String? pendingMessageText;

  String get id => widget.conversationId == 'support'
      ? 'support_${FirebaseService.user?.uid ?? 'guest'}'
      : widget.conversationId;

  @override
  void initState() {
    super.initState();
    FirebaseService.ensureConversation(id, widget.title);
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> sendImage() async {
    if (sendingImage) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (picked == null || !mounted) return;
    setState(() => sendingImage = true);
    try {
      await FirebaseService.ensureConversation(id, widget.title);
      await FirebaseService.sendImageMessage(id, File(picked.path));
    } catch (error, stackTrace) {
      debugPrint('LEF_LEF chat image failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الصورة ما تبعثتش. تثبّت من النوع والحجم والإنترنت.')),
        );
      }
    } finally {
      if (mounted) setState(() => sendingImage = false);
    }
  }

  Future<void> send() async {
    final user = FirebaseService.user;
    final message = input.text.trim();
    if (user == null || message.isEmpty) return;

    if (pendingMessageId == null || pendingMessageText != message) {
      pendingMessageId = FirebaseService.db
          .collection('conversations')
          .doc(id)
          .collection('messages')
          .doc()
          .id;
      pendingMessageText = message;
    }
    final operationId = pendingMessageId!;
    try {
      await FirebaseService.ensureConversation(id, widget.title);
      await FirebaseService.sendMessage(id, message, clientMessageId: operationId);
      if (pendingMessageId == operationId) {
        pendingMessageId = null;
        pendingMessageText = null;
      }
      input.clear();
    } catch (error, stackTrace) {
      debugPrint('LEF_LEF message send failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('المساج ما تبعثش. ثبّت من الإنترنت؛ تنجم تعاود من غير ما يتكرّر المساج.'),
            action: SnackBarAction(label: 'عاود', onPressed: send),
          ),
        );
      }
    }
  }

  Widget _messageBubble(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final isMine = data['senderId'] == FirebaseService.user?.uid;
    final mediaPath = data['mediaPath']?.toString() ?? '';
    final mediaUrl = data['mediaUrl']?.toString() ?? '';
    final isImage = data['mediaType'] == 'image' &&
        (mediaPath.startsWith('chatMedia/') || mediaUrl.startsWith('https://'));

    Widget content;
    if (isImage) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: mediaPath.startsWith('chatMedia/')
                ? ChatMediaImage(path: mediaPath)
                : Image.network(
                    mediaUrl,
                    width: 220,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      width: 220,
                      height: 90,
                      child: Center(child: Text('الصورة القديمة موش متوفرة')),
                    ),
                  ),
          ),
          if ((data['text'] ?? '').toString().trim().isNotEmpty && data['text'] != 'صورة')
            Text(data['text'].toString()),
        ],
      );
    } else {
      content = Text((data['text'] ?? '').toString());
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMine ? LefTheme.gold : LefTheme.cream,
          borderRadius: BorderRadius.circular(17),
        ),
        child: content,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = FirebaseService.db
        .collection('conversations')
        .doc(id)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: messages,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('المساجات موش متوفرة توا.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: snapshot.data!.docs.map(_messageBubble).toList(),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'ابعث صورة',
                    onPressed: sendingImage ? null : sendImage,
                    icon: sendingImage
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.image_outlined, color: LefTheme.goldDark),
                  ),
                  Expanded(
                    child: TextField(
                      controller: input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => send(),
                      decoration: const InputDecoration(hintText: 'اكتب مساج...'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'إرسال المساج',
                    onPressed: send,
                    icon: const Icon(Icons.send_rounded, color: LefTheme.goldDark),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Authenticated chat-media renderer. Unlike Image.network(downloadUrl), this
/// uses Firebase Storage SDK authorization and never needs a shareable token URL.
class ChatMediaImage extends StatefulWidget {
  const ChatMediaImage({super.key, required this.path});
  final String path;
  @override State<ChatMediaImage> createState() => _ChatMediaImageState();
}
class _ChatMediaImageState extends State<ChatMediaImage> {
  late Future<Uint8List?> _bytes;
  @override void initState() { super.initState(); _load(); }
  @override void didUpdateWidget(covariant ChatMediaImage oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.path != widget.path) _load(); }
  void _load() {
    if (!widget.path.startsWith('chatMedia/') || widget.path.contains('..')) {
      _bytes = Future<Uint8List?>.error(StateError('invalid_media_path'));
      return;
    }
    _bytes = FirebaseService.storage.ref().child(widget.path).getData(10 * 1024 * 1024);
  }
  @override Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _bytes,
    builder: (context, snapshot) {
      if (snapshot.hasError) return const SizedBox(width:220,height:90,child:Center(child:Text('الصورة موش متوفرة')));
      if (!snapshot.hasData) return const SizedBox(width:220,height:140,child:Center(child:CircularProgressIndicator()));
      return Image.memory(snapshot.data!,width:220,height:220,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox(width:220,height:90,child:Center(child:Text('الصورة موش متوفرة'))));
    },
  );
}
