import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  const ChatScreen({Key? key, required this.chatId}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String _otherUserName = '';
  String _otherUserPhotoUrl = '';
  DatabaseReference? _connectionsRef;
  DatabaseReference? _lastChangedRef;
  final TextEditingController _textController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChatInfo();
  }

  Future<void> _loadChatInfo() async {
    // 1) Leggi il documento chat
    final chatSnap = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .get();
    final participants = List<String>.from(chatSnap['participants'] as List);
    final currentId = FirebaseAuth.instance.currentUser!.uid;
    final otherId = participants.firstWhere((id) => id != currentId);

    // 2) Imposta i riferimenti al status
    final connectionsRef = FirebaseDatabase.instance.ref('status/$otherId/connections');
    final lastChangedRef = FirebaseDatabase.instance.ref('status/$otherId/last_changed');

    // 3) Leggi i dati utente
    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(otherId)
        .get();
    final userData = userSnap.data() ?? {};
    final name = userData['name'] as String? ?? 'Utente';
    final photos = List<String>.from(userData['photoUrls'] ?? []);
    final photoUrl = photos.isNotEmpty ? photos.first : null;

    // 4) Aggiorna lo stato locale
    setState(() {
      _otherUserName = name;
      _otherUserPhotoUrl = photoUrl ?? '';
      _connectionsRef = connectionsRef;
      _lastChangedRef = lastChangedRef;
      _loading = false;
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final now = FieldValue.serverTimestamp();
    final currentId = FirebaseAuth.instance.currentUser!.uid;

    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': currentId,
      'text': text,
      'timestamp': now,
    });

    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({
      'lastMessage': text,
      'lastUpdated': now,
    });

    _textController.clear();
  }

  Widget _buildPresence() {
    if (_connectionsRef == null || _lastChangedRef == null) {
      return const Text('Offline', style: TextStyle(fontSize: 12, color: Colors.grey));
    }
    return StreamBuilder<DatabaseEvent>(
      stream: _connectionsRef!.onValue,
      builder: (context, snap) {
        final raw = snap.data?.snapshot.value;
        final map = (raw is Map) ? raw.cast<String, dynamic>() : <String, dynamic>{};
        final online = map.isNotEmpty;
        if (online) {
          return const Text('Online', style: TextStyle(fontSize: 12, color: Colors.green));
        } else {
          return FutureBuilder<DatabaseEvent>(
            future: _lastChangedRef!.once(),
            builder: (context, lastSnap) {
              if (!lastSnap.hasData || lastSnap.data!.snapshot.value == null) {
                return const Text('Offline', style: TextStyle(fontSize: 12, color: Colors.grey));
              }
              final ts = lastSnap.data!.snapshot.value as int;
              final lastSeen = DateTime.fromMillisecondsSinceEpoch(ts);
              final formatted = TimeOfDay.fromDateTime(lastSeen).format(context);
              return Text('Ultimo accesso: $formatted', style: const TextStyle(fontSize: 12, color: Colors.grey));
            },
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _loading
            ? const Text('Caricamento...')
            : Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: _otherUserPhotoUrl.isNotEmpty
                        ? NetworkImage(_otherUserPhotoUrl)
                        : null,
                    child: _otherUserPhotoUrl.isEmpty ? const Icon(Icons.person) : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _otherUserName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        _buildPresence(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .doc(widget.chatId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (ctx, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data!.docs;
                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemCount: docs.length,
                        itemBuilder: (ctx2, i) {
                          final data = docs[i].data()! as Map<String, dynamic>;
                          final isMe = data['senderId'] == FirebaseAuth.instance.currentUser!.uid;
                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? Theme.of(context).primaryColor.withAlpha(200)
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                data['text'] ?? '',
                                style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Scrivi un messaggio...',
                        filled: true,
                        fillColor: Colors.grey.shade200,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendMessage,
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
