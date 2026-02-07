import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';

import '../bloc/swipe_bloc.dart';
import '../bloc/swipe_event.dart';
import '../bloc/swipe_state.dart';
import '../widgets/swipe_card.dart';
import '../widgets/heart_progress_indicator.dart';
import '../widgets/ripple_avatar.dart';

/// Direzioni interne per l’overlay
enum SwipeOverlayDir { none, left, superlike, right }

class HomeContent extends StatefulWidget {
  final String avatarUrl;
  final Position position;
  final VoidCallback onShowFilters;
  final ValueChanged<int> onNavTap;
  final int navIndex;

  const HomeContent({
    super.key,
    required this.avatarUrl,
    required this.position,
    required this.onShowFilters,
    required this.onNavTap,
    required this.navIndex,
  });

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent>
    with SingleTickerProviderStateMixin {
  final _controller = CardSwiperController();
  final _swiperKey = UniqueKey();
  late final AnimationController _rippleController;

  int _currentIndex = 0;

  // overlay
  bool _showOverlay = false;
  SwipeOverlayDir _overlayDir = SwipeOverlayDir.none;

  @override
  void initState() {
    super.initState();
    // Inizializza solo il ripple animation
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

  void _triggerOverlay(SwipeOverlayDir dir) {
    setState(() {
      _overlayDir = dir;
      _showOverlay = true;
    });
  }

  void _resetOverlay() {
    setState(() {
      _overlayDir = SwipeOverlayDir.none;
      _showOverlay = false;
    });
  }

  void _swipe(CardSwiperDirection dir, SwipeOverlayDir overlayDir) {
    _triggerOverlay(overlayDir);
    _controller.swipe(dir);
  }

  SwipeDir _mapToSwipeDir(SwipeOverlayDir dir) {
    switch (dir) {
      case SwipeOverlayDir.left:
        return SwipeDir.left;
      case SwipeOverlayDir.right:
        return SwipeDir.right;
      default:
        return SwipeDir.none;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SwipeBloc, SwipeState>(
      builder: (context, state) {
        if (state is SwipeInitial || state is ProfilesLoading) {
          return const Center(child: HeartProgressIndicator(size: 60));
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
                content: const Text('Puoi iniziare a chattare.'),
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
        if (state is ProfilesLoaded) {
          final jsonSafe = jsonDecode(jsonEncode(state.profiles));
          final List<Map<String, dynamic>> list =
              (jsonSafe as List).cast<Map<String, dynamic>>();

          if (list.isEmpty || _currentIndex >= list.length) {
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
                    imageSize: 100,
                  ),
                ],
              ),
            );
          }

          // Precache delle prime due immagini
          final remaining = list.length - _currentIndex;
          final displayed = remaining.clamp(1, 2);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            for (var p in list.take(displayed)) {
              precacheImage(NetworkImage(p['photoUrls'][0]), context);
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
            allowedSwipeDirection:
                AllowedSwipeDirection.only(left: true, right: true),
            onSwipeDirectionChange: (hDir, vDir) {
              if (hDir == CardSwiperDirection.left) {
                _triggerOverlay(SwipeOverlayDir.left);
              } else if (hDir == CardSwiperDirection.right) {
                _triggerOverlay(SwipeOverlayDir.right);
              } else {
                _resetOverlay();
              }
            },
            onSwipe: (prev, curr, dir) {
              final otherUid = list[prev]['uid'] as String;
              _resetOverlay();
              if (dir == CardSwiperDirection.left) {
                context.read<SwipeBloc>().add(SwipeNope(otherUid));
              } else if (dir == CardSwiperDirection.right) {
                context.read<SwipeBloc>().add(SwipeLike(otherUid));
              }
              if (curr != null) setState(() => _currentIndex = curr);
              return true;
            },
            cardBuilder: (ctx, i, _, __) {
              final data = list[i];
              final isTop = i == _currentIndex;
              return SwipeCard(
                data: data,
                showOverlay: _showOverlay && isTop,
                overlayDir: _mapToSwipeDir(_overlayDir),
                onNope: () =>
                    _swipe(CardSwiperDirection.left, SwipeOverlayDir.left),
                onLike: () =>
                    _swipe(CardSwiperDirection.right, SwipeOverlayDir.right),
                onSuperlike: () =>
                    _swipe(CardSwiperDirection.top, SwipeOverlayDir.superlike),
              );
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
