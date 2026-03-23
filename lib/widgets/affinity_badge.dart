import 'package:flutter/material.dart';

class AffinityBadge extends StatelessWidget {
  final int score;

  const AffinityBadge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    //if (score <= 0) return const SizedBox.shrink(); // Non mostrare nulla se 0

    // Definiamo il colore in base al punteggio
    final bool isHighAffinity = score >= 70;
    final Color badgeColor = isHighAffinity 
        ? Colors.pink.withOpacity(0.9) 
        : Colors.black.withOpacity(0.6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHighAffinity ? Icons.bolt : Icons.insights,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            "$score% Affinità",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}