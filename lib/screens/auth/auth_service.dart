// auth_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <-- Firestore import

// Web interop imports
import 'dart:html' as html;
import 'dart:js_util' as js_util;



/// Effettua il login via Facebook e restituisce l'utente Firebase autenticato.
/// Salva inoltre nome, email e foto in Firestore alla raccolta `users`.
Future<User?> signInWithFacebook() async {
  if (kIsWeb) {
    final resp = await _jsFbLogin();
    final status = js_util.getProperty(resp, 'status') as String;
    if (status != 'connected') {
      throw FirebaseAuthException(
        code: 'ERROR_FACEBOOK_LOGIN_FAILED',
        message: 'Stato Facebook non connesso: $status',
      );
    }

    final authResponse = js_util.getProperty(resp, 'authResponse');
    final token = js_util.getProperty(authResponse, 'accessToken') as String;
    final cred = FacebookAuthProvider.credential(token);
    final userCred = await FirebaseAuth.instance.signInWithCredential(cred);

    // Ottieni dati profilo Facebook
    final userData = await FacebookAuth.instance.getUserData(
      fields: 'email,name,picture.width(512)',
    );

    print('fb user:');
    print(userData);

    final name = userData['name'] as String?;
    final email = userData['email'] as String?;
    final photoUrl = (userData['picture']?['data']?['url']) as String?;

    // Salva o aggiorna il documento utente in Firestore
    await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set(
      {
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'lastLogin': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    print("▶️ Utente salvato in Firestore: ${userCred.user!.uid}");
    return userCred.user;

  } else {
    final result = await FacebookAuth.instance.login(
      permissions: ['email', 'public_profile'],
    );
    if (result.status != LoginStatus.success) {
      if (result.status == LoginStatus.cancelled) {
        throw FirebaseAuthException(
          code: 'ERROR_ABORTED_BY_USER',
          message: 'Login annullato dall’utente',
        );
      }
      throw FirebaseAuthException(
        code: 'ERROR_FACEBOOK_LOGIN_FAILED',
        message: result.message,
      );
    }
    final cred = FacebookAuthProvider.credential(
      result.accessToken!.token,
    );
    final userCred = await FirebaseAuth.instance.signInWithCredential(cred);

    // Ottieni dati profilo
    final userData = await FacebookAuth.instance.getUserData(
      fields: 'email,name,picture.width(512)',
    );
    final name = userData['name'] as String?;
    final email = userData['email'] as String?;
    final photoUrl = (userData['picture']?['data']?['url']) as String?;

    await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set(
      {
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'lastLogin': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    return userCred.user;
  }
}

/// Helper per Web: avvolge FB.login in un Future
Future<dynamic> _jsFbLogin() {
  final completer = Completer<dynamic>();
  final fb = js_util.getProperty(html.window, 'FB');
  js_util.callMethod(
    fb,
    'login',
    <Object>[
      js_util.allowInterop((response) => completer.complete(response)),
      js_util.jsify({'scope': 'public_profile'}),
    ],
  );
  return completer.future;
}
