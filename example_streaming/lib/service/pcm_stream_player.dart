import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';

enum PlayerPlaybackState {
  stopped,
  playing,
  paused,
}

class PcmStreamPlayer {
  PcmStreamPlayer();

  FlutterSoundPlayer _soundPlayer = FlutterSoundPlayer();
  bool _isOpen = false;
  PlayerPlaybackState _state = PlayerPlaybackState.stopped;

  // 再生位置通知用コールバック
  void Function(Duration position)? onPositionChanged;
  void Function(PlayerPlaybackState state)? onStateChanged;

  StreamSubscription<PlaybackDisposition>? _progressSubscription;

  PlayerPlaybackState get state => _state;
  bool get isPlaying => _state == PlayerPlaybackState.playing;
  bool get isPaused => _state == PlayerPlaybackState.paused;
  bool get isStopped => _state == PlayerPlaybackState.stopped;

  /// ストリーム再生を開始する
  Future<void> startStream() async {
    await stop();
    await dispose();

    _soundPlayer = FlutterSoundPlayer();

    if (_isOpen) return;
    await _soundPlayer.openPlayer();
    await _soundPlayer.setSubscriptionDuration(const Duration(milliseconds: 50));
    _isOpen = true;

    await _soundPlayer.startPlayerFromStream(
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 24000,
      bufferSize: 1024,
      interleaved: true,
    );

    // 1. 再生開始ごとに購読間隔を設定
    await _soundPlayer.setSubscriptionDuration(const Duration(milliseconds: 100));

    // 2. 既存の購読があればキャンセルして再登録
    await _progressSubscription?.cancel();
    _progressSubscription = _soundPlayer.onProgress?.listen((event) {
      onPositionChanged?.call(event.position);
    });

    _setState(PlayerPlaybackState.playing);
  }

  /// PCMチャンクをプレイヤーのバッファへ追加する
  Future<void> feed(Uint8List chunk) async {
    if (_isOpen && _state != PlayerPlaybackState.stopped) {
      // await _soundPlayer.feedUint8FromStream(chunk);
      _soundPlayer.uint8ListSink?.add(chunk);
    }
  }

  /// 一時停止
  Future<void> pause() async {
    if (_state == PlayerPlaybackState.playing) {
      await _soundPlayer.pausePlayer();
      _setState(PlayerPlaybackState.paused);
    }
  }

  /// 再開
  Future<void> resume() async {
    if (_state == PlayerPlaybackState.paused) {
      await _soundPlayer.resumePlayer();
      _setState(PlayerPlaybackState.playing);
    }
  }

  /// 停止
  Future<void> stop() async {
    if (_isOpen && _state != PlayerPlaybackState.stopped) {
      // 停止時にサブスクリプションを破棄
      await _progressSubscription?.cancel();
      _progressSubscription = null;

      await _soundPlayer.stopPlayer();
      _setState(PlayerPlaybackState.stopped);
      onPositionChanged?.call(Duration.zero);
    }
  }

  void _setState(PlayerPlaybackState newState) {
    if (_state != newState) {
      _state = newState;
      onStateChanged?.call(_state);
    }
  }

  Future<void> dispose() async {
    await _progressSubscription?.cancel();
    if (_isOpen) {
      await _soundPlayer.closePlayer();
      _isOpen = false;
    }
  }
}
