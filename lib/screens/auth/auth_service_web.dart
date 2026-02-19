// lib/screens/auth/auth_service_web.dart

import 'dart:async';
import 'dart:js_interop'; // IL NUOVO STANDARD

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'auth_service_stub.dart';

// --- BINDING JS INTEROP (Mappatura del codice Javascript di Facebook) ---

@JS('FB.login')
external void _fbLoginJS(JSFunction callback, JSObject options);

@JS()
@anonymous
extension type FbLoginOptions._(JSObject _) implements JSObject {
  external factory FbLoginOptions({String scope});
}

@JS()
@anonymous
extension type FbLoginResponse._(JSObject _) implements JSObject {
  external String get status;
  external FbAuthResponse? get authResponse;
}

@JS()
@anonymous
extension type FbAuthResponse._(JSObject _) implements JSObject {
  external String get accessToken;
}

// ------------------------------------------------------------------------

class AuthServiceImpl implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<User?> signInWithFacebook() async {
    // 1) faccio FB.login via JS
    final fbResponse = await _jsFbLogin();
    
    // 2) estraggo token in modo strongly-typed (sicuro)
    if (fbResponse.status != 'connected') return null;
    
    final token = fbResponse.authResponse?.accessToken;
    if (token == null) return null;

    // 3) chiamo Firebase con il token
    return await _signInWithFacebook(token);
  }

  /// JS-interop per FB.login aggiornato a Dart 3
  Future<FbLoginResponse> _jsFbLogin() {
    final completer = Completer<FbLoginResponse>();
    
    // Creiamo la callback convertendola in una JSFunction tramite .toJS
    final callback = ((FbLoginResponse response) {
      completer.complete(response);
    }).toJS;

    // Opzioni di login tipizzate
    final options = FbLoginOptions(scope: 'public_profile,email');

    // Chiamata diretta alla funzione Javascript
    _fbLoginJS(callback, options);
    
    return completer.future;
  }

  /// Converte il token FB in credenziali Firebase e aggiorna Firestore
  Future<User?> _signInWithFacebook(String token) async {
    final credential = FacebookAuthProvider.credential(token);
    final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
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
  
  @override
  Future<void> signOut() async {
    final user  = _auth.currentUser;
    final token = await _fcm.getToken();

    if (user != null && token != null) {
      // 1) cancella il mapping token→uid su Firestore
      await _db.collection('tokens').doc(token).delete();
      // 2) cancella il token lato FCM
      await _fcm.deleteToken();
    }
    // 3) esegui il logout
    await _auth.signOut();
  }
}

AuthService getAuthService() => AuthServiceImpl();