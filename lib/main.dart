import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'firebase/firebase_options.dart';
import 'firebase/firebase_emulators.dart';
import 'firebase/firebase_messaging_bg.dart';

import 'notifications/notifications_stub.dart'
    if (dart.library.io) 'notifications/notifications_mobile.dart';

import 'bloc/network_cubit.dart';
import 'bloc/swipe_bloc.dart';
import 'repository/swipe_repository.dart';
import 'services/swipe_service.dart';
import 'models/filter_model.dart';

import 'screens/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'widgets/heart_progress_indicator.dart';

// ─────────────────────────────────────────────
// Navigator key globale
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

const bool useEmulators =
    bool.fromEnvironment('USE_EMULATORS', defaultValue: false);

// ─────────────────────────────────────────────
// MAIN
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('*********************************************');
  debugPrint('*********** STARTING AffinityApp ***********');
  debugPrint('*********************************************');

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: firebaseOptions,
      );
    }
  } catch (e) {
    // Se l'errore è "duplicate-app", lo ignoriamo bellamente.
    if (e.toString().contains('duplicate-app')) {
      debugPrint('Firebase è già inizializzato (Nativo o Hot Restart), andiamo avanti!');
    } else {
      debugPrint('Errore imprevisto Firebase: $e');
    }
  }

  if (useEmulators) {
    await connectToFirebaseEmulators();
  }

  // Background + permissions SOLO mobile
  if (!kIsWeb) {
    initFirebaseBackgroundHandler();
    await initMobileNotifications();
  }

  final networkCubit = NetworkCubit();

  final swipeRepo = SwipeRepository(
    functions: FirebaseFunctions.instanceFor(region: 'us-central1'),
  );

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: networkCubit),
        BlocProvider(
          create: (_) => SwipeBloc(
            swipeRepo,
            FirebaseAuth.instance,
            SwipeService(),
            networkCubit,
          ),
        ),
      ],
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => FilterModel()),
        ],
        child: const AffinityApp(),
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// APP ROOT
class AffinityApp extends StatelessWidget {
  const AffinityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Affinity',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: Colors.blueAccent,
        fontFamily: 'Sans',
      ),
      routes: {
        '/login': (context) => LoginScreen(),
      },
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: HeartProgressIndicator(size: 60)),
            );
          }

          if (!snapshot.hasData) {
            return LoginScreen();
          }

          return const HomeScreen();
        },
      ),
    );
  }
}