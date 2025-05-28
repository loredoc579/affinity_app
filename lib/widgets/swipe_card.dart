import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
    final mediaSize = MediaQuery.of(context).size;
    final cardHeight = mediaSize.height * 0.85;
    final fontSize = min(max(mediaSize.width * 0.05, 16.0), 20.0);

    final photoList = data['photoUrls'] as List<dynamic>?;
    final photoUrl = (photoList != null && photoList.isNotEmpty)
        ? photoList.first as String
        : 'https://via.placeholder.com/300';
    final name = data['name'] as String? ?? 'Sconosciuto';
    final age = data['age'] != null ? '${data['age']}' : '–';
    final city = data['lastCity'] as String? ?? '';
    final titleText = '$name, $age${city.isNotEmpty ? ' • $city' : ''}';

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: SizedBox(
          height: cardHeight * 1,
          width: double.infinity,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              // Full image section with overlays
              SizedBox(
                height: cardHeight * 0.87,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background image
                    CachedNetworkImage(
                      imageUrl: photoUrl,
                      placeholder: (ctx, url) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (ctx, url, error) => const Center(
                        child: Icon(Icons.error, size: 40),
                      ),
                      fit: BoxFit.cover,
                    ),
                    // Title text
                    Positioned(
                      bottom: cardHeight * 0.2,
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
                    // Action buttons
                    Positioned(
                      bottom: cardHeight * 0.08,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(Icons.clear, Colors.red, onNope),
                          _buildActionButton(Icons.star, Colors.blue, onSuperlike),
                          _buildActionButton(Icons.favorite, Colors.green, onLike),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Profile details below
              ProfileDetailScreen(data: data),
              const SizedBox(height: 16.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    Color color,
    VoidCallback? onPressed,
  ) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4.0)],
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 24),
        onPressed: onPressed,
      ),
    );
  }
}
