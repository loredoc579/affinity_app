import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SafeAvatar extends StatelessWidget {
  final String url;
  final double radius;

  const SafeAvatar({Key? key, required this.url, required this.radius}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade300,
        child: Icon(Icons.person, size: radius, color: Colors.white),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: radius,
        backgroundImage: imageProvider,
      ),
      // Mostra un pallino di caricamento mentre la scarica la prima volta
      placeholder: (context, url) => CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade200,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
      // Se l'URL è rotto, mostra un'icona di errore
      errorWidget: (context, url, error) => CircleAvatar(
        radius: radius,
        backgroundColor: Colors.red.shade100,
        child: const Icon(Icons.error, color: Colors.red),
      ),
    );
  }
}