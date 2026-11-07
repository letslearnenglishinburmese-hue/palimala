import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimala/app_data.dart';
import 'package:palimala/main.dart';
import 'package:palimala/remote_app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Deliberately invented test fixture; it is not published lesson content.
const _storyFixture = <String, dynamic>{
  'contentType': 'story',
  'schemaVersion': 1,
  'titleMm': 'စမ်းသပ်ပုံပြင်',
  'titleEn': 'Test Story',
  'storyList': [
    {
      'paliMm': 'တေသ္ဋ်-ဝါကျံ ဧကံ။',
      'paliRoman': 'Tesṭa-vākyaṃ ekaṃ.',
      'translateMm': 'ဤသည် စမ်းသပ်ရန် ဖန်တီးထားသော စာကြောင်းဖြစ်သည်။',
      'translateEn': 'This sentence was created only for testing.',
    },
    {
      'paliMm': 'ဒုတိယံ တေသ္ဋ်-ဝါကျံ။',
      'paliRoman': 'Dutiyaṃ tesṭa-vākyaṃ.',
      'translateMm': 'ဤသည် ဒုတိယ စမ်းသပ်စာကြောင်းဖြစ်သည်။',
      'translateEn': 'This is a second test sentence.',
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('parses versioned story sentences with aligned fields', () {
    final lesson = SubCategory.fromJson(_storyFixture);

    expect(lesson.titleMm, 'စမ်းသပ်ပုံပြင်');
    expect(lesson.titleEn, 'Test Story');
    expect(lesson.story!.schemaVersion, 1);
    expect(lesson.story!.sentences, hasLength(2));
    expect(
      lesson.story!.sentences.first,
      isA<StorySentence>()
          .having((sentence) => sentence.paliMm, 'Pali script', isNotEmpty)
          .having((sentence) => sentence.paliRoman, 'Roman Pali', isNotEmpty)
          .having((sentence) => sentence.translateMm, 'Burmese', isNotEmpty)
          .having((sentence) => sentence.translateEn, 'English', isNotEmpty),
    );
    expect(lesson.vocabList, isNull);
    expect(lesson.dialogueList, isNull);
  });

  test('rejects malformed, empty, incomplete, and mixed story data', () {
    expect(() => jsonDecode('{"contentType":"story",'), throwsFormatException);
    expect(
      () => SubCategory.fromJson(
        jsonDecode('{"contentType":"story"}') as Map<String, dynamic>,
      ),
      throwsFormatException,
    );
    expect(
      () => SubCategory.fromJson({..._storyFixture, 'storyList': []}),
      throwsFormatException,
    );
    expect(
      () => SubCategory.fromJson({..._storyFixture, 'schemaVersion': 2}),
      throwsFormatException,
    );
    expect(
      () => SubCategory.fromJson({
        ..._storyFixture,
        'storyList': [
          {
            ...(_storyFixture['storyList'] as List).first as Map,
            'translateEn': '',
          },
        ],
      }),
      throwsFormatException,
    );
    final missingTranslation = Map<String, dynamic>.from(
      (_storyFixture['storyList'] as List).first as Map<String, dynamic>,
    )..remove('translateEn');
    expect(
      () => SubCategory.fromJson({
        ..._storyFixture,
        'storyList': [missingTranslation],
      }),
      throwsFormatException,
    );
    expect(
      () => SubCategory.fromJson({..._storyFixture, 'vocabList': []}),
      throwsFormatException,
    );
  });

  testWidgets('renders full story and aligned sentence translations', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DetailContentScreen(
          subCategory: SubCategory.fromJson(_storyFixture),
          currentLang: AppLanguage.myanmar,
          onLanguageToggle: () {},
          savedWords: const {},
          onSavedWordToggle: (_) {},
        ),
      ),
    );

    expect(find.text('စမ်းသပ်ပုံပြင်'), findsOneWidget);
    expect(find.text('ပုံပြင်အပြည့်အစုံ · Full story'), findsOneWidget);
    expect(find.text('စာကြောင်းအလိုက် · Sentence by sentence'), findsOneWidget);
    expect(find.text('Tesṭa-vākyaṃ ekaṃ.'), findsWidgets);
    expect(
      find.text('This sentence was created only for testing.'),
      findsWidgets,
    );
    expect(
      find.textContaining('This is a second test sentence.'),
      findsOneWidget,
    );
    expect(find.text('မြန်မာဘာသာပြန် · Burmese'), findsWidgets);
    expect(find.text('English translation'), findsWidgets);
  });

  test('keeps vocabulary and dialogue lessons backward compatible', () async {
    final categories = await AppDataRepository.loadBundled();
    final nouns = categories.firstWhere((category) => category.id == 'nouns');
    final dialogues = categories.firstWhere(
      (category) => category.id == 'dialogues',
    );

    expect(nouns.subCategories.first.vocabList, isNotNull);
    expect(nouns.subCategories.first.story, isNull);
    expect(dialogues.subCategories.first.dialogueList, isNotNull);
    expect(dialogues.subCategories.first.story, isNull);
  });

  test(
    'pali_stories source, generated dataset, config and manifest agree',
    () async {
      await AppDataRepository.loadBundled();
      final categorySource = jsonDecode(
        await rootBundle.loadString(
          'assets/lessons/pali_stories/category.json',
        ),
      ) as Map<String, dynamic>;
      final generatedText = await rootBundle.loadString(
        'assets/pali_data/pali_stories.json',
      );
      final generated = jsonDecode(generatedText) as Map<String, dynamic>;
      final manifestEntry = AppDataRepository.datasets.singleWhere(
        (dataset) => dataset.id == 'pali_stories',
      );
      final config = RemoteAppConfig.parse(
        await rootBundle.loadString('assets/app_config.json'),
      );
      final sourceCategory = Map<String, dynamic>.from(categorySource)
        ..remove('subCategoryFiles')
        ..['subCategories'] = <dynamic>[];
      final expected =
          '${const JsonEncoder.withIndent('  ').convert(sourceCategory)}\n';

      expect(
        config.categories.map((category) => category.id),
        contains('pali_stories'),
      );
      expect(generated, sourceCategory);
      expect(generatedText, expected);
      expect(manifestEntry.bytes, utf8.encode(generatedText).length);
      expect(
        manifestEntry.sha256,
        sha256.convert(utf8.encode(generatedText)).toString(),
      );
    },
  );
}
