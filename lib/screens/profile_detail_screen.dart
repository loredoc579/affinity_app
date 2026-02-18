import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../widgets/particle_overlay.dart';
import '../utils/translations.dart';

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

  Widget _buildVerticalImage(String url) {
    if (url.trim().isEmpty || !url.startsWith('http')) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: CachedNetworkImage(
          imageUrl: url,
          width: double.infinity,
          height: 450,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) => const SizedBox.shrink(),
        ),
      ),
    );
  }

 @override
  Widget build(BuildContext context) {
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
        if (data['bio'] != null && data['bio'].toString().isNotEmpty) ...[
          // USO DELLA CHIAVE: 'about_me'.tr
          Text('about_me'.tr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(data['bio'], style: const TextStyle(fontSize: 16, height: 1.4, color: Colors.black87)),
          const SizedBox(height: 20),
        ],

        // USO DELLA CHIAVE COMPOSITA: Etichetta + Dato + Fallback
        Text('${'lives_in'.tr}${ (data['location'] as Map?)?['city'] ?? 'not_available'.tr}', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        // QUI USIAMO ENTRAMBE LE EXTENSION!
        Text('${'gender_label'.tr}${(data['gender'] as String?)?.translateGender ?? 'not_available'.tr}', style: const TextStyle(fontSize: 16)),

        if (photo2 != null) _buildVerticalImage(photo2),

        if (hobbies.isNotEmpty) ...[
          // USO DELLA CHIAVE: 'hobbies_title'.tr
          Text('hobbies_title'.tr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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

        if (photo3 != null) _buildVerticalImage(photo3),

        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ParticleOverlay.show(context, icon: Icons.star, color: Colors.blueAccent);
                  onSuperlike?.call();
                },
                icon: const Icon(Icons.star, color: Colors.blueAccent),
                // USO DELLA CHIAVE: 'btn_superlike'.tr
                label: Text('btn_superlike'.tr, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.withOpacity(0.1),
                  elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ParticleOverlay.show(context, icon: Icons.favorite, color: Colors.green);
                  onLike?.call();
                },
                icon: const Icon(Icons.favorite, color: Colors.green),
                // USO DELLA CHIAVE: 'btn_like'.tr
                label: Text('btn_like'.tr, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.withOpacity(0.1),
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