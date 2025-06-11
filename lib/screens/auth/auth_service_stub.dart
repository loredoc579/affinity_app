// auth_service_stub.dart

import 'package:firebase_auth/firebase_auth.dart';
// Conditional import: solo una implementazione (mobile o web) sarà inclusa
import 'auth_service_mobile.dart'
  if (dart.library.html) 'auth_service_web.dart';

/// Interfaccia comune a tutte le implementazioni
abstract class AuthService {
  Future<User?> signInWithFacebook();
  Future<void> signOut();
}

/// Restituisce l'implementazione concreta a runtime
AuthService getAuthService() => AuthServiceImpl();
