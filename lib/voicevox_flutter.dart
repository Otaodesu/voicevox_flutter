import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:voicevox_flutter/thread_isolation.dart';

// たらい回しシステム: このファイル → thread_isolation → ffi_bridge → generated_bindings と、複数の層を経て "コア" に迫っていく構造😼
// このファイルの役割は？: かんたんに動かすための窓口。

class VoicevoxFlutter {
  late final NativeVoiceService service;

  /// 起動が完了するまではメソッドが呼び出されても足止めしなければならない。Completerを使って通知してみる
  final _initializationCompleter = Completer();

  /// voicevox_flutterを起動する
  Future<void> initialize({required Directory openJTalkDictDir}) async {
    service = NativeVoiceService();
    await service.initialize(openJTalkDictDir: openJTalkDictDir);
    _initializationCompleter.complete(); // しっかり報告する🫡
  }

  /// モデルを読み込む
  Future<void> loadVoiceModel({required File modelFile}) async {
    await _initializationCompleter.future; // 起動が完了するまで待つ
    await service.loadModel(modelFile);
  }

  /// テキストから AudioQuery を生成する
  Future<String> textToAudioQuery({required String text, required int styleId}) async {
    await _initializationCompleter.future;
    return await service.audioQuery(text, styleId);
  }

  /// AudioQuery から音声を生成する
  Future<void> audioQueryToWav({required String audioQuery, required int styleId, required File output}) async {
    await _initializationCompleter.future;
    final watch = Stopwatch()..start();
    await service.synthesis(audioQuery, styleId, output);
    watch.stop();
    // 合成にかかった時間を表示する
    debugPrint('⭐${watch.elapsedMilliseconds}msで生成して${output.path}に保存しました');
  }

  void dispose() {
    service.dispose();
  }
}
