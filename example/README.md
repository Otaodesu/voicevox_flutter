# voicevox_flutter_example

voicevox_flutter を使ったサンプルアプリ

## 使い方
[VOICEVOX VVMリポジトリ](https://github.com/VOICEVOX/voicevox_vvm) から VVM 音声モデルをダウンロードして、`assets/model` フォルダに入れてください。  
ビルドしたら、中央のテキストフィールドに好きな文字を入力して生成ボタンを押すだけ！  
- 話者は`main.dart`内の`styleId`によって変えることができます。  
- `assets/open_jtalk_dic_utf_8-1.11`は https://open-jtalk.sourceforge.net/ の Dictionary for Open JTalk version 1.11: Binary Package (UTF-8) から入手できます。

### Linux
Linux で実行する場合は、事前に GStreamer 開発ライブラリをインストールしてください：

```bash
sudo apt update && sudo apt install -y libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
```

アプリのビルドと起動：
```bash
flutter run -d linux
```
