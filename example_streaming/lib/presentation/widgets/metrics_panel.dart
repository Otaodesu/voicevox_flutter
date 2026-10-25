import 'package:flutter/material.dart';

class MetricsPanel extends StatelessWidget {
  const MetricsPanel({
    super.key,
    required this.timeToFirstByte,
    required this.synthesisElapsed,
    required this.totalDuration,
    required this.startOffset,
    required this.chunkCount,
    required this.receivedBytes,
    required this.isSynthesizing,
  });

  final Duration? timeToFirstByte;
  final Duration? synthesisElapsed;
  final Duration totalDuration;
  final Duration startOffset;
  final int chunkCount;
  final int receivedBytes;
  final bool isSynthesizing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String realTimeFactor = '-';

    // RTF（Real Time Factor）
    if (synthesisElapsed != null && synthesisElapsed! > Duration.zero && totalDuration > Duration.zero) {
      final audioDuration = totalDuration - startOffset; // シーク時のオフセットを考慮して生成した音声の長さを算出
      final rtf = synthesisElapsed!.inMilliseconds / audioDuration.inMilliseconds;
      realTimeFactor = rtf.toStringAsFixed(2); // 例: 0.85
    }

    final kb = (receivedBytes / 1024).toStringAsFixed(1);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'パフォーマンス指標',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MetricItem(
                  label: 'TTFB (発話開始遅延)',
                  value: timeToFirstByte != null ? '${timeToFirstByte!.inMilliseconds} ms' : '-',
                  color: Colors.green.shade700,
                  tooltip: '音声合成要求から最初のPCMチャンクが届くまでの時間',
                ),
                _MetricItem(
                  label: '全合成時間',
                  value: synthesisElapsed != null ? '${synthesisElapsed!.inMilliseconds} ms' : '-',
                  color: Colors.blue.shade700,
                  tooltip: 'すべての音声チャンクの生成が完了するまでの時間',
                ),
                _MetricItem(
                  label: 'RTF (実時間係数)',
                  value: realTimeFactor,
                  color: Colors.purple.shade700,
                  tooltip: '音声に対しての生成時間の比率 (処理時間 ÷ 音声長)',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '受信チャンク数: $chunkCount',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                  Text(
                    '総データ量: $kb KB',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.value,
    required this.color,
    required this.tooltip,
  });

  final String label;
  final String value;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
