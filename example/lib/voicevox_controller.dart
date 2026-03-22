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
  late final VoicevoxFlutter _voicevoxFlutter;

  // オリチャー: モデルが必要になってからメモリ上に展開する
  final List<String> _loadedModelNames = [];

  /// late変数の初期化が完了するまでは足止めしなければならない。Completerを使って通知してみる
  final _initializationCompleter = Completer();

  /// voicevox_flutterを起動する
  Future<void> initialize() async {
    _voicevoxFlutter = VoicevoxFlutter();

    // アセットからアプリケーションディレクトリに`open_jtalk_dict`をコピーする
    final openJTalkDictDir = Directory('${(await getApplicationSupportDirectory()).path}/open_jtalk_dic_utf_8-1.11');
    openJTalkDictDir.createSync();

    final openJTalkDictAssetDir = Directory('assets/open_jtalk_dic_utf_8-1.11');
    final AssetManifest assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final List<String> assets = assetManifest.listAssets();

    // open_jtalk_dic_utf_8-1.11ディレクトリ以下のファイルをコピーする。forEachではawaitできてない疑惑があったためfor-inの素直な記述に改めた
    final openJTalkAssets = assets.where((e) => e.contains(openJTalkDictAssetDir.path)).toList();
    for (final path in openJTalkAssets) {
      await _copyFile(fileName: p.basename(path), from: openJTalkDictAssetDir, to: openJTalkDictDir);
    }

    await _voicevoxFlutter.initialize(openJTalkDictDir: openJTalkDictDir);

    _initializationCompleter.complete(); // しっかり報告する🫡
  }

  /// テキストから AudioQuery を生成する
  Future<String> textToAudioQuery({required String text, required int styleId}) async {
    await _initializationCompleter.future; // 起動が完了するまで待つ
    await _prepareModel(styleId: styleId);
    final output = await _voicevoxFlutter.textToAudioQuery(text: text, styleId: styleId);
    return output;
  }

  /// AudioQuery から音声合成する
  Future<File> audioQueryToWav({required String audioQuery, required int styleId}) async {
    await _initializationCompleter.future;
    await _prepareModel(styleId: styleId);
    final wavFile = File('${(await getTemporaryDirectory()).path}/${audioQuery.hashCode}.wav');
    await _voicevoxFlutter.audioQueryToWav(audioQuery: audioQuery, styleId: styleId, output: wavFile);
    return wavFile;
  }

  /// pitchとlengthを再生成する。accentを変更したり、区切り位置を変更した場合などに使う
  Future<String> inferPitchAndLength({required String accentPhrases, required int styleId}) async {
    await _initializationCompleter.future;
    await _prepareModel(styleId: styleId);
    final updatedAccentPhrase = await _voicevoxFlutter.inferPitchAndLength(
      accentPhrases: accentPhrases,
      styleId: styleId,
    );
    return updatedAccentPhrase;
  }

  /// 必要なVVMモデルを探してロードする関数。モデルが必要になる前に実行すること
  Future<void> _prepareModel({required int styleId}) async {
    await _initializationCompleter.future; // 二重になる説あるが一応置いとく
    final requiredModelName = styleIdToModelName[styleId];
    if (requiredModelName == null) {
      throw Exception('このstyleId: $styleIdに対応するvvmファイルがどれなのかわかりません😫 style_id_to_model_name.dartを更新してください。');
    }

    if (_loadedModelNames.contains(requiredModelName)) {
      return;
    }

    debugPrint('${DateTime.now()}😸VVMモデル$requiredModelNameが必要になったので読み込みます');

    // アセットからアプリケーションディレクトリに`model`をコピーする
    final modelAssetDir = Directory('assets/model');
    final modelDir = Directory('${(await getTemporaryDirectory()).path}/model');
    await modelDir.create();
    await _copyFile(fileName: requiredModelName, from: modelAssetDir, to: modelDir);

    await _voicevoxFlutter.loadVoiceModel(modelFile: File('${modelDir.path}/$requiredModelName'));

    debugPrint('${DateTime.now()}😹VVMモデル${modelDir.path}/$requiredModelNameを読み込みました');
    _loadedModelNames.add(requiredModelName);
  }

  void dispose() {
    _voicevoxFlutter.dispose();
  }
}

/// 指定されたファイル（assets/を想定）をコピーする
Future<void> _copyFile({required String fileName, required Directory from, required Directory to}) async {
  final data = await rootBundle.load('${from.path}/$fileName'); // 別isolateの中でrootBundleは動かんらしい
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  await File('${to.path}/$fileName').writeAsBytes(bytes);
}
