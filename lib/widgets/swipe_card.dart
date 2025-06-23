// ==========================
// lib/widgets/swipe_card.dart
// ==========================
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../screens/profile_detail_screen.dart';

/// Direzioni per l'overlay/bottoni
enum SwipeDir { none, left, superlike, right }

class SwipeCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onLike;
  final VoidCallback? onNope;
  final VoidCallback? onSuperlike;

  /// Se true mostra overlay (label + animazioni pulsanti)
  final bool showOverlay;

  /// Direzione corrente dell’overlay
  final SwipeDir overlayDir;

  const SwipeCard({
    super.key,
    required this.data,
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
    final fontSize = min(max(mediaSize.width * 0.05, 16.0), 20.0);

    final photoList = data['photoUrls'] as List<dynamic>? ?? [];
    final photoUrl = photoList.isNotEmpty
        ? photoList.first as String
        : 'https://via.placeholder.com/300';
    final name = data['name'] as String? ?? 'Sconosciuto';
    final age = data['age'] != null ? '${data['age']}' : '–';
    final city =
        (data['location'] as Map<String, dynamic>?)?['city'] as String? ?? '';
    final titleText = '$name, $age${city.isNotEmpty ? ' • $city' : ''}';

    // helper per stato attivo pulsante
    bool _isActive(SwipeDir dir) => showOverlay && overlayDir == dir;

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
                  // ===== immagine + overlay =====
                  SizedBox(
                    height: cardHeight * 0.87,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // img
                        CachedNetworkImage(
                          imageUrl: photoUrl,
                          placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          errorWidget: (_, __, ___) =>
                              const Center(child: Icon(Icons.error, size: 40)),
                          fit: BoxFit.cover,
                        ),

                        // titolo (nome • città)
                        Positioned(
                          bottom: cardHeight * 0.20,
                          left: 16,
                          right: 16,
                          child: Text(
                            titleText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                              shadows: const [
                                Shadow(
                                  blurRadius: 6,
                                  color: Colors.black45,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // ===== pulsanti in basso =====
                        Positioned(
                          bottom: cardHeight * 0.08,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // NOPE
                              _buildActionButton(
                                icon: Icons.clear,
                                baseColor: Colors.red,
                                active: _isActive(SwipeDir.left),
                                onPressed: onNope,
                              ),

                              // SUPERLIKE
                              _buildActionButton(
                                icon: Icons.flash_on,
                                baseColor: Colors.blue,
                                active: _isActive(SwipeDir.superlike),
                                onPressed: onSuperlike,
                              ),

                              // LIKE
                              _buildActionButton(
                                icon: Icons.favorite,
                                baseColor: Colors.green,
                                active: _isActive(SwipeDir.right),
                                onPressed: onLike,
                              ),
                            ],
                          ),
                        ),

                        // ===== label diagonale =====
                        if (showOverlay && overlayDir != SwipeDir.none)
                          overlayDir == SwipeDir.superlike
                          // --- SUPER LIKE: centrata orizzontalmente ---
                          ? Positioned(
                              top: 16,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.blue, width: 3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'SUPER\nLIKE',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                      fontFamily: 'PermanentMarker',
                                    ),
                                  ),
                                ),
                              ),
                            )
                          // --- NOPE / LIKE: diagonale ai lati ---
                          : Positioned(
                            top: 16,
                            left: overlayDir == SwipeDir.left ? 16 : null,
                            right: overlayDir == SwipeDir.right ? 16 : null,
                            child: Transform.rotate(
                              angle: overlayDir == SwipeDir.left
                                  ? -0.3
                                  : overlayDir == SwipeDir.right
                                      ? 0.3
                                      : 0.0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: overlayDir == SwipeDir.left
                                        ? Colors.red
                                        : overlayDir == SwipeDir.right
                                            ? Colors.green
                                            : Colors.blue,
                                    width: 3,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  overlayDir == SwipeDir.left
                                      ? 'NOPE'
                                      : overlayDir == SwipeDir.right
                                          ? 'LIKE'
                                          : 'SUPER\nLIKE',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: overlayDir == SwipeDir.left
                                        ? Colors.red
                                        : overlayDir == SwipeDir.right
                                            ? Colors.green
                                            : Colors.blue,
                                    fontFamily: 'PermanentMarker',
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ===== dettagli scrollabili =====
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ProfileDetailScreen(data: data),
                        const SizedBox(height: 16.0),
                      ],
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

  // ===== widget pulsante =====
  Widget _buildActionButton({
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
}
