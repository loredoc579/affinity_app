import 'package:flutter/material.dart';

/// Schermata di dettaglio profilo
class ProfileDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const ProfileDetailScreen({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      children: [
            // Immagine profilo a piena larghezza
            if (data['photoUrl'] != null)
              Image.network(
                data['photoUrl'],
                height: 300,
                fit: BoxFit.cover,
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${data['age'] ?? ''} anni',
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Genere: ${data['gender'] ?? ''}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Città: ${data['lastCity'] ?? ''}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Hobby e passioni',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: (data['hobbies'] as String?)
                            ?.split(', ')
                            .map((h) => Chip(label: Text(h)))
                            .toList() ?? [],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Esempio: inviargli un like direttamente da dettaglio
                      Navigator.pop(context, true);
                    },
                    icon: const Icon(Icons.favorite),
                    label: const Text('Mi piace'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
  }
}
