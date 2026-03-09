import 'package:affinity_app/widgets/heart_progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/safe_avatar.dart';

class FilteredUsersScreen extends StatelessWidget {
  final String categoryTitle;
  final String interestKeyword;

  const FilteredUsersScreen({
    Key? key,
    required this.categoryTitle,
    required this.interestKeyword,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(categoryTitle), // Mostra il nome della categoria in alto
      ),
      // Il tuo codice originale per Firebase inizia qui!
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: HeartProgressIndicator(
                size: 60.0,
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Errore: ${snapshot.error}'));
          }

          final allDocs = snapshot.data?.docs ?? [];

          // NUOVO: Filtriamo la lista degli utenti!
          // Manteniamo solo quelli che hanno la 'keyword' nei loro interessi o hobby
          final filteredDocs = allDocs.where((doc) {
            final data = doc.data();
            
            // Prendiamo gli interessi dal database (li hai salvati come lista o stringa nel tuo user_model)
            final String hobbies = data['hobbies']?.toString().toLowerCase() ?? '';
            final List<dynamic> interestsList = data['interests'] ?? [];
            final String interestsString = interestsList.join(' ').toLowerCase();

            // Restituisce true se trova la parola chiave, altrimenti false
            return hobbies.contains(interestKeyword) || interestsString.contains(interestKeyword);
          }).toList();

          if (filteredDocs.isEmpty) {
            return const Center(child: Text('Nessun utente trovato per questa categoria 😔'));
          }

          // La tua bellissima griglia originale
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final data = filteredDocs[index].data();
              final name = data['name'] as String? ?? '—';
              final age = data['age']?.toString() ?? '—';
              final photoUrl = data['photoUrl'] as String?;
              
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SafeAvatar(
                      radius: 40,
                      url: photoUrl ?? '',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$age anni',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}