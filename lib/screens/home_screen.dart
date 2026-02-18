import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../screens/offline_screen.dart';
import '../bloc/network_cubit.dart';
import '../bloc/swipe_bloc.dart';
import '../bloc/swipe_state.dart';
import '../bloc/swipe_event.dart'; 
import '../content/home_content.dart';
import '../services/android_notifications.dart';
import '../utils/filter_manager.dart';
import '../services/presence_service.dart';
import '../widgets/heart_progress_indicator.dart';
import 'chat_list_screen.dart';
import 'profile_screen.dart';
import '../main.dart'; 

// ECCO L'IMPORT AGGIUNTO PER LA SCHERMATA IMPOSTAZIONI
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

  @override
  void initState() {
    super.initState();
    AndroidNotifications.init(navigatorKey);
    WidgetsBinding.instance.addObserver(this);

    final svc = PresenceService();
    svc.init().then((_) => svc.updatePresence(online: true));

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    if (!mounted) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    
    if (!mounted) return;
    final data = doc.data();
    _avatarUrl = data?['photoUrl'] as String?  
              ?? (data?['photoUrls'] as List<dynamic>?)?.firstOrNull as String? 
              ?? '';

    try {
      _position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      _position = Position(
        latitude: 0, longitude: 0, timestamp: DateTime.now(),
        accuracy: 0, altitude: 0, heading: 0, speed: 0,
        speedAccuracy: 0, headingAccuracy: 0, altitudeAccuracy: 0,
      );
    }

    if (!mounted) return;
    setState(() {});  
  }

  @override
  void dispose() {
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
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(state.message, style: const TextStyle(color: Colors.red)),
                    ElevatedButton(
                      onPressed: () {
                        final uid = FirebaseAuth.instance.currentUser!.uid;
                        FilterManager.loadAndDispatch(context, uid, () {});
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