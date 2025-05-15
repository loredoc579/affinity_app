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

import '../widgets/swipe_card.dart';
import '../widgets/heart_progress_indicator.dart';
import '../widgets/home_app_bar.dart';
import '../widgets/home_bottom_nav_bar.dart';

import 'profile_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = CardSwiperController();
  late final User _user;
  Position? _position;
  List<Map<String, dynamic>> _allProfiles = [];
  bool _loading = true;
  bool isEnd = false;
  Key _swiperKey = UniqueKey();
  int _currentIndex = 0; // swiped cards count
  int _selectedNavIndex = 0; // bottom navigation index

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _user = FirebaseAuth.instance.currentUser!;
    _position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

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
    final liked = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProfileDetailScreen(data: data)),
    );
    if (liked == true) {
      context.read<SwipeBloc>().add(SwipeLike(data['uid'] as String));
      _controller.swipe(CardSwiperDirection.right);
    }
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
        appBar: HomeAppBar(onFilterTap: _showFilters),
        body: const Center(child: Text('Hai visualizzato tutti i profili.')),
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
          final remaining = list.length - _currentIndex;
          final displayed = remaining >= 2 ? 2 : remaining;

          return Scaffold(
            appBar: HomeAppBar(onFilterTap: _showFilters),
            body: CardSwiper(
              key: _swiperKey,
              controller: _controller,
              cardsCount: list.length,
              numberOfCardsDisplayed: displayed,
              onSwipe: (prev, curr, dir) {
                final uid = list[prev]['uid'] as String;
                if (dir == CardSwiperDirection.left) {
                  context.read<SwipeBloc>().add(SwipeNope(uid));
                } else if (dir == CardSwiperDirection.right) {
                  context.read<SwipeBloc>().add(SwipeLike(uid));
                } else if (dir == CardSwiperDirection.top) {
                  context.read<SwipeBloc>().add(SwipeSuperlike(uid));
                }
                if (curr != null) {
                  setState(() => _currentIndex = curr);
                }
                return dir != CardSwiperDirection.bottom;
              },
              onEnd: () {
                if (mounted) setState(() => isEnd = true);
              },
              cardBuilder: (_, i, __, ___) => SwipeCard(
                data: list[i],
                onTap: () => _onCardTap(list[i]),
                onLike: () => _controller.swipe(CardSwiperDirection.right),
                onNope: () => _controller.swipe(CardSwiperDirection.left),
                onSuperlike: () => _controller.swipe(CardSwiperDirection.top),
              ),
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
