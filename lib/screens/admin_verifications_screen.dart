import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../widgets/heart_progress_indicator.dart';

class AdminVerificationsScreen extends StatelessWidget {
  const AdminVerificationsScreen({Key? key}) : super(key: key);

  Future<void> _approveUser(BuildContext context, String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'isVerified': true,
      'verificationStatus': 'approved',
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Utente Approvato!'), backgroundColor: Colors.green));
    }
  }

  Future<void> _rejectUser(BuildContext context, String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'isVerified': false,
      'verificationStatus': FieldValue.delete(), 
      'verificationImageUrl': FieldValue.delete(), 
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Utente Rifiutato.'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin: Verifiche in Attesa', style: TextStyle(color: Colors.blue)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.blue),
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').where('verificationStatus', isEqualTo: 'pending').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: HeartProgressIndicator(size: 40));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("Nessuna verifica in attesa! 🎉", style: TextStyle(fontSize: 18, color: Colors.grey)),
            );
          }

          final pendingUsers = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pendingUsers.length,
            itemBuilder: (context, index) {
              final userDoc = pendingUsers[index];
              final data = userDoc.data() as Map<String, dynamic>;
              
              final String name = data['name'] ?? 'Sconosciuto';
              final String selfieUrl = data['verificationImageUrl'] ?? '';
              
              // Recuperiamo TUTTE le foto del profilo
              final List<dynamic> photos = data['photoUrls'] ?? [];

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text("Richiesta da: $name", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      
                      // --- 1. SELFIE APPENA SCATTATO ---
                      const Text("Selfie di Verifica:", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: selfieUrl.isNotEmpty 
                          ? CachedNetworkImage(imageUrl: selfieUrl, height: 300, fit: BoxFit.cover)
                          : Container(height: 300, color: Colors.grey.shade300, child: const Icon(Icons.camera_alt, size: 50)),
                      ),
                      
                      const SizedBox(height: 20),

                      // --- 2. GALLERIA FOTO PROFILO (SCORREVOLE) ---
                      const Text("Foto caricate sul profilo:", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 140, // Altezza fissa per la riga scorrevole
                        child: photos.isNotEmpty
                            ? ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: photos.length,
                                itemBuilder: (context, photoIndex) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 12.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CachedNetworkImage(
                                        imageUrl: photos[photoIndex].toString(),
                                        width: 100, // Larghezza singola foto
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                width: 100,
                                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.person_off),
                              ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // --- BOTTONI APPROVA/RIFIUTA ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _rejectUser(context, userDoc.id),
                            icon: const Icon(Icons.close, color: Colors.red),
                            label: const Text('Rifiuta', style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _approveUser(context, userDoc.id),
                            icon: const Icon(Icons.check, color: Colors.white),
                            label: const Text('Approva', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}