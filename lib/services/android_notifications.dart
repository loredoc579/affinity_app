import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../screens/chat_screen.dart'; 

class AndroidNotifications {
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel', 
    'Notifiche Importanti', 
    description: 'Canale per notifiche importanti',
    importance: Importance.high,
  );

  static Future<void> init(
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    if (kIsWeb || !Platform.isAndroid) return;

    final status = await Permission.notification.request();
    debugPrint('🔔 Android notification permission: $status');

    const androidSettings = AndroidInitializationSettings('ic_notification');
    const initSettings = InitializationSettings(android: androidSettings);

    // CORREZIONE 1: "settings:" è un parametro nominato (richiesto nella v20+)
    await _flutterLocalNotificationsPlugin.initialize(
      settings: initSettings, 
      onDidReceiveNotificationResponse: (NotificationResponse response) {
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

    final androidImpl =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(_channel);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📩 FG message: ${message.messageId}');

      // CORREZIONE 2: Tutti i parametri di "show" ora sono nominati (id:, title:, body:, notificationDetails:)
      _flutterLocalNotificationsPlugin.show(
        id: message.hashCode,
        title: message.notification?.title ?? 'Nuovo Messaggio',
        body: message.notification?.body ?? '',
        notificationDetails: NotificationDetails(
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

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('📩 Notification opened from BACKGROUND');
      _handleNavigation(navigatorKey, message.data);
    });

    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('📩 Notification opened from TERMINATED');
      
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 300));
        _handleNavigation(navigatorKey, initialMessage.data);
      });
    }

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final String? token = await FirebaseMessaging.instance.getToken();

        if (token != null) {
          await FirebaseFirestore.instance.collection('tokens').doc(token).set({
            'uid': uid,
            'platform': 'android',
            'type': 'fcm',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          await FirebaseFirestore.instance.collection('tokens').doc(newToken).set({
            'uid': uid,
            'platform': 'android',
            'type': 'fcm',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        });
      }
    } catch (e) {
      debugPrint('❌ Errore salvataggio token FCM: $e');
    }
  }

  static Future<void> _handleNavigation(
    GlobalKey<NavigatorState> navigatorKey,
    Map<dynamic, dynamic> data,
  ) async {
    final type = data['type'];
    final chatId = data['chatId'];

    if ((type == 'new_chat' || type == 'new_message') && chatId != null) {
      
      final context = navigatorKey.currentContext;
      if (context == null) return;

      // RECUPERIAMO TUTTO DIRETTAMENTE DALLA NOTIFICA, ZERO TEMPO DI ATTESA!
      final otherUserId = data['otherUserId'] ?? '';
      final otherUserName = data['otherUserName'] ?? 'Utente';
      final otherUserPhotoUrl = data['otherUserPhotoUrl'] ?? '';

      if (otherUserId.isEmpty) return; // Se per caso manca l'id, blocchiamo

      bool isAlreadyInChat = false;
      Navigator.popUntil(context, (route) {
        if (route.settings.name == '/chat_$chatId') { 
          isAlreadyInChat = true;
        }
        return true;
      });

      if (!isAlreadyInChat) {
        Navigator.of(context).push(
          MaterialPageRoute(
            settings: RouteSettings(name: '/chat_$chatId'),
            builder: (_) => ChatScreen(
              chatId: chatId,
              otherUserId: otherUserId,
              otherUserName: otherUserName,
              otherUserPhotoUrl: otherUserPhotoUrl,
            ),
          ),
        );
      }
    }
  }
}
