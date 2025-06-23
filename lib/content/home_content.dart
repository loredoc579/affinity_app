// ==========================
// lib/home_content.dart
// ==========================
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../bloc/swipe_bloc.dart';
import '../bloc/swipe_event.dart';
import '../bloc/swipe_state.dart';
import '../models/filter_model.dart';
import '../services/filter_service.dart';
import '../utils/filter_manager.dart';
import '../widgets/swipe_card.dart';
import '../widgets/heart_progress_indicator.dart';
import '../widgets/ripple_avatar.dart';

/// Direzioni interne per l’overlay
enum SwipeOverlayDir { none, left, superlike, right }

class HomeContent extends StatefulWidget {
  final String avatarUrl;
  final Position position;
  final List<Map<String, dynamic>> allProfiles;
  final VoidCallback onShowFilters;
  final ValueChanged<int> onNavTap;
  final int navIndex;

  const HomeContent({
    super.key,
    required this.avatarUrl,
    required this.position,
    required this.allProfiles,
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

  bool _hasDispatched = false;
  int _currentIndex = 0;

  // overlay
  bool _showOverlay = false;
  SwipeOverlayDir _overlayDir = SwipeOverlayDir.none;

  // == overlay helpers =====
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

  // == swipe helpers =====
  void _swipe(CardSwiperDirection dir, SwipeOverlayDir overlayDir) {
    _triggerOverlay(overlayDir);
    _controller.swipe(dir);
  }

  // == lifecycle =====
  @override
  void initState() {
    super.initState();

    // 1) carico filtri da Firestore
    final filter = Provider.of<FilterModel>(context, listen: false);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    FilterService.loadFiltersForUser(filter, uid).then((_) {
      FilterManager.dispatchLoad(
        context,
        widget.allProfiles,
        widget.position,
      );
      setState(() => _hasDispatched = true);
    }).catchError((_) {
      FilterManager.dispatchLoad(
        context,
        widget.allProfiles,
        widget.position,
      );
      setState(() => _hasDispatched = true);
    });

    // 2) ripple avatar
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

  // ===== build =====
  @override
  Widget build(BuildContext context) {
    if (!_hasDispatched) {
      return const Center(child: HeartProgressIndicator(size: 60));
    }

    return BlocBuilder<SwipeBloc, SwipeState>(
      builder: (context, state) {
        // loader e gestioni varie
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
          final list = state.profiles.cast<Map<String, dynamic>>();

          // nessun profilo?
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

          final remaining = list.length - _currentIndex;
          final displayed = remaining.clamp(1, 2);

          // precache
          WidgetsBinding.instance.addPostFrameCallback((_) {
            for (var p in list.take(displayed)) {
              precacheImage(NetworkImage(p['photoUrls'][0] as String), context);
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

            // NOTE: consentiamo solo left / right dal dito
            allowedSwipeDirection:
                AllowedSwipeDirection.only(left: true, right: true),

            // Durante il trascinamento – solo per like/nope (superlike solo da pulsante)
            onSwipeDirectionChange: (hDir, vDir) {
              if (hDir == CardSwiperDirection.left) {
                _triggerOverlay(SwipeOverlayDir.left);
              } else if (hDir == CardSwiperDirection.right) {
                _triggerOverlay(SwipeOverlayDir.right);
              } else {
                _resetOverlay();
              }
            },

            // Rilascio
            onSwipe: (prev, curr, dir) {
              final otherUid = list[prev]['uid'] as String;
              _resetOverlay();

              if (dir == CardSwiperDirection.left) {
                context.read<SwipeBloc>().add(SwipeNope(otherUid));
              } else if (dir == CardSwiperDirection.right) {
                context.read<SwipeBloc>().add(SwipeLike(otherUid));
              } else if (dir == CardSwiperDirection.top) {
                // superlike partito da pulsante
                context.read<SwipeBloc>().add(SwipeSuperlike(otherUid));
              }

              if (curr != null) setState(() => _currentIndex = curr);
              return true;
            },

            // costruzione carta
            cardBuilder: (ctx, i, _, __) {
              final data = list[i];
              final isTopCard = i == _currentIndex;

              return SwipeCard(
                data: data,
                // passiamo overlay + dir alla carta
                showOverlay: _showOverlay && isTopCard,
                overlayDir: _mapToSwipeDir(_overlayDir),

                // callbacks pulsanti
                onNope: () =>
                    _swipe(CardSwiperDirection.left, SwipeOverlayDir.left),
                onLike: () =>
                    _swipe(CardSwiperDirection.right, SwipeOverlayDir.right),
                onSuperlike: () {
                  _swipe(CardSwiperDirection.top, SwipeOverlayDir.superlike);
                },
              );
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  /// Converte l’enum interno nell’enum usato da SwipeCard
  SwipeDir _mapToSwipeDir(SwipeOverlayDir dir) {
    switch (dir) {
      case SwipeOverlayDir.left:
        return SwipeDir.left;
      case SwipeOverlayDir.right:
        return SwipeDir.right;
      case SwipeOverlayDir.superlike:
        return SwipeDir.superlike;
      default:
        return SwipeDir.none;
    }
  }
}
