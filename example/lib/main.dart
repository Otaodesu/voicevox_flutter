import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'voicevox_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final voicevox = VoicevoxFlutterController();
  voicevox.initialize();
  final audioPlayer = AudioPlayer();
  runApp(MyApp(voicevox, audioPlayer));
}

class MyApp extends StatelessWidget {
  const MyApp(this.voicevox, this.audioPlayer, {super.key});
  final VoicevoxFlutterController voicevox;
  final AudioPlayer audioPlayer;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: controller),
                ElevatedButton(
                  onPressed: () async {
                    // speakerIdを変更すれば話者を変えられます。
                    const speakerId = 1;
                    final query = await voicevox.textToAudioQuery(
                      text: controller.text,
                      styleId: speakerId,
                    );
                    final wavPath = await voicevox.audioQueryToWav(
                      audioQuery: query,
                      styleId: speakerId,
                    );
                    await audioPlayer.play(DeviceFileSource(wavPath.path));
                  },
                  child: const Text('生成'),
                ),
                LinearProgressIndicator(), // スレッドが分離できていると生成中もなめらかに動きます
              ],
            ),
          ),
        ),
      ),
    );
  }
}
