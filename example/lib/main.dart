import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'voicevox_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final voicevox = VoicevoxFlutterController();
  await voicevox.initialize();
  final audioPlayer = AudioPlayer();
  runApp(MyApp(voicevox, audioPlayer));
}

class MyApp extends StatelessWidget {
  MyApp(this.voicevox, this.audioPlayer, {super.key});

  final VoicevoxFlutterController voicevox;
  final AudioPlayer audioPlayer;

  final _textEditingController = TextEditingController();

  Future<void> _textToSpeech() async {
    // styleIdを変更すれば話者を変えられます。
    const styleId = 1;
    final audioQuery = await voicevox.textToAudioQuery(
      text: _textEditingController.text,
      styleId: styleId,
    );
    final wavFile = await voicevox.audioQueryToWav(
      audioQuery: audioQuery,
      styleId: styleId,
    );
    await audioPlayer.play(DeviceFileSource(wavFile.path));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: _textEditingController),
                ElevatedButton(
                  onPressed: _textToSpeech,
                  child: const Text('生成'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
