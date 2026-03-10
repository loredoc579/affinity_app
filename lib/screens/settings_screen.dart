import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'admin_verifications_screen.dart'; 
import 'match_screen.dart'; // <-- IMPORT FONDAMENTALE PER IL TEST

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // --- 🛡️ LISTA UTENTI PROTETTI (SAFE LIST) ---
  // Inserisci qui gli UID degli account di test che NON vuoi che vengano
  // modificati (foto) o le cui chat/swipe non devono essere cancellate.
  static const List<String> _excludedUserIds = [
    'OdKJBolEegRW4dFHCvzXvDbfguv2'// 'inserisci_qui_uid_1',''
    // 'inserisci_qui_uid_2',
  ];

  // --- 1. SET FOTOGRAFICI HD (Ampliati e verificati) ---
  static const List<List<String>> _profiliUomoHD = [
    [
      'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1537511446984-935f663eb1f4?q=80&w=800&auto=format&fit=crop',
    ],
    [
      'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1488161628813-04466f872528?q=80&w=800&auto=format&fit=crop',
    ],
    [
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1504222490345-c075b6008014?q=80&w=800&auto=format&fit=crop',
    ],
    [
      'https://images.unsplash.com/photo-1480455624313-e29b44bbfde1?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=800&auto=format&fit=crop',
    ],
    [
      'https://images.unsplash.com/photo-1504257432389-523431e11205?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1513956589380-bad6acb9b9d4?q=80&w=800&auto=format&fit=crop',
    ]
  ];

  static const List<List<String>> _profiliDonnaHD = [
    [
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=800&auto=format&fit=crop',
    ],
    [
      'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?q=80&w=800&auto=format&fit=crop',
    ],
    [
      'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1488426862026-3ee34a7d66df?q=80&w=800&auto=format&fit=crop',
    ],
    [
      'https://images.unsplash.com/photo-1517365830460-955ce3ccd263?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?q=80&w=800&auto=format&fit=crop',
    ],
    [
      'https://images.unsplash.com/photo-1489424731084-a5d8b219a5bb?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1517841905240-472988babdf9?q=80&w=800&auto=format&fit=crop',
    ]
  ];

  // --- FUNZIONE: POPOLA IMMAGINI HD ---
  Future<void> _ripopolaImmaginiDatabase(BuildContext context) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🔄 Aggiornamento in corso...')));

    try {
      final db = FirebaseFirestore.instance;
      final snapshot = await db.collection('users').get();
      int countUomini = 0, countDonne = 0;

      for (var doc in snapshot.docs) {
        // 🛡️ CONTROLLO PROTEZIONE: Salta te stesso e chi è nella lista esclusi
        if (doc.id == currentUid || _excludedUserIds.contains(doc.id)) continue; 

        final data = doc.data();
        final String rawGender = data['gender']?.toString().toLowerCase().trim() ?? 'female';
        final bool isMale = (rawGender == 'male' || rawGender == 'uomo' || rawGender == 'm');

        List<String> nuoveFoto;
        if (isMale) {
          nuoveFoto = _profiliUomoHD[countUomini % _profiliUomoHD.length];
          countUomini++;
        } else {
          nuoveFoto = _profiliDonnaHD[countDonne % _profiliDonnaHD.length];
          countDonne++;
        }

        await db.collection('users').doc(doc.id).update({
          'photoUrl': nuoveFoto[0],
          'photoUrls': nuoveFoto,   
          'imageUrls': FieldValue.delete(),
        });
      }
      
      if (context.mounted) {
        await DefaultCacheManager().emptyCache();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Foto HD impostate (utenti protetti ignorati)!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Errore: $e')));
    }
  }

  // --- FUNZIONE: AZZERA SWIPE ---
  Future<void> _azzeraSwipe(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final db = FirebaseFirestore.instance;
      final swipesSnapshot = await db.collection('swipes').where('from', isEqualTo: uid).get();
      final batch = db.batch();
      
      for (var doc in swipesSnapshot.docs) {
        final data = doc.data();
        // 🛡️ CONTROLLO PROTEZIONE: Non cancellare gli swipe fatti verso utenti protetti
        if (_excludedUserIds.contains(data['to'])) continue;
        
        batch.delete(doc.reference); 
      }
      
      await batch.commit();

      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Swipe azzerati (esclusi protetti)!')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Errore: $e')));
    }
  }

  // --- FUNZIONE: HARD RESET (BOMBA NUCLEARE PER TEST) ---
  Future<void> _hardResetDev(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('💣 Reset Totale'),
        content: const Text('Vuoi eliminare FISICAMENTE le chat e swipe? Verranno salvati gli utenti nella Safe List.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('DISTRUGGI', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (conferma != true) return;

    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('💣 Distruzione in corso...')));

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // 1. ELIMINA CHAT
      final chatsSnap = await db.collection('chats').where('participants', arrayContains: uid).get();
      for (var doc in chatsSnap.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        
        // 🛡️ CONTROLLO PROTEZIONE: Se la chat include un utente protetto, saltala!
        if (participants.any((p) => _excludedUserIds.contains(p))) continue;

        final messagesSnap = await doc.reference.collection('messages').get();
        for (var msgDoc in messagesSnap.docs) {
          batch.delete(msgDoc.reference);
        }
        batch.delete(doc.reference);
      }

      // 2. ELIMINA SWIPE
      final swipesSnap = await db.collection('swipes').where('from', isEqualTo: uid).get();
      for (var doc in swipesSnap.docs) {
        final data = doc.data();
        // 🛡️ CONTROLLO PROTEZIONE
        if (_excludedUserIds.contains(data['to'])) continue;
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Hard Reset completato! Riavvia l\'app.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Errore: $e')));
    }
  }

  // --- CARICA CATEGORIE "ESPLORA" SU FIREBASE ---
  Future<void> _uploadCategories(BuildContext context) async {
    try {
      // Le nostre categorie pronte per essere inviate
      final categories = [
        {'title': 'Tutti i profili', 'keyword': 'all', 'iconName': 'people', 'colorHex': '#2196F3', 'order': 1},
        {'title': 'Amore vero', 'keyword': 'amore', 'iconName': 'favorite', 'colorHex': '#FF5252', 'order': 2},
        {'title': 'Un caffè', 'keyword': 'caffè', 'iconName': 'cafe', 'colorHex': '#795548', 'order': 3},
        {'title': 'Sport', 'keyword': 'sport', 'iconName': 'sports', 'colorHex': '#4CAF50', 'order': 4},
        {'title': 'Serata', 'keyword': 'festa', 'iconName': 'party', 'colorHex': '#E040FB', 'order': 5},
      ];

      // Usiamo un Batch per inviarle tutte insieme in un decimo di secondo
      final batch = FirebaseFirestore.instance.batch();
      final collection = FirebaseFirestore.instance.collection('browse_categories');

      for (var cat in categories) {
        // Usiamo la keyword (es. 'amore') come ID del documento. 
        // Così se clicchi il tasto 10 volte, non crea duplicati ma sovrascrive!
        final docRef = collection.doc(cat['keyword'] as String);
        batch.set(docRef, cat);
      }

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Categorie caricate con successo!'), 
            backgroundColor: Colors.green
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- FUNZIONE: SVUOTA CACHE MANUALE ---
  Future<void> _svuotaCacheManuale(BuildContext context) async {
    await DefaultCacheManager().emptyCache();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🧹 Cache immagini pulita! Ricarica le pagine.'), backgroundColor: Colors.orange),
      );
    }
  }

  // --- FUNZIONE: TEST ANIMAZIONE MATCH ---
  Future<void> _testMatchScreen(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    // Prende la tua foto attuale per renderlo realistico
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final myPhoto = doc.data()?['photoUrl'] ?? 'https://via.placeholder.com/150';

    if (!context.mounted) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false, // Fondamentale per la sfocatura!
        pageBuilder: (BuildContext context, _, __) => MatchScreen(
          myPhotoUrl: myPhoto,
          otherPhotoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=800&auto=format&fit=crop',
          otherName: 'Giulia (Test)',
          otherUserId: 'fake_id_123',
          chatId: 'fake_chat_123',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni'), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: ListView(
        children: [
          const ListTile(leading: Icon(Icons.person), title: Text('Account'), subtitle: Text('Gestisci il tuo profilo')),
          const ListTile(leading: Icon(Icons.notifications), title: Text('Notifiche'), subtitle: Text('Preferenze messaggi e match')),
          
          // --- SEZIONE SVILUPPATORE ---
          const Padding(
            padding: EdgeInsets.only(top: 24, left: 16, bottom: 8),
            child: Text('🛠️ MENU SVILUPPATORE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
          ),
          Container(
            color: Colors.red.shade50,
            child: Column(
              children: [
                // --- BOTTONE ADMIN VERIFICHE ---
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: Colors.purple),
                  title: const Text('Admin: Verifiche Identità', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Approva o rifiuta i selfie degli utenti', style: TextStyle(color: Colors.purple, fontSize: 12)),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminVerificationsScreen()));
                  },
                ),
                const Divider(height: 1),
                // --- BOTTONE: CARICA CATEGORIE ---
                ListTile(
                  leading: const Icon(Icons.cloud_upload, color: Colors.blue),
                  title: const Text('Carica Categorie Esplora', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Invia le categorie base al database', style: TextStyle(color: Colors.blue, fontSize: 12)),
                  onTap: () => _uploadCategories(context),
                ),
                const Divider(height: 1),              
                ListTile(
                  leading: const Icon(Icons.favorite, color: Colors.pink),
                  title: const Text('Test Animazione Match', style: TextStyle(color: Colors.pink, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Simula la schermata di match senza swipe', style: TextStyle(color: Colors.pink, fontSize: 12)),
                  onTap: () => _testMatchScreen(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.hd, color: Colors.red),
                  title: const Text('Applica Foto HD al DB', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Risolve foto bianche (non tocca la Safe List)', style: TextStyle(color: Colors.red, fontSize: 12)),
                  onTap: () => _ripopolaImmaginiDatabase(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.refresh, color: Colors.red),
                  title: const Text('Azzera i miei Swipe', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Esclude gli utenti nella Safe List', style: TextStyle(color: Colors.red, fontSize: 12)),
                  onTap: () => _azzeraSwipe(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cleaning_services, color: Colors.orange),
                  title: const Text('Svuota Cache Immagini', style: TextStyle(color: Colors.orange)),
                  subtitle: const Text('Usa se il tuo avatar non si aggiorna', style: TextStyle(color: Colors.orange, fontSize: 12)),
                  onTap: () => _svuotaCacheManuale(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  title: const Text('Hard Reset (Chat + Swipe)', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Rispetta le regole della Safe List', style: TextStyle(color: Colors.purple, fontSize: 12)),
                  onTap: () => _hardResetDev(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}