// lib/services/ranking_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class RankingService {
  static Future<void> registerSwipe({
    required String currentUserId,
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