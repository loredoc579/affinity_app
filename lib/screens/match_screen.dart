import 'package:flutter/material.dart';
import '../widgets/safe_avatar.dart';
import 'chat_screen.dart';

class MatchScreen extends StatelessWidget {
  final String myPhotoUrl;
  final String otherPhotoUrl;
  final String otherName;
  final String otherUserId;
  final String chatId;

  const MatchScreen({
    Key? key,
    required this.myPhotoUrl,
    required this.otherPhotoUrl,
    required this.otherName,
    required this.otherUserId,
    required this.chatId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.85), // Sfondo semi-trasparente
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "IT'S A MATCH!",
              style: TextStyle(
                fontFamily: 'Impact',
                fontSize: 48,
                color: Colors.pinkAccent,
                letterSpacing: 2,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Tu e $otherName vi piacete a vicenda.",
              style: const TextStyle(fontSize: 18, color: Colors.white70),
            ),
            const SizedBox(height: 48),
            
            // Le due foto affiancate e leggermente inclinate
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.rotate(
                  angle: -0.1,
                  child: SafeAvatar(url: myPhotoUrl, radius: 60),
                ),
                const SizedBox(width: 16),
                Transform.rotate(
                  angle: 0.1,
                  child: SafeAvatar(url: otherPhotoUrl, radius: 60),
                ),
              ],
            ),
            const SizedBox(height: 60),
            
            // Bottone per andare in Chat
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                onPressed: () {
                  // Chiude la schermata Match e apre la Chat
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatId: chatId,
                        otherUserId: otherUserId,
                        otherUserName: otherName,
                        otherUserPhotoUrl: otherPhotoUrl,
                      ),
                    ),
                  );
                },
                child: const Text("Scrivi un messaggio", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            
            // Bottone per tornare a fare Swipe
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Continua a scorrere", style: TextStyle(fontSize: 16, color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }
}