import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserPhotoUrl;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserPhotoUrl,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final DatabaseReference _connectionsRef;
  late final DatabaseReference _lastChangedRef;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Preparo subito i riferimenti alla presenza
    _connectionsRef = FirebaseDatabase.instance
        .ref('status/${widget.otherUserId}/connections');
    _lastChangedRef = FirebaseDatabase.instance
        .ref('status/${widget.otherUserId}/last_changed');
  }

  void _sendMessage() {
  final text = _textController.text.trim();
  if (text.isEmpty) return;

  final now = FieldValue.serverTimestamp();
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;
  final currentUid = currentUser.uid;

    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': currentUid, 
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
    return StreamBuilder<DatabaseEvent>(
      stream: _connectionsRef.onValue,
      builder: (context, snap) {
        final raw = snap.data?.snapshot.value;
        final map = (raw is Map) ? raw.cast<String, dynamic>() : <String, dynamic>{};
        final online = map.isNotEmpty;
        if (online) {
          return const Text('Online',
              style: TextStyle(fontSize: 12, color: Colors.green));
        } else {
          return StreamBuilder<DatabaseEvent>(
            stream: _lastChangedRef.onValue,
            builder: (context, lastSnap) {
              final ts = lastSnap.data?.snapshot.value as int?;
              if (ts == null) {
                return const Text('Offline',
                    style: TextStyle(fontSize: 12, color: Colors.grey));
              }
              final lastSeen = DateTime.fromMillisecondsSinceEpoch(ts);
              final formatted =
                  TimeOfDay.fromDateTime(lastSeen).format(context);
              return Text('Ultimo accesso: $formatted',
                  style: const TextStyle(fontSize: 12, color: Colors.grey));
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
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.otherUserPhotoUrl.isNotEmpty
                  ? NetworkImage(widget.otherUserPhotoUrl)
                  : null,
              child: widget.otherUserPhotoUrl.isEmpty
                  ? const Icon(Icons.person)
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
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
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: docs.length,
                  itemBuilder: (ctx2, i) {
                    final data = docs[i].data();
                    final isMe = data['senderId'] ==
                        FirebaseAuth.instance.currentUser!.uid;
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Theme.of(context).primaryColor.withAlpha(200)
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          data['text'] ?? '',
                          style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Scrivi un messaggio...',
                        filled: true,
                        fillColor: Colors.grey.shade200,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
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
