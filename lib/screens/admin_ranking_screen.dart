// lib/screens/admin_ranking_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdminRankingScreen extends StatefulWidget {
  const AdminRankingScreen({super.key});

  @override
  State<AdminRankingScreen> createState() => _AdminRankingScreenState();
}

class _AdminRankingScreenState extends State<AdminRankingScreen> {
  // Variabile per memorizzare il filtro scelto. Partiamo da "Tutti"
  String _selectedGender = 'Tutti'; 

  // Le opzioni del nostro menu a tendina
  final List<String> _genderOptions = ['Tutti', 'male', 'female', 'other'];

  void _showScoreBreakdown(BuildContext context, String userId, String userName) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Dettaglio Punteggio: $userName", 
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.pink)),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('received_swipes')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  final votes = snapshot.data!.docs;
                  if (votes.isEmpty) return const Center(child: Text("Nessun voto registrato ancora."));

                  return ListView.builder(
                    itemCount: votes.length,
                    itemBuilder: (context, i) {
                      final v = votes[i].data() as Map<String, dynamic>;
                      final action = v['action'] ?? 'unknown';
                      final points = v['points'] ?? 0;
                      final fromId = v['fromId'] ?? 'Anonimo';
                      final fromName = v['fromName'] ?? fromId;

                      return ListTile(
                        leading: _getIconForAction(action),
                        title: Text("Azione: ${action.toUpperCase()}"),
                        subtitle: Text("Da: $fromName"),
                        trailing: Text(
                          points > 0 ? "+$points" : "$points",
                          style: TextStyle(
                            color: points > 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

// Helper per le icone del log
Widget _getIconForAction(String action) {
  switch (action) {
    case 'like': return const Icon(Icons.favorite, color: Colors.green);
    case 'superlike': return const Icon(Icons.star, color: Colors.blue);
    case 'nope': return const Icon(Icons.close, color: Colors.red);
    default: return const Icon(Icons.help_outline);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Classifica Popolarità'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          // --- 1. SEZIONE FILTRI IN ALTO ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.filter_list, color: Colors.pink),
                const SizedBox(width: 12),
                const Text(
                  'Filtra per genere:', 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedGender,
                    isExpanded: true,
                    items: _genderOptions.map((String gender) {
                      return DropdownMenuItem<String>(
                        value: gender,
                        child: Text(gender == 'male' ? 'Maschio' : 
                                    gender == 'female' ? 'Femmina' : 
                                    gender == 'other' ? 'Altro' : 'Tutti'),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedGender = newValue;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // --- 2. SEZIONE CLASSIFICA (GRIGLIA) ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Costruiamo la query in base al filtro scelto
              stream: _buildRankingQuery().snapshots(),
              builder: (context, snapshot) {
                // Controllo se sta caricando
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.pink));
                }
                
                // Controllo se ci sono errori (es. Indice mancante)
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Errore (Probabilmente manca l\'indice su Firebase):\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(child: Text('Nessun utente trovato.'));
                }

                // Mostriamo i risultati in una griglia a 2 colonne
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // Quante colonne vogliamo
                    crossAxisSpacing: 12, // Spazio orizzontale
                    mainAxisSpacing: 12, // Spazio verticale
                    childAspectRatio: 0.75, // Proporzione della "carta" (più alta che larga)
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    
                    // Estraiamo i dati in modo sicuro
                    final name = data['name'] ?? 'Sconosciuto';
                    final rankingScore = data['rankingScore'] ?? 50; // 50 è la media di base
                    
                    // Cerchiamo la prima foto disponibile
                    String? imageUrl;
                    if (data['photoUrl'] != null && data['photoUrl'] != '') {
                      imageUrl = data['photoUrl'];
                    } else if (data['photoUrls'] != null && (data['photoUrls'] as List).isNotEmpty) {
                      imageUrl = data['photoUrls'][0];
                    }

                    return InkWell(
                      onTap: () => _showScoreBreakdown(context, docs[index].id, name),
                      child: _buildRankingCard(name, imageUrl, rankingScore, index + 1),
                    );    
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Funzione che crea la "Domanda" (Query) da fare a Firebase
  Query _buildRankingQuery() {
    Query query = FirebaseFirestore.instance.collection('users');

    // Se non abbiamo selezionato "Tutti", aggiungiamo il filtro del genere
    if (_selectedGender != 'Tutti') {
      // Nota: assicurati che nel tuo DB il campo si chiami 'gender' e abbia i valori 'Male', 'Female', ecc.
      query = query.where('gender', isEqualTo: _selectedGender);
    }

    // Ordiniamo sempre per rankingScore, dal più alto al più basso (descending: true)
    return query.orderBy('rankingScore', descending: true).limit(50); // Limitiamo a 50 per non sovraccaricare il DB
  }

  // Funzione che disegna la singola "carta" dell'utente
  Widget _buildRankingCard(String name, String? imageUrl, num score, int rankPosition) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias, // Taglia l'immagine se esce dai bordi arrotondati
      child: Stack(
        fit: StackFit.expand,
        children: [
          // L'immagine di sfondo
          if (imageUrl != null)
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey.shade300),
              errorWidget: (context, url, error) => Container(color: Colors.grey.shade300, child: const Icon(Icons.person, size: 50, color: Colors.grey)),
            )
          else
            Container(color: Colors.grey.shade300, child: const Icon(Icons.person, size: 50, color: Colors.grey)),

          // Sfumatura nera in basso per leggere bene il nome
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 60,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black87, Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                )
              ),
              padding: const EdgeInsets.all(8),
              alignment: Alignment.bottomLeft,
              child: Text(
                name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Il Badge in alto a sinistra con la posizione in classifica (es. #1)
          Positioned(
            top: 8, left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '#$rankPosition',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Il Punteggio in alto a destra
          Positioned(
            top: 8, right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.pink,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    score.toString(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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