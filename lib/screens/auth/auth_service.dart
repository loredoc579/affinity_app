// lib/screens/auth/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';

// Importa lo stub per avere in-scope getAuthService() quando compili
import 'auth_service_stub.dart' show getAuthService;

// Re-export condizionale delle implementazioni
export 'auth_service_stub.dart'
  if (dart.library.html) 'auth_service_web.dart'
  if (dart.library.io)   'auth_service_mobile.dart';

/// Compatibilità col vecchio codice:
/// chiama internamente [getAuthService().login()]
Future<User?> signInWithFacebook() => getAuthService().signInWithFacebook();
