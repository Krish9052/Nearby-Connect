import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class VoiceMessageBubble extends StatefulWidget {
  final String voiceUrl;
  final bool me;

  const VoiceMessageBubble({
    super.key,
    required this.voiceUrl,
    required this.me,
  });

  @override
  State<VoiceMessageBubble> createState() =>
      _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {

  final AudioPlayer player = AudioPlayer();

  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  bool isPlaying = false;

  @override
  void initState() {
    super.initState();

    player.positionStream.listen((p) {
      if (mounted) {
        setState(() {
          position = p;
        });
      }
    });

    player.durationStream.listen((d) {
      if (mounted && d != null) {
        setState(() {
          duration = d;
        });
      }
    });

    player.playerStateStream.listen((state) {
      if (!mounted) return;

      setState(() {
        isPlaying = state.playing;
      });

      if (state.processingState == ProcessingState.completed) {
        setState(() {
          isPlaying = false;
          position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

@override
Widget build(BuildContext context) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: widget.me ? Colors.purple.shade300 : Colors.white12,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
          ),
          onPressed: () async {
            if (isPlaying) {
              await player.pause();
            } else {
              await player.setUrl(widget.voiceUrl);
              await player.play();
            }
          },
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 180,
              child: Slider(
                value: position.inSeconds
                    .toDouble()
                    .clamp(
                      0.0,
                      duration.inSeconds > 0
                          ? duration.inSeconds.toDouble()
                          : 1.0,
                    ),
                max: duration.inSeconds > 0
                    ? duration.inSeconds.toDouble()
                    : 1,
                onChanged: (value) async {
                  await player.seek(
                    Duration(seconds: value.toInt()),
                  );
                },
              ),
            ),
        
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _formatDuration(duration),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
}