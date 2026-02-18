import 'package:flutter/material.dart';

class SafeAvatar extends StatelessWidget {
  final String? url;
  final double radius;

  const SafeAvatar({super.key, this.url, this.radius = 20.0});

  @override
  Widget build(BuildContext context) {
    // 1. Controlliamo se l'URL è valido, non nullo e inizia con http/https
    final bool isValidUrl = url != null && url!.trim().isNotEmpty && url!.trim().startsWith(RegExp(r'https?://'));

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      // 2. Se è valido lo carichiamo, altrimenti passiamo null al backgroundImage
      backgroundImage: isValidUrl ? NetworkImage(url!.trim()) : null,
      // 3. Se NON è valido, mostriamo un'icona
      child: !isValidUrl ? Icon(Icons.person, color: Colors.white, size: radius) : null,
    );
  }
}