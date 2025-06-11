// lib/screens/auth/auth_service_mobile.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import 'auth_service_stub.dart';

class AuthServiceImpl implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<User?> signInWithFacebook() async {
    // 1) Login Facebook via plugin mobile
    final result = await FacebookAuth.instance.login(
      permissions: ['public_profile'],
      loginBehavior: LoginBehavior.dialogOnly,   
    );
    print('LoginStatus: ${result.status}');
    print('Message:    ${result.message}');
    print('AccessTok:  ${result.accessToken}');
    if (result.status != LoginStatus.success || result.accessToken == null) {
      return null;
    }

    // 2) Sign in su Firebase
    final credential = FacebookAuthProvider.credential(result.accessToken!.tokenString);
    final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
    final user = userCred.user;

    // 3) Firestore e salvataggio dati come prima
    if (user != null) {
      final userData = await FacebookAuth.instance.getUserData(
        fields: "name,email,picture.width(800).height(800)",
      );
      final name = userData['name'] as String?;
      final email = userData['email'] as String?;
      final photoUrl = (userData['picture'] as Map)['data']['url'] as String?;

      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await docRef.set({
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
      }, SetOptions(merge: true));

      // gestione photoUrls come nel tuo snippet originale
      final snapshot = await docRef.get();
      final dataMap = snapshot.data() ?? {};
      final existing = dataMap['photoUrls'] as List<dynamic>?;
      final hasImages = existing != null &&
          existing.any((e) => e != null && (e as String).isNotEmpty);
      if (!hasImages && photoUrl != null && photoUrl.isNotEmpty) {
        List<String?> nine = List<String?>.filled(9, null);
        nine[0] = photoUrl;
        await docRef.set({'photoUrls': nine}, SetOptions(merge: true));
      }
    }

    return user;
  }

  @override
  Future<void> signOut() async {
    final user  = _auth.currentUser;
    final token = await _fcm.getToken();
    if (user != null && token != null) {
      await _db.collection('tokens').doc(token).delete();
      await _fcm.deleteToken();
    }
    return _auth.signOut();
  }
}

AuthService getAuthService() => AuthServiceImpl();
