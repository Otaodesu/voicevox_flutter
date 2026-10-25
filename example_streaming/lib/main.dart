import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'presentation/streaming_player_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VoicevoxStreamingApp());
}

class VoicevoxStreamingApp extends StatelessWidget {
  const VoicevoxStreamingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'example_streaming',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja', 'JP')],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF66B032), // ずんだカラー
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const StreamingPlayerScreen(),
    );
  }
}
