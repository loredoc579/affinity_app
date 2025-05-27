import 'package:affinity_app/widgets/heart_progress_indicator.dart';
import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';               // ← import Provider

import 'bloc/swipe_event.dart';
import 'screens/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/auth/facebook_init.dart';

import 'models/filter_model.dart';                     // ← il tuo FilterModel

import 'services/swipe_service.dart';
import 'bloc/swipe_bloc.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🔄 main(): WidgetsBinding initialized');

    try {
    debugPrint('🔄 main(): Trying Firebase.initializeApp()');
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
    debugPrint('✅ main(): Firebase.initializeApp() completed');
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      debugPrint('⚠️ Firebase already initialized, skipping');
    } else {
      rethrow;
    }
  }


  await setupFacebook(); // inizializza fbInit qui
  
  runApp(
    // 1) Prima i Bloc
    MultiBlocProvider(
      providers: [
        BlocProvider<SwipeBloc>(
          create: (_) =>
            // inietta subito l'evento di caricamento
            SwipeBloc(SwipeService())
              ..add(LoadProfiles([])), // carica la lista vuota inizialmente
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

class AffinityApp extends StatelessWidget {
  const AffinityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
