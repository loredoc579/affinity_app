import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({Key? key}) : super(key: key);

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool isPaused = false;

  @override
  void initState() {
    super.initState();
    _loadAccountStatus();
  }

  // Leggiamo se l'utente è in modalità "Pausa"
  Future<void> _loadAccountStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists) {
      setState(() {
        isPaused = doc.data()?['isPaused'] ?? false;
      });
    }
  }

  // Salviamo il nuovo stato su Firebase
  Future<void> _togglePause(bool value) async {
    setState(() => isPaused = value);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'isPaused': value});
    }
  }

  // --- FUNZIONE PER ELIMINARE L'ACCOUNT ---
  Future<void> _deleteAccount() async {
    // 1. Chiediamo conferma all'utente col classico popup di sicurezza
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Elimina Account"),
        content: const Text("Sei sicuro di voler eliminare definitivamente il tuo account? Tutti i tuoi match, messaggi e foto andranno persi. L'azione non può essere annullata."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annulla", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Elimina Definitivamente", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    // Se clicca "Annulla" o chiude il popup, ci fermiamo qui
    if (confirm != true) return;

    try {
      // Mostriamo la rotellina di caricamento
      showDialog(
        context: context, 
        barrierDismissible: false, 
        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.red))
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final uid = user.uid;
        
        // 2. Cancelliamo il documento utente da Firestore
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        
        // 3. Cancelliamo l'utente da Firebase Auth (Questo lo sbatte fuori)
        await user.delete();

        // 4. Chiudiamo il caricamento e lo rimandiamo alla schermata di Login
        if (mounted) {
          Navigator.pop(context); // Chiude la rotellina
          // ATTENZIONE: Sostituisci '/login' con il nome della tua rotta di login iniziale
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false); 
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Chiude la rotellina in caso di errore
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  // --- FUNZIONE PER RICHIEDERE I DATI (GDPR) ---
  Future<void> _requestMyData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Creiamo un documento in una nuova collezione "data_requests"
      await FirebaseFirestore.instance.collection('data_requests').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email ?? 'Email non disponibile',
        'requestDate': FieldValue.serverTimestamp(),
        'status': 'pending', // tu poi potrai metterlo a 'completato' dal DB
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Richiesta ricevuta! Ti invieremo un'email con i tuoi dati entro 30 giorni."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Errore durante la richiesta: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Account", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("VISIBILITÀ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          SwitchListTile(
            activeColor: Colors.pink,
            title: const Text("Metti in pausa il mio account"),
            subtitle: const Text("Non verrai mostrato a nuove persone, ma potrai continuare a chattare con i tuoi match attuali."),
            value: isPaused,
            onChanged: _togglePause,
          ),
          
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("GESTIONE DATI", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text("Richiedi i miei dati"),
            subtitle: const Text("Ricevi una copia dei tuoi dati personali via email."),
            onTap: _requestMyData,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("Elimina Account", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}