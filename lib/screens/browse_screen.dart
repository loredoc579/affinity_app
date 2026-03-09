import 'package:flutter/material.dart';
import 'filtered_users_screen.dart'; 

class BrowseScreen extends StatelessWidget {
  const BrowseScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Abbiamo aggiunto "Tutti i profili" come prima opzione!
    final List<Map<String, dynamic>> categories = [
      {'title': 'Tutti i profili', 'keyword': 'all', 'icon': Icons.people_alt, 'color': Colors.blue},
      {'title': 'Amore vero', 'keyword': 'amore', 'icon': Icons.favorite, 'color': Colors.redAccent},
      {'title': 'Un caffè', 'keyword': 'caffè', 'icon': Icons.local_cafe, 'color': Colors.brown},
      {'title': 'Sport', 'keyword': 'sport', 'icon': Icons.sports_tennis, 'color': Colors.green},
      {'title': 'Serata', 'keyword': 'festa', 'icon': Icons.nightlife, 'color': Colors.purpleAccent},
    ];

    return Padding( // <-- NIENTE SCAFFOLD, NIENTE APPBAR! Solo il contenuto.
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cosa stai cercando?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                return _buildCategoryCard(
                  context,
                  title: cat['title'],
                  keyword: cat['keyword'],
                  icon: cat['icon'],
                  color: cat['color'],
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
        // Naviga alla pagina dei risultati
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
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