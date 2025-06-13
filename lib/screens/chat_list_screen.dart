import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final uid = user.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Le mie chat')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: uid)
            .snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Errore: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Nessuna chat ancora'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final chatDoc = docs[i];
              final participants = List<String>.from(chatDoc['participants'] as List);
              final otherUid = participants.firstWhere((id) => id != uid);
              final lastMessage = chatDoc['lastMessage'] as String? ?? '';

              // Carica utente correlato
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUid)
                    .get(),
                builder: (ctx2, userSnap) {
                  if (userSnap.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      title: Text('Caricamento...'),
                    );
                  }
                  if (userSnap.hasError || !userSnap.hasData || !userSnap.data!.exists) {
                    return ListTile(
                      title: const Text('Utente sconosciuto'),
                      subtitle: Text(lastMessage),
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/chat',
                        arguments: chatDoc.id,
                      ),
                    );
                  }

                  final userData = userSnap.data!.data() as Map<String, dynamic>;
                  final name = userData['name'] as String? ?? 'Utente';
                  final photos = List<String>.from(userData['photoUrls'] ?? []);
                  final photoUrl = photos.isNotEmpty ? photos.first : null;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          photoUrl != null ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null ? const Icon(Icons.person) : null,
                    ),
                    title: Text(name),
                    subtitle: Text(lastMessage),
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/chat',
                      arguments: chatDoc.id,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
