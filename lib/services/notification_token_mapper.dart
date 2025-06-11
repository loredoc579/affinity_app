import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationTokenMapper {
  final _auth = FirebaseAuth.instance;
  final _fcm  = FirebaseMessaging.instance;
  final _db   = FirebaseFirestore.instance;

  void initialize() {
    // ascolta login/logout
    _auth.authStateChanges().listen(_handleAuthChange);
    // ascolta refresh del token
    _fcm.onTokenRefresh.listen(_handleTokenRefresh);
  }

  Future<void> _handleAuthChange(User? user) async {
    final token = await _fcm.getToken();
    if (token == null) return;
    final doc = _db.collection('tokens').doc(token);
    if (user != null) {
      await doc.set({
        'uid': user.uid,
        'type': 'fcm',                            // <— campo “tipo”
        'platform': Platform.operatingSystem,     // esempio: 'android' o 'ios'
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _fcm.deleteToken();
    }
  }

  Future<void> _handleTokenRefresh(String newToken) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _db.collection('tokens').doc(newToken).set({
        'uid': user.uid,
        'type': 'fcm',                            // <— campo “tipo”
        'platform': Platform.operatingSystem,     // esempio: 'android' o 'ios'
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}