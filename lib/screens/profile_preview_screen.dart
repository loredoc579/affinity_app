import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/heart_progress_indicator.dart';
import 'profile_detail_screen.dart'; // Importiamo il nostro modello unificato!

class ProfilePreviewScreen extends StatelessWidget {
  final String uid;

  const ProfilePreviewScreen({Key? key, required this.uid}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Anteprima Profilo"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      // Leggiamo i tuoi dati in tempo reale
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: HeartProgressIndicator(size: 60));
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Errore nel caricamento del profilo."));
          }

          final data = snapshot.data!.data()!;

          // ECCO LA MAGIA:
          // Richiamiamo la stessa identica schermata che vedono gli altri,
          // ma le diciamo che è un'anteprima, così nasconderà i bottoni!
          return ProfileDetailScreen(
            data: data,
            isPreview: true, 
          );
        },
      ),
    );
  }
}