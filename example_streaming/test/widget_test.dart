import 'package:flutter_test/flutter_test.dart';
import 'package:example_streaming/main.dart';

void main() {
  testWidgets('VoicevoxStreamingApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const VoicevoxStreamingApp());
    expect(find.text('VOICEVOX ストリーミング合成'), findsOneWidget);
  });
}
