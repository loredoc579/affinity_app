import 'package:flutter/material.dart';
import 'affinity_badge.dart';

class ProfileCard extends StatelessWidget {
  final Map<String, dynamic> user; // Riceve i dati dal backend

  const ProfileCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // Estraiamo i dati (con dei fallback di sicurezza)
    final String name = user['name'] ?? 'Utente';
    final int age = user['age'] ?? 0;
    final String photoUrl = (user['photoUrls'] as List?)?.first ?? 'https://via.placeholder.com/400';
    final int matchScore = user['matchScore'] ?? 0; // Il nuovo campo dal backend!
    final String bio = user['bio'] ?? '';

    debugPrint("DEBUG: Utente ${user['name']} - Score: ${user['matchScore']}");

    return Card(
      margin: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias, // Taglia l'immagine per seguire i bordi arrotondati
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // 1. L'IMMAGINE DI SFONDO
                Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
                
                // 2. IL BADGE DI AFFINITÀ (Posizionato in alto a sinistra)
                Positioned(
                  top: 12,
                  left: 12,
                  child: AffinityBadge(score: matchScore),
                ),
              ],
            ),
          ),
          
          // 3. I DETTAGLI SOTTO
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
// Nel metodo build, dove scrivi il nome:
Text(
  '$name, $age (Score: ${user['matchScore'] ?? "NULL"})', // <-- AGGIUNGI QUESTO
  style: const TextStyle(
    fontSize: 24, 
    fontWeight: FontWeight.bold, 
    color: Colors.red // <-- AGGIUNGI QUESTO
  ),
),
                const SizedBox(height: 8),
                Text(
                  bio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}