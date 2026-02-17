import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onLike;
  final VoidCallback? onSuperlike;

  const ProfileDetailScreen({
    Key? key, 
    required this.data,
    this.onLike,
    this.onSuperlike,
  }) : super(key: key);

  // Helper per le immagini secondarie
  Widget _buildVerticalImage(String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: CachedNetworkImage(
          imageUrl: url,
          width: double.infinity,
          height: 450,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(height: 450, color: Colors.grey[100], child: const Center(child: CircularProgressIndicator())),
          errorWidget: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Recupero foto (saltando la prima che è già in cima alla carta)
    final List<String> photos = List<String>.from(data['photoUrls'] ?? []);
    final String? photo2 = photos.length > 1 ? photos[1] : null;
    final String? photo3 = photos.length > 2 ? photos[2] : null;

    final String hobbiesStr = data['hobbies'] ?? '';
    final List<String> hobbies = hobbiesStr.isNotEmpty 
        ? hobbiesStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() 
        : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // BIO
        if (data['bio'] != null && data['bio'].toString().isNotEmpty) ...[
          const Text('Su di me', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(data['bio'], style: const TextStyle(fontSize: 16, height: 1.4, color: Colors.black87)),
          const SizedBox(height: 20),
        ],

        // INFO EXTRA
        Text('📍 Vive a ${ (data['location'] as Map?)?['city'] ?? 'N.D.'}', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Text('🚻 Genere: ${data['gender'] ?? 'N.D.'}', style: const TextStyle(fontSize: 16)),

        // FOTO 2 (Prima degli hobby)
        if (photo2 != null) _buildVerticalImage(photo2),

        // HOBBY
        if (hobbies.isNotEmpty) ...[
          const Text('Hobby e passioni', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: hobbies.map((h) => Chip(
              label: Text(h, style: const TextStyle(color: Colors.pink, fontWeight: FontWeight.w600)),
              backgroundColor: Colors.pink.withOpacity(0.05),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            )).toList(),
          ),
          const SizedBox(height: 20),
        ],

        // FOTO 3 (Prima dei pulsanti)
        if (photo3 != null) _buildVerticalImage(photo3),

        // BOTTONI FINALI
        const SizedBox(height: 10),
        Row(
          children: [
            // SUPERLIKE
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onSuperlike,
                icon: const Icon(Icons.star, color: Colors.blueAccent),
                label: const Text('SUPERLIKE', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.withOpacity(0.1),
                  elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // LIKE (Verde su verdino chiaro)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onLike,
                icon: const Icon(Icons.favorite, color: Colors.green),
                label: const Text('MI PIACE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.withOpacity(0.1), // <--- FIX COLORE RICHIESTO
                  elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}