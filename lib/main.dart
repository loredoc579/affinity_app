import 'dart:convert';

import 'package:affinity_app/screens/chat_list_screen.dart';
import 'package:affinity_app/widgets/heart_progress_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';             
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'repository/swipe_repository.dart';
import 'screens/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/auth/facebook_init.dart';
import 'screens/chat_screen.dart';  

import 'models/filter_model.dart';                     

import 'services/notification_token_mapper.dart';
import 'services/presence_service.dart';
import 'services/swipe_service.dart';
import 'bloc/swipe_bloc.dart';
import 'dart:io' show Platform;

// 1) chiave globale per il Navigator
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 2) handler per il tap sulla notifica
void _handleMessage(RemoteMessage? msg) {
  final data = msg?.data;
  if (data != null && data['type'] == 'new_chat' && data['chatId'] != null) {
    debugPrint('🔔 tap sulla notifica BG, contenuto: ${msg?.data}');

    navigatorKey.currentState
        ?.pushNamed('/chat', arguments: data['chatId']);
  }
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// è richiamato quando la notifica arriva mentre l’app è chiusa/background
// 1) Funzione top-level, non in una classe
// 2) Annotata per dire al tree-shaker di non eliminarla
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await initializeFirebase();
  // qui puoi loggare o salvare il payload per statistiche
  debugPrint('✅ BG message received: ${message.messageId}');
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🔄 main(): WidgetsBinding initialized');

  try {
    debugPrint('🔄 main(): Trying Firebase.initializeApp()');
    await initializeFirebase();
    debugPrint('✅ main(): Firebase.initializeApp() completed');
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      debugPrint('⚠️ Firebase already initialized, skipping');
    } else {
      rethrow;
    }
  }

  await setupFacebook(); // inizializza fbInit qui

  NotificationTokenMapper().initialize();

  await Firebase.initializeApp();

    // ④ Registra l’handler in background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ① Inizializza Firebase Messaging Android Notifications
  if (Platform.isAndroid) {
      await initializeFBAndroidNotification(); 
  }

  // inizializza la presenza **una sola volta** subito dopo il login
  FirebaseAuth.instance
    .authStateChanges()
    .firstWhere((user) => user != null)
    .then((_) => PresenceService().init());
  
  runApp(
    // 1) Prima i Bloc
    MultiBlocProvider(
      providers: [
        BlocProvider<SwipeBloc>(
          create: (_) =>
            // inietta subito l'evento di caricamento
            SwipeBloc(
            SwipeRepository(FirebaseFirestore.instance),
              FirebaseAuth.instance,  
              SwipeService()
          ), // carica la lista vuota inizialmente
        ),
        // altri BlocProvider se ti servono...
      ],
      child: 
      // 2) Poi i ChangeNotifier
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FilterModel>(
            create: (_) => FilterModel(),
          ),
          // altri ChangeNotifierProvider...
        ],
        child: const AffinityApp(),
      ),
    ),
  );
}

Future<void> initializeFBAndroidNotification() async {
  debugPrint('🔄 main(): Initializing Firebase Messaging for Android');
  
  // Solo Android 13+ richiede esplicitamente la permission
  var status = await ph.Permission.notification.status;
  if (status.isDenied) {
    status = await ph.Permission.notification.request();
  }
  
  debugPrint('🔄 Notification permission status: $status');
  
  const channel = AndroidNotificationChannel(
    'high_importance_channel', // deve combaciare con il meta-data
    'Notifiche Importanti',
    description: 'Canale per notifiche importanti',
    importance: Importance.high,
  );
  
  await flutterLocalNotificationsPlugin
    .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
    ?.createNotificationChannel(channel);
  
  const defaultIcon = 'ic_notification';
  const androidInitSettings =
    AndroidInitializationSettings(defaultIcon);
  
  final initSettings = InitializationSettings(
    android: androidInitSettings,
    // iOS: DarwinInitializationSettings(), 
    // macOS: DarwinInitializationSettings(),
  );
  
  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse resp) {
      final payload = resp.payload;

      debugPrint('🔔 Notifica FG tap: ${resp.id}, payload: $payload');
      if (payload == null) return;
      try {
        final data = json.decode(payload) as Map<String, dynamic>;
        if (data['type'] == 'new_chat' && data['chatId'] != null) {
          navigatorKey.currentState
              ?.pushNamed('/chat', arguments: data['chatId']);
        }
      } catch (e) {
        debugPrint('❌ Errore decoding payload: $e');
      }
    },
  );
  
  // ⑤ Listener foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
    debugPrint('✅ FG message received: ${msg.messageId}');
  
    flutterLocalNotificationsPlugin.show(
      msg.notification.hashCode,
      msg.notification?.title,
      msg.notification?.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id, 
          channel.name,
          channelDescription: channel.description,
          icon: defaultIcon,      // la tua icona bianca
          importance: Importance.max,    // ← massima importanza
          priority: Priority.high,       // ← massima priorità
          playSound: true,               // ← riproduci suono
        ),
      ),
      payload: json.encode({
        'type':   'new_chat',
        'chatId': msg.data['chatId'],
      }),
    );
  });   
  
  // ⑥ Listener per tap sulla notifica (background e terminated)
  FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  final initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();
  _handleMessage(initialMessage); 
}

Future<void> initializeFirebase() async {
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCKYB6X4-8S-pI3Xjec26badT5BxI4LQ38",
      authDomain: "affinity-9e25e.firebaseapp.com",
      projectId: "affinity-9e25e",
      storageBucket: "affinity-9e25e.firebasestorage.app",
      messagingSenderId: "767355252810",
      appId: "1:767355252810:web:11cf87c4904dd764c9f6b3"
    ),
  );
}

class AffinityApp extends StatelessWidget {
  const AffinityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,   
      title: 'Affinity',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Sans',
      ),
      routes: {
        '/signup': (context) => SignupScreen(),
        '/login': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(),
        '/profile': (context) => ProfileScreen(),
        '/chat': (context) {
          // Estrae la mappa di argomenti passati
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return ChatScreen(
            chatId: args['chatId'] as String,
            otherUserId: args['otherUserId'] as String,
            otherUserName: args['otherUserName'] as String,
            otherUserPhotoUrl: args['otherUserPhotoUrl'] as String,
          );
        },
        '/chats': (_) => ChatListScreen(),
      },
      // 👇 Questo StreamBuilder è ciò che rileva login/logout in tempo reale
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: HeartProgressIndicator(
              size: 60.0,
              color: Theme.of(context).colorScheme.primary,
            ));
          } else if (snapshot.hasData) {
            return HomeScreen();
          } else {
            return LoginScreen();
          }
        },
      ),
    );
  }
}
