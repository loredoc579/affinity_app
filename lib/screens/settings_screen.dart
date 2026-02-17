import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // Lo script magico per popolare il database
  Future<void> _ripopolaImmaginiDatabase(BuildContext context) async {
    // Mostriamo un avviso di caricamento in basso
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🔄 Aggiornamento database in corso...'), duration: Duration(seconds: 2)),
    );

    try {
      final db = FirebaseFirestore.instance;
      final snapshot = await db.collection('users').get();

      int countUomini = 1;
      int countDonne = 1;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String gender = data['gender']?.toString().toLowerCase() ?? 'female';
        
        List<String> nuoveFoto = [];
        
        for (int i = 0; i < 3; i++) {
          if (gender == 'male' || gender == 'uomo') {
            nuoveFoto.add('https://randomuser.me/api/portraits/men/${(countUomini % 99) + i}.jpg');
          } else {
            nuoveFoto.add('https://randomuser.me/api/portraits/women/${(countDonne % 99) + i}.jpg');
          }
        }

        if (gender == 'male' || gender == 'uomo') {
          countUomini += 3;
        } else {
          countDonne += 3;
        }

        await db.collection('users').doc(doc.id).update({
          'photoUrls': nuoveFoto,
          'imageUrls': FieldValue.delete(), // Rimuoviamo il vecchio campo "imageUrls" se esiste
          'uid': doc.id,
        });
      }
      
      // Avviso di successo!
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Database aggiornato! Torna alla Home.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Errore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.person),
            title: Text('Account'),
            subtitle: Text('Gestisci il tuo profilo'),
          ),
          const ListTile(
            leading: Icon(Icons.notifications),
            title: Text('Notifiche'),
            subtitle: Text('Preferenze messaggi e match'),
          ),
          const Divider(),
          
          // LA NOSTRA VOCE "SEGRETA"
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.grey),
            title: const Text('Versione App', style: TextStyle(color: Colors.grey)),
            subtitle: const Text('1.0.0 (Build 12)', style: TextStyle(color: Colors.grey)),
            // onLongPress attiva la funzione segreta quando tieni premuto!
            onLongPress: () => _ripopolaImmaginiDatabase(context),
          ),
        ],
      ),
    );
  }
}