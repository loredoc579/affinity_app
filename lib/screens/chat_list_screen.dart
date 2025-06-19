import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'chat_screen.dart'; // ← import della ChatScreen

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final uid = user.uid;

    final chatStream = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: uid)
        .where('deleted', isEqualTo: false)
        .orderBy('lastUpdated', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: chatStream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Errore: ${snap.error}'));
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('Nessuna chat ancora'));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final chatDoc = docs[i];
            final data = chatDoc.data();

            // Trovo l'altro partecipante
            final participants =
                List<String>.from(data['participants'] as List<dynamic>);
            final otherUid = participants.firstWhere((id) => id != uid);

            final lastMessage = data['lastMessage'] as String? ?? '';

            return Slidable(
              key: ValueKey(chatDoc.id),
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                extentRatio: 0.25,
                children: [
                  SlidableAction(
                    onPressed: (_) =>
                        _confirmCancel(context, uid, chatDoc.id),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    icon: Icons.close,
                    label: 'Annulla',
                  ),
                ],
              ),
              child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUid)
                    .get(),
                builder: (ctx2, userSnap) {
                  // Loading dello user
                  if (userSnap.connectionState ==
                      ConnectionState.waiting) {
                    return const ListTile(
                      title: Text('Caricamento...'),
                    );
                  }
                  // Errore o utente non esistente
                  if (userSnap.hasError ||
                      !userSnap.hasData ||
                      !userSnap.data!.exists) {
                    return ListTile(
                      title: const Text('Utente sconosciuto'),
                      subtitle: Text(lastMessage),
                      onTap: () {
                        // Passo solo chatId, ma meglio non entrare qui
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              chatId: chatDoc.id,
                              otherUserId: otherUid,
                              otherUserName: 'Utente',
                              otherUserPhotoUrl: '',
                            ),
                          ),
                        );
                      },
                    );
                  }

                  // Dati utente caricati
                  final udata = userSnap.data!.data()!;
                  final name = udata['name'] as String? ?? 'Utente';
                  final photos =
                      List<String>.from(udata['photoUrls'] as List? ?? []);
                  final photoUrl = photos.isNotEmpty ? photos.first : '';

                  return ListTile(
                    leading: photoUrl.isNotEmpty
                        ? CircleAvatar(
                            backgroundImage: NetworkImage(photoUrl),
                          )
                        : const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(name),
                    subtitle: Text(lastMessage),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            chatId: chatDoc.id,
                            otherUserId: otherUid,
                            otherUserName: name,
                            otherUserPhotoUrl: photoUrl,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  void _confirmCancel(BuildContext context, String uid, String chatId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annullare il match?'),
        content: const Text(
            'Sei sicuro di voler annullare il match e rimuovere questa chat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _cancelMatch(uid, chatId);
            },
            child: const Text('Sì, annulla'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelMatch(String uid, String chatId) async {
    final doc = FirebaseFirestore.instance.collection('chats').doc(chatId);
    await doc.update({
      'deleted': true,
      'deletedBy': FieldValue.arrayUnion([uid]),
      'deletedDate': FieldValue.serverTimestamp(),
    });
  }
}
