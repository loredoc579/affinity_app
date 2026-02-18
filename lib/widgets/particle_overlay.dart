import 'dart:math';
import 'package:flutter/material.dart';

class ParticleOverlay {
  static void show(BuildContext context, {required IconData icon, required Color color}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _ParticleExplosion(
        icon: icon,
        color: color,
        onFinished: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _ParticleExplosion extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onFinished;

  const _ParticleExplosion({super.key, required this.icon, required this.color, required this.onFinished});

  @override
  State<_ParticleExplosion> createState() => _ParticleExplosionState();
}

class _ParticleExplosionState extends State<_ParticleExplosion> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final int _particleCount = 10;
  final List<double> _randomX = [];
  final List<double> _randomSize = [];
  final List<double> _randomDelay = [];

  @override
  void initState() {
    super.initState();
    final rand = Random();
    for (int i = 0; i < _particleCount; i++) {
      _randomX.add((rand.nextDouble() - 0.5) * 300);
      _randomSize.add(24 + rand.nextDouble() * 20);
      _randomDelay.add(rand.nextDouble() * 0.3);
    }

    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _controller.forward().then((_) => widget.onFinished());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            children: List.generate(_particleCount, (i) {
              double progress = (_controller.value - _randomDelay[i]) / (1 - _randomDelay[i]);
              if (progress < 0) progress = 0;
              if (progress > 1) progress = 1;

              final bottomOffset = 100 + (progress * 500);
              final opacity = 1.0 - progress;

              return Positioned(
                bottom: bottomOffset,
                left: (MediaQuery.of(context).size.width / 2) + _randomX[i] - (_randomSize[i] / 2),
                child: Opacity(
                  opacity: opacity,
                  child: Transform.rotate(
                    angle: progress * 3,
                    child: Icon(widget.icon, color: widget.color, size: _randomSize[i]),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}