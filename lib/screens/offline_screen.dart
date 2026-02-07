import 'package:flutter/material.dart';

class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.wifi_off, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Sei offline',
              style: TextStyle(fontSize: 24, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Controlla la connessione e riprova',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
