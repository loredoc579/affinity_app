import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/filter_manager.dart';
import '../bloc/swipe_bloc.dart';
import '../bloc/swipe_event.dart';
import '../bloc/swipe_state.dart';
import '../models/user_model.dart'; // Import fondamentale
import '../widgets/particle_overlay.dart';
import '../widgets/swipe_card.dart';
import '../widgets/heart_progress_indicator.dart';
import '../widgets/ripple_avatar.dart';

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

class _HomeContentState extends State<HomeContent> with SingleTickerProviderStateMixin {
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
      case SwipeOverlayDir.left: return SwipeDir.left;
      case SwipeOverlayDir.right: return SwipeDir.right;
      default: return SwipeDir.none;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SwipeBloc, SwipeState>(
      listener: (context, state) {
        if (state is SwipeMatched) {
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
        }
      },
      builder: (context, state) {
        if (state is SwipeInitial || state is SwipeLoading) {
          return const Center(child: HeartProgressIndicator(size: 60));
        }
        if (state is SwipeError) {
          return Center(child: Text('Errore: ${state.message}'));
        }
        
        // MODIFICA: Usiamo SwipeLoaded e la lista di UserModel
        if (state is SwipeLoaded) {
          final List<UserModel> users = state.users;

          if (users.isEmpty || _currentIndex >= users.length) {
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
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: () {
                      // 1. Dimentichiamo le carte vecchie e resettiamo l'indice a ZERO!
                      setState(() => _currentIndex = 0);
                      
                      // 2. Chiamiamo Firebase usando la tua "cabina di regia" dei filtri
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid != null) {
                        FilterManager.loadAndDispatch(context, uid, () {
                          debugPrint("🔄 Profili ricaricati dal pulsante!");
                        });
                      }
                    },
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'Ricarica Profili', 
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink, // Colore in stile app di dating
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 4,
                    ),
                  ),
                ],
              ),
            );
          }

          // Precache immagini (usando properties dell'oggetto user)
          final remaining = users.length - _currentIndex;
          final displayed = remaining.clamp(1, 2);
          
          // MODIFICA: Controllo corazzato prima di fare il precache
          final firstImageUrl = users[_currentIndex].imageUrls.isNotEmpty ? users[_currentIndex].imageUrls.first : '';
          
          if (firstImageUrl.trim().isNotEmpty && firstImageUrl.startsWith('http')) {
             WidgetsBinding.instance.addPostFrameCallback((_) {
               precacheImage(NetworkImage(firstImageUrl), context);
             });
          }

          return CardSwiper(
            key: _swiperKey,
            controller: _controller,
            cardsCount: users.length,
            isLoop: false,
            numberOfCardsDisplayed: displayed,
            scale: 0.8,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            threshold: 50,
            maxAngle: 20,
            duration: const Duration(milliseconds: 200),
            allowedSwipeDirection: const AllowedSwipeDirection.only(left: true, right: true),
            onSwipeDirectionChange: (hDir, vDir) {
              if (hDir == CardSwiperDirection.left) {
                _triggerOverlay(SwipeOverlayDir.left);
              } else if (hDir == CardSwiperDirection.right) {
                _triggerOverlay(SwipeOverlayDir.right);
              } else {
                _resetOverlay();
              }
            },
            onEnd: () {
              // Quando il pacchetto si accorge che non ci sono più carte, forziamo la schermata
              setState(() => _currentIndex = users.length);
            },
            onSwipe: (prev, curr, dir) {
              final otherUid = users[prev].id;
              
              // 🎥 TELECAMERA DI DEBUG: Stampa cosa succede prima di Firebase!
              debugPrint('👉 [DEBUG SWIPE] Carta n. $prev swipata verso: $dir');
              debugPrint('👉 [DEBUG SWIPE] ID Utente letto dalla carta: "$otherUid"');
              
              _resetOverlay();
              
              if (dir == CardSwiperDirection.left) {
                // ❌ NOPE: Nessuna particella, solo lo swipe
                context.read<SwipeBloc>().add(SwipeNope(otherUid));
                
              } else if (dir == CardSwiperDirection.right) {
                // 💚 LIKE: Lancio i cuoricini e invio a Firebase!
                ParticleOverlay.show(context, icon: Icons.favorite, color: Colors.green);
                context.read<SwipeBloc>().add(SwipeLike(otherUid));
                
              } else if (dir == CardSwiperDirection.top) {
                // 🌟 SUPERLIKE: Lancio le stelline e scommentiamo l'invio a Firebase!
                ParticleOverlay.show(context, icon: Icons.star, color: Colors.blueAccent);
                context.read<SwipeBloc>().add(SwipeSuperlike(otherUid));
              }
              
              setState(() => _currentIndex = curr ?? users.length);
              return true;
            },
            cardBuilder: (ctx, i, _, __) {
              final user = users[i];
              final isTop = i == _currentIndex;
              
              // MODIFICA: Passiamo l'oggetto User alla card
              return SwipeCard(
                key: ValueKey(user.id),
                user: user, // <--- Importante: dovremo aggiornare SwipeCard
                showOverlay: _showOverlay && isTop,
                overlayDir: _mapToSwipeDir(_overlayDir),
                onNope: () => _swipe(CardSwiperDirection.left, SwipeOverlayDir.left),
                onLike: () => _swipe(CardSwiperDirection.right, SwipeOverlayDir.right),
                onSuperlike: () => _swipe(CardSwiperDirection.top, SwipeOverlayDir.superlike),
              );
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}