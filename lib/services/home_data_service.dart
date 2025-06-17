import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';

class HomeData {
  final String avatarUrl;
  final Position position;
  final List<Map<String, dynamic>> allProfiles;

  HomeData({
    required this.avatarUrl,
    required this.position,
    required this.allProfiles,
  });
}

class HomeDataService {
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;
  final GeolocatorPlatform _geolocator;

  HomeDataService({
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
    GeolocatorPlatform? geolocator,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _messaging = messaging ?? FirebaseMessaging.instance,
        _geolocator = geolocator ?? GeolocatorPlatform.instance;

  /// Inizializza FCM e location, scarica avatar e lista completa profili
  Future<HomeData> loadInitialData(String uid) async {
    // 1) Avatar
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final avatarUrl = userDoc.data()?['photoUrls']?[0] as String? ?? '';

    // 2) FCM token & permissions
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    // (listener di onMessage etc. va registrato in HomeScreen usando navigatorKey)

    // 3) Geolocalizzazione
    Position pos = await _geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );

    // 4) Lista completa profili
    final snap = await _firestore.collection('users').get();
    final allProfiles = snap.docs
        .where((d) => d.id != uid)
        .map((d) => {...d.data(), 'uid': d.id})
        .toList();

    return HomeData(
      avatarUrl: avatarUrl,
      position: pos,
      allProfiles: allProfiles,
    );
  }
}
