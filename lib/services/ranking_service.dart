// lib/services/ranking_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class RankingService {
  static Future<void> resetAllRankings() async {
    final firestore = FirebaseFirestore.instance;
    final usersSnap = await firestore.collection('users').get();
    
    // Creiamo una lista di "missioni" da compiere in contemporanea
    List<Future<void>> missions = usersSnap.docs.map((userDoc) async {
      final batch = firestore.batch();
      
      // Reset punteggi
      batch.update(userDoc.reference, {
        'rankingScore': 50, 'likeCount': 0, 'nopeCount': 0, 'superlikeCount': 0,
      });

      // Peschiamo i documenti da cancellare
      final swipes = await userDoc.reference.collection('swipes').get();
      for (var s in swipes.docs) batch.delete(s.reference);

      final received = await userDoc.reference.collection('received_swipes').get();
      for (var r in received.docs) batch.delete(r.reference);

      // Eseguiamo il batch per questo singolo utente
      return batch.commit();
    }).toList();

    // 🚀 LANCIO IN PARALLELO: Esegue tutte le missioni insieme!
    await Future.wait(missions);
  }

  static Future<void> registerSwipe({
    required String currentUserId,
    required String currentUserName,
    required String targetUserId,
    required String action,
  }) async {
    final firestore = FirebaseFirestore.instance;

    // 1. Puntatore alla "Ricevuta" per evitare voti doppi
    final swipeReceiptRef = firestore
        .collection('users')
        .doc(currentUserId)
        .collection('swipes')
        .doc(targetUserId);

    // Controllo Anti-Spam
    final receiptDoc = await swipeReceiptRef.get();
    if (receiptDoc.exists) {
      debugPrint("ANTI-SPAM: Hai già votato l'utente $targetUserId. Voto ignorato.");
      return;
    }

    // 2. Calcolo dei punti
    int scoreChange = 0;
    if (action == 'like') scoreChange = 5;
    else if (action == 'superlike') scoreChange = 15;
    else if (action == 'nope') scoreChange = -2;

    // 3. Esecuzione in BATCH
    final batch = firestore.batch();

    // Azione A: Crea la ricevuta
    batch.set(swipeReceiptRef, {
      'action': action,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Salviamo chi ci ha votato e cosa ci ha dato nel nostro profilo
    final receivedRef = firestore
          .collection('users')
          .doc(targetUserId)
          .collection('received_swipes')
          .doc(currentUserId);

    batch.set(receivedRef, {
      'fromId': currentUserId,
      'fromName': currentUserName, // 🌟 SALVIAMO IL NOME
      'action': action,
      'points': scoreChange,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Azione B: Aggiorna il punteggio dell'altro utente
    final targetUserRef = firestore.collection('users').doc(targetUserId);
    batch.update(targetUserRef, {
      'rankingScore': FieldValue.increment(scoreChange),
      '${action}Count': FieldValue.increment(1),
    });

    try {
      await batch.commit();
      debugPrint("✅ Voto registrato: $action per $targetUserId ($scoreChange punti)");
    } catch (e) {
      debugPrint("❌ Errore durante il salvataggio del voto: $e");
    }
  }
}