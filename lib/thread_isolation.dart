import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';

import 'ffi_bridge.dart';

// スレッドを分離してUIをフリーズさせない！もとはservice.dart
// isolateなるものを操縦して戦う。

class NativeVoiceService {
  late Isolate isolate;
  late SendPort sendPort;

  Future<void> initialize({required Directory openJTalkDictDir}) async {
    final receivePort = ReceivePort();
    final rootToken = RootIsolateToken.instance!;
    isolate = await Isolate.spawn<(SendPort, RootIsolateToken)>((message) async {
      BackgroundIsolateBinaryMessenger.ensureInitialized(message.$2);

      final receivePort = ReceivePort();
      message.$1.send(receivePort.sendPort);

      receivePort.listen((message) async {
        message = message as Map<String, dynamic>;
        switch (message['method']) {
          case 'initialize':
            await _initialize(
              openJTalkDictPath: message['openJTalkDictPath'] as String,
            );
            (message['sendPort'] as SendPort).send(null);
          case 'audioQuery':
            (message['sendPort'] as SendPort).send(
              _audioQuery(
                text: message['text'] as String,
                styleId: message['styleId'] as int,
              ),
            );
          case 'synthesis':
            await _synthesis(
              query: message['query'] as String,
              styleId: message['styleId'] as int,
              outputPath: message['outputPath'] as String,
            );
            (message['sendPort'] as SendPort).send(null);
          case 'loadModel':
            await _loadModel(
              modelPath: message['modelPath'] as String,
            );
            (message['sendPort'] as SendPort).send(null);
        }
      });
    }, (receivePort.sendPort, rootToken));
    sendPort = await receivePort.first as SendPort;

    final r = ReceivePort();
    sendPort.send({
      'method': 'initialize',
      'openJTalkDictPath': openJTalkDictDir.path,
      'sendPort': r.sendPort,
    });
    await r.first;
  }

  /// AudioQuery を生成する
  Future<String> audioQuery(String text, int styleId) async {
    final receivePort = ReceivePort();
    sendPort.send({
      'method': 'audioQuery',
      'text': text,
      'styleId': styleId,
      'sendPort': receivePort.sendPort,
    });
    return (await receivePort.first) as String;
  }

  /// AudioQuery から合成を実行する
  Future<void> synthesis(String query, int styleId, File output) async {
    final receivePort = ReceivePort();
    sendPort.send({
      'method': 'synthesis',
      'query': query,
      'styleId': styleId,
      'outputPath': output.path,
      'sendPort': receivePort.sendPort,
    });
    await receivePort.first;
  }

  /// 新設！モデルファイルを読み込む
  Future<void> loadModel(File modelFile) async {
    final receivePort = ReceivePort();
    sendPort.send({
      'method': 'loadModel',
      'modelPath': modelFile.path,
      'sendPort': receivePort.sendPort,
    });
    await receivePort.first;
  }

  void dispose() {
    isolate.kill();
  }
}

// isolateの中で使う関数たち

Future<void> _initialize({required String openJTalkDictPath}) async {
  await FFIBridge.instance.initialize(
    openJTalkDictPath: openJTalkDictPath,
    cpuNumThreads: 4,
  );
}

String _audioQuery({required String text, required int styleId}) {
  return FFIBridge.instance.textToAudioQuery(
    text,
    styleId: styleId,
  );
}

Future<void> _synthesis({required String query, required int styleId, required String outputPath}) async {
  await FFIBridge.instance.audioQueryToWav(
    query,
    styleId: styleId,
    outputPath: outputPath,
  );
}

Future<void> _loadModel({required String modelPath}) async {
  await FFIBridge.instance.loadVoiceModel(
    modelPath: modelPath,
  );
}
