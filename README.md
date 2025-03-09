# voicevox_flutter

Dart:FFIを利用して、VOICEVOX COREをArm64-v8aのAndroidデバイスで動かすFlutterパッケージ。  
[voicevox_core](https://github.com/VOICEVOX/voicevox_core) の 非公式 ラッパーです。

## 使い方
ご自身のFlutterアプリで使用する場合は以下のようにしてください。
### Android

- vvmモデルファイルを[ここ](https://github.com/VOICEVOX/voicevox_vvm/tree/main/vvms)からダウンロードし、`your_app/assets/model` フォルダに追加します。

- voicevox_onnxruntimeのAndroid向けライブラリを[ここ](https://github.com/VOICEVOX/onnxruntime-builder/releases/tag/voicevox_onnxruntime-1.17.3)からダウンロードし、`your_app/assets/libvoicevox_onnxruntime.so` フォルダに追加します。

- OpenJTalkのUTF-8辞書を[このへん](https://open-jtalk.sourceforge.net/)からダウンロードし、`your_app/assets/open_jtalk_dic_utf_8-1.11` フォルダに追加します。

- `your_app/pubspec.yaml` を編集します。

```yaml
dependencies:
  voicevox_flutter:
    path: /path/to/voicevox_flutter

flutter:
  assets:
    - assets/open_jtalk_dic_utf_8-1.11/
    - assets/model/
    - assets/libvoicevox_onnxruntime.so
```

~~実際の使用方法は[example](example)を参考にしてください。~~  exampleは今のところ動きません😥

## 高レベルAPI
VoicevoxFlutterクラスは現在audioQuery, synthesis, tts のみをサポートしています。

## 低レベルAPI
[generated_bindings.dart](lib/generated_bindings.dart)に[ffigen](https://github.com/dart-lang/ffigen)で生成しただけのものがあります。


## ライセンス
MITライセンスが適用されています。[LICENSE](LICENSE)を参照してください。

## ファイルの出どころ
- [libc++_shared.so](android/src/main/jniLibs/arm64-v8a/libc++_shared.so): Android NDKの[ダウンロードページ](https://developer.android.com/ndk/downloads?hl=ja)に転がっていた `android-ndk-r27c-windows.zip` から拾いました。

- [libvoicevox_core.so](android/src/main/jniLibs/libvoicevox_core.so): VOICEVOX CORE公式様の[Releases 0.16.0-preview.0](https://github.com/VOICEVOX/voicevox_core/releases/tag/0.16.0-preview.0)からありがたく頂戴いたしました。

- [voicevox_core.h](voicevox_core.h): VOICEVOX CORE公式様の[Releases 0.16.0-preview.0](https://github.com/VOICEVOX/voicevox_core/releases/tag/0.16.0-preview.0)からありがたく頂戴いたしました。