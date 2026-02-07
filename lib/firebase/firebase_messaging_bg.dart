import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('🔔 BG message: ${message.messageId}');
}

void initFirebaseBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );
}
