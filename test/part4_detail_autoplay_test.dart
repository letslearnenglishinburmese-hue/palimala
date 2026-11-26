import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimala/app_data.dart';
import 'package:palimala/main.dart';
import 'package:palimala/remote_app_config.dart';
import 'package:palimala/widgets/word_share_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleSubCategory = SubCategory(
    titleMm: 'စမ်းသပ်အခန်း',
    titleEn: 'Test Chapter',
    vocabList: [
      VocabItem(
        paliMm: 'ပိတာ',
        paliRoman: 'Pitā (M)',
        translateMm: 'အဖ',
        translateEn: 'Father',
        example: ExampleSentence(
          paliMm: 'မမ ပိတာ အာဂစ္ဆတိ။',
          paliRoman: 'Mama pitā āgacchati.',
          translateMm: 'ငါ၏ အဖ လာနေသည်။',
          translateEn: 'My father is coming.',
        ),
      ),
      VocabItem(
        paliMm: 'ဓမ္မ',
        paliRoman: 'Dhamma (M)',
        translateMm: 'တရားတော်',
        translateEn: 'The Dhamma',
      ),
    ],
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (call) async => 1,
        );
  });

  Widget buildTestScreen() {
    return MaterialApp(
      home: DetailContentScreen(
        subCategory: sampleSubCategory,
        currentLang: AppLanguage.myanmar,
        onLanguageToggle: () {},
        savedWords: const {},
        onSavedWordToggle: (_) {},
      ),
    );
  }

  group('Modern Vocab Card & Study Mode', () {
    testWidgets('displays Myanmar-only script, Myanmar index badges, clean gender tag, and share button', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Myanmar-only script in Myanmar mode (no Roman Pali subtitle)
      expect(find.text('ပိတာ'), findsOneWidget);
      expect(find.text('Pitā (M)'), findsNothing);

      // Clean Myanmar gender tag without #1/#၁ index badges or · M
      expect(find.text('#၁'), findsNothing);
      expect(find.text('#1'), findsNothing);
      expect(find.text('ပုလ္လိင်'), findsNWidgets(2));
      expect(find.text('ပုလ္လိင် · M'), findsNothing);

      // Per-word share button opens WordShareDialog
      await tester.tap(find.byIcon(Icons.share_outlined).first);
      await tester.pumpAndSettle();
      expect(find.byType(WordShareDialog), findsOneWidget);
    });

    test('buildRemoteTheme switches digit font between Myanmar and English modes', () {
      final config = RemoteAppConfigRepository.current;
      final mmTheme = buildRemoteTheme(config, dark: false, isMyanmar: true);
      final enTheme = buildRemoteTheme(config, dark: false, isMyanmar: false);

      expect(mmTheme.textTheme.bodyMedium?.fontFamily, 'Pyidaungsu Numbers');
      expect(enTheme.textTheme.bodyMedium?.fontFamily, 'SourceSans3');
    });

    testWidgets('Study Mode hides meanings and reveals on card tap', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      expect(find.text('အဖ'), findsOneWidget);

      // Toggle Study Mode (hide meanings)
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      expect(find.text('အဖ'), findsNothing);
      expect(find.text('အဓိပ္ပာယ်ကြည့်ရန် နှိပ်ပါ'), findsNWidgets(2));

      // Tap first card to reveal its meaning
      await tester.tap(find.text('ပိတာ'));
      await tester.pumpAndSettle();

      expect(find.text('အဖ'), findsOneWidget);
      expect(find.text('အဓိပ္ပာယ်ကြည့်ရန် နှိပ်ပါ'), findsOneWidget);
    });
  });

  group('Auto-Play Audio Playlist & Mini-Player', () {
    testWidgets('starts Auto-Play, shows Mini-Player, pauses and stops cleanly', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Start Auto-Play
      await tester.tap(find.text('တစ်ခန်းလုံး နားထောင်မည် (Auto-Play)'));
      await tester.pump();

      // Mini-Player bar appears with controls and inline speed chips
      expect(find.text('ဝါကျပါ ဖတ်မည်'), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      expect(find.text('0.3x'), findsOneWidget);
      expect(find.text('0.45x'), findsOneWidget);
      expect(find.text('0.6x'), findsOneWidget);

      // Pause Auto-Play
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // Stop Auto-Play
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('ဝါကျပါ ဖတ်မည်'), findsNothing);
    });
  });
}
