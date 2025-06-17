// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../services/home_data_service.dart';
import '../utils/filter_manager.dart';
import '../content/home_content.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _dataService = HomeDataService();
  late final Future<HomeData> _initialFuture;
  bool _isEnd = false;
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialFuture = _dataService.loadInitialData(
      FirebaseAuth.instance.currentUser!.uid,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _showFilters(
    List<Map<String, dynamic>> allProfiles,
    Position position,
  ) {
    final user = FirebaseAuth.instance.currentUser!;
    FilterManager.showFilterSheet(
      context: context,
      allProfiles: allProfiles,
      position: position,
      user: user,
      onResetSwiper: () {
        setState(() => _isEnd = false);
        // Il dispatchLoad viene eseguito da HomeContent quando 
        // il bottom sheet richiama dispatchLoad internamente.
      },
    );
  }

  void _onNavTap(int index) {
    setState(() => _navIndex = index);
    Navigator.pushNamed(
      context,
      index == 0 ? '/chats' : '/profile',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeData>(
      future: _initialFuture,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError || snap.data == null) {
          return const Scaffold(
            body: Center(child: Text('Errore caricamento dati')),
          );
        }

        final data = snap.data!;
        return HomeContent(
          avatarUrl:     data.avatarUrl,
          position:      data.position,
          allProfiles:   data.allProfiles,
          onShowFilters: () => _showFilters(data.allProfiles, data.position),
          onNavTap:      _onNavTap,
          navIndex:      _navIndex,
          isEnd:         _isEnd,
          onEndReached:  () => setState(() => _isEnd = true),
        );
      },
    );
  }
}
