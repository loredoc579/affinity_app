import 'package:flutter/material.dart';

class ProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Expanded(
            child: Image.network(
              'https://example.com/photo.jpg',
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Anna, 28', style: TextStyle(fontSize: 24)),
                SizedBox(height: 4),
                Text('New York'),
                SizedBox(height: 8),
                Text('Ama ballare, viaggiare e la musica jazz.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}