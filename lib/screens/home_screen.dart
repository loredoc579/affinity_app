import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'dart:async'; // Serve per ascoltare i cambiamenti in tempo reale

import '../screens/offline_screen.dart';
import '../bloc/network_cubit.dart';
import '../bloc/swipe_bloc.dart';
import '../bloc/swipe_state.dart';
import '../content/home_content.dart';
import '../services/android_notifications.dart';
import '../utils/filter_manager.dart';
import '../services/presence_service.dart';
import '../widgets/heart_progress_indicator.dart';
import '../main.dart'; 

import 'chat_list_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String? _avatarUrl;
  Position? _position;
  int _navIndex = 0;
  bool _profilesRequested = false;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  @override
  void initState() {
    super.initState();
    AndroidNotifications.init(navigatorKey);
    WidgetsBinding.instance.addObserver(this);

    final svc = PresenceService();
    svc.init().then((_) => svc.updatePresence(online: true));

    final uid = FirebaseAuth.instance.currentUser!.uid;
    _userSubscription = FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((doc) {
      if (mounted && doc.exists) {
        final data = doc.data();
        final newAvatar = (data?['photoUrls'] as List<dynamic>?)?.firstOrNull as String? 
                       ?? data?['photoUrl'] as String? 
                       ?? '';
        if (_avatarUrl != newAvatar) {
          setState(() => _avatarUrl = newAvatar); // Aggiorna la UI se la foto cambia!
        }
      }
    });

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    if (!mounted) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    
    final data = doc.data();
    _avatarUrl = (data?['photoUrls'] as List<dynamic>?)?.firstOrNull as String? 
              ?? data?['photoUrl'] as String? 
              ?? '';

    try {
      // --- ROBUST LOCATION HANDLING ---
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("Location services are disabled.");
        throw Exception("Location services disabled");
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint("Location permissions are denied");
          throw Exception("Location permissions denied");
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint("Location permissions are permanently denied, we cannot request permissions.");
        throw Exception("Location permissions permanently denied");
      }

      // If we reach here, we have permission!
      _position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      ).timeout(const Duration(seconds: 5));

      // Save to Firestore
      FirebaseFirestore.instance.collection('users').doc(uid).update({
        'location.position': GeoPoint(_position!.latitude, _position!.longitude),
        'location.updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint("📍 Posizione aggiornata su Firestore: ${_position!.latitude}, ${_position!.longitude}");
    } catch (e) {
      debugPrint("Errore durante l'aggiornamento della posizione: $e");
      _position = Position(
        latitude: 0, longitude: 0, timestamp: DateTime.now(),
        accuracy: 0, altitude: 0, heading: 0, speed: 0,
        speedAccuracy: 0, headingAccuracy: 0, altitudeAccuracy: 0,
      );
      debugPrint("⚠️ Impossibile ottenere la posizione. Usando valori di default.");
      debugPrint("📍 Posizione di default: ${_position!.latitude}, ${_position!.longitude}");
    }

    if (!mounted) return;
    setState(() {});  
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    PresenceService().updatePresence(online: false);
    super.dispose();
  }

  void _onNavTap(int index) => setState(() => _navIndex = index);

  void _showFilters() {
    final user = FirebaseAuth.instance.currentUser!;
    FilterManager.showFilterSheet(
      context: context,
      user: user,
      onResetSwiper: () {
         // Lasciamo vuoto! Il FilterManager fa già il dispatch coi filtri!
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_avatarUrl == null || _position == null) {
      return const Scaffold(
        body: Center(child: HeartProgressIndicator(size: 60)),
      );
    }

    final netState = context.watch<NetworkCubit>().state;
    if (netState == NetworkStatus.offline) {
      return const OfflineScreen();
    }

    if (!_profilesRequested) {
      _profilesRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final uid = FirebaseAuth.instance.currentUser!.uid;
        FilterManager.loadAndDispatch(context, uid, () {}); // <-- CARICA I FILTRI E SPARA!
      });
    }

    return BlocListener<NetworkCubit, NetworkStatus>(
      listenWhen: (prev, curr) => prev == NetworkStatus.offline && curr == NetworkStatus.online,
      listener: (context, _) {
         final uid = FirebaseAuth.instance.currentUser!.uid;
         FilterManager.loadAndDispatch(context, uid, () {}); // <-- CARICA I FILTRI E SPARA!
      },
      child: BlocBuilder<SwipeBloc, SwipeState>(
        builder: (context, state) {
          
          if (state is SwipeError) {
            return Scaffold(
              // AGGIUNGIAMO LA APPBAR CON IL TASTO LOGOUT PER LE EMERGENZE!
              appBar: AppBar(
                title: const Text('Oops!', style: TextStyle(color: Colors.black87)),
                backgroundColor: Colors.white,
                elevation: 0,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.red),
                    onPressed: () async {
                      await PresenceService().goOffline();
                      await FirebaseAuth.instance.signOut();
                      if (!mounted) return;
                      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                    },
                  ),
                ],
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(state.message, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null) {
                          FilterManager.loadAndDispatch(context, uid, () {});
                        }
                      }, 
                      child: const Text("Riprova")
                    )
                  ],
                ),
              ),
            );
          }

          if (state is SwipeInitial || state is SwipeLoading) {
            return const Scaffold(
              body: Center(child: HeartProgressIndicator(size: 60)),
            );
          }

          final pages = <Widget>[
            HomeContent(
              avatarUrl: _avatarUrl!,
              position: _position!,
              onShowFilters: _showFilters,
              onNavTap: _onNavTap,
              navIndex: _navIndex,
            ),
            const ChatListScreen(),
            const ProfileScreen(),
          ];

          return Scaffold(
            appBar: AppBar(
              // --- ECCO IL PULSANTE AGGIUNTO IN ALTO A SINISTRA ---
              leading: IconButton(
                icon: const Icon(Icons.settings, color: Colors.black87),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
              ),
              // ----------------------------------------------------
              title: const Text('Affinity', style: TextStyle(color: Colors.pink, fontWeight: FontWeight.bold)),
              centerTitle: true,
              backgroundColor: Colors.white,
              elevation: 0,
              actions: [
                if (_navIndex == 0)
                  IconButton(
                    icon: const Icon(Icons.tune, color: Colors.black87),
                    onPressed: _showFilters,
                  ),
                if (_navIndex == 2)
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.black87),
                    onPressed: () async {
                      await PresenceService().goOffline();
                      await FirebaseAuth.instance.signOut();
                      if (!mounted) return;
                      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                    },
                  ),
              ],
            ),
            body: IndexedStack(index: _navIndex, children: pages),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _navIndex,
              onTap: _onNavTap,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              selectedItemColor: Colors.pink,
              unselectedItemColor: Colors.grey,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.style), label: 'Swipe'),
                BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
                BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
              ],
            ),
          );
        },
      ),
    );
  }
}