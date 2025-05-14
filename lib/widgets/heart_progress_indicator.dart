import 'package:flutter/material.dart';

/// A custom progress indicator that displays a pulsating heart icon,
/// suitable for Affinity/dating/love themes, replacing the default CircularProgressIndicator.
class HeartProgressIndicator extends StatefulWidget {
  /// Size of the heart icon.
  final double size;
  /// Color of the heart icon.
  final Color color;

  const HeartProgressIndicator({
    Key? key,
    this.size = 48.0,
    this.color = Colors.red,
  }) : super(key: key);

  @override
  _HeartProgressIndicatorState createState() => _HeartProgressIndicatorState();
}

class _HeartProgressIndicatorState extends State<HeartProgressIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Icon(
          Icons.favorite,
          size: widget.size,
          color: widget.color,
        ),
      ),
    );
  }
}

// Example usage:
// Replace CircularProgressIndicator() with HeartProgressIndicator(
//   size: 60,
//   color: Theme.of(context).accentColor,
// );
