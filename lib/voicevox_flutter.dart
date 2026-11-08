import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:voicevox_flutter/thread_isolation.dart';

// たらい回しシステム: このファイル → thread_isolation → ffi_bridge → generated_bindings と、複数の層を経て "コア" に迫っていく構造😼
// このファイルの役割は？: かんたんに動かすための窓口。

class VoicevoxFlutter {
  late final ThreadIsolator _isolatedVoicevox;

  /// 起動が完了するまではメソッドが呼び出されても足止めしなければならない。Completerを使って通知してみる
  final _initializationCompleter = Completer();

  /// voicevox_flutterを起動する
  ///
  /// [openJTalkDictDir] OpenJtalkの辞書フォルダ。パッケージからは your_app/assets にアクセスできないので、別の場所にコピーする必要があります。
  Future<void> initialize({required Directory openJTalkDictDir}) async {
    _isolatedVoicevox = ThreadIsolator();
    await _isolatedVoicevox.initialize(openJTalkDictDir: openJTalkDictDir);
    _initializationCompleter.complete(); // しっかり報告する🫡
  }

  /// モデルを読み込む
  ///
  /// [modelFile] VVMファイル
  Future<void> loadVoiceModel({required File modelFile}) async {
    await _initializationCompleter.future; // 起動が完了するまで待つ
    await _isolatedVoicevox.loadModel(modelFile);
  }

  /// テキストからAudioQueryを生成する
  ///
  /// [text] テキスト
  ///
  /// [styleId] スタイルID
  Future<String> textToAudioQuery({required String text, required int styleId}) async {
    await _initializationCompleter.future;
    return await _isolatedVoicevox.audioQuery(text, styleId);
  }

  /// AudioQueryから音声を生成する
  ///
  /// [audioQuery] jsonフォーマットされたAudioQuery
  ///
  /// [styleId] スタイルID
  ///
  /// [output] 出力ファイル
  Future<void> audioQueryToWav({required String audioQuery, required int styleId, required File output}) async {
    await _initializationCompleter.future;
    final watch = Stopwatch()..start();
    await _isolatedVoicevox.synthesis(audioQuery, styleId, output);
    watch.stop();
    // 合成にかかった時間を表示する
    debugPrint('⭐${watch.elapsedMilliseconds}msで生成して${output.path}に保存しました');
  }

  /// AudioQueryから音声の長さを取得する
  ///
  /// [audioQuery] jsonフォーマットされたAudioQuery
  Future<Duration> audioQueryToAudioDuration({
    required String audioQuery,
  }) async {
    await _initializationCompleter.future;
    return await _isolatedVoicevox.audioQueryToAudioDuration(
      query: audioQuery,
    );
  }

  /// AudioQueryから音声をストリーミング生成する
  ///
  /// - RealTimeFactorが1未満の（1秒間の音声を1秒未満で生成できる）高速なデバイスでは、1つめのチャンクが返ったらすぐに再生を開始できます。
  /// - streamSubscription.cancel()で生成をキャンセルできます。streamSubscription.pause()は非対応です。
  ///
  /// [audioQuery] jsonフォーマットされたAudioQuery
  ///
  /// [styleId] スタイルID
  ///
  /// [start] 開始位置
  ///
  /// [end] 終了位置。nullの場合は末尾まで生成します。
  ///
  /// [chunkDuration] チャンクあたりの長さ。短くすると1つめのチャンクがより速く返りますが、オーバーヘッドが大きくなります。
  Stream<Uint8List> audioQueryToPCMStream({
    required String audioQuery,
    required int styleId,
    Duration start = Duration.zero,
    Duration? end,
    Duration chunkDuration = const Duration(milliseconds: 300),
  }) {
    if (start < Duration.zero) {
      throw ArgumentError.value(start, 'start', 'startは0以上である必要があります');
    }
    if (chunkDuration <= Duration.zero) {
      throw ArgumentError.value(chunkDuration, 'chunkDuration', 'chunkDurationは0より大きい必要があります');
    }
    if (end != null && end < start) {
      throw ArgumentError.value(end, 'end', 'endはstart以上である必要があります');
    }

    return _audioQueryToPCMStream(
      audioQuery: audioQuery,
      styleId: styleId,
      start: start,
      end: end,
      chunkDuration: chunkDuration,
    );
  }

  Stream<Uint8List> _audioQueryToPCMStream({
    required String audioQuery,
    required int styleId,
    required Duration start,
    required Duration? end,
    required Duration chunkDuration,
  }) async* {
    await _initializationCompleter.future;
    yield* _isolatedVoicevox.audioQueryToPCMStream(
      query: audioQuery,
      styleId: styleId,
      start: start,
      end: end,
      chunkDuration: chunkDuration,
    );
  }

  /// pitchとlengthを再生成する
  ///
  /// - accent位置を変更したり、単語の区切りを変更した場合などに使います。
  /// - VOICEVOX Engineのエンドポイント "mora_data" と同じ機能。のはず。
  ///
  /// [accentPhrases] AccentPhraseのリスト
  ///
  /// [styleId] スタイルID
  Future<String> inferPitchAndLength({required String accentPhrases, required int styleId}) async {
    await _initializationCompleter.future;
    return await _isolatedVoicevox.inferPitchAndLength(
      accentPhrases: accentPhrases,
      styleId: styleId,
    );
  }

  void dispose() {
    _isolatedVoicevox.dispose();
  }
}
