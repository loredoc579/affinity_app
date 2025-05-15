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
/// Salva inoltre nome, email e foto in Firestore e, se non presenti,
/// imposta la foto Facebook come principale tra le 9 immagini in Firestore.
Future<User?> signInWithFacebook() async {
  try {
    final LoginResult result;
    if (kIsWeb) {
      final fbResponse = await _jsFbLogin();
      // Estrai proprietà dal JS object
      final status = js_util.getProperty(fbResponse, 'status') as String;
      final authResp = js_util.getProperty(fbResponse, 'authResponse');
      final accessTokenStr = js_util.getProperty(authResp, 'accessToken') as String;
      final userIdStr = js_util.getProperty(authResp, 'userID') as String;
      final expiration = DateTime.now().add(Duration(days: 60));
      result = LoginResult(
        status: status == 'connected' ? LoginStatus.success : LoginStatus.failed,
        accessToken: AccessToken(
          token: accessTokenStr,
          userId: userIdStr,
          expires: expiration,
          lastRefresh: DateTime.now(),
          applicationId: '',
          grantedPermissions: [],
          declinedPermissions: [],
          isExpired: false,
          dataAccessExpirationTime: expiration,
        ),
      );
    } else {
      result = await FacebookAuth.instance.login();
    }
    if (result.status == LoginStatus.success && result.accessToken != null) {
      final OAuthCredential facebookAuthCredential =
          FacebookAuthProvider.credential(result.accessToken!.token);

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(facebookAuthCredential);
      final user = userCredential.user;

      if (user != null) {
        // Ottengo nome, email e foto da Facebook (alta risoluzione)
        final userData = await FacebookAuth.instance.getUserData(
          fields: "name,email,picture.width(800).height(800)",
        );
        final name = userData['name'] as String?;
        final email = userData['email'] as String?;
        final photoUrl =
            (userData['picture'] as Map)['data']['url'] as String?;

        // Salvo su Firestore
        final docRef =
            FirebaseFirestore.instance.collection('users').doc(user.uid);
        await docRef.set({
          'name': name,
          'email': email,
          'photoUrl': photoUrl,
        }, SetOptions(merge: true));

        // Se non ci sono già foto tra le 9, imposto la FB photo come principale
        final snapshot = await docRef.get();
        final dataMap = snapshot.data() ?? {};
        final existing = dataMap['photoUrls'] as List<dynamic>?;
        final hasImages = existing != null &&
            existing.any((e) => e != null && (e as String).isNotEmpty);
        if (!hasImages) {
          List<String?> nine = List<String?>.filled(9, null);
          if (photoUrl != null && photoUrl.isNotEmpty) {
            nine[0] = photoUrl;
          }
          await docRef.set({'photoUrls': nine}, SetOptions(merge: true));
        }
      }
      return user;
    }
    return null;
  } catch (e) {
    rethrow;
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
