// lib/screens/home_content.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:geolocator/geolocator.dart';

import '../bloc/swipe_bloc.dart';
import '../bloc/swipe_event.dart';
import '../bloc/swipe_state.dart';

import '../utils/filter_manager.dart';

import '../widgets/home_app_bar.dart';
import '../widgets/home_bottom_nav_bar.dart';
import '../widgets/swipe_card.dart';
import '../widgets/heart_progress_indicator.dart';
import '../widgets/ripple_avatar.dart';

class HomeContent extends StatefulWidget {
  final String avatarUrl;
  final Position position;
  final List<Map<String, dynamic>> allProfiles;
  final VoidCallback onShowFilters;
  final ValueChanged<int> onNavTap;
  final int navIndex;
  final bool isEnd;
  final VoidCallback onEndReached;

  const HomeContent({
    super.key,
    required this.avatarUrl,
    required this.position,
    required this.allProfiles,
    required this.onShowFilters,
    required this.onNavTap,
    required this.navIndex,
    required this.isEnd,
    required this.onEndReached,
  });

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent>
    with SingleTickerProviderStateMixin {
  final _controller = CardSwiperController();
  final Key _swiperKey = UniqueKey();
  int _currentIndex = 0;
  late final AnimationController _rippleController;
  bool _isSuperlikeInProgress = false; 

  @override
  void initState() {
    super.initState();
    // ① dispatchiamo subito il filtraggio lato UI al bloc
    FilterManager.dispatchLoad(
      context,
      widget.allProfiles,
      widget.position,
    );

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Se hai già finito tutte le card
    if (widget.isEnd) {
      return returnRippleAvatar();
    }

    return BlocBuilder<SwipeBloc, SwipeState>(
      builder: (context, state) {
        debugPrint('State: ${state.toString()}.');

        // ② Stato iniziale: mostriamo ancora un loader
        if (state is SwipeInitial || state is ProfilesLoading) {
          debugPrint('loading... waiting for profiles');
          return Scaffold(
            body: Center(child: HeartProgressIndicator(size: 60.0)),
            bottomNavigationBar: HomeBottomNavBar(
              currentIndex: widget.navIndex, 
              onTap: widget.onNavTap,
            ),
          );
        }

        if (state is ProfilesLoaded) {
          debugPrint('ProfilesLoaded state.');
          final list = state.profiles.cast<Map<String, dynamic>>();
          // nessuna carta?
          if (list.isEmpty) {
            debugPrint('No profiles to show');
            return returnRippleAvatar();
          }

          // preload immagini
          final remaining = list.length - _currentIndex;
          final displayed = remaining.clamp(1, 2);

          debugPrint('Remaining $remaining profiles');

          WidgetsBinding.instance.addPostFrameCallback((_) {
            for (var p in list.take(displayed)) {
              precacheImage(NetworkImage(p['photoUrls'][0] as String), context);
            }
          });

          return Scaffold(
            appBar: HomeAppBar(onFilterTap: widget.onShowFilters),
            body: CardSwiper(
              key: _swiperKey,
              controller: _controller,
              cardsCount: list.length,
              numberOfCardsDisplayed: displayed,
              scale: 0.8,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              threshold: 50,
              maxAngle: 20,
              duration: const Duration(milliseconds: 200),
              allowedSwipeDirection:
                  AllowedSwipeDirection.only(left: true, right: true),
              onSwipe: (prev, curr, dir) {
                final otherUid = list[prev]['uid'] as String;

                if (_isSuperlikeInProgress) {
                  debugPrint('Superlike in progress for $otherUid');                  
                  context.read<SwipeBloc>().add(
                    SwipeSuperlike(otherUid), // o SwipeSuperlike(otherUid)
                  );
                  _isSuperlikeInProgress = false;
                } else if (dir == CardSwiperDirection.left) {
                  debugPrint('Swiped left on $otherUid');
                  context.read<SwipeBloc>().add(SwipeNope(otherUid));
                } else if (dir == CardSwiperDirection.right) {
                  debugPrint('Swiped right on $otherUid');
                  context.read<SwipeBloc>().add(SwipeLike(otherUid));
                }

                if (curr != null) setState(() => _currentIndex = curr);

                return dir == CardSwiperDirection.left
                  || dir == CardSwiperDirection.right
                  || dir == CardSwiperDirection.top; 
              },
              onEnd: widget.onEndReached,
              cardBuilder: (ctx, i, _, __) {
                final data = list[i];
                return SwipeCard(
                  data: data,
                  onNope: () {
                    debugPrint('OnNope button tapped: Swiped left on ${data['uid']}');
                    _controller.swipe(CardSwiperDirection.left);
                  },
                  onSuperlike: () {
                    debugPrint('OnSuperlike button tapped: Swiped up on ${data['uid']}');
                    _isSuperlikeInProgress = true;
                    _controller.swipe(CardSwiperDirection.top);
                  },
                  onLike: () {
                    debugPrint('OnLike button tapped: Swiped right on ${data['uid']}');
                    _controller.swipe(CardSwiperDirection.right);
                  },
                );
              },
            ),
            bottomNavigationBar:
                HomeBottomNavBar(currentIndex: widget.navIndex, onTap: widget.onNavTap),
          );
        }

        // ③ errore nel caricamento
        if (state is ProfilesError) {
          debugPrint('ProfilesError state with message: ${state.message}');
          return Scaffold(
            appBar: HomeAppBar(onFilterTap: widget.onShowFilters),
            body: Center(child: Text('Errore: ${state.message}')),
            bottomNavigationBar: HomeBottomNavBar(
              currentIndex: widget.navIndex,
              onTap: widget.onNavTap,
            ),
          );
        }

        if (state is SwipeMatched) {
          debugPrint('SwipeMatched state with otherUid: ${state.otherUid}');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('È match! 🎉'),
                content:
                    const Text('Puoi iniziare a chattare con questo utente.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          });
        }

        // fallback, non dovrebbe mai accadere
        return const Scaffold(body: SizedBox.shrink());
      },
    );
  }

  Scaffold returnRippleAvatar() {
    return Scaffold(
      appBar:
          HomeAppBar(autoimplyLeading: false, onFilterTap: widget.onShowFilters),
      body: Center(
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
              imageUrl: widget.avatarUrl,
              imageSize: 100.0,
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          HomeBottomNavBar(currentIndex: widget.navIndex, onTap: widget.onNavTap),
    );
  }
}
