import 'package:flutter/material.dart';

/// Widget separato per l'animazione ripple attorno all'avatar
class RippleAvatar extends StatelessWidget {
  final AnimationController controller;
  final String imageUrl;
  final double imageSize;

  const RippleAvatar({
    Key? key,
    required this.controller,
    required this.imageUrl,
    this.imageSize = 100.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double endScale = screenWidth / imageSize;

    return SizedBox(
      width: imageSize * endScale,
      height: imageSize * endScale,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final progress = controller.value;
          final p1 = progress;
          final p2 = (progress + 0.5) % 1.0;

          final s1 = 1 + (endScale - 1) * p1;
          final a1 = (1 - p1).clamp(0.0, 1.0);
          final s2 = 1 + (endScale - 1) * p2;
          final a2 = (1 - p2).clamp(0.0, 1.0);

          return Stack(
            alignment: Alignment.center,
            children: [
              _buildRipple(context, scale: s1, alpha: a1),
              _buildRipple(context, scale: s2, alpha: a2),
              ClipOval(
                child: Image.network(
                  imageUrl,
                  width: imageSize,
                  height: imageSize,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRipple(BuildContext context, {required double scale, required double alpha}) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: imageSize,
        height: imageSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: alpha),
            width: 2,
          ),
        ),
      ),
    );
  }
}
