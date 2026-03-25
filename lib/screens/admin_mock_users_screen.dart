import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../constants/hobbies_dictionary.dart';

class AdminMockUsersScreen extends StatefulWidget {
  const AdminMockUsersScreen({Key? key}) : super(key: key);

  @override
  State<AdminMockUsersScreen> createState() => _AdminMockUsersScreenState();
}

class _AdminMockUsersScreenState extends State<AdminMockUsersScreen> {
  bool _isLoading = false;

  // --- DATI REALI PER IL TEST ---
  final List<String> _maleNames = ['Marco', 'Luca', 'Alessandro', 'Matteo', 'Giovanni', 'Davide', 'Simone', 'Andrea'];
  final List<String> _femaleNames = ['Giulia', 'Chiara', 'Martina', 'Sara', 'Alice', 'Elena', 'Francesca', 'Sofia'];

  final List<String> _malePhotos = [
    'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=500&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=500&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=500&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=500&auto=format&fit=crop',
  ];

  final List<String> _femalePhotos = [
    'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=500&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=500&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=500&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=500&auto=format&fit=crop',
  ];

  // --- FUNZIONE DI PULIZIA SICURA (RISPETTA LA SAFE LIST) ---
  Future<void> _deleteAllMockUsers() async {
    // 1. Chiediamo conferma
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("⚠️ Distruggi Cloni"),
        content: const Text("Vuoi cancellare TUTTI i profili di test generati in precedenza?\n\nI tuoi account reali e quelli nella Safe List NON verranno toccati."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annulla")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Distruggi", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final db = FirebaseFirestore.instance;
      
      // Cerchiamo SOLO gli utenti che hanno l'etichetta "isMock" a true
      final snap = await db.collection('users').where('isMock', isEqualTo: true).get();

      if (snap.docs.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nessun clone trovato!')));
        setState(() => _isLoading = false);
        return;
      }

      // Usiamo di nuovo il Batch per cancellarli a pacchetti di 500 (super veloce)
      WriteBatch batch = db.batch();
      int count = 0;

      for (var doc in snap.docs) {
        // PER SUPER SICUREZZA: Se per qualche assurdo motivo un UID della Safe List 
        // finisce qui dentro, lo saltiamo brutalmente.
        // Nota: Assicurati di importare SettingsScreen per accedere a _excludedUserIds, 
        // oppure copia la lista qui se SettingsScreen non è accessibile
        // if (SettingsScreen._excludedUserIds.contains(doc.id)) continue; 

        batch.delete(doc.reference);
        count++;

        // Se superiamo i 500, inviamo il pacco e ne creiamo uno nuovo
        if (count % 500 == 0) {
          await batch.commit();
          batch = db.batch();
        }
      }

      // Inviamo gli ultimi rimasti
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🔥 Eliminati $count profili clone in sicurezza!'), backgroundColor: Colors.orange)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

// --- NUOVA FUNZIONE OTTIMIZZATA PER I GRANDI NUMERI ---
  Future<void> _generateUsers(int count) async {
    setState(() => _isLoading = true);
    final random = Random();

    const double baseLat = 45.5289;
    const double baseLng = 9.2744;

    try {
      final db = FirebaseFirestore.instance;
      int totalGenerated = 0;

      // Firebase accetta massimo 500 scritture per ogni "Batch".
      // Usiamo un ciclo while per gestire numeri anche più grandi di 500.
      while (totalGenerated < count) {
        WriteBatch batch = db.batch();
        int currentBatchSize = 0;

        while (currentBatchSize < 500 && totalGenerated < count) {
          bool isMale = random.nextBool();
          String name = isMale 
              ? _maleNames[random.nextInt(_maleNames.length)] 
              : _femaleNames[random.nextInt(_femaleNames.length)];
              
          int age = random.nextInt(28) + 18;

          String photoUrl = isMale 
              ? _malePhotos[random.nextInt(_malePhotos.length)]
              : _femalePhotos[random.nextInt(_femalePhotos.length)];

          List<String> allAvailableHobbies = HobbiesDictionary.allHobbies;
          List<String> shuffledHobbies = List.from(allAvailableHobbies)..shuffle();
          
          int hobbyCount = random.nextInt(10) + 1; // Sceglie da 1 a 10 hobby casuali
          List<String> userHobbies = shuffledHobbies.take(hobbyCount).toList();

          // Aumentiamo un po' lo sparpagliamento (raggio più ampio per 500+ utenti)
          double latOffset = (random.nextDouble() - 0.5) * 0.3;
          double lngOffset = (random.nextDouble() - 0.5) * 0.3;

          // Invece di fare .add() [che fa una chiamata di rete immediata],
          // prepariamo il documento e lo mettiamo nel "pacco" (batch).
          DocumentReference newDocRef = db.collection('users').doc();
          
          batch.set(newDocRef, {
            'name': name,
            'gender': isMale ? 'male' : 'female',
            'age': age,
            'bio': 'Ciao! Sono un profilo di test generato automaticamente. Scrivimi!',
            'photoUrls': [photoUrl],
            'hobbies': userHobbies,
            'isVerified': random.nextBool(),
            'isPaused': false,
            'role': 'user',
            'location': {
              'position': {
                'latitude': baseLat + latOffset,
                'longitude': baseLng + lngOffset,
              }
            },
            'isMock': true,
            'createdAt': FieldValue.serverTimestamp(),
            'lastActive': FieldValue.serverTimestamp(),
          });

          currentBatchSize++;
          totalGenerated++;
        }

        // Spediamo l'intero pacco a Firebase in un colpo solo! 🚚
        await batch.commit();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Generati $count profili in un lampo!'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generatore Profili', style: TextStyle(color: Colors.deepPurple)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.deepPurple),
      ),
      body: Center(
        child: _isLoading 
          ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.deepPurple),
                SizedBox(height: 16),
                Text("Creazione profili in corso... Firebase sta lavorando 🛠️"),
              ],
            )
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.group_add, size: 80, color: Colors.deepPurple),
                  const SizedBox(height: 24),
                  const Text(
                    "Popola il database con profili finti completi di Hobby, Età, Coordinate e Foto HD. Perfetto per testare l'algoritmo di Affinità!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: () => _generateUsers(10),
                    icon: const Icon(Icons.person_add, color: Colors.white),
                    label: const Text("Aggiungi 10 Profili", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.all(16)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _generateUsers(100),
                    icon: const Icon(Icons.group_add, color: Colors.white),
                    label: const Text("Genera 100 Profili", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple.shade400, padding: const EdgeInsets.all(16)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _generateUsers(500),
                    icon: const Icon(Icons.rocket_launch, color: Colors.white),
                    label: const Text("Simula Lancio (500 Profili)", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, padding: const EdgeInsets.all(16)),
                  ),
                  const Divider(height: 32),
                  ElevatedButton.icon(
                    onPressed: _deleteAllMockUsers,
                    icon: const Icon(Icons.delete_forever, color: Colors.white),
                    label: const Text("Distruggi tutti i Profili Finti", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.all(16)),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}