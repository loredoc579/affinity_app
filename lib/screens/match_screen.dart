import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui'; // Serve per il BackdropFilter (sfocatura)

import 'chat_screen.dart';

class MatchScreen extends StatefulWidget {
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
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bgOpacity;
  late Animation<Offset> _leftAvatarSlide;
  late Animation<Offset> _rightAvatarSlide;
  late Animation<double> _contentScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // 1. Lo sfondo si scurisce subito
    _bgOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );

// 2. L'avatar di sinistra (Tu) entra scivolando e si ferma a SINISTRA del centro (-0.4)
    _leftAvatarSlide = Tween<Offset>(begin: const Offset(-2.0, 0.0), end: const Offset(-0.4, 0.0)).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.7, curve: Curves.elasticOut)),
    );

    // 3. L'avatar di destra (L'altro) entra scivolando e si ferma a DESTRA del centro (0.4)
    _rightAvatarSlide = Tween<Offset>(begin: const Offset(2.0, 0.0), end: const Offset(0.4, 0.0)).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 0.8, curve: Curves.elasticOut)),
    );

    // 4. I testi e i bottoni compaiono dal basso ingrandendosi
    _contentScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.6, 1.0, curve: Curves.elasticOut)),
    );

    _controller.forward(); // Fa partire l'animazione!
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildAvatar(String url) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(color: Colors.pink.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
        ],
        image: DecorationImage(
          image: CachedNetworkImageProvider(url),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Fondamentale per vedere l'app dietro!
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // --- SFONDO SFOCATO ---
              Opacity(
                opacity: _bgOpacity.value,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.black.withOpacity(0.7),
                  ),
                ),
              ),

              // --- CONTENUTO CENTRALE ---
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Scritta "IT'S A MATCH"
                  Transform.scale(
                    scale: _contentScale.value,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      // FittedBox costringe il testo a stare su una riga sola, rimpicciolendolo se necessario!
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: const Text(
                          "IT'S A MATCH!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Impact',
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Colors.pinkAccent,
                            letterSpacing: 2,
                            shadows: [Shadow(color: Colors.white54, blurRadius: 10, offset: Offset(0, 0))],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Sottotitolo
                  Transform.scale(
                    scale: _contentScale.value,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32), // Diamo respiro ai lati
                      child: Text(
                        "Tu e ${widget.otherName} vi piacete a vicenda.",
                        textAlign: TextAlign.center, // <-- FIX: Mantiene il testo centrato anche se va a capo!
                        style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 16, 
                          fontWeight: FontWeight.w500,
                          height: 1.3, // Leggermente più distanziato per leggibilità
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const SizedBox(height: 10),

                  // Le Foto che si scontrano
                  SizedBox(
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SlideTransition(
                          position: _leftAvatarSlide,
                          child: _buildAvatar(widget.myPhotoUrl),
                        ),
                        SlideTransition(
                          position: _rightAvatarSlide,
                          child: _buildAvatar(widget.otherPhotoUrl),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),

                  // Bottoni Azione
                  Transform.scale(
                    scale: _contentScale.value,
                    child: Column(
                      children: [
                        // Bottone Principale: Vai alla chat
                        ElevatedButton.icon(
                          onPressed: () {
                            // Chiude la schermata Match e apre la Chat
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  chatId: widget.chatId,
                                  otherUserId: widget.otherUserId,
                                  otherUserName: widget.otherName,
                                  otherUserPhotoUrl: widget.otherPhotoUrl,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.send, color: Colors.white),
                          label: Text("Scrivi a ${widget.otherName}"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pinkAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 8,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Bottone Secondario: Continua a giocare
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Continua a cercare",
                            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}