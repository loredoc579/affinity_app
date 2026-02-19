import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class PresenceService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  /// Inizializza l'ascolto della connessione (da chiamare all'avvio)
  Future<void> init() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final myStatusRef = _db.ref('status/$uid');
    final myConnectionsRef = myStatusRef.child('connections');
    final myLastChangedRef = myStatusRef.child('last_changed');

    // Ascoltiamo il nodo speciale di Firebase che ci dice se c'è connessione fisica col server
    _db.ref('.info/connected').onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;
      
      if (connected) {
        // Generiamo una "connessione" univoca per questa sessione
        final con = myConnectionsRef.push();

        // 1. Diciamo al server cosa fare se l'app crasha o perde il segnale all'improvviso
        con.onDisconnect().remove();
        myLastChangedRef.onDisconnect().set(ServerValue.timestamp);

        // 2. Impostiamo lo stato come online ADESSO (scrivendo true, non una mappa!)
        con.set(true);
        myLastChangedRef.set(ServerValue.timestamp);
      }
    });
  }

  /// Aggiorna manualmente lo stato (es. per il logout)
  Future<void> updatePresence({required bool online}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final myStatusRef = _db.ref('status/${user.uid}');
    
    try {
      if (!online) {
         // Se andiamo offline, RIMUOVIAMO tutte le connessioni per svuotare il nodo
         await myStatusRef.child('connections').remove();
         await myStatusRef.child('last_changed').set(ServerValue.timestamp);
      }
    } catch (e) {
      debugPrint('⚠️ Errore durante updatePresence: $e');
    }
  }

  /// Alias per comodità
  Future<void> goOffline() async {
    await updatePresence(online: false);
  }
}