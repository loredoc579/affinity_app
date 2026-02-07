import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

Future<void> initMobileNotifications() async {
  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission();

  debugPrint('🔔 Mobile notifications initialized');
}
