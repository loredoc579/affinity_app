// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../services/home_data_service.dart';
import '../services/presence_service.dart';
import '../utils/filter_manager.dart';
import '../content/home_content.dart';
import 'chat_list_screen.dart';
import 'profile_screen.dart';

/// Schermata principale con swipe, chat e profilo in tre tab
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _dataService = HomeDataService();
  late final PresenceService _presenceService;
  late Future<HomeData> _initialFuture;
  int _navIndex = 0;
  bool _isEnd = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _presenceService = PresenceService()
      ..init().then((_) => _presenceService.updatePresence(online: true));
    _initialFuture = _loadHomeData();
  }

  Future<HomeData> _loadHomeData() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return _dataService.loadInitialData(uid);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _presenceService.updatePresence(online: true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _presenceService.updatePresence(online: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presenceService.updatePresence(online: false);
    super.dispose();
  }

  void _showFilters(List<Map<String, dynamic>> allProfiles, Position position) {
    final user = FirebaseAuth.instance.currentUser!;
    FilterManager.showFilterSheet(
      context: context,
      allProfiles: allProfiles,
      position: position,
      user: user,
      onResetSwiper: () => setState(() => _isEnd = false),
    );
  }

  Future<void> _signOut() async {
    await _presenceService.goOffline();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _onNavTap(int index) => setState(() => _navIndex = index);

  PreferredSizeWidget _buildAppBar(HomeData? data) {
    switch (_navIndex) {
      case 0:
        return AppBar(
          title: const Text('Affinity'),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () {
                if (data != null) {
                  _showFilters(data.allProfiles, data.position);
                }
              },
            ),
          ],
        );
      case 1:
        return AppBar(
          title: const Text('Le mie chat'),
        );
      case 2:
      default:
        return AppBar(
          title: const Text('Profilo'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _signOut,
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeData>(
      future: _initialFuture,
      builder: (ctx, snap) {
        // Loading ed error handled with their own Scaffold
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: _buildAppBar(null),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError || snap.data == null) {
          return Scaffold(
            appBar: _buildAppBar(null),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Errore caricamento dati'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => setState(() => _initialFuture = _loadHomeData()),
                    child: const Text('Riprova'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snap.data!;
        final pages = <Widget>[
          RefreshIndicator(
            onRefresh: () async {
              final fresh = await _loadHomeData();
              setState(() => _initialFuture = Future.value(fresh));
            },
            child: HomeContent(
              avatarUrl: data.avatarUrl,
              position: data.position,
              allProfiles: data.allProfiles,
              onShowFilters: () => _showFilters(data.allProfiles, data.position),
              onNavTap: _onNavTap,
              navIndex: _navIndex,
              isEnd: _isEnd,
              onEndReached: () => setState(() => _isEnd = true),
            ),
          ),
          const ChatListScreen(),
          const ProfileScreen(),
        ];

        return Scaffold(
          appBar: _buildAppBar(data),
          body: IndexedStack(index: _navIndex, children: pages),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _navIndex,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            onTap: _onNavTap,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.view_carousel), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.chat),   label: 'Chat'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profilo'),
            ],
          ),
        );
      },
    );
  }
}
