import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';

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
import 'match_screen.dart';
import 'chat_screen.dart';

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
  StreamSubscription<Position>? _locationSubscription;

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

    // Ascoltiamo la creazione di NUOVE chat in tempo reale
    FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      for (var change in snapshot.docChanges) {
        // Se c'è un documento NUOVO aggiunto in questo istante
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          // Controlliamo che sia stato creato proprio negli ultimi 5 secondi
          final timestamp = data['timestamp'] as Timestamp?;
          if (timestamp != null && DateTime.now().difference(timestamp.toDate()).inSeconds < 5) {
            
            // Controlliamo se la schermata "MatchScreen" NON è già aperta
            // (Questo impedisce il doppio avviso per l'Utente A)
            bool isMatchScreenOpen = false;
            Navigator.popUntil(context, (route) {
              if (route.settings.name == 'MatchScreen' || route.runtimeType.toString() == 'PageRouteBuilder<dynamic>') {
                isMatchScreenOpen = true;
              }
              return true; 
            });

            if (!isMatchScreenOpen) {
              // Siamo l'Utente B! Mostriamo un bellissimo banner In-App
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: const [
                      Icon(Icons.favorite, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(child: Text("Hai un nuovo Match! Corri a scrivergli.", style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  backgroundColor: Colors.pinkAccent,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'Scrivi', // Cambiato da "Vedi" a "Scrivi"
                    textColor: Colors.white,
                    onPressed: () async {
                      // 1. Recuperiamo l'ID dell'altra persona dalla chat creata
                      final participants = List<String>.from(data['participants'] ?? []);
                      final otherUserId = participants.firstWhere((id) => id != uid, orElse: () => '');
                      
                      if (otherUserId.isNotEmpty) {
                        // Mostra un piccolo caricamento visivo opzionale qui se vuoi, ma Firebase cache è istantaneo
                        
                        // 2. Andiamo a prendere Nome e Foto dell'altro utente
                        final otherUserDoc = await FirebaseFirestore.instance.collection('users').doc(otherUserId).get();
                        
                        // Controllo di sicurezza se nel frattempo l'utente ha chiuso l'app
                        if (!mounted) return; 
                        
                        if (otherUserDoc.exists) {
                          final otherData = otherUserDoc.data()!;
                          final otherName = otherData['name'] ?? 'Utente';
                          final otherPhoto = otherData['photoUrl'] ?? '';
                          final chatId = change.doc.id; // L'ID del documento chat

                          // 3. IL TELETRASPORTO!
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                chatId: chatId,
                                otherUserId: otherUserId,
                                otherUserName: otherName,
                                otherUserPhotoUrl: otherPhoto,
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              );
            }
          }
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
      // --- 1. CONTROLLO PERMESSI E GPS ---
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception("Location services disabled");

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception("Location permissions denied");
      }
      if (permission == LocationPermission.deniedForever) throw Exception("Location permissions permanently denied");

      // --- 2. OTTIENI POSIZIONE ATTUALE ---
      _position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      ).timeout(const Duration(seconds: 5));

      // --- 3. LOGICA DI RISPARMIO SCRITTURE (IL BLOCCO DEL DIVANO) ---
      bool shouldUpdateDb = false;
      final savedLocation = data?['location'];

      if (savedLocation == null || savedLocation['position'] == null) {
        // L'utente non ha MAI salvato la posizione, dobbiamo aggiornare per forza
        shouldUpdateDb = true;
      } else {
        // Estraiamo le vecchie coordinate in modo sicuro
        final savedPos = savedLocation['position'];
        double savedLat = savedPos is GeoPoint ? savedPos.latitude : (savedPos['latitude'] ?? savedPos['_latitude'] ?? 0.0);
        double savedLng = savedPos is GeoPoint ? savedPos.longitude : (savedPos['longitude'] ?? savedPos['_longitude'] ?? 0.0);

        // Calcoliamo quanti metri si è spostato dall'ultima volta
        double distanceMoved = Geolocator.distanceBetween(savedLat, savedLng, _position!.latitude, _position!.longitude);

        if (distanceMoved > 2000) { // 2000 metri = 2 km
          shouldUpdateDb = true;
          debugPrint("📍 Utente in viaggio (Spostamento: ${distanceMoved.round()}m). Aggiorno DB!");
        } else {
          debugPrint("📍 Utente fermo (Spostamento: ${distanceMoved.round()}m). Salto scrittura su Firebase.");
        }
      }

      // --- 4. SCRITTURA SU FIREBASE (SOLO SE NECESSARIO) ---
      if (shouldUpdateDb) {
        List<Placemark> placemarks = await placemarkFromCoordinates(_position!.latitude, _position!.longitude);
        final city = placemarks.isNotEmpty ? (placemarks.first.locality ?? "Sconosciuta") : "Sconosciuta";

        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'location.position': GeoPoint(_position!.latitude, _position!.longitude),
          'location.city': city,
          'location.updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint("📍 DB Aggiornato: Città $city");
      }

      // --- 5. ATTIVA IL RADAR CONTINUO ---
      final locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.medium, 
        distanceFilter: 2000, // 2 km
      );

      _locationSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
          .listen((Position newPosition) async {
        
        debugPrint("🚗 [STREAM GPS] L'utente ha viaggiato per più di 2 km!");
        
        if (!mounted) return;

        setState(() {
          _position = newPosition; // Aggiorna la posizione locale
        });

        List<Placemark> placemarks = await placemarkFromCoordinates(newPosition.latitude, newPosition.longitude);
        final city = placemarks.isNotEmpty ? (placemarks.first.locality ?? "Sconosciuta") : "Sconosciuta";

        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'location.position': GeoPoint(newPosition.latitude, newPosition.longitude),
          'location.city': city,
          'location.updatedAt': FieldValue.serverTimestamp(),
        });
        
        debugPrint("🚗 [STREAM GPS] Firebase aggiornato: sei a $city");

        // ---> RICARICA IL MAZZO DI CARTE! <---
        if (mounted) {
          debugPrint("🔄 Ricarico i profili per la nuova zona ($city)...");
          // Richiamiamo il FilterManager che svuota il BLoC e riscarica la gente vicina
          FilterManager.loadAndDispatch(context, uid, () {});
        }
      });   
    } catch (e) {
      debugPrint("⚠️ Errore GPS: $e. Usando coordinate default.");
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
    _userSubscription?.cancel();
    _locationSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    PresenceService().updatePresence(online: false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      // L'utente ha riaperto l'app -> Torna Online
      PresenceService().init(); 
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // L'utente ha messo l'app in background o l'ha chiusa -> Vai Offline subito
      PresenceService().goOffline();
    }
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
      // --- ABBIAMO AGGIUNTO QUESTO BLOCLISTENER PER IL MATCH ---
        child: BlocListener<SwipeBloc, SwipeState>(
          listener: (context, state) async {
            if (state is SwipeMatched) {
              final myUid = FirebaseAuth.instance.currentUser!.uid;
              final otherDoc = await FirebaseFirestore.instance.collection('users').doc(state.matchId).get();
              final myDoc = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
              
              if (otherDoc.exists && myDoc.exists && context.mounted) {
                final otherData = otherDoc.data()!;
                final myData = myDoc.data()!;
                
                // --- ESTRAZIONE FOTO A PROVA DI BOMBA ---
                // Peschiamo la prima foto dall'array, se non c'è usiamo il vecchio campo, altrimenti vuoto
                final myPhoto = (myData['photoUrls'] as List<dynamic>?)?.firstOrNull as String? 
                             ?? myData['photoUrl'] as String? 
                             ?? '';
                             
                final otherPhoto = (otherData['photoUrls'] as List<dynamic>?)?.firstOrNull as String? 
                                ?? otherData['photoUrl'] as String? 
                                ?? '';
                
                Navigator.of(context).push(
                  PageRouteBuilder(
                    opaque: false, 
                    pageBuilder: (BuildContext context, _, __) => MatchScreen(
                      myPhotoUrl: myPhoto,       // <-- Assicurati che ci sia myPhoto qui
                      otherPhotoUrl: otherPhoto, // <-- E otherPhoto qui!
                      otherName: otherData['name'] ?? 'Utente',
                      otherUserId: state.matchId,
                      chatId: state.chatRoomId,
                    ),
                  ),
                );
              }
            }
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
                items: [
                  const BottomNavigationBarItem(icon: Icon(Icons.style), label: 'Swipe'),
                  BottomNavigationBarItem(
                    icon: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('chats')
                          .where('participants', arrayContains: FirebaseAuth.instance.currentUser?.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        int unread = 0;
                        if (snapshot.hasData) {
                          final uid = FirebaseAuth.instance.currentUser?.uid;
                          for (var doc in snapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            
                            final isDeleted = data['deleted'] == true;
                            
                            if (!isDeleted) {
                              final readBy = List<String>.from(data['readBy'] as List<dynamic>? ?? []);
                              // Se il mio ID non è nell'array dei letti, c'è un messaggio nuovo!
                              if (uid != null && !readBy.contains(uid)) {
                                unread++;
                              }
                            }
                          }
                        }
                        return Badge(
                          isLabelVisible: unread > 0,
                          label: Text(unread.toString()),
                          child: const Icon(Icons.chat_bubble_outline),
                        );
                      },
                    ),
                    label: 'Chat',
                  ),
                  const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}