import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../screens/profile_detail_screen.dart';

class SwipeCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onLike;
  final VoidCallback? onNope;
  final VoidCallback? onSuperlike;

  const SwipeCard({
    Key? key,
    required this.data,
    this.onLike,
    this.onNope,
    this.onSuperlike,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mediaHeight = MediaQuery.of(context).size.height;
    final mediaWidth = MediaQuery.of(context).size.width;
    final cardHeight = mediaHeight * 0.85;

    final photoUrl = data['photoUrls'][0] as String? ??
        'https://via.placeholder.com/300';
    final name = data['name'] as String? ?? 'Sconosciuto';
    final age = data['age'] != null ? '${data['age']}' : '–';
    final city = data['lastCity'] as String? ?? '';
    final titleText = '$name, $age${city.isNotEmpty ? ' • $city' : ''}';

    final double fontSize = min(max(mediaWidth * 0.05, 16.0), 20.0);
    const double buttonSize = 50.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      child: Card(
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: SizedBox(
          height: cardHeight,
          width: double.infinity,
          child: ScrollConfiguration(
            behavior: MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
              },
            ),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              dragStartBehavior: DragStartBehavior.down,
              padding: EdgeInsets.zero,
              children: [
                // Full image covers entire card
                SizedBox(
                  height: cardHeight,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.error),
                        ),
                      ),
                      // Name overlay
                      Positioned(
                        bottom: cardHeight * 0.25,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text(
                            titleText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                              shadows: const [
                                Shadow(
                                  blurRadius: 6.0,
                                  color: Colors.black45,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      // Buttons overlay
                      Positioned(
                        bottom: cardHeight * 0.12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildActionButton(
                              Icons.clear,
                              Colors.red,
                              onNope,
                              buttonSize,
                            ),
                            _buildActionButton(
                              Icons.star,
                              Colors.blue,
                              onSuperlike,
                              buttonSize,
                            ),
                            _buildActionButton(
                              Icons.favorite,
                              Colors.green,
                              onLike,
                              buttonSize,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Profile details below image
                ProfileDetailScreen(
                  data: data
                ),
                const SizedBox(height: 8.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    Color color,
    VoidCallback? onPressed,
    double size,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4.0,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: color,
          size: size * 0.5,
        ),
        onPressed: onPressed,
      ),
    );
  }
}
