import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

// --- CLASSE PRINCIPALE ---
class AudioBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  final List<dynamic>? amplitudes; // <--- NUOVO PARAMETRO
  final int? durationSeconds;

  const AudioBubble({super.key, required this.audioUrl, required this.isMe, this.amplitudes, this.durationSeconds,});

  @override
  State<AudioBubble> createState() => _AudioBubbleState();
}

// --- CLASSE DELLO STATO (Con velocità 1.5x e 2x) ---
class _AudioBubbleState extends State<AudioBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  
  double _playbackSpeed = 1.0; 

  String _formatTimer(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero; // Riporta il pallino all'inizio quando finisce!
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.setPlaybackRate(_playbackSpeed); 
      await _audioPlayer.play(UrlSource(widget.audioUrl));
    }
  }

  void _changeSpeed() {
    setState(() {
      if (_playbackSpeed == 1.0) _playbackSpeed = 1.5;
      else if (_playbackSpeed == 1.5) _playbackSpeed = 2.0;
      else _playbackSpeed = 1.0;
    });
    if (_isPlaying) _audioPlayer.setPlaybackRate(_playbackSpeed);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMe ? Colors.white : Colors.black87;
    final hasWaves = widget.amplitudes != null && widget.amplitudes!.isNotEmpty;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
          color: color,
          iconSize: 36,
          onPressed: _togglePlay,
          padding: EdgeInsets.zero,
        ),
        // Mini barra di progresso
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // LIVELLO 1: Le Onde (Sfondo) auto-adattanti!
              if (hasWaves)
                Padding( // <--- AGGIUNTO PADDING PER ALLINEARE LE ONDE ALLO SLIDER
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: widget.amplitudes!.map((amp) {
                      double val = (amp is num) ? amp.toDouble() : 0.1;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          height: 30 * val, 
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.4), 
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              // LIVELLO 2: Il cursore interattivo (Trasparente se ci sono le onde)
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  // Nasconde la riga brutta se abbiamo il grafico a onde
                  activeTrackColor: hasWaves ? Colors.transparent : color,
                  inactiveTrackColor: hasWaves ? Colors.transparent : color.withOpacity(0.3),
                  thumbColor: color, // Mantiene il pallino visibile
                ),
                child: Slider(
                  min: 0,
                  max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                  value: _position.inMilliseconds.toDouble().clamp(0, _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0),
                  onChanged: (value) async {
                    final position = Duration(milliseconds: value.toInt());
                    await _audioPlayer.seek(position);
                  },
                ),
              ),
            ],
          ),
        ),

        // --- NUOVO: IL TIMER DINAMICO ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            // Se sta riproducendo, mostra la posizione attuale. Altrimenti mostra la durata totale pre-salvata.
            _position.inMilliseconds > 0 
                ? _formatTimer(_position) 
                : _formatTimer(Duration(seconds: widget.durationSeconds ?? _duration.inSeconds)),
            style: TextStyle(
              color: color.withOpacity(0.8), 
              fontSize: 11, 
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()], // Evita che il testo "balli" mentre i numeri cambiano
            ),
          ),
        ),
        
        // --- BOTTONE VELOCITÀ ---
        GestureDetector(
          onTap: _changeSpeed,
          child: Container(
            margin: const EdgeInsets.only(right: 8, left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_playbackSpeed}x',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}