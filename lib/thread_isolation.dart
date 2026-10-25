import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';

import 'ffi_bridge.dart';

// スレッドを分離してUIをフリーズさせない！もとはservice.dart

class ThreadIsolator {
  late Isolate _isolate;
  late SendPort _sendPort;

  Future<void> initialize({required Directory openJTalkDictDir}) async {
    final receivePort = ReceivePort();
    final rootToken = RootIsolateToken.instance!;
    _isolate = await Isolate.spawn<(SendPort, RootIsolateToken)>((message) async {
      BackgroundIsolateBinaryMessenger.ensureInitialized(message.$2);

      final receivePort = ReceivePort();
      message.$1.send(receivePort.sendPort);

      // キャンセルされたトークン
      final cancelledTokens = <Capability>{};

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

          case 'inferPitchAndLength':
            (message['sendPort'] as SendPort).send(
              _inferPitchAndLength(
                accentPhrases: message['accentPhrases'] as String,
                styleId: message['styleId'] as int,
              ),
            );

          case 'audioQueryToAudioDuration':
            (message['sendPort'] as SendPort).send(
              _audioQueryToAudioDuration(
                query: message['query'] as String,
                styleId: message['styleId'] as int,
                enableInterrogativeUpspeak: message['enableInterrogativeUpspeak'] as bool? ?? true,
              ),
            );

          case 'cancelStream':
            final token = message['token'] as Capability;
            cancelledTokens.add(token);

          case 'audioQueryToPCMStream':
            final token = message['token'] as Capability;
            final targetSendPort = message['sendPort'] as SendPort;

            // 処理開始前に既にキャンセルが届いていた場合は即座に終了する
            if (cancelledTokens.contains(token)) {
              cancelledTokens.remove(token);
              targetSendPort.send({'type': 'done'});
              break;
            }

            try {
              final stream = _audioQueryToPCMStream(
                query: message['query'] as String,
                styleId: message['styleId'] as int,
                start: message['start'] as Duration,
                end: message['end'] as Duration?,
                chunkDuration: message['chunkDuration'] as Duration,
                isCancelled: () => cancelledTokens.contains(token),
              );

              await for (final chunk in stream) {
                targetSendPort.send({
                  'type': 'data',
                  'data': chunk,
                });
              }
              targetSendPort.send({
                'type': 'done',
              });
            } catch (e) {
              targetSendPort.send({
                'type': 'error',
                'error': e.toString(),
              });
            } finally {
              cancelledTokens.remove(token);
            }
        }
      });
    }, (receivePort.sendPort, rootToken));
    _sendPort = await receivePort.first as SendPort;

    final r = ReceivePort();
    _sendPort.send({
      'method': 'initialize',
      'openJTalkDictPath': openJTalkDictDir.path,
      'sendPort': r.sendPort,
    });
    await r.first;
  }

  /// AudioQuery を生成する
  Future<String> audioQuery(String text, int styleId) async {
    final receivePort = ReceivePort();
    _sendPort.send({
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
    _sendPort.send({
      'method': 'synthesis',
      'query': query,
      'styleId': styleId,
      'outputPath': output.path,
      'sendPort': receivePort.sendPort,
    });
    await receivePort.first;
  }

  /// モデルファイルを読み込む
  Future<void> loadModel(File modelFile) async {
    final receivePort = ReceivePort();
    _sendPort.send({
      'method': 'loadModel',
      'modelPath': modelFile.path,
      'sendPort': receivePort.sendPort,
    });
    await receivePort.first;
  }

  /// AccentPhrasesのpitchとlengthを再生成する
  Future<String> inferPitchAndLength({required String accentPhrases, required int styleId}) async {
    final receivePort = ReceivePort();
    _sendPort.send({
      'method': 'inferPitchAndLength',
      'accentPhrases': accentPhrases,
      'styleId': styleId,
      'sendPort': receivePort.sendPort,
    });
    return (await receivePort.first) as String;
  }

  /// AudioQuery から音声の長さを取得する
  Future<Duration> audioQueryToAudioDuration({
    required String query,
    required int styleId,
    bool enableInterrogativeUpspeak = true,
  }) async {
    final receivePort = ReceivePort();
    _sendPort.send({
      'method': 'audioQueryToAudioDuration',
      'query': query,
      'styleId': styleId,
      'enableInterrogativeUpspeak': enableInterrogativeUpspeak,
      'sendPort': receivePort.sendPort,
    });
    return (await receivePort.first) as Duration;
  }

  /// AudioQuery から PCM データをストリーミング生成する
  Stream<Uint8List> audioQueryToPCMStream({
    required String query,
    required int styleId,
    required Duration start,
    required Duration? end,
    required Duration chunkDuration,
  }) {
    final token = Capability();
    final chunkPort = ReceivePort();
    late StreamController<Uint8List> controller;

    controller = StreamController<Uint8List>(
      onListen: () {
        _sendPort.send({
          'method': 'audioQueryToPCMStream',
          'token': token,
          'query': query,
          'styleId': styleId,
          'start': start,
          'end': end,
          'chunkDuration': chunkDuration,
          'sendPort': chunkPort.sendPort,
        });

        chunkPort.listen((message) {
          if (message is Map<String, dynamic>) {
            switch (message['type']) {
              case 'data':
                controller.add(message['data'] as Uint8List);
              case 'done':
                chunkPort.close();
                controller.close();
              case 'error':
                chunkPort.close();
                controller.addError(Exception(message['error']));
                controller.close();
            }
          }
        });
      },
      onCancel: () {
        chunkPort.close();
        _sendPort.send({
          'method': 'cancelStream',
          'token': token,
        });
      },
    );

    return controller.stream;
  }

  void dispose() {
    _isolate.kill();
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

String _inferPitchAndLength({required String accentPhrases, required int styleId}) {
  return FFIBridge.instance.inferPitchAndLength(accentPhrases: accentPhrases, styleId: styleId);
}

Duration _audioQueryToAudioDuration({
  required String query,
  required int styleId,
  bool enableInterrogativeUpspeak = true,
}) {
  return FFIBridge.instance.audioQueryToAudioDuration(
    query,
    styleId: styleId,
    enableInterrogativeUpspeak: enableInterrogativeUpspeak,
  );
}

Stream<Uint8List> _audioQueryToPCMStream({
  required String query,
  required int styleId,
  required Duration start,
  required Duration? end,
  required Duration chunkDuration,
  required bool Function() isCancelled,
}) {
  return FFIBridge.instance.audioQueryToPCMStream(
    query: query,
    styleId: styleId,
    start: start,
    end: end,
    chunkDuration: chunkDuration,
    isCancelled: isCancelled,
  );
}
