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
  /// [openJTalkDictDir] OpenJtalkの辞書フォルダ。パッケージからは your_app/assets にアクセスできないので別の場所にコピーする必要がある
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

  /// テキストから AudioQuery を生成する
  ///
  /// [text] テキスト
  ///
  /// [styleId] スタイルID
  Future<String> textToAudioQuery({required String text, required int styleId}) async {
    await _initializationCompleter.future;
    return await _isolatedVoicevox.audioQuery(text, styleId);
  }

  /// AudioQuery から音声を生成する
  ///
  /// [audioQuery] jsonフォーマットされた AudioQuery
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

  /// pitchとlengthを再生成する。accentを変更したり、単語の区切り位置を変更した場合などに使う
  ///
  /// VOICEVOX Engineのエンドポイント "mora_data" と同じ機能。のはず。
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
