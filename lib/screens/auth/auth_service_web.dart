// lib/screens/auth/auth_service_web.dart

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service_stub.dart';

class AuthServiceWeb implements AuthService {
  @override
  Future<User?> signInWithFacebook() async {
    // 1) faccio FB.login via JS
    final fbResponse = await _jsFbLogin();
    // 2) estraggo token
    final status = js_util.getProperty(fbResponse, 'status') as String;
    if (status != 'connected') return null;
    final authResp = js_util.getProperty(fbResponse, 'authResponse');
    final token = js_util.getProperty(authResp, 'accessToken') as String;
    // 3) chiamo Firebase con il token
    return await _signInWithFacebook(token);
  }

  /// JS-interop per FB.login
  Future<dynamic> _jsFbLogin() {
    final completer = Completer<dynamic>();
    final fb = js_util.getProperty(html.window, 'FB');
    js_util.callMethod(fb, 'login', <Object>[
      js_util.allowInterop((resp) => completer.complete(resp)),
      js_util.jsify({'scope': 'public_profile,email'}),
    ]);
    return completer.future;
  }

  /// Converte il token FB in credenziali Firebase e aggiorna Firestore
  Future<User?> _signInWithFacebook(String token) async {
    final credential = FacebookAuthProvider.credential(token);
    final userCred =
        await FirebaseAuth.instance.signInWithCredential(credential);
    final user = userCred.user;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
            {
              'lastLogin': DateTime.now().toIso8601String(),
            },
            SetOptions(merge: true),
          );
    }
    return user;
  }
}

AuthService getAuthService() => AuthServiceWeb();
