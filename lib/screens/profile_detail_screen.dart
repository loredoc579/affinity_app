import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../widgets/particle_overlay.dart';
import '../utils/translations.dart';
import '../widgets/preferences_wrap.dart';

class ProfileDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onLike;
  final VoidCallback? onSuperlike;
  final bool isPreview;

  const ProfileDetailScreen({
    Key? key, 
    required this.data,
    this.onLike,
    this.onSuperlike,
    this.isPreview = false,
  }) : super(key: key);

  // Widget per le foto: ora è veramente "Edge-to-Edge"
  Widget _buildVerticalImage(BuildContext context, String url) {
    if (url.trim().isEmpty || !url.startsWith('http')) return const SizedBox.shrink();

    return CachedNetworkImage(
      imageUrl: url,
      width: double.infinity,
      height: MediaQuery.of(context).size.width * 1.25, // Proporzione 4:5
      fit: BoxFit.cover,
      errorWidget: (context, url, error) => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> photos = List<String>.from(data['photoUrls'] ?? []);
    final String? photo1 = photos.isNotEmpty ? photos[0] : null;
    final String? photo2 = photos.length > 1 ? photos[1] : null;
    final String? photo3 = photos.length > 2 ? photos[2] : null;

    // Gestione Hobbies Robusta
    List<String> hobbies = [];
    final dynamic hobbiesData = data['hobbies'];
    if (hobbiesData is List) {
      hobbies = hobbiesData.map((e) => e.toString()).toList();
    } else if (hobbiesData is String && hobbiesData.trim().isNotEmpty) {
      hobbies = hobbiesData.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    final relType = data['relationshipType'] as String?;
    final relGoal = data['relationshipGoal'] as String?;

    final bool isVerified = data['isVerified'] == true;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. FOTO PRINCIPALE (A TUTTO SCHERMO)
          if (photo1 != null && isPreview) _buildVerticalImage(context, photo1),

          // 2. CONTENUTO TESTUALE (CON PADDING)
          Padding(
            padding: const EdgeInsets.all(20.0), // Padding solo per i testi
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- NOME, ETÀ E SPUNTA BLU ---
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${data['name'] ?? '—'}, ${data['age'] ?? '—'}',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    // Se l'utente è verificato, mostriamo la spunta!
                    if (isVerified)
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Icon(Icons.verified, color: Colors.blue, size: 28),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Luogo e Genere
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${(data['location'] as Map?)?['city'] ?? 'not_available'.tr}', 
                         style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 20),

                // Sezione Bio
                if (data['bio'] != null && data['bio'].toString().isNotEmpty) ...[
                  Text('about_me'.tr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(data['bio'], style: const TextStyle(fontSize: 16, height: 1.4, color: Colors.black87)),
                  const SizedBox(height: 25),
                ],

                // Preferenze (Tipo relazione / Obiettivo)
                PreferencesWrap(relGoal: relGoal, relType: relType),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // 3. SECONDA FOTO (A TUTTO SCHERMO)
          if (photo2 != null) _buildVerticalImage(context, photo2),

          // 4. ALTRE INFO (CON PADDING)
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hobbies.isNotEmpty) ...[
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
                  const SizedBox(height: 25),
                ],
              ],
            ),
          ),

          // 5. TERZA FOTO E SUCCESSIVE
          if (photo3 != null) _buildVerticalImage(context, photo3),
          if (photos.length > 3)
            ...photos.skip(3).map((url) => _buildVerticalImage(context, url)).toList(),

          // 6. BOTTONI AZIONE (SE NON PREVIEW)
          if (!isPreview)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      context, 
                      icon: Icons.star, 
                      label: 'btn_superlike'.tr, 
                      color: Colors.blueAccent, 
                      onTap: onSuperlike
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      context, 
                      icon: Icons.favorite, 
                      label: 'btn_like'.tr, 
                      color: Colors.green, 
                      onTap: onLike
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  // Piccolo helper per pulire il codice dei bottoni
  Widget _buildActionButton(BuildContext context, {required IconData icon, required String label, required Color color, VoidCallback? onTap}) {
    return ElevatedButton.icon(
      onPressed: () {
        ParticleOverlay.show(context, icon: icon, color: color);
        onTap?.call();
      },
      icon: Icon(icon, color: color),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        elevation: 0, 
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}