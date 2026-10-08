// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:palimala/main.dart';
import 'package:palimala/app_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final dataJson = await rootBundle.loadString('assets/pali_data.json');
    final decodedData = jsonDecode(dataJson) as List<dynamic>;
    appData = decodedData
        .map((value) => MainCategory.fromJson(value as Map<String, dynamic>))
        .toList();
  });

  test('Family vocabulary includes the requested relatives', () {
    final family = appData.first.subCategories.first.vocabList!;
    final romanWords = family.map((item) => item.paliRoman).toSet();

    expect(family, hasLength(31));
    expect(romanWords, hasLength(family.length));
    expect(
      romanWords,
      containsAll([
        'Bhātā',
        'Bhaginī',
        'Pitāmaho',
        'Mātāmahī',
        'Jeṭṭhabhātā',
        'Kaniṭṭhabhātā',
        'Jeṭṭhabhaginī',
        'Kaniṭṭhabhaginī',
        'Nattā',
        'Bhattā',
        'Bhariyā',
        'Mahāpitā',
        'Cūḷapitā',
        'Mātulo',
        'Mātulānī',
        'Mātucchā',
        'Pitucchā',
        'Jāmātā',
        'Suṇisā',
        'Sālo',
        'Nanandā',
        'Bhāgineyyo',
        'Bhāgineyyā',
        'Ayyako',
        'Ayyikā',
        'Sassu',
        'Sassuro',
      ]),
    );
    expect(
      family
          .firstWhere((item) => item.paliRoman == 'Mātāmahī')
          .example
          ?.translateEn,
      'The maternal grandmother gives alms.',
    );
  });

  test('Color vocabulary includes the requested colors', () {
    final colors = appData.first.subCategories[1].vocabList!;
    final romanWords = colors.map((item) => item.paliRoman).toSet();

    expect(colors, hasLength(6));
    expect(
      romanWords,
      containsAll(['Nīlo', 'Pīto', 'Seto / Sukko', 'Kaṇho', 'Harito']),
    );
    expect(colors[1].example?.translateEn, 'The blue sky is beautiful.');
  });

  test('Classroom vocabulary includes the requested words', () {
    final classroom = appData.first.subCategories[2].vocabList!;
    final romanWords = classroom.map((item) => item.paliRoman).toSet();

    expect(classroom, hasLength(6));
    expect(
      romanWords,
      containsAll([
        'Sisso',
        'Ācariyo',
        'Potthakaṃ',
        'Lekhanī',
        'Phalakaṃ',
        'Satthālayo / Vijjālayo',
      ]),
    );
    expect(classroom.first.example?.paliRoman, 'Sisso satthālayaṃ gacchati.');
  });

  test('Apparel vocabulary includes the requested clothes and accessories', () {
    final apparel = appData.first.subCategories
        .firstWhere((category) => category.titleMm == 'အဝတ်အစားများ')
        .vocabList!;
    final romanWords = apparel.map((item) => item.paliRoman).toSet();

    expect(apparel, hasLength(27));
    expect(romanWords, hasLength(apparel.length));
    expect(
      romanWords,
      containsAll([
        'Vatthaṃ',
        'Kappāsikaṃ',
        'Koseyyaṃ',
        'Nivāsanaṃ',
        'Uttarīyaṃ',
        'Kañcuko',
        'Antarakañcuko',
        'Kambalaṃ',
        'Gīveyyaṃ',
        'Gaṇṭhi',
        'Nālipaṭṭo',
        'Sīsaveṭhanaṃ',
        'Kirīṭaṃ',
        'Uṇhīsaṃ',
        'Kuṇḍalaṃ',
        'Valayo',
        'Kaṇṭhābhūsanaṃ',
        'Hāro / Muttāvali',
        'Aṅguliyakaṃ / Muddikā',
        'Kāyabandhanaṃ',
        'Mekhalā',
        'Pādadaṃ',
        'Upāhano',
        'Pādukā',
        'Chattaṃ',
        'Hatthapuñchanaṃ',
        'Mukhapuñchanaṃ',
      ]),
    );
    expect(apparel.every((item) => item.example != null), isTrue);
  });

  test('Academic verbs include the requested verbs without duplicates', () {
    final academicVerbs = appData[1].subCategories.first.vocabList!;
    final romanWords = academicVerbs.map((item) => item.paliRoman).toSet();

    expect(academicVerbs, hasLength(19));
    expect(romanWords, hasLength(academicVerbs.length));
    expect(
      romanWords,
      containsAll([
        'Passati',
        'Vicināti',
        'Nijjhāyati',
        'Vibhajati',
        'Upanidheti',
        'Niddisati',
        'Sādheti',
        'Pakāseti',
        'Saṃharati',
        'Likhati',
        'Paṭhati',
        'Sāreti',
        'Sodheti',
        'Sampādeti',
      ]),
    );
    expect(academicVerbs.every((item) => item.example != null), isTrue);
    expect(
      academicVerbs
          .firstWhere((item) => item.paliRoman == 'Likhati')
          .example
          ?.paliRoman,
      'Lekhako sāratthaṃ likhati.',
    );
  });

  test('Emotional verbs include the requested verbs without duplicates', () {
    final emotionalVerbs = appData[1].subCategories
        .firstWhere(
          (category) => category.titleMm == 'စိတ်ခံစားမှုဆိုင်ရာကြိယာများ',
        )
        .vocabList!;
    final romanWords = emotionalVerbs.map((item) => item.paliRoman).toSet();

    expect(emotionalVerbs, hasLength(12));
    expect(romanWords, hasLength(emotionalVerbs.length));
    expect(
      romanWords,
      containsAll([
        'Pamodati',
        'Kujjhati',
        'Socati',
        'Bhāyati',
        'Kaṅkhati',
        'Sineheti',
        'Jigucchati',
        'Issayati',
        'Anuddayati',
        'Pasādeti',
        'Visīdati',
        'Assāseti',
      ]),
    );
    expect(emotionalVerbs.every((item) => item.example != null), isTrue);
    expect(
      emotionalVerbs
          .firstWhere((item) => item.paliRoman == 'Socati')
          .example
          ?.paliRoman,
      'Mātā puttassa viyogena socati.',
    );
  });

  test(
    'Travel verbs include all twenty requested verbs without duplicates',
    () {
      final travelVerbs = appData[1].subCategories
          .firstWhere(
            (category) => category.titleMm == 'ခရီးသွားလာခြင်းဆိုင်ရာကြိယာများ',
          )
          .vocabList!;
      final romanWords = travelVerbs.map((item) => item.paliRoman).toSet();

      expect(travelVerbs, hasLength(20));
      expect(romanWords, hasLength(travelVerbs.length));
      expect(
        romanWords,
        containsAll([
          'Gacchati',
          'Āgacchati',
          'Carati / Āhiṇḍati',
          'Tiṭṭhati',
          'Nisīdati',
          'Ārohati',
          'Otarati',
          'Kīṇāti',
          'Passati',
          'Pāpuṇāti',
          'Nikkhamati',
          'Paṭṭhāpeti',
          'Abhirūhati',
          'Tarati',
          'Nivattati',
          'Vāsitaṃ karoti / Vasati',
          'Pariyessati',
          'Parivajjeti',
          'Anugacchati',
          'Vissamati',
        ]),
      );
      expect(travelVerbs.every((item) => item.example != null), isTrue);
    },
  );

  test('Cooking verbs include all ten requested verbs without duplicates', () {
    final cookingVerbs = appData[1].subCategories
        .firstWhere(
          (category) => category.titleMm == 'ချက်ပြုတ်ခြင်းဆိုင်ရာကြိယာများ',
        )
        .vocabList!;
    final romanWords = cookingVerbs.map((item) => item.paliRoman).toSet();

    expect(cookingVerbs, hasLength(10));
    expect(romanWords, hasLength(cookingVerbs.length));
    expect(
      romanWords,
      containsAll([
        'Pacati',
        'Dhovati',
        'Chindati',
        'Koṭṭeti',
        'Bhajjati',
        'Pakkuthitaṃ karoti',
        'Āsiñcati',
        'Misseti',
        'Sajjeti / Sampādeti',
        'Sādeti',
      ]),
    );
    expect(cookingVerbs.every((item) => item.example != null), isTrue);
  });

  test('Main vocabulary has exactly six requested sections', () {
    final categoryTitles = appData.map((category) => category.titleMm).toSet();

    expect(appData, hasLength(6));
    expect(
      categoryTitles,
      containsAll([
        'နာမ်ပုဒ်များ',
        'ကြိယာပုဒ်များ',
        'နာမဝိသေသနပုဒ်များ',
        'ကြိယာဝိသေသနပုဒ်များ',
        'နိပါတ်ပုဒ်များ',
        'ပါဠိစကားပြောခန်း',
      ]),
    );
    expect(categoryTitles, isNot(contains('ကိတ်ကြိယာပုဒ်များ')));
    expect(categoryTitles, isNot(contains('ပါဠိစကားပြောပုံစံများ')));
  });

  test('Qualitative adjective chapter includes all twenty examples', () {
    final adjectiveCategory = appData.firstWhere(
      (category) => category.titleMm == 'နာမဝိသေသနပုဒ်များ',
    );
    final qualitativeAdjectives = adjectiveCategory.subCategories[2];
    final vocabList = qualitativeAdjectives.vocabList!;
    final romanWords = vocabList.map((item) => item.paliRoman).toSet();

    expect(qualitativeAdjectives.titleMm, 'ဂုဏဝိသေသနများ');
    expect(qualitativeAdjectives.titleEn, 'Qualitative Adjectives');
    expect(vocabList, hasLength(20));
    expect(romanWords, hasLength(vocabList.length));
    expect(
      romanWords,
      containsAll([
        'Sukka',
        'Kaṇha',
        'Ratta',
        'Mahanta',
        'Khuddaka',
        'Dīgha',
        'Rassa',
        'Sādhu',
        'Pāpa',
        'Madhura',
        'Tittaka',
        'Sīta',
        'Uṇha',
        'Balavanta',
        'Dubbala',
        'Paṇḍita',
        'Mūḷha',
        'Taruṇa',
        'Vuḍḍha',
        'Suci',
      ]),
    );
    expect(vocabList.every((item) => item.example != null), isTrue);
    expect(
      vocabList
          .firstWhere((item) => item.paliRoman == 'Sukka')
          .example
          ?.paliRoman,
      'So sukkaṃ vatthaṃ paridahati.',
    );
  });

  test('Nipata categories include the requested particles and examples', () {
    final nipata = appData.firstWhere(
      (category) => category.titleMm == 'နိပါတ်ပုဒ်များ',
    );
    final timeParticles = nipata.subCategories
        .firstWhere((category) => category.titleMm == 'ကာလပြနိပါတ်ပုဒ်များ')
        .vocabList!;
    final mannerParticles = nipata.subCategories
        .firstWhere((category) => category.titleMm == 'အခြေအနေပြနိပါတ်ပုဒ်များ')
        .vocabList!;
    final placeParticles = nipata.subCategories
        .firstWhere((category) => category.titleMm == 'နေရာဒေသပြနိပါတ်ပုဒ်များ')
        .vocabList!;

    expect(timeParticles, hasLength(19));
    expect(
      timeParticles.map((item) => item.paliRoman),
      containsAll([
        'Pāto',
        'Sāyaṃ',
        'Divā',
        'Rattiṃ',
        'Sabbadā',
        'Kadāci',
        'Sampati',
        'Āyatiṃ',
        'Etarahi',
        'Tāva',
        'Suve',
        'Sayaṃ',
        'Pacchā',
        'Ciraṃ',
      ]),
    );
    expect(
      timeParticles.where((item) => item.paliRoman == 'Suve'),
      hasLength(1),
    );
    expect(mannerParticles, hasLength(15));
    expect(
      mannerParticles.map((item) => item.paliRoman),
      containsAll([
        'Sīghaṃ',
        'Saṇikaṃ',
        'Suṭṭhu',
        'Sukhena',
        'Dukkhena',
        'Sabbathā',
        'Sayaṃ',
        'Musā',
        'Saccaṃ',
        'Punappunaṃ',
      ]),
    );
    expect(placeParticles, hasLength(10));
    expect(
      placeParticles.map((item) => item.paliRoman),
      containsAll([
        'Idha',
        'Tattha / Tahiṃ',
        'Aññattha',
        'Sabbattha',
        'Kattha / Kuhiṃ',
        'Upari',
        'Adho',
        'Anto',
        'Bahi',
        'Samantā',
      ]),
    );
    expect(
      [
        timeParticles,
        mannerParticles,
        placeParticles,
      ].expand((items) => items).every((item) => item.example != null),
      isTrue,
    );
    expect(
      mannerParticles
          .firstWhere((item) => item.paliRoman == 'Sayaṃ')
          .example
          ?.paliRoman,
      'Lekhako sayaṃ cāmūṃ likhati.',
    );
    expect(
      placeParticles
          .firstWhere((item) => item.paliRoman == 'Idha')
          .example
          ?.translateEn,
      'The teacher lives here.',
    );
  });

  testWidgets('PaliLearningApp renders', (WidgetTester tester) async {
    await tester.pumpWidget(const PaliLearningApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('ယနေ့လေ့လာရန်'), findsOneWidget);
    expect(find.text('ဝေါဟာရ လေ့ကျင့်မည်'), findsNothing);
    expect(find.widgetWithText(TextButton, 'ရှာရန်'), findsNothing);
    expect(find.text('နာမ်ပုဒ်များ'), findsOneWidget);
    expect(find.text('ကြိယာပုဒ်များ'), findsOneWidget);
    expect(find.text('နာမဝိသေသနပုဒ်များ'), findsOneWidget);
    expect(find.text('ကြိယာဝိသေသနပုဒ်များ'), findsOneWidget);
    expect(find.text('နိပါတ်ပုဒ်များ'), findsOneWidget);
    expect(find.text('ပါဠိစကားပြောခန်း'), findsOneWidget);
    expect(find.text('ကိတ်ကြိယာပုဒ်များ'), findsNothing);
    expect(find.text('ပါဠိစကားပြောပုံစံများ'), findsNothing);
  });

  testWidgets('Drawer displays the supplied logo and bilingual name', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PaliLearningApp());
    await tester.tap(find.byTooltip('မီနူး'));
    await tester.pumpAndSettle();

    expect(find.text('ပါဠိမာလာ'), findsOneWidget);
    expect(find.text('Pāḷimālā'), findsOneWidget);
    expect(
      (tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName,
      'assets/palimala_logo.png',
    );
  });

  testWidgets('Vocabulary quiz records correct answers and completes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PaliLearningApp());
    await tester.drag(find.byType(ListView).first, const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(find.text('နာမ်ပုဒ်များ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ဆွေမျိုးများ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ဤအခန်းကို လေ့ကျင့်မည်'));
    await tester.pumpAndSettle();

    for (var questionIndex = 0; questionIndex < 10; questionIndex++) {
      await tester.tap(find.byType(OutlinedButton).at(questionIndex % 4));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -220));
      await tester.pumpAndSettle();
      await tester.tap(find.text('နောက်မေးခွန်း'));
      await tester.pumpAndSettle();
    }

    expect(find.text('အဖြေမှန် 10 / 10 ခု'), findsOneWidget);
  });

  testWidgets('Dialogue chapters provide a working practice exercise', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PaliLearningApp());
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ပါဠိစကားပြောခန်း'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ဆရာတပည့် အပြန်အလှန်ဆွေးနွေးခန်း'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ဤအခန်းကို လေ့ကျင့်မည်'));
    await tester.pumpAndSettle();

    for (var questionIndex = 0; questionIndex < 2; questionIndex++) {
      await tester.tap(find.byType(OutlinedButton).at(questionIndex));
      await tester.pumpAndSettle();
      if (questionIndex == 0) {
        await tester.tap(find.text('နောက်မေးခွန်း'));
        await tester.pumpAndSettle();
      }
    }

    await tester.tap(find.text('နောက်မေးခွန်း'));
    await tester.pumpAndSettle();
    expect(find.text('အဖြေမှန် 2 / 2 ခု'), findsOneWidget);
  });

  testWidgets(
    'Vocabulary examples appear inline with save and audio controls',
    (WidgetTester tester) async {
      await tester.pumpWidget(const PaliLearningApp());

      await tester.drag(find.byType(ListView).first, const Offset(0, -260));
      await tester.pumpAndSettle();
      await tester.tap(find.text('နာမ်ပုဒ်များ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ဆွေမျိုးများ'));
      await tester.pumpAndSettle();

      expect(find.text('ပိတာ ဂေဟံ အာဂစ္ဆတိ။'), findsOneWidget);
      expect(find.text('Pitā gehaṃ āgacchati.'), findsNothing);
      expect(find.text('အဖေသည် အိမ်သို့ လာ၏။'), findsOneWidget);
      expect(find.byTooltip('သိမ်းရန်'), findsWidgets);
      expect(find.byTooltip('အသံနားထောင်ရန်'), findsWidgets);
      expect(find.byTooltip('စာကြောင်းအသံနားထောင်ရန်'), findsWidgets);
      expect(find.text('ဥပမာဝါကျ'), findsNothing);
      expect(find.text('ဥပမာဝါကျဖြင့် လေ့လာရန်'), findsNothing);
      final paliSentence = tester.widget<Text>(
        find.text('ပိတာ ဂေဟံ အာဂစ္ဆတိ။'),
      );
      expect(paliSentence.style?.fontSize, 18);
      expect(
        paliSentence.style?.color,
        Theme.of(tester.element(find.text('ပိတာ'))).colorScheme.primary,
      );

      await tester.tap(find.byType(FilterChip));
      await tester.pumpAndSettle();

      expect(find.text('ENG'), findsOneWidget);
      expect(find.text('ပိတာ ဂေဟံ အာဂစ္ဆတိ။'), findsNothing);
      expect(find.text('Pitā gehaṃ āgacchati.'), findsOneWidget);
      expect(find.text('အဖေသည် အိမ်သို့ လာ၏။'), findsNothing);
      expect(find.text('The father comes home.'), findsOneWidget);
    },
  );

  testWidgets('Language toggle works on a pushed subcategory screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PaliLearningApp());

    await tester.drag(find.byType(ListView).first, const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(find.text('နာမ်ပုဒ်များ'));
    await tester.pumpAndSettle();

    expect(find.text('ဆွေမျိုးများ'), findsOneWidget);

    await tester.tap(find.byType(FilterChip));
    await tester.pumpAndSettle();

    expect(find.text('Ralitives and Family Members'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('Search Word'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Search and settings are available from bottom navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PaliLearningApp());

    await tester.tap(find.text('မြန်မာ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search Word'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Father');
    await tester.pumpAndSettle();

    expect(find.text('Pitā'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });

  testWidgets('Vocabulary can be saved and viewed from the saved tab', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const PaliLearningApp());

    await tester.drag(find.byType(ListView).first, const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(find.text('နာမ်ပုဒ်များ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ဆွေမျိုးများ'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('သိမ်းရန်').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('မှတ်ထားသည်များ'));
    await tester.pumpAndSettle();

    expect(find.text('ပိတာ'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('saved_pali_words'), contains('Pitā'));
  });
}
