import 'package:flutter/material.dart';
import '../controller/streaming_playback_controller.dart';
import 'widgets/buffered_seek_bar.dart';
import 'widgets/metrics_panel.dart';
import 'widgets/player_controls.dart';

class StreamingPlayerScreen extends StatefulWidget {
  const StreamingPlayerScreen({super.key});

  @override
  State<StreamingPlayerScreen> createState() => _StreamingPlayerScreenState();
}

class _StreamingPlayerScreenState extends State<StreamingPlayerScreen> {
  late final StreamingPlaybackController _streamingController;
  final TextEditingController _textEditingController = TextEditingController(
    text: 'ストリーミング音声合成のテストです。全体の合成完了を待たずに、生成された音声チャンクから順次再生を開始します。',
  );

  final int _styleId = 3; // ずんだもん (ノーマル)

  @override
  void initState() {
    super.initState();
    _streamingController = StreamingPlaybackController();
  }

  @override
  void dispose() {
    _streamingController.dispose();
    _textEditingController.dispose();
    super.dispose();
  }

  void _onPlay({Duration start = Duration.zero}) {
    _streamingController.startStreaming(text: _textEditingController.text, styleId: _styleId, start: start);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ストリーミング音声合成'),
      ),
      body: ListenableBuilder(
        listenable: _streamingController,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. テキスト入力エリア
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _textEditingController,
                            maxLines: 4,
                            minLines: 2,
                            decoration: const InputDecoration(
                              hintText: 'テキストを入力してください',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.all(12),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 例文チップ
                          Wrap(
                            spacing: 8,
                            children: [
                              ActionChip(
                                label: const Text('短文'),
                                onPressed: () {
                                  _textEditingController.text = 'ストリーミング音声合成のテストなのだ！';
                                },
                              ),
                              ActionChip(
                                label: const Text('標準文'),
                                onPressed: () {
                                  _textEditingController.text =
                                      'ストリーミング音声合成のテストです。全体の合成完了を待たずに、生成された音声チャンクから順次再生を開始します。';
                                },
                              ),
                              ActionChip(
                                label: const Text('長文'),
                                onPressed: () {
                                  _textEditingController.text =
                                      'あのイーハトーヴォのすきとおった風、夏でも底に冷たさをもつ青いそら、うつくしい森で飾られたモリーオ市、郊外のぎらぎらひかる草の波。またそのなかにおこるさまざまなこと、むかしの森の巨人のこと、植物油工場の不思議な様子、そこらじゅうに立ちこめる独特の匂い、そしてあのポラーノの広場のまつりのこと。';
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // 2. チャンクサイズ動的調整スライダー
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'チャンクサイズ (chunkDuration)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${_streamingController.chunkDuration.inMilliseconds} ms',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            min: 100,
                            max: 2000,
                            divisions: 19, // 100ms刻み
                            value: _streamingController.chunkDuration.inMilliseconds.toDouble(),
                            onChanged: (val) {
                              _streamingController.chunkDuration = Duration(milliseconds: val.round());
                            },
                          ),
                          Text(
                            'チャンクを小さくすると発話までの時間(TTFB)が短縮されますが、オーバーヘッドが大きくなり再生が途切れやすくなります。',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. パフォーマンス指標カード
                MetricsPanel(
                  timeToFirstByte: _streamingController.timeToFirstByte,
                  synthesisElapsed: _streamingController.synthesisElapsed,
                  totalDuration: _streamingController.totalDuration,
                  startOffset: _streamingController.startOffset,
                  chunkCount: _streamingController.chunkCount,
                  receivedBytes: _streamingController.receivedBytes,
                  isSynthesizing: _streamingController.isSynthesizing,
                ),

                const SizedBox(height: 8),

                // 4. 動画プレイヤー風プレイヤーエリア
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                      child: Column(
                        children: [
                          // ステータスバッジ
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(_streamingController.status, theme),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _streamingController.statusMessage,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // バッファ可視化シークバー
                          BufferedSeekBar(
                            totalDuration: _streamingController.totalDuration,
                            bufferedDuration: _streamingController.bufferedDuration,
                            currentPosition: _streamingController.currentPosition,
                            onSeek: (pos) => _onPlay(start: pos),
                          ),

                          const SizedBox(height: 16),

                          // プレイヤーコントロール
                          PlayerControls(
                            status: _streamingController.status,
                            onPlay: _onPlay,
                            onPause: () => _streamingController.pause(),
                            onResume: () => _streamingController.resume(),
                            onStop: () => _streamingController.stop(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(PlaybackStatus status, ThemeData theme) {
    switch (status) {
      case PlaybackStatus.synthesizing:
        return Colors.orange.shade700;
      case PlaybackStatus.playing:
        return Colors.green.shade700;
      case PlaybackStatus.paused:
        return Colors.blueGrey;
      case PlaybackStatus.completed:
        return theme.colorScheme.primary;
      case PlaybackStatus.error:
        return Colors.red.shade700;
      case PlaybackStatus.idle:
        return Colors.grey.shade600;
    }
  }
}
