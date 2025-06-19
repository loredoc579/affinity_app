import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Widget che mostra una lista di profili (card) presi da Firestore
class ProfileCardList extends StatelessWidget {
  const ProfileCardList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Errore: ${snapshot.error}'));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('Nessun profilo disponibile'));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            return _ProfileCard(
              name: data['name'] as String? ?? '—',
              age: data['age'] as String? ?? '—',
              city: (data['location'] as Map<String, dynamic>?)?['city'] as String? ?? '—',
              photoUrl: data['photoUrl'] as String?,
              gender: data['gender'] as String? ?? '—',
              hobbies: (data['hobbies'] as String?)?.split(', ') ?? [],
            );
          },
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String name;
  final String age;
  final String city;
  final String gender;
  final List<String> hobbies;
  final String? photoUrl;

  const _ProfileCard({
    Key? key,
    required this.name,
    required this.age,
    required this.city,
    required this.gender,
    required this.hobbies,
    this.photoUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundImage: photoUrl != null
                  ? NetworkImage(photoUrl!)
                  : null,
              child: photoUrl == null
                  ? const Icon(Icons.person, size: 36)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$age anni',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$city • ${gender[0].toUpperCase()}${gender.substring(1)}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: -8,
                    children: hobbies.map((h) => Chip(label: Text(h))).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
