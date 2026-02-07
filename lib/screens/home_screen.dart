import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../screens/offline_screen.dart';
import '../bloc/network_cubit.dart';
import '../bloc/swipe_bloc.dart';
import '../bloc/swipe_state.dart';
import '../content/home_content.dart';
import '../services/android_notifications.dart';
import '../utils/filter_manager.dart';
import '../services/presence_service.dart';
import '../widgets/heart_progress_indicator.dart';
import 'chat_list_screen.dart';
import 'profile_screen.dart';
import '../main.dart'; // importa SOLO la key, niente altro

/// Schermata principale con swipe, chat e profilo in tre tab
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

    // inizializza presence
    final svc = PresenceService();
    svc.init().then((_) => svc.updatePresence(online: true));

    // bootstrap avatar + posizione (non ancora profili)
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // --- Recupero avatar ---
    if (!mounted) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!mounted) return;
    _avatarUrl = (doc.data()?['photoUrls'] as List<dynamic>?)
            ?.first as String?
        ?? '';

    // --- Recupero posizione con timeout/fallback ---
    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      position = Position(
        latitude: 0, longitude: 0,
        timestamp: DateTime.now(),
        accuracy: 0, altitude: 0,
        heading: 0, speed: 0,
        speedAccuracy: 0,
        headingAccuracy: 0,
        altitudeAccuracy: 0,
      );
    }
    // Salvo la posizione
    _position = position;

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
      onResetSwiper: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1️⃣ loading avatar/position
    if (_avatarUrl == null || _position == null) {
      return const Scaffold(
        body: Center(child: HeartProgressIndicator(size: 60)),
      );
    }

    // 2️⃣ tri-stato network
    final netState = context.watch<NetworkCubit>().state;
    if (netState == NetworkStatus.unknown) {
      debugPrint('🔄 HomeScreen: network unknown, waiting...');
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (netState == NetworkStatus.offline) {
      debugPrint('🔄 HomeScreen: network offline, showing OfflineScreen');
      return const OfflineScreen();
    }

    // 3️⃣ primo dispatch appena online
    if (!_profilesRequested) {
      _profilesRequested = true;
      debugPrint('🔄 HomeScreen: dispatching LoadProfiles');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final uid = FirebaseAuth.instance.currentUser!.uid;
        FilterManager.loadAndDispatch(context, uid, () {});
      });
    }

    // 4️⃣ listener per ripristino online successivo
    return BlocListener<NetworkCubit, NetworkStatus>(
      listenWhen: (prev, curr) =>
        prev == NetworkStatus.offline && curr == NetworkStatus.online,
      listener: (context, _) {
        debugPrint('🔄 HomeScreen: network tornato online, ricarico filtri');
        final uid = FirebaseAuth.instance.currentUser!.uid;
        FilterManager.loadAndDispatch(context, uid, () {});
      },
      child: BlocBuilder<SwipeBloc, SwipeState>(
        builder: (context, state) {
          // 5️⃣ error
          if (state is ProfilesError) {
            return Scaffold(
              body: Center(
                child: Text(
                  state.message,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          // 6️⃣ full-screen loading
          if (state is SwipeInitial || state is ProfilesLoading) {
            return const Scaffold(
              body: Center(child: HeartProgressIndicator(size: 60)),
            );
          }

          // 7️⃣ offline lato server
          if (state is ProfilesOffline) {
            debugPrint('🔄 HomeScreen: server offline, mostrando OfflineScreen');
            return const OfflineScreen();
          }

          // 8️⃣ loaded o refreshing → UI con banner opzionale
          final isRefreshing = state is ProfilesRefreshing;
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
              title: const Text('Affinity'),
              actions: [
                if (_navIndex == 0)
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: _showFilters,
                  ),
                if (_navIndex == 2)
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      await PresenceService().goOffline();
                      await FirebaseAuth.instance.signOut();
                      setState(() => _profilesRequested = false);
                      if (!mounted) return;
                      Navigator.of(context)
                          .pushNamedAndRemoveUntil('/login', (_) => false);
                    },
                  ),
              ],
            ),
            body: Column(
              children: [
                if (isRefreshing)
                  Container(
                    width: double.infinity,
                    color: Colors.amberAccent,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Text(
                      'Aggiornamento in corso…',
                      textAlign: TextAlign.center,
                    ),
                  ),
                Expanded(
                  child: IndexedStack(index: _navIndex, children: pages),
                ),
              ],
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _navIndex,
              onTap: _onNavTap,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.view_carousel), label: ''),
                BottomNavigationBarItem(icon: Icon(Icons.chat), label: ''),
                BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
              ],
            ),
          );
        },
      ),
    );
  }

}
