import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminDataRequestsScreen extends StatelessWidget {
  const AdminDataRequestsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin: Richieste GDPR', style: TextStyle(color: Colors.orange)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.orange),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('data_requests')
            .orderBy('requestDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final requests = snapshot.data!.docs;
          if (requests.isEmpty) {
            return const Center(child: Text("Nessuna richiesta dati presente."));
          }

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              final data = req.data() as Map<String, dynamic>;
              final date = (data['requestDate'] as Timestamp?)?.toDate();
              final String formattedDate = date != null 
                  ? DateFormat('dd/MM/yyyy HH:mm').format(date) 
                  : 'Data ignota';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.email_outlined, color: Colors.orange),
                  title: Text(data['email'] ?? 'No email'),
                  subtitle: Text('Richiesto il: $formattedDate\nUID: ${req.id}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_sweep, color: Colors.red),
                    onPressed: () => _confirmDelete(context, req.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Chiudi richiesta"),
        content: const Text("Hai già inviato i dati all'utente? Rimuovendo la richiesta la segnerai come evasa."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annulla")),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('data_requests').doc(docId).delete();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text("Evasa / Elimina"),
          ),
        ],
      ),
    );
  }
}