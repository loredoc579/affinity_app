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
  final ScrollController _scrollController = ScrollController();
  List<DocumentSnapshot> _users = []; // Lista locale degli utenti
  DocumentSnapshot? _lastDocument;    // L'ultimo utente caricato (per sapere da dove ripartire)
  bool _isLoading = false;            // Per evitare doppie chiamate mentre carica
  bool _hasMore = true;               // Per sapere se ci sono ancora utenti da caricare

  // Variabile per memorizzare il filtro scelto. Partiamo da "Tutti"
  String _selectedGender = 'Tutti'; 
  String _searchText = "";

  final TextEditingController _searchController = TextEditingController();
  
  // Le opzioni del nostro menu a tendina
  final List<String> _genderOptions = ['Tutti', 'male', 'female', 'other'];

  Future<void> _fetchUsers() async {
    if (_isLoading || !_hasMore) return; // Se sta già caricando o non c'è altro, fermati

    setState(() => _isLoading = true);

    Query query = FirebaseFirestore.instance
        .collection('users')
        .orderBy('rankingScore', descending: true)
        .limit(20);

    // Se non è la prima volta, riparti da dopo l'ultimo documento
    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    final snapshot = await query.get();

    if (snapshot.docs.length < 20) {
      _hasMore = false; // Se ne tornano meno di 20, significa che la lista è finita
    }

    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;
      setState(() {
        _users.addAll(snapshot.docs); // Aggiungiamo i nuovi arrivati alla lista esistente
      });
    }

    setState(() => _isLoading = false);
  }

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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SizedBox(
        height: 40, // 1. Forza l'altezza massima a 40 pixel
        child: TextField(
          textInputAction: TextInputAction.search,
          controller: _searchController,
          textAlignVertical: TextAlignVertical.center, // Mantiene il testo centrato verticalmente
          onChanged: (value) {
            setState(() {
              _searchText = value;
            });
          },
          onSubmitted: (value) {
            FocusScope.of(context).unfocus();
          },
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            // 2. Passiamo da labelText a hintText
            hintText: 'Cerca utente (es: Marco)',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Rimuovi il vertical: 0
            
            // 3. Riduciamo lo spazio occupato dalle icone (fondamentale)
            prefixIconConstraints: const BoxConstraints(minWidth: 40, maxHeight: 40),
            suffixIconConstraints: const BoxConstraints(minWidth: 40, maxHeight: 40),
            
            prefixIcon: const Icon(Icons.search, size: 18), // Icona leggermente più piccola
            suffixIcon: _searchText.isNotEmpty 
              ? IconButton(
                  padding: EdgeInsets.zero, // Toglie il padding interno dell'IconButton
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchText = "";
                    });
                  },
                )
              : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
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
  void initState() {
    super.initState();
    _fetchUsers(); // Carica i primi 20 all'avvio

    _scrollController.addListener(() {
      // Se mancano 200 pixel alla fine della lista, carica i successivi
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _fetchUsers();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
  // Avvolgiamo tutto in un GestureDetector per catturare i tocchi sullo sfondo
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => FocusScope.of(context).unfocus(),
    child: Scaffold(
        appBar: AppBar(
          title: const Text('Classifica Popolarità'),
          backgroundColor: Colors.pink,
          foregroundColor: Colors.white,
        ),
        backgroundColor: Colors.grey.shade100,
        body: Column(
          children: [
            _buildSearchBar(),
            // --- 1. SEZIONE FILTRI IN ALTO ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              child: _users.isEmpty && _isLoading 
                    // Mostriamo un caricamento centrale solo se la lista è vuota e stiamo caricando i primissimi dati
                    ? const Center(child: CircularProgressIndicator(color: Colors.pink))             
                    : _users.isEmpty
                    // Se ha finito di caricare ma la lista è ancora vuota, non ci sono utenti
                    ? const Center(child: Text('Nessun utente trovato.'))
                    
                    // Se invece abbiamo utenti, costruiamo la nostra griglia
                    : GridView.builder(
                        controller: _scrollController, // 🌟 FONDAMENTALE: Questo "ascolta" quando arrivi in fondo
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,          // 2 colonne
                          crossAxisSpacing: 12,       // Spazio orizzontale tra le card
                          mainAxisSpacing: 12,        // Spazio verticale tra le card
                          childAspectRatio: 0.75,     // Proporzione (più alte che larghe)
                        ),
                        // Se _hasMore è true, aggiungiamo 1 elemento finto in fondo per mostrare il caricamento
                        itemCount: _users.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                              
                  // Se l'indice è uguale alla lunghezza della lista, significa che siamo 
                  // sull'elemento "finto" aggiuntivo: mostriamo la rotellina!
                  if (index == _users.length) {
                    return const Center(child: CircularProgressIndicator(color: Colors.pink));
                  }

                  // Estraiamo i dati dell'utente corrente dalla nostra lista
                  final data = _users[index].data() as Map<String, dynamic>;
                  
                  // 1. Estrazione del nome (con fallback se manca)
                  final name = data['name'] ?? 'Sconosciuto';
                  
                  // 2. Estrazione del punteggio (50 come media di base)
                  final rankingScore = data['rankingScore'] ?? 50; 
                  
                  // 3. Estrazione sicura dell'immagine
                  // Controlliamo prima se c'è 'photoUrl', altrimenti peschiamo la prima da 'photoUrls'
                  String? imageUrl;
                  if (data['photoUrl'] != null && data['photoUrl'] != '') {
                    imageUrl = data['photoUrl'];
                  } else if (data['photoUrls'] != null && (data['photoUrls'] as List).isNotEmpty) {
                    imageUrl = data['photoUrls'][0];
                  }

                  // 4. Creiamo la card cliccabile
                  return InkWell(
                    // Al tocco, apriamo il dettaglio voti passando l'ID e il nome
                    onTap: () => _showScoreBreakdown(context, _users[index].id, name),
                    // L'indice + 1 ci dà la posizione in classifica (1°, 2°, 3°...)
                    child: _buildRankingCard(name, imageUrl, rankingScore, index + 1),
                  );    
                },
              ),
            ),      
          ],
        ),
      ),
    );
  }

  // Funzione che crea la "Domanda" (Query) da fare a Firebase
  Query _buildRankingQuery() {
    Query query = FirebaseFirestore.instance.collection('users');

    // Filtro Genere
    if (_selectedGender != 'Tutti') {
      query = query.where('gender', isEqualTo: _selectedGender);
    }

    // 🔍 RICERCA CASE-INSENSITIVE
    if (_searchText.length >= 2) {
      // 1. Trasformiamo la ricerca in minuscolo
      String searchLower = _searchText.toLowerCase();
      
      // 2. Interroghiamo il campo name_lowercase
      query = query
          .where('name_lowercase', isGreaterThanOrEqualTo: searchLower)
          .where('name_lowercase', isLessThanOrEqualTo: '$searchLower\uf8ff');
    } else {
      query = query.orderBy('rankingScore', descending: true);
    }

    return query.limit(50);
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