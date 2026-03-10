import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/heart_progress_indicator.dart';
import '../widgets/safe_avatar.dart'; // Assicurati che il percorso sia corretto
import 'profile_preview_screen.dart'; // O la pagina che usi per aprire il profilo
import 'profile_detail_screen.dart';

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
        title: Text(categoryTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pink)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.pink),
        elevation: 0,
      ),
      // Scarichiamo TUTTI gli utenti (o almeno una parte) e li filtriamo noi
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: HeartProgressIndicator(size: 40));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nessun utente trovato nel database."));
          }

          final allDocs = snapshot.data!.docs;
          
          // --- MAGIA: FILTRAGGIO LOCALE ROBUSTO ---
          final filteredDocs = allDocs.where((doc) {
            // Se la keyword è 'all', li accettiamo tutti!
            if (interestKeyword.toLowerCase() == 'all') return true;

            final data = doc.data();
            final dynamic hobbiesData = data['hobbies'];
            List<String> userHobbies = [];

            // Usiamo la stessa logica robusta del profilo per estrarre gli hobby
            if (hobbiesData is List) {
              userHobbies = hobbiesData.map((e) => e.toString().toLowerCase()).toList();
            } else if (hobbiesData is String && hobbiesData.trim().isNotEmpty) {
              userHobbies = hobbiesData.split(',').map((e) => e.trim().toLowerCase()).toList();
            }

            // Controlliamo anche gli obiettivi e il tipo di relazione per sicurezza!
            final relGoal = (data['relationshipGoal'] as String?)?.toLowerCase() ?? '';
            final relType = (data['relationshipType'] as String?)?.toLowerCase() ?? '';

            final searchKeyword = interestKeyword.toLowerCase();

            // L'utente passa il filtro se la keyword è negli hobby, nell'obiettivo o nel tipo di relazione
            return userHobbies.contains(searchKeyword) || 
                   relGoal.contains(searchKeyword) || 
                   relType.contains(searchKeyword);
          }).toList();

          if (filteredDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 60, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text("Nessun utente trovato per '$categoryTitle'.", 
                    style: const TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          // Mostriamo i risultati in una griglia
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.75, // Proporzione stile card di Tinder
            ),
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final data = filteredDocs[index].data();
              return _buildUserCard(context, data);
            },
          );
        },
      ),
    );
  }

  // Costruisce la singola "Card" per l'utente trovato
  Widget _buildUserCard(BuildContext context, Map<String, dynamic> data) {
    // Prendiamo la prima foto disponibile
    final List<String> photos = List<String>.from(data['photoUrls'] ?? []);
    final String photoUrl = photos.isNotEmpty ? photos[0] : '';
    final String name = data['name'] ?? 'Sconosciuto';
    final String age = data['age']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        // Opzionale: Apri il profilo dell'utente quando clicchi sulla card
        // Sostituisci con la navigazione corretta se necessario
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Foto di sfondo
            if (photoUrl.isNotEmpty)
              Image.network(photoUrl, fit: BoxFit.cover)
            else
              Container(color: Colors.grey.shade300, child: const Icon(Icons.person, size: 50, color: Colors.grey)),
            
            // Sfumatura nera in basso per leggere bene il testo
            Positioned(
              bottom: 0, left: 0, right: 0,
              height: 60,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
              ),
            ),
            
            // Testo (Nome, Età)
            Positioned(
              bottom: 12, left: 12, right: 12,
              child: Text(
                age.isNotEmpty ? '$name, $age' : name,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}