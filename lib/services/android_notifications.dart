import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../screens/chat_screen.dart'; // Per poter aprire la schermata

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

    // 6️⃣ NOVITÀ: Genera il token e salvalo nel database per i nuovi utenti
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final String? token = await FirebaseMessaging.instance.getToken();
        
        if (token != null) {
          debugPrint('📲 Token generato: $token');
          await FirebaseFirestore.instance.collection('tokens').doc(token).set({
            'uid': uid,
            'platform': 'android',
            'type': 'fcm',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        // Se il token dovesse cambiare in futuro, lo aggiorniamo
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

/// Gestisce la navigazione in base al payload
  static Future<void> _handleNavigation(
    GlobalKey<NavigatorState> navigatorKey,
    Map<String, dynamic> data,
  ) async {
    final type = data['type'];
    final chatId = data['chatId'];

    // Accettiamo sia i nuovi match che i nuovi messaggi!
    if ((type == 'new_chat' || type == 'new_message') && chatId != null) {
      
      final context = navigatorKey.currentContext;
      if (context == null) return;

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      try {
        // 1. Chiediamo al volo a Firebase: "Chi c'è in questa chat?"
        final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
        if (!chatDoc.exists) return;

        final participants = List<String>.from(chatDoc.data()?['participants'] ?? []);
        final otherUserId = participants.firstWhere((id) => id != currentUser.uid, orElse: () => '');
        if (otherUserId.isEmpty) return;

        // 2. Chiediamo: "Come si chiama e che foto ha l'altro utente?"
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(otherUserId).get();
        final userData = userDoc.data() ?? {};
        final name = userData['name'] as String? ?? 'Utente';
        
        final rawPhotos = userData['photoUrls'] as List<dynamic>? ?? [];
        final validPhotos = rawPhotos
            .where((url) => url != null && url.toString().isNotEmpty)
            .map((url) => url.toString())
            .toList();
        final photoUrl = validPhotos.isNotEmpty ? validPhotos.first : '';

        // 3. BOOM! Entriamo direttamente nella chat con tutti i dati corretti!
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
              otherUserId: otherUserId,
              otherUserName: name,
              otherUserPhotoUrl: photoUrl,
            ),
          ),
        );
      } catch (e) {
        debugPrint('❌ Errore durante l\'apertura della chat da notifica: $e');
      }
    }
  }
}
