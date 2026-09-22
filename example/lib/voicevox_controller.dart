import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:voicevox_flutter/voicevox_flutter.dart';

import 'style_id_to_model_name.dart';

// パッケージから assets/ にアクセスできないことが判明したのでここでファイルを操作することにした

class VoicevoxFlutterController {
  final VoicevoxFlutter _voicevoxFlutter = VoicevoxFlutter();

  /// テキストから AudioQuery を生成する
  Future<String> textToAudioQuery({required String text, required int styleId}) async {
    await _initialize();
    await _prepareModel(styleId: styleId);
    final output = await _voicevoxFlutter.textToAudioQuery(text: text, styleId: styleId);
    return output;
  }

  /// AudioQuery から音声合成する
  Future<File> audioQueryToWav({required String audioQuery, required int styleId}) async {
    await _initialize();
    await _prepareModel(styleId: styleId);
    final wavFile = File('${(await getTemporaryDirectory()).path}/${audioQuery.hashCode}.wav');
    await _voicevoxFlutter.audioQueryToWav(audioQuery: audioQuery, styleId: styleId, output: wavFile);
    return wavFile;
  }

  /// 起動が完了するまで足止めしなければならない。Completerを使って通知してみる
  final _initializationCompleter = Completer();
  bool _hasInitializeStarted = false;

  /// voicevox_flutterを起動する
  Future<void> _initialize() async {
    if (_hasInitializeStarted == true) {
      await _initializationCompleter.future; // 起動が完了するまで待つ
      return;
    }

    _hasInitializeStarted = true;

    // アセットからアプリケーションディレクトリに`open_jtalk_dict`をコピーする
    final openJTalkDictDir = Directory('${(await getApplicationSupportDirectory()).path}/open_jtalk_dic_utf_8-1.11');
    openJTalkDictDir.createSync();

    final AssetManifest assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final openJTalkAssets = assetManifest
        .listAssets()
        .where((eachPath) => eachPath.startsWith('assets/open_jtalk_dic_utf_8-1.11'))
        .toList();

    for (final eachPath in openJTalkAssets) {
      final data = await rootBundle.load(eachPath);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final destFile = File('${openJTalkDictDir.path}/${p.basename(eachPath)}');
      await destFile.writeAsBytes(bytes);
    }

    await _voicevoxFlutter.initialize(openJTalkDictDir: openJTalkDictDir);

    _initializationCompleter.complete(); // しっかり報告する🫡
  }

  // オリチャー: モデルが必要になってからメモリ上に展開する
  final List<String> _loadedModelNames = [];

  /// 必要なVVMモデルを探してロードする関数。モデルが必要になる前に実行すること
  Future<void> _prepareModel({required int styleId}) async {
    await _initialize();
    final requiredModelName = styleIdToModelName[styleId];
    if (requiredModelName == null) {
      throw Exception('このstyleId: $styleIdに対応するvvmファイルがどれなのかわかりません😫 style_id_to_model_name.dartを更新してください。');
    }

    if (_loadedModelNames.contains(requiredModelName)) {
      return;
    }

    debugPrint('${DateTime.now()}😸VVMモデル$requiredModelNameが必要になったので読み込みます');

    // アセットからアプリケーションディレクトリに`model`をコピーする
    final data = await rootBundle.load('assets/model/$requiredModelName');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    final modelDir = Directory('${(await getTemporaryDirectory()).path}/model');
    await modelDir.create();

    final modelFile = File('${modelDir.path}/$requiredModelName');

    await modelFile.writeAsBytes(bytes);

    await _voicevoxFlutter.loadVoiceModel(modelFile: modelFile);

    debugPrint('${DateTime.now()}😹VVMモデル${modelFile.path}を読み込みました');
    _loadedModelNames.add(requiredModelName);
  }

  void dispose() {
    _voicevoxFlutter.dispose();
  }
}
