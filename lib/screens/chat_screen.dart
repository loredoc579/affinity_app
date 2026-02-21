import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Per caricare le immagini nella chat
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart'; // <--- QUESTA RISOLVE L'ERRORE!

import '../widgets/audio_bubble.dart';
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
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream;
  late final String _myUid;
  final _audioRecorder = AudioRecorder();
  

  bool _isTyping = false;
  bool _isUploadingImage = false;
  bool _isRecording = false;
  DateTime? _recordStartTime; // <--- Salva quando iniziamo a parlare
  Timer? _typingTimer;
  Timer? _ampTimer;
  List<double> _amplitudes = []; // Conterrà l'altezza delle barrette

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

    // Salviamo lo stream qui, così non verrà mai ricreato dal setState!
    _messagesStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
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
    _ampTimer?.cancel();
    _activeChatRef.remove();
    _textController.dispose();
    super.dispose();
  }

Future<void> _toggleRecording() async {
    if (_isRecording) {
      // 🛑 FERMA REGISTRAZIONE E TIMER
      _ampTimer?.cancel();
      final path = await _audioRecorder.stop();

      final finalAmps = List<double>.from(_amplitudes);

      // Calcoliamo quanti secondi è durato l'audio
      int durationSecs = 0;
      if (_recordStartTime != null) {
        durationSecs = DateTime.now().difference(_recordStartTime!).inSeconds;
      }

      setState(() {
        _isRecording = false;
        _amplitudes.clear(); // Pulisce il grafico
      });
      
      if (path != null) {
        _sendAudio(File(path), finalAmps, durationSecs);
      }
    } else {
      // 🎤 INIZIA REGISTRAZIONE
      if (await Permission.microphone.request().isGranted) {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _recordStartTime = DateTime.now();
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);

        // 📊 AVVIA IL GRAFICO DELLE FREQUENZE
        _ampTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
          final amp = await _audioRecorder.getAmplitude();
          // Converte i Decibel (da -50 a 0) in un valore da 0.1 a 1.0
          double level = (amp.current + 50) / 50;
          level = level.clamp(0.1, 1.0);
          
          if (mounted) {
            setState(() {
              _amplitudes.add(level);
              if (_amplitudes.length > 40) _amplitudes.removeAt(0); 
            });
          }
        });

      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permesso microfono negato')));
      }
    }
  }

  Future<void> _sendAudio(File file, List<double> amps, int durationSecs) async {
    try {
      final m = (durationSecs ~/ 60).toString().padLeft(2, '0');
      final s = (durationSecs % 60).toString().padLeft(2, '0');
      final formattedTime = '$m:$s';
      final messagePreview = '🎤 Audio ($formattedTime)';
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = FirebaseStorage.instance.ref().child('chat_audios/${widget.chatId}/$fileName.m4a');
      
      await ref.putFile(file);
      final audioUrl = await ref.getDownloadURL();
      final now = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').add({
        'senderId': _myUid,
        'type': 'audio',
        'audioUrl': audioUrl,
        'amplitudes': amps,
        'duration': durationSecs, // <--- SALVIAMO LA DURATA IN SECONDI
        'text': messagePreview,   // <--- TESTO FORMATTATO (🎤 Audio 00:15)
        'timestamp': now,
      });

      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
        'lastMessage': messagePreview,
        'lastUpdated': now,
        'readBy': [_myUid], 
      });
    } catch (e) {
      debugPrint("Errore invio audio: $e");
    }
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

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final file = File(pickedFile.path);
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      
      // 1. Carichiamo la foto su Firebase Storage nella cartella della chat
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_images/${widget.chatId}/$fileName.jpg');
          
      await ref.putFile(file);
      final imageUrl = await ref.getDownloadURL();

      final now = FieldValue.serverTimestamp();

      // 2. Salviamo il messaggio su Firestore specificando il "type"
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'senderId': _myUid,
        'type': 'image', // <--- FONDAMENTALE!
        'imageUrl': imageUrl,
        'text': '📷 Immagine', // Testo di fallback
        'timestamp': now,
      });

      // 3. Aggiorniamo l'ultimo messaggio della chat
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
        'lastMessage': '📷 Immagine',
        'lastUpdated': now,
        'readBy': [_myUid], 
      });

    } catch (e) {
      debugPrint("Errore invio immagine: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Errore invio immagine')));
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
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
              stream: _messagesStream,
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
                    final msgType = data['type'] ?? 'text';
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: msgType == 'image' ? const EdgeInsets.all(4) : const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Theme.of(context).primaryColor.withAlpha(200) : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        // Se è un'immagine, mostriamo la foto con i bordi arrotondati
                        child: msgType == 'image' 
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: data['imageUrl'] ?? '',
                                width: 200, 
                                fit: BoxFit.cover,
                              ),
                            )
                          : msgType == 'audio'
                              ? SizedBox(
                                  width: 250, // Larghezza del player audio
                                  child: AudioBubble(
                                    audioUrl: data['audioUrl'] ?? '', 
                                    isMe: isMe,
                                    amplitudes: data['amplitudes'] ?? [], 
                                    durationSeconds: data['duration'] ?? 0,
                                  ),
                                )
                              : Text(data['text'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
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
                  
                  // 1. TASTO FOTO (Scompare mentre registri l'audio!)
                  if (!_isRecording) ...[
                    if (_isUploadingImage)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.image, color: Colors.grey),
                        onPressed: _sendImage,
                      ),
                  ],

                  // 2. CENTRO: ONDE AUDIO O CAMPO DI TESTO
                  Expanded(
                    child: _isRecording
                        ? Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(24)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Icon(Icons.mic, color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                const Text('Rec...', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    reverse: true,
                                    itemCount: _amplitudes.length,
                                    itemBuilder: (context, index) {
                                      final amp = _amplitudes[_amplitudes.length - 1 - index];
                                      return Center(
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 2),
                                          width: 3,
                                          height: 40 * amp,
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          )
                        : TextField(
                            controller: _textController,
                            decoration: InputDecoration(
                              hintText: 'Scrivi un messaggio...',
                              filled: true,
                              fillColor: Colors.grey.shade200,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                            ),
                            minLines: 1,
                            maxLines: 4,
                          ),
                  ),

                  // 3. TASTO INVIA TESTO (Scompare mentre registri l'audio!)
                  if (!_isRecording)
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.pink),
                      onPressed: _sendMessage,
                    ),

                  // 4. TASTO AUDIO (Diventa un tasto Invia rosso mentre registri!)
                  IconButton(
                    // L'icona cambia da microfono ad aeroplanino di carta
                    icon: Icon(_isRecording ? Icons.send : Icons.mic),
                    color: _isRecording ? Colors.red : Colors.grey,
                    iconSize: _isRecording ? 28 : 24,
                    onPressed: _toggleRecording,
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