import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'; // <-- Nuovo import per la cache

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
        if (doc.id == currentUid) continue; // Salta TE STESSO

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

        // AGGIORNAMENTO CORRETTO: Aggiorniamo SIA photoUrls che photoUrl!
        await db.collection('users').doc(doc.id).update({
          'photoUrl': nuoveFoto[0], // L'avatar principale (Risolve i quadrati bianchi!)
          'photoUrls': nuoveFoto,   // L'array per il profilo
          'imageUrls': FieldValue.delete(),
        });
      }
      
      if (context.mounted) {
        // Obblighiamo la cache a svuotarsi per vedere i nuovi risultati subito!
        await DefaultCacheManager().emptyCache();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Foto HD impostate!'), backgroundColor: Colors.green),
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
      for (var doc in swipesSnapshot.docs) { batch.delete(doc.reference); }
      await batch.commit();

      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Swipe azzerati!')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Errore: $e')));
    }
  }

  // --- FUNZIONE: HARD RESET (BOMBA NUCLEARE PER TEST) ---
  Future<void> _hardResetDev(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Chiediamo conferma perché è un'azione distruttiva
    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('💣 Reset Totale'),
        content: const Text('Vuoi eliminare FISICAMENTE tutte le tue chat e i tuoi swipe? Utile per testare di nuovo i Match da zero.'),
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

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('💣 Distruzione in corso...')));
    }

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // 1. Troviamo ed eliminiamo TUTTE le chat in cui sei coinvolto
      final chatsSnap = await db.collection('chats').where('participants', arrayContains: uid).get();
      for (var doc in chatsSnap.docs) {
        // Entriamo nella sottocollezione e distruggiamo i messaggi
        final messagesSnap = await doc.reference.collection('messages').get();
        for (var msgDoc in messagesSnap.docs) {
          batch.delete(msgDoc.reference);
        }
        // Infine distruggiamo il contenitore della chat
        batch.delete(doc.reference);
      }

      // 2. Troviamo ed eliminiamo TUTTI i tuoi swipe
      final swipesSnap = await db.collection('swipes').where('from', isEqualTo: uid).get();
      for (var doc in swipesSnap.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Hard Reset completato! Riavvia l\'app.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Errore: $e')));
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
                ListTile(
                  leading: const Icon(Icons.hd, color: Colors.red),
                  title: const Text('Applica Foto HD al DB', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Risolve foto bianche (non tocca il tuo profilo)', style: TextStyle(color: Colors.red, fontSize: 12)),
                  onTap: () => _ripopolaImmaginiDatabase(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.refresh, color: Colors.red),
                  title: const Text('Azzera i miei Swipe', style: TextStyle(color: Colors.red)),
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
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.purple),
                  title: const Text('Hard Reset (Chat + Swipe)', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Elimina fisicamente tutto per ri-testare', style: TextStyle(color: Colors.purple, fontSize: 12)),
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