import 'package:flutter/material.dart';
import '../../controller/streaming_playback_controller.dart';

class PlayerControls extends StatelessWidget {
  const PlayerControls({
    super.key,
    required this.status,
    required this.onPlay,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  final PlaybackStatus status;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPlaying = status == PlaybackStatus.playing;
    final isPaused = status == PlaybackStatus.paused;
    final isSynthesizing = status == PlaybackStatus.synthesizing;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(width: 48),
        // メイン再生 / 一時停止ボタン
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            iconSize: 42,
            color: Colors.white,
            icon: isSynthesizing
                ? const SizedBox(
                    width: 42,
                    height: 42,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      color: Colors.white,
                      padding: EdgeInsets.all(6),
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
            onPressed: isSynthesizing
                ? null
                : () {
                    if (isPlaying) {
                      onPause();
                    } else if (isPaused) {
                      onResume();
                    } else {
                      onPlay();
                    }
                  },
          ),
        ),
        const SizedBox(width: 16),
        // 停止ボタン
        IconButton(
          icon: const Icon(Icons.stop),
          iconSize: 36,
          color: Colors.red.shade700,
          onPressed: (isPlaying || isPaused || isSynthesizing) ? onStop : null,
        ),
      ],
    );
  }
}
