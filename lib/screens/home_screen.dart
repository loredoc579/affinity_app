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
import '../widgets/swipe_card.dart';
import '../widgets/filter_sheet.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _user = FirebaseAuth.instance.currentUser!;
    _position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    // Carica tutti i profili tranne quello corrente
    final snap = await FirebaseFirestore.instance.collection('users').get();
    _allProfiles = snap.docs
        .where((d) => d.id != _user.uid)
        .map((d) => {...d.data(), 'uid': d.id})
        .toList();

    // Inizializza filtri da Firestore in FilterModel
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

    // Dopo aver caricato dati e filtri, invia al Bloc
    _dispatchLoad();

    setState(() => _loading = false);
  }

  void _dispatchLoad() {
    final filter = context.read<FilterModel>();
    final filtered = _allProfiles.where((p) {
      // Applica gli stessi criteri di _filtered
      final age = p['age'] is num ? (p['age'] as num).toInt() : int.tryParse('${p['age']}') ?? 0;
      if (age < filter.ageRange.start || age > filter.ageRange.end) return false;
      final gender = p['gender']?.toString() ?? '';
      if (filter.gender != 'all' && gender != filter.gender) return false;
      final lat = (p['lastLat'] as num?)?.toDouble();
      final lon = (p['lastLong'] as num?)?.toDouble();
      if (lat == null || lon == null) return false;
      final distKm = Geolocator.distanceBetween(
            _position!.latitude,
            _position!.longitude,
            lat,
            lon,
          ) /
          1000;
      return distKm <= filter.maxDistance;
    }).toList();

    context.read<SwipeBloc>().add(LoadProfiles(filtered));
  }

  // Gestione tap sul dettaglio profilo
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return BlocBuilder<SwipeBloc, SwipeState>(
      builder: (context, state) {

        if (state is SwipeLoadSuccess) {
          final list = state.profiles;
          if (list.isEmpty || isEnd) {
            return Scaffold(
              appBar: _buildAppBar(),
              body: const Center(child: Text('Hai visualizzato tutti i profili.')),
            );
          }
          return Scaffold(
            appBar: _buildAppBar(),
            body: CardSwiper(
              key: _swiperKey,
              controller: _controller,
              cardsCount: list.length,
              numberOfCardsDisplayed: list.length >= 2 ? 2 : list.length,
              onSwipe: (prev, curr, dir) {
                final uid = list[prev]['uid'] as String;
                if (dir == CardSwiperDirection.left) {
                  context.read<SwipeBloc>().add(SwipeNope(uid));
                } else if (dir == CardSwiperDirection.right) {
                  context.read<SwipeBloc>().add(SwipeLike(uid));
                } else if (dir == CardSwiperDirection.top) {
                  context.read<SwipeBloc>().add(SwipeSuperlike(uid));
                }
                return dir != CardSwiperDirection.bottom;
              },
              onEnd: () { if(mounted){
                setState(() {
                  isEnd = true;
                });
              }},
              cardBuilder: (_, i, __, ___) => SwipeCard(
                data: list[i],
                onTap: () => _onCardTap(list[i]),
                onLike: () => _controller.swipe(CardSwiperDirection.right),
                onNope: () => _controller.swipe(CardSwiperDirection.left),
                onSuperlike: () => _controller.swipe(CardSwiperDirection.top),
              ),
            ),
          );
        } else if (state is SwipeProcessing) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        } else if (state is SwipeFailure) {
          return Scaffold(
            appBar: _buildAppBar(),
            body: Center(child: Text('Errore: ${state.error}')),
          );
        }
        // stato iniziale o altri
        return const Scaffold(body: SizedBox.shrink());
      },
    );
  }

  AppBar _buildAppBar() => AppBar(
        title: const Text('Affinity'),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: _showFilters),
          IconButton(icon: const Icon(Icons.person), onPressed: () => Navigator.pushNamed(context, '/profile')),
        ],
      );

  void _showFilters() {
    final filter = context.read<FilterModel>();
    showModalBottomSheet(
      context: context,
      builder: (_) => FilterSheet(
        ageRange: filter.ageRange,
        maxDistance: filter.maxDistance,
        genderFilter: filter.gender,
        onAgeChanged: (r) {
          filter.updateAge(r);
          _dispatchLoad();
        },
        onDistanceChanged: (d) {
          filter.updateDistance(d);
          _dispatchLoad();
        },
        onGenderChanged: (g) {
          filter.updateGender(g);
          _dispatchLoad();
        },
        onApply: () async {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_user.uid)
              .update({
            'filterMinAge': filter.ageRange.start.toInt(),
            'filterMaxAge': filter.ageRange.end.toInt(),
            'filterMaxDistance': filter.maxDistance,
            'filterGender': filter.gender,
          });

          setState(() {
            isEnd = false;
            _swiperKey = UniqueKey();
          });

          _dispatchLoad();
          Navigator.pop(context);
        },
      ),
    );
  }
}
