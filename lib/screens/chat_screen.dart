import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async'; // <-- Serve per usare il Timer

import '../widgets/safe_avatar.dart';
import 'profile_preview_screen.dart'; // Importa l'anteprima!

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
  late final DatabaseReference _activeChatRef;
  late final DatabaseReference _typingRef;
  late final String _myUid;

  bool _isTyping = false;
  Timer? _typingTimer;

  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser!.uid;

    // Presenza Online/Offline
    _connectionsRef = FirebaseDatabase.instance.ref('status/${widget.otherUserId}/connections');
    _lastChangedRef = FirebaseDatabase.instance.ref('status/${widget.otherUserId}/last_changed');

    // Riferimento per sapere chi sta scrivendo in QUESTA chat
    _typingRef = FirebaseDatabase.instance.ref('chats/${widget.chatId}/typing');
    
    // Ascolta ogni volta che premi un tasto sulla tastiera
    _textController.addListener(_onTextChanged);

    // Diciamo al server in quale chat siamo attualmente
    _activeChatRef = FirebaseDatabase.instance.ref('status/$_myUid/activeChat');
    _activeChatRef.set(widget.chatId);
    // Se l'app crasha o si chiude improvvisamente, pulisce il dato
    _activeChatRef.onDisconnect().remove();

    // Segna i messaggi come letti entrando
    FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
      'readBy': FieldValue.arrayUnion([_myUid])
    });
  }

  // Controlla il campo di testo e usa un Timer per capire quando ti fermi
  void _onTextChanged() {
    // Se cancelli tutto il testo, spegniamo subito l'indicatore
    if (_textController.text.isEmpty) {
      if (_isTyping) {
        _isTyping = false;
        _typingRef.child(_myUid).set(false);
        _typingTimer?.cancel();
      }
      return;
    }

    // Se c'è del testo e non eravamo in modalità "scrittura", l'accendiamo
    if (!_isTyping) {
      _isTyping = true;
      _typingRef.child(_myUid).set(true);
    }

    // Qui c'è la magia: cancelliamo il vecchio timer e ne facciamo partire uno nuovo di 2 secondi
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 1500), () {
      // Se passano 2 secondi senza che tu prema altri tasti, spegniamo!
      _isTyping = false;
      _typingRef.child(_myUid).set(false);
    });
  }

  @override
  void dispose() {
    // Rimuove l'ascoltatore e imposta "sta scrivendo" a falso prima di chiudere
    _textController.removeListener(_onTextChanged);
    _typingTimer?.cancel();
    _typingRef.child(_myUid).set(false);
    _activeChatRef.remove();
    _textController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final now = FieldValue.serverTimestamp();

    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': _myUid, 
      'text': text,
      'timestamp': now,
    });

    FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
      'lastMessage': text,
      'lastUpdated': now,
      'readBy': [_myUid], 
    });

    _textController.clear();
    _typingTimer?.cancel();
    _typingRef.child(_myUid).set(false);
  }

  // --- FUNZIONI DI SICUREZZA ---
  void _confirmUnmatch() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annulla Match'),
        content: const Text('Sei sicuro? La chat verrà eliminata e non vi vedrete più nell\'app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Indietro')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
                'deleted': true,
                'deletedBy': FieldValue.arrayUnion([_myUid]),
              });
              if (mounted) Navigator.pop(context); // Torna alla lista
            },
            child: const Text('Sì, Annulla', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmReport() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Segnala Utente'),
        content: const Text('Questo profilo è falso, offensivo o viola le linee guida?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Invia la segnalazione
              await FirebaseFirestore.instance.collection('reports').add({
                'reporterId': _myUid,
                'reportedUserId': widget.otherUserId,
                'chatId': widget.chatId,
                'timestamp': FieldValue.serverTimestamp(),
              });
              // Annulla il match per sicurezza
              await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
                'deleted': true,
                'deletedBy': FieldValue.arrayUnion([_myUid]),
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Utente segnalato e bloccato.")));
                Navigator.pop(context); 
              }
            },
            child: const Text('Segnala e Blocca', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildPresence() {
    return StreamBuilder<DatabaseEvent>(
      stream: _connectionsRef.onValue,
      builder: (context, snap) {
        final raw = snap.data?.snapshot.value;
        bool online = false;
        if (raw is Map) online = raw.isNotEmpty;
        else if (raw is bool) online = raw; 
        else if (raw != null) online = true;

        if (online) {
          return const Text('Online', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold));
        } else {
          return StreamBuilder<DatabaseEvent>(
            stream: _lastChangedRef.onValue,
            builder: (context, lastSnap) {
              final ts = lastSnap.data?.snapshot.value as int?;
              if (ts == null) return const Text('Offline', style: TextStyle(fontSize: 12, color: Colors.grey));
              
              final lastSeen = DateTime.fromMillisecondsSinceEpoch(ts);
              final formattedTime = TimeOfDay.fromDateTime(lastSeen).format(context);
              final today = DateTime.now();
              final isToday = lastSeen.year == today.year && lastSeen.month == today.month && lastSeen.day == today.day;
              final dateText = isToday ? 'Oggi alle $formattedTime' : '${lastSeen.day}/${lastSeen.month} alle $formattedTime';

              return Text('Ultimo accesso: $dateText', style: const TextStyle(fontSize: 12, color: Colors.grey));
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
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.otherUserId).snapshots(),
          builder: (context, snapshot) {
            String currentName = widget.otherUserName;
            String currentPhotoUrl = widget.otherUserPhotoUrl;

            if (snapshot.hasData && snapshot.data!.exists) {
              final userData = snapshot.data!.data() as Map<String, dynamic>;
              currentName = userData['name'] ?? currentName;
              currentPhotoUrl = userData['photoUrl'] ?? currentPhotoUrl;
            }

            // Toccando l'intestazione si apre l'anteprima!
            return InkWell(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePreviewScreen(uid: widget.otherUserId)));
              },
              child: Row(
                children: [
                  SafeAvatar(url: currentPhotoUrl, radius: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(currentName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        _buildPresence(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // --- MENU OPZIONI AGGIUNTO QUI ---
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onSelected: (value) {
              if (value == 'unmatch') _confirmUnmatch();
              else if (value == 'report') _confirmReport();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'unmatch', child: Text('Annulla Match')),
              const PopupMenuItem(value: 'report', child: Text('Segnala Utente', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
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

                if (snapshot.hasData) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
                      'readBy': FieldValue.arrayUnion([_myUid])
                    }).catchError((_) {}); 
                  });
                }

                final docs = snapshot.data?.docs ?? [];
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: docs.length,
                  itemBuilder: (ctx2, i) {
                    final data = docs[i].data();
                    final isMe = data['senderId'] == _myUid;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Theme.of(context).primaryColor.withAlpha(200) : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(data['text'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // --- INDICATORE "STA SCRIVENDO..." ---
          StreamBuilder<DatabaseEvent>(
            stream: _typingRef.child(widget.otherUserId).onValue,
            builder: (context, snapshot) {
              final isOtherTyping = snapshot.data?.snapshot.value as bool? ?? false;
              if (isOtherTyping) {
                return Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 4, top: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "${widget.otherUserName} sta scrivendo...", 
                      style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12)
                    ),
                  ),
                );
              }
              return const SizedBox.shrink(); // Non mostra nulla se non scrive
            },
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
                    icon: const Icon(Icons.send, color: Colors.pink),
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