import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:voicevox_flutter/voicevox_flutter.dart';

import '../style_id_to_model_name.dart';

class VoicevoxService {
  final VoicevoxFlutter _voicevox = VoicevoxFlutter();
  final Completer<void> _initializationCompleter = Completer<void>();
  bool _hasStartedInitialization = false;
  final List<String> _loadedModelNames = [];

  /// VOICEVOX エンジンおよび OpenJTalk 辞書を初期化する
  Future<void> initialize() async {
    if (_hasStartedInitialization) {
      await _initializationCompleter.future;
      return;
    }
    _hasStartedInitialization = true;

    final openJTalkDictDir = Directory(
      '${(await getApplicationSupportDirectory()).path}/open_jtalk_dic_utf_8-1.11',
    );
    if (!openJTalkDictDir.existsSync()) {
      openJTalkDictDir.createSync(recursive: true);
    }

    final AssetManifest assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final openJTalkAssets = assetManifest
        .listAssets()
        .where((eachPath) => eachPath.startsWith('assets/open_jtalk_dic_utf_8-1.11'))
        .toList();

    for (final eachPath in openJTalkAssets) {
      final destFile = File('${openJTalkDictDir.path}/${p.basename(eachPath)}');
      if (!destFile.existsSync()) {
        final data = await rootBundle.load(eachPath);
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await destFile.writeAsBytes(bytes);
      }
    }

    await _voicevox.initialize(openJTalkDictDir: openJTalkDictDir);
    _initializationCompleter.complete();
  }

  /// 指定スタイルIDに対応するVVMモデルを読み込む
  Future<void> prepareModel({required int styleId}) async {
    await initialize();
    final modelName = styleIdToModelName[styleId];
    if (modelName == null) {
      throw Exception('styleId: $styleId に対応する VVM モデルが見つかりません');
    }

    if (_loadedModelNames.contains(modelName)) {
      return;
    }

    final data = await rootBundle.load('assets/model/$modelName');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    final modelDir = Directory('${(await getTemporaryDirectory()).path}/model');
    if (!modelDir.existsSync()) {
      await modelDir.create(recursive: true);
    }

    final modelFile = File('${modelDir.path}/$modelName');
    await modelFile.writeAsBytes(bytes);

    await _voicevox.loadVoiceModel(modelFile: modelFile);
    _loadedModelNames.add(modelName);
  }

  /// テキストから AudioQuery (JSON) を生成する
  Future<String> textToAudioQuery({required String text, required int styleId}) async {
    await initialize();
    await prepareModel(styleId: styleId);
    return await _voicevox.textToAudioQuery(text: text, styleId: styleId);
  }

  /// AudioQuery から PCM データのストリームを生成する
  Stream<Uint8List> audioQueryToPCMStream({
    required String audioQuery,
    required int styleId,
    required Duration chunkDuration,
    Duration start = Duration.zero,
  }) {
    return _voicevox.audioQueryToPCMStream(
      audioQuery: audioQuery,
      styleId: styleId,
      start: start,
      chunkDuration: chunkDuration,
    );
  }

  /// AudioQuery から音声の総尺（Duration）を取得する
  Future<Duration> audioQueryToAudioDuration({
    required String audioQuery,
    required int styleId,
  }) async {
    return await _voicevox.audioQueryToAudioDuration(
      audioQuery: audioQuery,
      styleId: styleId,
    );
  }

  void dispose() {
    if (_hasStartedInitialization && _initializationCompleter.isCompleted) {
      _voicevox.dispose();
    }
  }
}
