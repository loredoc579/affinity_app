import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfilePreviewScreen extends StatelessWidget {
  final String uid;

  const ProfilePreviewScreen({Key? key, required this.uid}) : super(key: key);

  // Widget di supporto per disegnare le foto con le giuste proporzioni (stile ritratto)
  Widget _buildPhoto(String url, BuildContext context) {
    return SizedBox(
      width: double.infinity,
      // Usiamo una proporzione 4:5 molto usata per i ritratti mobile
      height: MediaQuery.of(context).size.width * 1.25, 
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey.shade200,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey.shade300,
          child: const Center(child: Icon(Icons.error, color: Colors.grey)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true, // Permette alla prima foto di finire sotto la barra di stato
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Diamo un'ombra all'icona "Indietro" per farla risaltare anche su foto chiare
        iconTheme: const IconThemeData(
          color: Colors.white,
          shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Profilo non trovato.'));
          }

          // Estrazione dati
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String name = data['name'] ?? 'Utente';
          final String age = data['age']?.toString() ?? '';
          final String bio = data['bio'] ?? '';
          final String jobTitle = data['jobTitle'] ?? '';
          final String city = (data['location'] as Map<String, dynamic>?)?['city'] ?? 'Città sconosciuta';
          
          final rawHobbies = data['hobbies'];
          List<String> hobbies = [];
          if (rawHobbies is List) {
            hobbies = rawHobbies.map((e) => e.toString()).toList();
          } else if (rawHobbies is String && rawHobbies.isNotEmpty) {
            hobbies = rawHobbies.split(', ');
          }

          final rawPhotos = data['photoUrls'] as List<dynamic>? ?? [];
          final List<String> validPhotos = rawPhotos
              .where((url) => url != null && url.toString().isNotEmpty)
              .map((url) => url.toString())
              .toList();
          
          if (validPhotos.isEmpty && data['photoUrl'] != null && data['photoUrl'] != '') {
            validPhotos.add(data['photoUrl']);
          }

          // COSTRUZIONE DINAMICA DELLA LISTA VERTICALE
          List<Widget> feedWidgets = [];

          // 1. FOTO PRINCIPALE (Top)
          if (validPhotos.isNotEmpty) {
            feedWidgets.add(_buildPhoto(validPhotos[0], context));
          } else {
            feedWidgets.add(
              Container(
                height: MediaQuery.of(context).size.width * 1.25,
                color: Colors.grey.shade300,
                child: const Icon(Icons.person, size: 120, color: Colors.white),
              )
            );
          }

          // 2. BLOCCO INTESTAZIONE (Nome, Età, Lavoro, Città)
          feedWidgets.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    age.isNotEmpty ? '$name, $age' : name,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 12),
                  if (jobTitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.work, size: 20, color: Colors.grey.shade600),
                          const SizedBox(width: 10),
                          Text(jobTitle, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 20, color: Colors.grey.shade600),
                      const SizedBox(width: 10),
                      Text(city, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                    ],
                  ),
                ],
              ),
            ),
          );

          // 3. FOTO SECONDARIA (Se esiste)
          if (validPhotos.length > 1) {
            feedWidgets.add(_buildPhoto(validPhotos[1], context));
          }

          // 4. BLOCCO BIO & HOBBIES
          if (bio.isNotEmpty || hobbies.isNotEmpty) {
            feedWidgets.add(
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (bio.isNotEmpty) ...[
                      const Text('Chi sono', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        bio, 
                        style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87)
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (hobbies.isNotEmpty) ...[
                      const Text('Le mie passioni', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 12,
                        children: hobbies.map((h) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.pink.shade200),
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.pink.shade50.withOpacity(0.5),
                          ),
                          child: Text(h, style: TextStyle(color: Colors.pink.shade700, fontWeight: FontWeight.w500)),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          // 5. RESTANTI FOTO (Cascata finale)
          for (int i = 2; i < validPhotos.length; i++) {
            feedWidgets.add(
              Padding(
                // Un piccolo margine tra le foto finali per far capire che sono immagini distinte
                padding: const EdgeInsets.only(bottom: 4.0), 
                child: _buildPhoto(validPhotos[i], context),
              ),
            );
          }

          // Spazio finale bianco per poter scorrere bene fino in fondo
          feedWidgets.add(const SizedBox(height: 60));

          // Inseriamo tutto nello scroll
          return SingleChildScrollView(
            // "Bouncing" dà quell'effetto elastico tipico di iOS/Tinder a fine pagina
            physics: const BouncingScrollPhysics(), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: feedWidgets,
            ),
          );
        },
      ),
    );
  }
}