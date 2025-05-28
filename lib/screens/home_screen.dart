import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';


import '../bloc/swipe_bloc.dart';
import '../bloc/swipe_event.dart';
import '../bloc/swipe_state.dart';

import '../models/filter_model.dart';

import '../utils/filter_manager.dart';

import '../widgets/ripple_avatar.dart';
import '../widgets/swipe_card.dart';
import '../widgets/heart_progress_indicator.dart';
import '../widgets/home_app_bar.dart';
import '../widgets/home_bottom_nav_bar.dart';


class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin<HomeScreen>{
  late final User _user;
  late final CardSwiperController _controller;
  var _userAvatar;
  Position? _position;
  List<Map<String, dynamic>> _allProfiles = [];
  bool _loading = true;
  bool isEnd = false;
  Key _swiperKey = UniqueKey();
  int _currentIndex = 0; // swiped cards count
  int _selectedNavIndex = 0; // bottom navigation index
  late final AnimationController _rippleController;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _controller = CardSwiperController();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
     _loadData();
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _user = FirebaseAuth.instance.currentUser!;
    final userinlist = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user.uid)
        .get();

    final usdata = userinlist.data();
    _userAvatar = usdata?['photoUrls'][0];

    // 1) Verifica lo stato dei permessi
    LocationPermission permission = await Geolocator.checkPermission();
     if (permission == LocationPermission.denied) {
      // 2) Richiedili
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Utente ha negato → mostra messaggio e esci
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permesso posizione negato'))
        );
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      // Utente ha negato per sempre → invitalo alle impostazioni
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Permesso posizione negato permanentemente'),
          action: SnackBarAction(
            label: 'Impostazioni',
            onPressed: () => Geolocator.openAppSettings(),
          ),
        ),
      );
      return;
    }
    // 3) Oramai permessi OK → ottieni la posizione
    try {
      _position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      // usa pos.latitude e pos.longitude
    } on Exception catch (e) {
      // altri errori nativi
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore geolocalizzazione: $e'))
      );
    }

    final snap = await FirebaseFirestore.instance.collection('users').get();
    _allProfiles = snap.docs
      .where((d) => d.id != _user.uid)
      .map((d) => {...d.data(), 'uid': d.id})
      .toList();

    final filterModel = context.read<FilterModel>();
    final doc = await FirebaseFirestore.instance.collection('users').doc(_user.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      if (data['filterMinAge'] != null && data['filterMaxAge'] != null) {
        filterModel.updateAge(RangeValues(
          (data['filterMinAge'] as num).toDouble(),
          (data['filterMaxAge'] as num).toDouble(),
        ));
      }
      if (data['filterMaxDistance'] != null) {
        filterModel.updateDistance((data['filterMaxDistance'] as num).toDouble());
      }
      if (data['filterGender'] is String) {
        filterModel.updateGender(data['filterGender'] as String);
      }
    }

    FilterManager.dispatchLoad(context, _allProfiles, _position!);
    setState(() => _loading = false);
  }

  void _showFilters() {
  FilterManager.showFilterSheet(
      context: context,
      allProfiles: _allProfiles,
      position: _position!,
      user: _user,
      onResetSwiper: () {
        setState(() {
          isEnd = false;
          _swiperKey = UniqueKey();
        });
      },
    );
  }

  Future<void> _onCardTap(Map<String, dynamic> data) async {
    // final liked = await Navigator.push<bool>(
    //   context,
    //   MaterialPageRoute(builder: (_) => ProfileDetailScreen(data: data)),
    // );

    // if (liked == true) {
    //     context.read<SwipeBloc>().add(SwipeLike(data['uid'] as String));
    //     _controller.swipe(CardSwiperDirection.right);
    // }

        // Apri il pannello a metà schermo
    _sheetController.animateTo(
      0.5,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedNavIndex = index;
    });
    if (index == 0) {
      Navigator.pushNamed(context, '/chats');
    } else if (index == 1) {
      Navigator.pushNamed(context, '/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: HeartProgressIndicator(
            size: 60.0,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (isEnd) {
      return Scaffold(
        appBar: HomeAppBar(autoimplyLeading: false, onFilterTap: _showFilters),
        body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Hai visualizzato tutti i profili.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              RippleAvatar(
                controller: _rippleController,
                imageUrl: _userAvatar,
                imageSize: 100.0,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: HomeBottomNavBar(
              currentIndex: _selectedNavIndex,
              onTap: _onNavItemTapped,
            ),
      );
    }

    return BlocBuilder<SwipeBloc, SwipeState>(
      builder: (context, state) {
        if (state is SwipeLoadSuccess) {
          final list = state.profiles;

          // Se non ci sono carte, mostra un messaggio
          if (list.isEmpty) {
            return const Center(child: Text('Nessuna carta da mostrare'));
          }

          final remaining = list.length - _currentIndex;
          final displayed = remaining.clamp(1, 2);

          // PRECACHE: si esegue in post frame, così non blocca il build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            for (var p in list.take(displayed)) {
              precacheImage(NetworkImage(p['photoUrls'][0] as String), context);
            }
          });

          return Scaffold(
            appBar: HomeAppBar(onFilterTap: _showFilters),
            body: CardSwiper(
                key: _swiperKey,
                controller: _controller,
                cardsCount: list.length,
                numberOfCardsDisplayed: 2,   // mostra due carte per un rendering più fluido
                scale: 0.8,                  // scala per la seconda carta
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                threshold: 50,               // soglia di pixel per il trigger dello swipe
                maxAngle: 20,                // angolo massimo di rotazione
                duration: const Duration(milliseconds: 200), // durata dell'animazione di swipe
                // consentiamo solo swipe orizzontali per like/nope
                allowedSwipeDirection: AllowedSwipeDirection.only(left: true, right: true),
                
                onSwipe: (prev, curr, dir) {
                  final uid = list[prev]['uid'] as String;
                  if (dir == CardSwiperDirection.left) {
                    context.read<SwipeBloc>().add(SwipeNope(uid));
                  } else if (dir == CardSwiperDirection.right) {
                    context.read<SwipeBloc>().add(SwipeLike(uid));
                  }
                  if (curr != null) setState(() => _currentIndex = curr);
                  return dir == CardSwiperDirection.left || dir == CardSwiperDirection.right;
                },
                onEnd: () {
                  if (mounted) setState(() => isEnd = true);
                },
                cardBuilder: (context, i, _, __) {
                  final data = list[i];
                  final uid = data['uid'] as String;

                  return RepaintBoundary(
                    child:SwipeCard(
                      data: data,
                      onNope: () {
                        _controller.swipe(CardSwiperDirection.left);
                        context.read<SwipeBloc>().add(SwipeNope(uid));
                      },
                      onSuperlike: () {
                        _controller.swipe(CardSwiperDirection.top);
                        context.read<SwipeBloc>().add(SwipeSuperlike(uid));
                      },
                      onLike: () {
                        _controller.swipe(CardSwiperDirection.right);
                        context.read<SwipeBloc>().add(SwipeLike(uid));
                      },
                    ),
                  );
                },
              ),
            
            bottomNavigationBar: HomeBottomNavBar(
              currentIndex: _selectedNavIndex,
              onTap: _onNavItemTapped,
            ),
          );
        } else if (state is SwipeProcessing) {
          return Scaffold(
            body: Center(
              child: HeartProgressIndicator(
                size: 60.0,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            bottomNavigationBar: HomeBottomNavBar(
              currentIndex: _selectedNavIndex,
              onTap: _onNavItemTapped,
            ),
          );
        } else if (state is SwipeFailure) {
          return Scaffold(
            appBar: HomeAppBar(onFilterTap: _showFilters),
            body: Center(child: Text('Errore: ${state.error}')),
            bottomNavigationBar: HomeBottomNavBar(
              currentIndex: _selectedNavIndex,
              onTap: _onNavItemTapped,
            ),
          );
        }

        return const Scaffold(body: SizedBox.shrink());
      },
    );
  }
}
