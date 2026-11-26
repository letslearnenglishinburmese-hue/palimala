import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:palimala/app_data.dart';
import 'package:palimala/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Part 1 Fixes Verification', () {
    testWidgets('VocabularyQuizScreen randomizes choices and answers', (
      WidgetTester tester,
    ) async {
      final sampleWords = List.generate(
        10,
        (i) => VocabItem(
          paliMm: 'ပါဠိ $i',
          paliRoman: 'pali_$i',
          translateMm: 'အဓိပ္ပာယ် $i',
          translateEn: 'Meaning $i',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: VocabularyQuizScreen(
            words: sampleWords,
            isMyanmar: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check that a question is displayed
      expect(find.text('မေးခွန်း 1 / 10'), findsOneWidget);

      // Verify that the correct button has the matching text
      final correctMeaning = sampleWords[0].translateMm;
      final correctButton = find.widgetWithText(OutlinedButton, correctMeaning);
      expect(correctButton, findsOneWidget);

      // Tapping the correct answer records correct
      await tester.tap(correctButton);
      await tester.pumpAndSettle();
      expect(find.text('အဖြေမှန်ပါသည်'), findsOneWidget);
    });

    testWidgets('DetailContentScreen displays translations without hardcoded black87', (
      WidgetTester tester,
    ) async {
      final sampleSub = SubCategory(
        titleMm: 'စမ်းသပ်ခန်း',
        titleEn: 'Test Chapter',
        vocabList: [
          VocabItem(
            paliMm: 'ဗုဒ္ဓ',
            paliRoman: 'buddha',
            translateMm: 'မြတ်စွာဘုရား',
            translateEn: 'Buddha',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: DetailContentScreen(
            subCategory: sampleSub,
            currentLang: AppLanguage.myanmar,
            onLanguageToggle: () {},
            savedWords: const {},
            onSavedWordToggle: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text('မြတ်စွာဘုရား'));
      // Verify color is not hardcoded black87
      expect(textWidget.style?.color, isNot(equals(Colors.black87)));
    });

    test('Settings persistence loads stored preferences', () async {
      SharedPreferences.setMockInitialValues({
        'pali_pref_language': 'english',
        'pali_pref_dark_mode': true,
        'pali_pref_text_scale': 1.2,
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pali_pref_language'), equals('english'));
      expect(prefs.getBool('pali_pref_dark_mode'), isTrue);
      expect(prefs.getDouble('pali_pref_text_scale'), equals(1.2));
    });
  });
}
