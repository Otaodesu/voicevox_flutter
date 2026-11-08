import 'dart:async';

import 'package:flutter/foundation.dart';
import '../service/pcm_stream_player.dart';
import '../service/voicevox_service.dart';

enum PlaybackStatus {
  idle,
  synthesizing,
  playing,
  paused,
  completed,
  error,
}

class StreamingPlaybackController extends ChangeNotifier {
  StreamingPlaybackController({
    VoicevoxService? voicevoxService,
    PcmStreamPlayer? player,
  })  : _voicevox = voicevoxService ?? VoicevoxService(),
        _player = player ?? PcmStreamPlayer() {
    _initPlayerCallbacks();
  }

  final VoicevoxService _voicevox;
  final PcmStreamPlayer _player;

  // 再生・合成ステータス
  PlaybackStatus _status = PlaybackStatus.idle;
  PlaybackStatus get status => _status;

  String _statusMessage = '待機中';
  String get statusMessage => _statusMessage;

  // チャンク時間設定
  // Androidの実機で300msだとスペックが足りず途切れまくる。あと800msは75フレームなのでキリがよさげ感
  Duration _chunkDuration = const Duration(milliseconds: 800);
  Duration get chunkDuration => _chunkDuration;
  set chunkDuration(Duration value) {
    if (_chunkDuration != value) {
      _chunkDuration = value;
      notifyListeners();
    }
  }

  // 時間情報 (シークバー用)
  Duration _totalDuration = Duration.zero;
  Duration get totalDuration => _totalDuration;

  Duration _bufferedDuration = Duration.zero;
  Duration get bufferedDuration => _bufferedDuration;

  Duration _currentPosition = Duration.zero;
  Duration get currentPosition => _currentPosition;

  // パフォーマンス計測値
  Duration? _timeToFirstByte;
  Duration? get timeToFirstByte => _timeToFirstByte;

  Duration? _synthesisElapsed;
  Duration? get synthesisElapsed => _synthesisElapsed;

  int _chunkCount = 0;
  int get chunkCount => _chunkCount;

  int _receivedBytes = 0;
  int get receivedBytes => _receivedBytes;

  bool _isSynthesizing = false;
  bool get isSynthesizing => _isSynthesizing;

  /// シークしたときのストリーミング開始位置のオフセット
  Duration _startOffset = Duration.zero;
  Duration get startOffset => _startOffset;

  /// ストリーミングの開始時刻をキーとして、同時に1つのストリーミングしか動かないよう制御する
  DateTime? _synthesisStartTime;

  void _initPlayerCallbacks() {
    _player.onPositionChanged = (position) {
      // プレイヤー内部の再生位置 (0秒起点) に startOffset を加算して全体の再生位置を算出
      _currentPosition = _startOffset + position;
      if (_totalDuration > Duration.zero && _currentPosition >= _totalDuration) {
        _currentPosition = _totalDuration;
        _status = PlaybackStatus.completed;
      }
      notifyListeners();
    };

    _player.onStateChanged = (state) {
      switch (state) {
        case PlayerPlaybackState.playing:
          _status = PlaybackStatus.playing;
        case PlayerPlaybackState.paused:
          _status = PlaybackStatus.paused;
        case PlayerPlaybackState.stopped:
          if (_status != PlaybackStatus.idle && _status != PlaybackStatus.error) {
            _status = PlaybackStatus.idle;
          }
      }
      notifyListeners();
    };
  }

  /// ストリーミング再生を開始する
  /// [start]: 再生開始位置（シーク位置）。途中から再生する場合に指定します。
  Future<void> startStreaming({
    required String text,
    required int styleId,
    Duration start = Duration.zero,
  }) async {
    if (text.trim().isEmpty) return;

    // 負の値が渡された場合は 0 に補正
    _startOffset = start < Duration.zero ? Duration.zero : start;

    await _player.stop();

    final myStartTime = DateTime.now();
    _synthesisStartTime = myStartTime;

    _status = PlaybackStatus.synthesizing;
    _statusMessage = 'テキスト解析 & AudioQuery 生成中...';
    _isSynthesizing = true;
    _timeToFirstByte = null;
    _synthesisElapsed = null;
    _chunkCount = 0;
    _receivedBytes = 0;
    _bufferedDuration = _startOffset;
    _currentPosition = _startOffset;
    notifyListeners();

    try {
      // 1. AudioQuery 生成
      final audioQuery = await _voicevox.textToAudioQuery(
        text: text,
        styleId: styleId,
      );

      // 2. 音声の総尺を取得 (シークバーの最大値として使用)
      _totalDuration = await _voicevox.audioQueryToAudioDuration(
        audioQuery: audioQuery,
      );

      // 開始位置が総尺を超えている場合のガード
      if (_startOffset >= _totalDuration && _totalDuration > Duration.zero) {
        _status = PlaybackStatus.completed;
        _statusMessage = '再生完了';
        _currentPosition = _totalDuration;
        _isSynthesizing = false;
        notifyListeners();
        return;
      }

      _statusMessage = 'ストリーミング合成中...';
      notifyListeners();

      // 3. 指定の開始位置 (start) からストリーミング音声合成の購読開始
      final stream = _voicevox.audioQueryToPCMStream(
        audioQuery: audioQuery,
        styleId: styleId,
        chunkDuration: _chunkDuration,
        start: _startOffset,
      );

      try {
        await for (final chunk in stream) {
          // 停止したりシークしたときには自分の開始時刻と異なる時刻が [_synthesisStartTime] に入る
          if (_synthesisStartTime != myStartTime) {
            break;
          }

          _chunkCount++;

          if (_chunkCount == 1) {
            _timeToFirstByte = DateTime.now().difference(myStartTime);

            // 4. プレイヤー起動
            await _player.startStream();
            _statusMessage = '再生中 (ストリーミング受信中)';
          }

          _receivedBytes += chunk.length;

          final bufferedSeconds = _receivedBytes / (24000 * 2); // 24000Hz, 16bit(2bytes), 1ch
          // バッファされた時間も [startOffset] を考慮して計算
          _bufferedDuration = _startOffset + Duration(milliseconds: (bufferedSeconds * 1000).round());
          if (_bufferedDuration > _totalDuration && _totalDuration > Duration.zero) {
            _bufferedDuration = _totalDuration;
          }

          // プレイヤーにチャンクを流し込む
          await _player.feed(chunk);
          notifyListeners();
        }

        // 最後まで生成完了したパターン
        if (_synthesisStartTime == myStartTime) {
          _isSynthesizing = false;
          _synthesisElapsed = DateTime.now().difference(myStartTime);
          _statusMessage = '全チャンク受信完了';
          notifyListeners();
        }
      } catch (error) {
        _status = PlaybackStatus.error;
        _statusMessage = 'エラー発生: $error';
        _isSynthesizing = false;
        notifyListeners();
      }
    } catch (e) {
      _status = PlaybackStatus.error;
      _statusMessage = '開始失敗: $e';
      _isSynthesizing = false;
      notifyListeners();
    }
  }

  /// 一時停止
  Future<void> pause() async {
    await _player.pause();
    _statusMessage = '一時停止中';
    notifyListeners();
  }

  /// 再開
  Future<void> resume() async {
    await _player.resume();
    _statusMessage = _isSynthesizing ? '再生中 (ストリーミング受信中)' : '再生中';
    notifyListeners();
  }

  /// 停止（生成・再生のキャンセル）
  Future<void> stop() async {
    _synthesisStartTime = null; // 生成を止める
    _isSynthesizing = false;

    await _player.stop();

    _status = PlaybackStatus.idle;
    _statusMessage = '停止';
    _startOffset = Duration.zero;
    _currentPosition = Duration.zero;
    _bufferedDuration = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _synthesisStartTime = null;
    _player.dispose();
    _voicevox.dispose();
    super.dispose();
  }
}
