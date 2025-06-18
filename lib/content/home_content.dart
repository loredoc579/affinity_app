import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:geolocator/geolocator.dart';

import '../bloc/swipe_bloc.dart';
import '../bloc/swipe_event.dart';
import '../bloc/swipe_state.dart';
import '../utils/filter_manager.dart';
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
  bool _canSwipe = true;

  void _trySwipe(CardSwiperDirection dir) {
    if (!_canSwipe) return;
    _canSwipe = false;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _canSwipe = true;
    });
    _controller.swipe(dir);
  }

  @override
  void initState() {
    super.initState();
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
    if (widget.isEnd) {
      return returnRippleAvatarBody();
    }

    return BlocBuilder<SwipeBloc, SwipeState>(
      builder: (context, state) {
        if (state is SwipeInitial || state is ProfilesLoading) {
          return Center(child: HeartProgressIndicator(size: 60.0));
        }

        if (state is ProfilesLoaded) {
          final list = state.profiles.cast<Map<String, dynamic>>();
          if (list.isEmpty) {
            return returnRippleAvatarBody();
          }

          final remaining = list.length - _currentIndex;
          final displayed = remaining.clamp(1, 2);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            for (var p in list.take(displayed)) {
              precacheImage(
                NetworkImage(p['photoUrls'][0] as String), context);
            }
          });

          return CardSwiper(
            key: _swiperKey,
            controller: _controller,
            cardsCount: list.length,
            numberOfCardsDisplayed: displayed,
            scale: 0.8,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            threshold: 50,
            maxAngle: 20,
            duration: const Duration(milliseconds: 200),
            allowedSwipeDirection: AllowedSwipeDirection.only(
              left: true, right: true
            ),
            onSwipe: (prev, curr, dir) {
              if (!_canSwipe) return false;
              _canSwipe = false;
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) _canSwipe = true;
              });

              final otherUid = list[prev]['uid'] as String;
              if (_isSuperlikeInProgress) {
                context.read<SwipeBloc>().add(
                  SwipeSuperlike(otherUid),
                );
                _isSuperlikeInProgress = false;
              } else if (dir == CardSwiperDirection.left) {
                context.read<SwipeBloc>().add(SwipeNope(otherUid));
              } else if (dir == CardSwiperDirection.right) {
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
                onNope: () => _trySwipe(CardSwiperDirection.left),
                onSuperlike: () {
                  _isSuperlikeInProgress = true;
                  _trySwipe(CardSwiperDirection.top);
                },
                onLike: () => _trySwipe(CardSwiperDirection.right),
              );
            },
          );
        }

        if (state is ProfilesError) {
          return Center(child: Text('Errore: ${state.message}'));
        }

        if (state is SwipeMatched) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('È match! 🎉'),
                content: const Text(
                  'Puoi iniziare a chattare con questo utente.'
                ),
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

        return const SizedBox.shrink();
      },
    );
  }

  Widget returnRippleAvatarBody() {
    return Center(
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
    );
  }
}
