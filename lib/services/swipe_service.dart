// swipe_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SwipeService {
  /// Invia un "like" a un altro utente salvandolo in Firestore
  Future<void> sendLike(String toUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('Utente non autenticato');
    }
    await FirebaseFirestore.instance
      .collection('swipes')
      .add({
        'from': currentUser.uid,
        'to': toUserId,
        'type': 'like',
        'timestamp': FieldValue.serverTimestamp(),
      });
  }

  Future<void> sendNope(String toUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('Utente non autenticato');
    }
    await FirebaseFirestore.instance
      .collection('swipes')
      .add({
        'from': currentUser.uid,
        'to': toUserId,
        'type': 'nope',
        'timestamp': FieldValue.serverTimestamp(),
      });
  }

  Future<void> sendSuperlike(String toUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('Utente non autenticato');
    }
    await FirebaseFirestore.instance
      .collection('swipes')
      .add({
        'from': currentUser.uid,
        'to': toUserId,
        'type': 'superlike',
        'timestamp': FieldValue.serverTimestamp(),
      });
  }
}
