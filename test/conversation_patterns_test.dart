import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimala/app_data.dart';
import 'package:palimala/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('bundles the Pali ability pattern and its five examples', () async {
    final categories = await AppDataRepository.loadBundled();
    final category = categories.singleWhere(
      (item) => item.id == 'conversation_patterns',
    );
    final lesson = category.subCategories.single;

    expect(category.icon, Icons.school_rounded);
    expect(lesson.titleMm, 'ကတ္တား+ကြိယာအရင်း+တုံ+သက္ကောတိ');
    expect(lesson.descriptionMm, contains('ကတ္တား + ကြိယာအရင်း'));
    expect(lesson.descriptionEn, contains('Subject + verb stem'));
    expect(lesson.vocabList, hasLength(5));
    expect(
      lesson.vocabList!.map((item) => item.paliRoman),
      containsAll([
        'So potthakaṃ paṭhituṃ sakkoti.',
        'Tvaṃ pāḷibhāsaṃ vattuṃ sakkosi.',
        'So udake tarituṃ sakkoti.',
        'Āgantuko khippaṃ gantuṃ sakkoti.',
        'Paṇḍito dhammaṃ kathetuṃ sakkoti.',
      ]),
    );
  });

  testWidgets('shows ability examples and pronunciation controls', (
    tester,
  ) async {
    final lesson = SubCategory.fromJson({
      'titleMm': 'စွမ်းဆောင်နိုင်မှုကို ဖော်ပြခြင်း',
      'titleEn': 'Expressing Ability',
      'descriptionMm':
          'ပုံစံ — ကတ္တား + ကြိယာအရင်း + တုံ + သက္ကောတိ\n'
          'အဓိပ္ပာယ် — (လုပ်)နိုင်တယ်၊ (လုပ်)တတ်တယ်။',
      'descriptionEn':
          'Pattern — Subject + verb stem + tuṃ + sakkoti\n'
          'Meaning — can / be able to do something.',
      'vocabList': [
        {
          'paliMm': 'သော ပေါတ္ထကံ ပဌိတုံ သက္ကောတိ။',
          'paliRoman': 'So potthakaṃ paṭhituṃ sakkoti.',
          'translateMm': 'သူ စာအုပ်ဖတ်နိုင်တယ်။',
          'translateEn': 'He can read the book.',
        },
      ],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: DetailContentScreen(
          subCategory: lesson,
          currentLang: AppLanguage.myanmar,
          onLanguageToggle: () {},
          savedWords: const {},
          onSavedWordToggle: (_) {},
        ),
      ),
    );

    expect(find.textContaining('ကတ္တား + ကြိယာအရင်း'), findsOneWidget);
    expect(find.text('သော ပေါတ္ထကံ ပဌိတုံ သက္ကောတိ။'), findsOneWidget);
    expect(find.text('သူ စာအုပ်ဖတ်နိုင်တယ်။'), findsOneWidget);
    expect(find.byTooltip('အသံနားထောင်ရန်'), findsWidgets);
  });
}
