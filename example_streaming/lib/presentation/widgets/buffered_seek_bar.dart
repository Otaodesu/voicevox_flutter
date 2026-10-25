import 'dart:math' as math;
import 'package:flutter/material.dart';

class BufferedSeekBar extends StatefulWidget {
  const BufferedSeekBar({
    super.key,
    required this.totalDuration,
    required this.bufferedDuration,
    required this.currentPosition,
    required this.onSeek,
  });

  final Duration totalDuration;
  final Duration bufferedDuration;
  final Duration currentPosition;
  final ValueChanged<Duration> onSeek;

  @override
  State<BufferedSeekBar> createState() => _BufferedSeekBarState();
}

class _BufferedSeekBarState extends State<BufferedSeekBar> {
  double? _dragValue;

  // ミリ秒を小数第一位までの秒数文字列にフォーマット (例: 12.3s)
  String _formatSeconds(double milliseconds) {
    final seconds = milliseconds / 1000.0;
    return '${seconds.toStringAsFixed(1)}s';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.totalDuration.inMilliseconds.toDouble();
    final bufferedMs = widget.bufferedDuration.inMilliseconds.toDouble();
    final currentMs = _dragValue ?? widget.currentPosition.inMilliseconds.toDouble();

    // バッファ残量（マイナスにならないよう 0 でクリップ）
    final remainingBufferMs = math.max(0.0, bufferedMs - currentMs);

    final maxVal = totalMs > 0 ? totalMs : 1.0;
    final bufferedRatio = (bufferedMs / maxVal).clamp(0.0, 1.0);
    final sliderVal = currentMs.clamp(0.0, maxVal);

    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    const labelStyle = TextStyle(
      fontSize: 12,
      color: Colors.grey,
    );

    final valueStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: Colors.grey.shade700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 現在位置
              Column(
                children: [
                  const Text('現在位置', style: labelStyle),
                  const SizedBox(height: 2),
                  Text(_formatSeconds(currentMs), style: valueStyle),
                ],
              ),
              // バッファ残量
              Column(
                children: [
                  const Text('バッファ残量', style: labelStyle),
                  const SizedBox(height: 2),
                  Text(_formatSeconds(remainingBufferMs), style: valueStyle),
                ],
              ),
              // 合計時間
              Column(
                children: [
                  const Text('合計時間', style: labelStyle),
                  const SizedBox(height: 2),
                  Text(_formatSeconds(totalMs), style: valueStyle),
                ],
              ),
            ],
          ),
        ),
        Stack(
          alignment: Alignment.centerLeft,
          children: [
            // 背景トラック
            Container(
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // バッファ済みバー (半透明アクセント色)
            LayoutBuilder(
              builder: (context, constraints) {
                final trackWidth = constraints.maxWidth - 48;
                return Container(
                  height: 6,
                  width: trackWidth * bufferedRatio,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              },
            ),
            // 再生スライダー
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                activeTrackColor: primaryColor,
                inactiveTrackColor: Colors.transparent,
                thumbColor: primaryColor,
                overlayColor: primaryColor.withValues(alpha: 0.15),
              ),
              child: Slider(
                min: 0.0,
                max: maxVal,
                value: sliderVal,
                onChanged: (val) {
                  setState(() {
                    _dragValue = val;
                  });
                },
                onChangeEnd: (val) {
                  widget.onSeek(Duration(milliseconds: val.round()));
                  setState(() {
                    _dragValue = null;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
