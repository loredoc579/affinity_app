import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../screens/profile_detail_screen.dart';

class SwipeCard extends StatefulWidget {
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
  _SwipeCardState createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> {
  bool _isHorizontalDrag = false;

  @override
  Widget build(BuildContext context) {
    final mediaHeight = MediaQuery.of(context).size.height;
    final mediaWidth = MediaQuery.of(context).size.width;
    final cardHeight = mediaHeight * 0.85;

    final photoUrl = widget.data['photoUrls'][0] as String? ??
        'https://via.placeholder.com/300';
    final name = (widget.data['name'] as String?) ?? 'Sconosciuto';
    final age = widget.data['age'] != null ? '${widget.data['age']}' : '–';
    final city = (widget.data['lastCity'] as String?) ?? '';
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
                dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
              ),
              child: RawGestureDetector(
                gestures: {
                  VerticalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
                    () => VerticalDragGestureRecognizer(),
                    (VerticalDragGestureRecognizer instance) {
                      instance
                        ..onStart = (_) {}
                        ..onUpdate = (_) {}
                        ..onEnd = (_) {};
                    },
                  ),
                },
                behavior: HitTestBehavior.translucent,
                child: ListView(
                physics: _isHorizontalDrag
                    ? const NeverScrollableScrollPhysics()
                    : kIsWeb
                        ? const ClampingScrollPhysics()
                        : const BouncingScrollPhysics(),
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
                          errorBuilder: (_, __, ___) =>
                              const Center(child: Icon(Icons.error)),
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
                                  Icons.clear, Colors.red, widget.onNope, buttonSize),
                              _buildActionButton(
                                  Icons.star, Colors.blue, widget.onSuperlike, buttonSize),
                              _buildActionButton(
                                  Icons.favorite, Colors.green, widget.onLike, buttonSize),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Profile details below image
                  ProfileDetailScreen(
                    data: widget.data
                  ),
                  const SizedBox(height: 8.0),
                ],
              ),
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
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4.0)],
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: size * 0.5),
        onPressed: onPressed,
      ),
    );
  }
}
