import 'package:flutter/material.dart';

class SwipeCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onLike;
  final VoidCallback onNope;
  final VoidCallback onSuperlike;
  final VoidCallback onTap;

  const SwipeCard({
    required this.data,
    required this.onLike,
    required this.onNope,
    required this.onSuperlike,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(fit: StackFit.expand, children: [
        Image.network(data['photoUrls'][0], fit: BoxFit.cover),
        Positioned(
          bottom: 120, left: 16, right: 16,
          child: Text(
            '${data['name']}, ${data['age']} · ${data['lastCity']}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0,1))],
            ),
          ),
        ),
        Positioned(
          bottom: 16, left: 16, right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _actionButton(Icons.close, Colors.redAccent, onNope),
              _actionButton(Icons.star,  Colors.blueAccent, onSuperlike),
              _actionButton(Icons.favorite, Colors.green, onLike),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _actionButton(IconData icon, Color color, VoidCallback onTap) {
    return CircleAvatar(
      backgroundColor: color,
      child: IconButton(icon: Icon(icon, color: Colors.white), onPressed: onTap),
    );
  }
}