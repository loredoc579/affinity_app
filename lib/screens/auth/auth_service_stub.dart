// lib/screens/auth/auth_service_stub.dart

import 'package:firebase_auth/firebase_auth.dart';

/// L’interfaccia AuthService ora restituisce sempre un [User?].
abstract class AuthService {
  /// Ritorna l'utente autenticato, o null.
  Future<User?> signInWithFacebook();
}

/// Il “fallback” se la piattaforma non è web né mobile.
AuthService getAuthService() {
  throw UnsupportedError('AuthService non implementato per questa piattaforma');
}
