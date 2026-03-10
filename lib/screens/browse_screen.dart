import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'filtered_users_screen.dart'; 
import '../widgets/heart_progress_indicator.dart';

class BrowseScreen extends StatelessWidget {
  const BrowseScreen({Key? key}) : super(key: key);

  // --- HELPER: Converte il nome stringa (da DB) in un'icona Flutter ---
  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'favorite': return Icons.favorite;
      case 'cafe': return Icons.local_cafe;
      case 'sports': return Icons.sports_tennis;
      case 'party': return Icons.nightlife;
      case 'people': return Icons.people_alt;
      case 'explore': return Icons.explore;
      default: return Icons.grid_view;
    }
  }

  // --- HELPER: Converte il codice HEX (da DB) in un Colore Flutter ---
  Color _getColorFromHex(String? hexColor) {
    if (hexColor == null || !hexColor.startsWith('#')) return Colors.pink;
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xff')));
    } catch (e) {
      return Colors.pink;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cosa stai cercando?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            // --- STREAMBUILDER: Legge le categorie da Firebase in tempo reale ---
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('browse_categories')
                  .orderBy('order') // Le ordiniamo come preferisci tu
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: HeartProgressIndicator(size: 40));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Nessuna categoria disponibile"));
                }

                final categories = snapshot.data!.docs;

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index].data();
                    
                    return _buildCategoryCard(
                      context,
                      title: cat['title'] ?? '—',
                      keyword: cat['keyword'] ?? 'all',
                      icon: _getIconData(cat['iconName']),
                      color: _getColorFromHex(cat['colorHex']),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, {
    required String title,
    required String keyword,
    required IconData icon,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FilteredUsersScreen(
              categoryTitle: title,
              interestKeyword: keyword,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20), // Angoli più tondi, più moderni
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icona con un leggero sfondo circolare
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}