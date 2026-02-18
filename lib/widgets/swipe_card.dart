import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../screens/profile_detail_screen.dart';
import '../widgets/particle_overlay.dart';

/// Direzioni per l'overlay/bottoni
enum SwipeDir { none, left, superlike, right }

class SwipeCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback? onLike;
  final VoidCallback? onNope;
  final VoidCallback? onSuperlike;

  /// Se true mostra overlay (label + animazioni pulsanti)
  final bool showOverlay;

  /// Direzione corrente dell’overlay
  final SwipeDir overlayDir;

  const SwipeCard({
    super.key,
    required this.user,
    this.onLike,
    this.onNope,
    this.onSuperlike,
    this.showOverlay = false,
    this.overlayDir = SwipeDir.none,
  });

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.of(context).size;
    final cardHeight = mediaSize.height * 0.85;
    final fontSize = (mediaSize.width * 0.05).clamp(16.0, 22.0);

    // Estrazione foto dal modello
    // In swipe_card.dart
    final String mainPhoto = (user.imageUrls.isNotEmpty && 
                          user.imageUrls.first.contains('http')) 
    ? user.imageUrls.first 
    : 'https://via.placeholder.com/600x800.png?text=Immagine+non+valida';

    // Helper per stato attivo pulsante (DALLA TUA VERSIONE)
    bool isActive(SwipeDir dir) => showOverlay && overlayDir == dir;

    // Helper per costruire i pulsanti ANIMATI (DALLA TUA VERSIONE)
    Widget buildActionButton({
      required IconData icon,
      required Color baseColor,
      required bool active,
      VoidCallback? onPressed,
    }) {
      return AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: active || !showOverlay ? 1.0 : 0.0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 200),
          scale: active ? 1.6 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? baseColor : Colors.white.withOpacity(0.9),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4),
              ],
            ),
            child: IconButton(
              icon: Icon(
                icon,
                color: active ? Colors.white : baseColor,
                size: 28,
              ),
              onPressed: onPressed,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: RepaintBoundary(
        child: Card(
          clipBehavior: Clip.hardEdge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: SizedBox(
            height: cardHeight,
            width: double.infinity,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // ===== FOTO PRINCIPALE + OVERLAY ANIMATI =====
                  Stack(
                    alignment: Alignment.bottomLeft,
                    children: [
                      CachedNetworkImage(
                        imageUrl: mainPhoto,
                        width: double.infinity,
                        height: cardHeight * 0.85,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        errorWidget: (_, __, ___) => const Center(child: Icon(Icons.error, size: 40)),
                      ),
                      
                      // Gradient per leggibilità
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                          ),
                        ),
                      ),

                      // Testo Nome e Età
                      Padding(
                        padding: const EdgeInsets.only(left: 20, bottom: 90),
                        child: Text(
                          '${user.name}, ${user.age}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            shadows: const [Shadow(blurRadius: 6, color: Colors.black45, offset: Offset(0, 2))],
                          ),
                        ),
                      ),

                      // ===== PULSANTI ANIMATI =====
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            buildActionButton(
                              icon: Icons.clear,
                              baseColor: Colors.red,
                              active: isActive(SwipeDir.left),
                              onPressed: onNope,
                            ),
                            buildActionButton(
                              icon: Icons.star, // Usiamo star per il superlike
                              baseColor: Colors.blue,
                              active: isActive(SwipeDir.superlike),
                              onPressed: () {
                                // 1. Magia delle stelle
                                ParticleOverlay.show(context, icon: Icons.star, color: Colors.blue);
                                // 2. Esegui il superlike
                                onSuperlike?.call();
                              },
                            ),
                            buildActionButton(
                              icon: Icons.favorite,
                              baseColor: Colors.green,
                              active: isActive(SwipeDir.right),
                              onPressed: () {
                                // 1. Magia dei cuori
                                ParticleOverlay.show(context, icon: Icons.favorite, color: Colors.green);
                                // 2. Esegui il like
                                onLike?.call();
                              },
                            ),
                          ],
                        ),
                      ),

                      // ===== LABEL DIAGONALI (Tua logica originale) =====
                      if (showOverlay && overlayDir != SwipeDir.none)
                        _buildOverlayLabel(overlayDir),
                    ],
                  ),

                  // ===== DETTAGLI SCROLLABILI (Stile Bumble con foto extra) =====
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: ProfileDetailScreen(
                      data: user.toMap(),
                      onLike: onLike,
                      onSuperlike: onSuperlike,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Metodo per le etichette diagonali
  Widget _buildOverlayLabel(SwipeDir dir) {
    if (dir == SwipeDir.superlike) {
      return Positioned(
        top: 40, left: 0, right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 3),
              borderRadius: BorderRadius.circular(4),
              color: Colors.white.withOpacity(0.2),
            ),
            child: const Text(
              'SUPER\nLIKE',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
        ),
      );
    }

    final isLeft = dir == SwipeDir.left;
    return Positioned(
      top: 60,
      left: isLeft ? 20 : null,
      right: !isLeft ? 20 : null,
      child: Transform.rotate(
        angle: isLeft ? -0.3 : 0.3,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: isLeft ? Colors.red : Colors.green, width: 3),
            borderRadius: BorderRadius.circular(4),
            color: Colors.white.withOpacity(0.2),
          ),
          child: Text(
            isLeft ? 'NOPE' : 'LIKE',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isLeft ? Colors.red : Colors.green),
          ),
        ),
      ),
    );
  }
}