import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'generated_bindings.dart';

// 参考文献😘: https://github.com/VOICEVOX/voicevox_core/blob/00f891c8664ed302a1b0778ed2eddea4551d6287/example/cpp/unix/simple_tts.cpp

// もともとはこれがvoicevox_flutter.dart

/// VoicevoxCoreLibraryのラッパークラス
class FFIBridge extends VoicevoxCoreLibrary {
  static final FFIBridge instance = FFIBridge._(() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libvoicevox_core.so');
    }

    if (Platform.isLinux) {
      try {
        DynamicLibrary.open('libvoicevox_onnxruntime.so.1.23.2');
      } catch (_) {
        DynamicLibrary.open('libvoicevox_onnxruntime.so');
      }
      return DynamicLibrary.open('libvoicevox_core.so');
    }

    if (Platform.isWindows) {
      DynamicLibrary.open('voicevox_onnxruntime.dll');
      return DynamicLibrary.open('voicevox_core.dll');
    }

    throw UnsupportedError(
      'このプラットフォームはサポートしていません。 Android、Linux、Windowsのみ動作確認済みです。',
    );
  }());
  FFIBridge._(super.dynamicLibrary);

  /// VoicevoxSynthesizerのポインタ
  late Pointer<VoicevoxSynthesizer> _synthesizerPtr;

  /// 読み込まれたモデルのポインタのリスト
  final _loadedModelPtrList = <Pointer<VoicevoxVoiceModelFile>>[];

  /// voicevox_flutterを初期化する
  Future<void> initialize({
    required String openJTalkDictPath,
    int? cpuNumThreads,
  }) async {
    final onnxruntimePtrPtr = malloc<Pointer<VoicevoxOnnxruntime>>();
    final openJTalkDictPathPtr = openJTalkDictPath.toNativeUtf8();
    final openJTalkPtrPtr = malloc<Pointer<OpenJtalkRc>>();
    final outputSynthesizerPtrPtr = malloc<Pointer<VoicevoxSynthesizer>>();

    try {
      // onnxruntimeを準備する
      final ortLoadResult = voicevox_onnxruntime_load_once(
        voicevox_make_default_load_onnxruntime_options(),
        onnxruntimePtrPtr,
      );
      if (VoicevoxResultCode.fromValue(ortLoadResult) != VoicevoxResultCode.VOICEVOX_RESULT_OK) {
        throw Exception('VOICEVOX_CORE エラー$ortLoadResult: ${_errorcodeToText(ortLoadResult)}');
      }

      // OpenJTalkを準備する
      final ojtLoadResult = voicevox_open_jtalk_rc_new(
        openJTalkDictPathPtr.cast<Char>(),
        openJTalkPtrPtr,
      );
      if (VoicevoxResultCode.fromValue(ojtLoadResult) != VoicevoxResultCode.VOICEVOX_RESULT_OK) {
        throw Exception('VOICEVOX_CORE エラー$ojtLoadResult: ${_errorcodeToText(ojtLoadResult)}');
      }

      // VOICEVOX_COREを起動する！！
      final initializeOptions = voicevox_make_default_initialize_options();

      initializeOptions
        ..acceleration_mode = VoicevoxAccelerationMode.VOICEVOX_ACCELERATION_MODE_CPU.value
        ..cpu_num_threads = cpuNumThreads ?? 0;

      final voicevoxInitResult = voicevox_synthesizer_new(
        onnxruntimePtrPtr.value,
        openJTalkPtrPtr.value,
        initializeOptions,
        outputSynthesizerPtrPtr,
      );
      if (VoicevoxResultCode.fromValue(voicevoxInitResult) != VoicevoxResultCode.VOICEVOX_RESULT_OK) {
        throw Exception('VOICEVOX CORE エラー$voicevoxInitResult: ${_errorcodeToText(voicevoxInitResult)}');
      }

      _synthesizerPtr = outputSynthesizerPtrPtr.value;
    } catch (_) {
      rethrow;
    } finally {
      calloc.free(openJTalkDictPathPtr);
      malloc
        ..free(onnxruntimePtrPtr)
        ..free(openJTalkPtrPtr)
        ..free(outputSynthesizerPtrPtr);
    }
  }

  /// モデルを読み込む
  Future<void> loadVoiceModel({required String modelPath}) async {
    final modelPtrPtr = malloc<Pointer<VoicevoxVoiceModelFile>>();
    final modelPathPtr = modelPath.toNativeUtf8();
    try {
      // モデルファイルをopenしていく
      final modelOpenResult = voicevox_voice_model_file_open(
        modelPathPtr.cast<Char>(),
        modelPtrPtr,
      );
      if (VoicevoxResultCode.fromValue(modelOpenResult) != VoicevoxResultCode.VOICEVOX_RESULT_OK) {
        throw Exception('VOICEVOX_CORE エラー$modelOpenResult: ${_errorcodeToText(modelOpenResult)}');
      }

      final loadOptions = voicevox_make_default_load_voice_model_options();

      // モデルファイルをloadしていく… openで手札に取って、loadで場に出す的な？カードゲーム的思想やな
      final modelLoadResult = voicevox_synthesizer_load_voice_model(_synthesizerPtr, modelPtrPtr.value, loadOptions);

      if (VoicevoxResultCode.fromValue(modelLoadResult) != VoicevoxResultCode.VOICEVOX_RESULT_OK) {
        throw Exception('VOICEVOX_CORE エラー$modelLoadResult: ${_errorcodeToText(modelLoadResult)}');
      }
      _loadedModelPtrList.add(modelPtrPtr.value);
    } finally {
      calloc.free(modelPathPtr);
      malloc.free(modelPtrPtr);
    }
  }

  /// テキストから AudioQuery を生成する
  String textToAudioQuery(
    String text, {
    required int styleId,
  }) {
    final textPtr = text.toNativeUtf8();
    Pointer<Pointer<Char>> outputPtr = malloc<Pointer<Char>>();
    try {
      final resultCode = voicevox_synthesizer_create_audio_query(
        _synthesizerPtr,
        textPtr.cast<Char>(),
        styleId,
        outputPtr,
      );
      if (VoicevoxResultCode.fromValue(resultCode) != VoicevoxResultCode.VOICEVOX_RESULT_OK) {
        throw Exception('VOICEVOX_CORE エラー$resultCode: ${_errorcodeToText(resultCode)}');
      }

      final query = outputPtr.value.cast<Utf8>().toDartString();
      return query;
    } catch (_) {
      rethrow;
    } finally {
      calloc.free(textPtr);
      malloc.free(outputPtr);
    }
  }

  /// AudioQuery から音声合成する
  Future<void> audioQueryToWav(
    String query, {
    required int styleId,
    required String outputPath,
    bool enableInterrogativeUpspeak = true,
  }) async {
    final outputWavLengthPtr = malloc<UintPtr>();
    final outputWavPtr = malloc<Pointer<Uint8>>();
    try {
      final synthesisOptions = voicevox_make_default_synthesis_options();
      synthesisOptions.enable_interrogative_upspeak = enableInterrogativeUpspeak;

      final queryPtr = query.toNativeUtf8();
      final resultCode = voicevox_synthesizer_synthesis(
        _synthesizerPtr,
        queryPtr.cast<Char>(),
        styleId,
        synthesisOptions,
        outputWavLengthPtr, // generated_bindingsを再生成するとなぜかInt(大文字)になったのでEDITした👌
        outputWavPtr,
      );
      if (VoicevoxResultCode.fromValue(resultCode) != VoicevoxResultCode.VOICEVOX_RESULT_OK) {
        throw Exception('VOICEVOX_CORE エラー$resultCode: ${_errorcodeToText(resultCode)}');
      }
      final wavFile = File(outputPath);
      wavFile.writeAsBytesSync(outputWavPtr.value.asTypedList(outputWavLengthPtr.value));
    } catch (_) {
      rethrow;
    } finally {
      malloc
        ..free(outputWavLengthPtr)
        ..free(outputWavPtr);
    }
  }

  /// AudioQuery から PCM データをストリーミング生成する
  Stream<Uint8List> audioQueryToPCMStream({
    required String query,
    required int styleId,
    required Duration start,
    required Duration? end,
    required Duration chunkDuration,
    required bool Function() isCancelled,
    bool enableInterrogativeUpspeak = true,
  }) async* {
    final synthesisOptions = voicevox_make_default_synthesis_options();
    synthesisOptions.enable_interrogative_upspeak = enableInterrogativeUpspeak;

    final queryPtr = query.toNativeUtf8();
    final audioFeaturePtrPtr = malloc<Pointer<VoicevoxAudioFeature>>();
    Pointer<VoicevoxAudioFeature>? audioFeature;

    try {
      final featureCreateResult = voicevox_synthesizer_create_audio_feature(
        _synthesizerPtr,
        queryPtr.cast<Char>(),
        styleId,
        synthesisOptions,
        audioFeaturePtrPtr,
      );
      if (VoicevoxResultCode.fromValue(featureCreateResult) != VoicevoxResultCode.VOICEVOX_RESULT_OK) {
        throw Exception('VOICEVOX_CORE エラー$featureCreateResult: ${_errorcodeToText(featureCreateResult)}');
      }
      audioFeature = audioFeaturePtrPtr.value;

      final totalFrames = voicevox_audio_feature_len(audioFeature);
      final totalSeconds = totalFrames / VOICEVOX_FRAME_RATE;
      final totalDuration = Duration(microseconds: (totalSeconds * 1000000).round());

      if (start > totalDuration) {
        throw ArgumentError.value(start, 'start', 'startが音声の総時間($totalDuration)を超えています');
      }
      if (end != null && end > totalDuration) {
        throw ArgumentError.value(end, 'end', 'endが音声の総時間($totalDuration)を超えています');
      }

      final startFrames = (start.inMicroseconds * VOICEVOX_FRAME_RATE / 1000000).round();
      final endFrames = end != null ? (end.inMicroseconds * VOICEVOX_FRAME_RATE / 1000000).round() : totalFrames;

      int chunkFrames = (chunkDuration.inMicroseconds * VOICEVOX_FRAME_RATE / 1000000).round();
      if (chunkFrames <= 0) {
        chunkFrames = 1;
      }

      final outputPcmLengthPtr = malloc<UintPtr>();
      final outputPcmPtr = malloc<Pointer<Uint8>>();
      final slicePtr = malloc<VoicevoxAudioFeatureSlice>();

      try {
        int currentFrame = startFrames;
        while (currentFrame < endFrames) {
          if (isCancelled()) {
            break;
          }

          final nextFrame = (currentFrame + chunkFrames).clamp(currentFrame, endFrames);
          final sliceResult = voicevox_audio_feature_slice(
            audioFeature,
            currentFrame,
            nextFrame,
            false,
            false,
            false,
            slicePtr,
          );

          if (VoicevoxResultCode.fromValue(sliceResult) != VoicevoxResultCode.VOICEVOX_RESULT_OK) {
            throw Exception('VOICEVOX_CORE エラー$sliceResult: ${_errorcodeToText(sliceResult)}');
          }

          final renderResult = voicevox_synthesizer_render(
            _synthesizerPtr,
            slicePtr.ref,
            outputPcmLengthPtr,
            outputPcmPtr,
          );

          if (VoicevoxResultCode.fromValue(renderResult) != VoicevoxResultCode.VOICEVOX_RESULT_OK) {
            throw Exception('VOICEVOX_CORE エラー$renderResult: ${_errorcodeToText(renderResult)}');
          }

          final length = outputPcmLengthPtr.value;
          if (length > 0) {
            final pcmData = Uint8List.fromList(outputPcmPtr.value.asTypedList(length));
            voicevox_bytes_free(outputPcmPtr.value);
            yield pcmData;
          }

          currentFrame = nextFrame;

          // Isolateのイベントループに一瞬制御を戻し、キャンセル等のメッセージを処理できるようにする
          await Future<void>.delayed(Duration.zero);
        }
      } finally {
        malloc
          ..free(outputPcmLengthPtr)
          ..free(outputPcmPtr)
          ..free(slicePtr);
      }
    } finally {
      calloc.free(queryPtr);
      if (audioFeature != null) {
        voicevox_audio_feature_delete(audioFeature);
      }
      malloc.free(audioFeaturePtrPtr);
    }
  }

  /// pitchとlengthを再生成する
  String inferPitchAndLength({
    required String accentPhrases,
    required int styleId,
  }) {
    final textPtr = accentPhrases.toNativeUtf8();
    Pointer<Pointer<Char>> outputPtr = malloc<Pointer<Char>>();
    try {
      final resultCode = voicevox_synthesizer_replace_mora_data(
        _synthesizerPtr,
        textPtr.cast<Char>(),
        styleId,
        outputPtr,
      );
      if (VoicevoxResultCode.fromValue(resultCode) != VoicevoxResultCode.VOICEVOX_RESULT_OK) {
        throw Exception('VOICEVOX_CORE エラー$resultCode: ${_errorcodeToText(resultCode)}');
      }

      final updatedAccentPhrases = outputPtr.value.cast<Utf8>().toDartString();
      return updatedAccentPhrases;
    } catch (_) {
      rethrow;
    } finally {
      calloc.free(textPtr);
      malloc.free(outputPtr);
    }
  }

  /// AudioQuery から音声の長さを取得する
  Duration audioQueryToAudioDuration(
    String query, {
    bool enableInterrogativeUpspeak = true,
  }) {
    final options = voicevox_make_default_audio_query_frame_length_options();
    options.enable_interrogative_upspeak = enableInterrogativeUpspeak;

    final queryPtr = query.toNativeUtf8();
    final outputFrameLengthPtr = malloc<UintPtr>();

    try {
      final result = voicevox_audio_query_frame_length(
        queryPtr.cast<Char>(),
        options,
        outputFrameLengthPtr,
      );
      if (VoicevoxResultCode.fromValue(result) != VoicevoxResultCode.VOICEVOX_RESULT_OK) {
        throw Exception('VOICEVOX_CORE エラー$result: ${_errorcodeToText(result)}');
      }

      final totalFrames = outputFrameLengthPtr.value;
      final totalSeconds = totalFrames / VOICEVOX_FRAME_RATE;
      return Duration(microseconds: (totalSeconds * 1000000).round());
    } finally {
      calloc.free(queryPtr);
      malloc.free(outputFrameLengthPtr);
    }
  }

  void dispose() {
    for (final modelPtr in _loadedModelPtrList) {
      voicevox_voice_model_file_delete(modelPtr);
    }
    voicevox_synthesizer_delete(_synthesizerPtr);
  }
}

/// VoicevoxCoreLibraryのエラーコードをテキストに変換する
String _errorcodeToText(int code) {
  switch (code) {
    case 0:
      return '成功';
    case 1:
      return 'open_jtalk辞書ファイルが読み込まれていない';
    case 3:
      return 'サポートされているデバイス情報取得に失敗した';
    case 4:
      return 'GPUモードがサポートされていない';
    case 6:
      return 'スタイルIDに対するスタイルが見つからなかった';
    case 7:
      return '音声モデルIDに対する音声モデルが見つからなかった';
    case 8:
      return '推論に失敗した、もしくは推論結果が異常';
    case 11:
      return '入力テキストの解析に失敗した';
    case 12:
      return '無効なutf8文字列が入力された';
    case 13:
      return 'AquesTalk風記法のテキストの解析に失敗した';
    case 14:
      return '無効なAudioQuery';
    case 15:
      return '無効なAccentPhrase';
    case 16:
      return 'ZIPファイルを開くことに失敗した';
    case 17:
      return 'ZIP内のファイルが読めなかった';
    case 18:
      return 'すでに読み込まれている音声モデルを読み込もうとした';
    case 20:
      return 'ユーザー辞書を読み込めなかった';
    case 21:
      return 'ユーザー辞書を書き込めなかった';
    case 22:
      return 'ユーザー辞書に単語が見つからなかった';
    case 23:
      return 'OpenJTalkのユーザー辞書の設定に失敗した';
    case 24:
      return 'ユーザー辞書の単語のバリデーションに失敗した';
    case 25:
      return 'UUIDの変換に失敗した';
    case 26:
      return 'すでに読み込まれているスタイルを読み込もうとした';
    case 27:
      return '無効なモデルデータ';
    case 28:
      return 'モデルの形式が不正';
    case 29:
      return '推論ライブラリのロードまたは初期化ができなかった';
    case 30:
      return '無効なMora';
    case 31:
      return '無効な楽譜';
    case 32:
      return '無効なノート';
    case 33:
      return '無効なFrameAudioQuery';
    case 34:
      return '無効なFramePhoneme';
    case 35:
      return '楽譜とFrameAudioQueryの組み合わせが不正';
    case 36:
      return 'AudioFeatureSliceをスライスするときの始端が大きすぎた';
    case 37:
      return 'AudioFeatureSliceをスライスするときの終端が大きすぎた';
    case 38:
      return 'AudioFeatureSliceをスライスするときに始端が終端を超えていた';
    default:
      return '不明なエラー';
  }
}
