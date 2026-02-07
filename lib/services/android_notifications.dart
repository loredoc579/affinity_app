import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Gestisce TUTTO ciò che riguarda le notifiche su Android.
/// - richiesta permessi
/// - inizializzazione plugin
/// - foreground notifications
/// - tap su notifica
///
/// ⚠️ NON usare nel main.dart
/// ✔️ chiamare da HomeScreen.initState()
class AndroidNotifications {
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'high_importance_channel',
    'Notifiche Importanti',
    description: 'Canale per notifiche importanti',
    importance: Importance.high,
  );

  /// Inizializza notifiche Android
  static Future<void> init(
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    // Web / iOS: esci subito
    if (kIsWeb || !Platform.isAndroid) return;

    // 1️⃣ Permessi
    final status = await Permission.notification.request();
    debugPrint('🔔 Android notification permission: $status');

    // 2️⃣ Init local notifications
    const androidSettings =
        AndroidInitializationSettings('ic_notification');

    final initSettings =
        const InitializationSettings(android: androidSettings);

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null) return;

        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          _handleNavigation(navigatorKey, data);
        } catch (e) {
          debugPrint('❌ Notification payload error: $e');
        }
      },
    );

    // 3️⃣ Crea canale (Android 8+)
    final androidImpl =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(_channel);
    }

    // 4️⃣ Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📩 FG message: ${message.messageId}');

      _flutterLocalNotificationsPlugin.show(
        message.hashCode,
        message.notification?.title,
        message.notification?.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_notification',
          ),
        ),
        payload: jsonEncode(message.data),
      );
    });

    // 5️⃣ Tap da background / terminated
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('📩 Notification opened');
      _handleNavigation(navigatorKey, message.data);
    });
  }

  /// Gestisce la navigazione in base al payload
  static void _handleNavigation(
    GlobalKey<NavigatorState> navigatorKey,
    Map<String, dynamic> data,
  ) {
    if (data['type'] == 'new_chat' && data['chatId'] != null) {
      navigatorKey.currentState?.pushNamed(
        '/chat',
        arguments: {
          'chatId': data['chatId'],
        },
      );
    }
  }
}
