// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:palimala/main.dart';
import 'package:palimala/app_data.dart';

String _withoutGenderMarker(String paliRoman) =>
    paliRoman.replaceFirst(RegExp(r' \([MFN/]+\)$'), '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    appData = await AppDataRepository.loadBundled();
  });

  test('Family vocabulary includes the requested relatives', () {
    final family = appData.first.subCategories.first.vocabList!;
    final romanWords = family
        .map((item) => _withoutGenderMarker(item.paliRoman))
        .toSet();

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
          .firstWhere(
            (item) => _withoutGenderMarker(item.paliRoman) == 'Mātāmahī',
          )
          .example
          ?.translateEn,
      'The maternal grandmother gives alms.',
    );
  });

  test('Color vocabulary includes the requested colors', () {
    final colors = appData.first.subCategories[1].vocabList!;
    final romanWords = colors
        .map((item) => _withoutGenderMarker(item.paliRoman))
        .toSet();

    expect(colors, hasLength(6));
    expect(
      romanWords,
      containsAll(['Nīlo', 'Pīto', 'Seto / Sukko', 'Kaṇho', 'Harito']),
    );
    expect(colors[1].example?.translateEn, 'The blue sky is beautiful.');
  });

  test('Classroom vocabulary includes the requested words', () {
    final classroom = appData.first.subCategories[2].vocabList!;
    final romanWords = classroom
        .map((item) => _withoutGenderMarker(item.paliRoman))
        .toSet();

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

  test('Travel dialogue has eight alternating quadruple-line turns', () {
    final dialogues = appData
        .firstWhere((category) => category.titleEn == 'Pāḷi Dialogues')
        .subCategories
        .firstWhere((category) => category.titleEn == 'Traveling in Pāḷi')
        .dialogueList!;

    expect(dialogues, hasLength(8));
    for (var index = 0; index < dialogues.length; index++) {
      final dialogue = dialogues[index];
      expect(
        dialogue.speakerEn,
        index.isEven ? 'Pathaviko (Traveler)' : 'Māggiko (Local Guide)',
      );
      expect(dialogue.paliMm, isNotEmpty);
      expect(dialogue.paliRoman, isNotEmpty);
      expect(dialogue.translateMm, isNotEmpty);
      expect(dialogue.translateEn, isNotEmpty);
    }
  });

  test('Reloading local lessons notifies the app to rebuild', () async {
    final previousRevision = appDataRevision.value;

    await AppDataRepository.reloadBundled();

    expect(appDataRevision.value, previousRevision + 1);
    expect(
      AppDataRepository.categories
          .firstWhere((category) => category.titleEn == 'Pāḷi Dialogues')
          .subCategories
          .map((category) => category.titleEn),
      contains('Traveling in Pāḷi'),
    );
  });

  test('Apparel vocabulary includes the requested clothes and accessories', () {
    final apparel = appData.first.subCategories
        .firstWhere((category) => category.titleMm == 'အဝတ်အစားများ')
        .vocabList!;
    final romanWords = apparel
        .map((item) => _withoutGenderMarker(item.paliRoman))
        .toSet();

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

  test('Fruit vocabulary includes all twenty requested examples', () {
    final fruits = appData.first.subCategories
        .firstWhere((category) => category.titleMm == 'သစ်သီးများ')
        .vocabList!;
    final romanWords = fruits
        .map((item) => _withoutGenderMarker(item.paliRoman))
        .toSet();

    expect(fruits, hasLength(20));
    expect(romanWords, hasLength(fruits.length));
    expect(
      romanWords,
      containsAll([
        'Amba',
        'Kadali',
        'Panasa',
        'Nāḷikera',
        'Jambū',
        'Badara',
        'Kapiṭṭha',
        'Dāḷimaphala',
        'Tāla',
        'Muddikā',
        'Jambīra',
        'Siṅgivera',
        'Alābu',
        'Kakkarī',
        'Kālinda',
        'Udumbara',
        'Āmalaka',
        'Harītakī',
        'Vibhīṭakaphala',
        'Sītāphala',
      ]),
    );
    expect(fruits.every((item) => item.example != null), isTrue);
    expect(
      fruits
          .firstWhere(
            (item) => _withoutGenderMarker(item.paliRoman) == 'Dāḷimaphala',
          )
          .example
          ?.paliRoman,
      'Sā rattaṃ dāḷimaphalaṃ ānayati.',
    );
  });

  test('Every noun has matching Burmese and Roman gender markers', () {
    final nouns = appData.firstWhere(
      (category) => category.titleMm == 'နာမ်ပုဒ်များ',
    );
    const romanGender = {'ပု': 'M', 'ထီ': 'F', 'န': 'N'};

    for (final item in nouns.subCategories.expand(
      (category) => category.vocabList!,
    )) {
      final mmMarker = RegExp(r' \(([^()]*)\)$')
          .firstMatch(item.paliMm)
          ?.group(1);
      final romanMarker = RegExp(r' \(([MFN/]+)\)$')
          .firstMatch(item.paliRoman)
          ?.group(1);

      expect(mmMarker, isNotNull, reason: item.paliMm);
      expect(romanMarker, isNotNull, reason: item.paliRoman);
      expect(
        romanMarker,
        mmMarker!.split('/').map((marker) => romanGender[marker]).join('/'),
        reason: item.paliRoman,
      );
    }
  });

  test('Noun chapters include all requested vocabulary groups', () {
    final nouns = appData.firstWhere(
      (category) => category.titleMm == 'နာမ်ပုဒ်များ',
    );
    const expectedWords = {
      'သစ်ပင်နှင့် အပင်များ': [
        'Rukkha',
        'Taru',
        'Latā',
        'Paṇṇa',
        'Puppha',
        'Sākhā',
        'Mūla',
        'Taca',
        'Vana',
        'Gaccha',
      ],
      'ခန္ဓာကိုယ်အစိတ်အပိုင်းများ': [
        'Sīsa / Sira',
        'Mukha',
        'Akkhi / Nayana',
        'Sota / Kaṇṇa',
        'Nāsā / Nāsikā',
        'Jivhā',
        'Hattha / Kara',
        'Pāda',
        'Hadaya',
        'Kāya',
      ],
      'အိမ်သုံးပစ္စည်းများ': [
        'Geha / Ghara',
        'Pīṭha',
        'Mañca',
        'Patta',
        'Kaṭāha',
        'Kumba',
        'Saraka / Casaka',
        'Sucī',
        'Sattha / Satthaka',
        'Dvāra',
      ],
      'ရာသီဥတုနှင့် သဘာဝအရာများ': [
        'Sūriya / Ādicca',
        'Canda / Candima',
        'Megha / Vallāhaka',
        'Vassa / Vuṭṭhi',
        'Vāta / Anila',
        'Ākāsa / Gagana',
        'Pabbata / Giri',
        'Nadī',
        'Samudda / Sāgara',
        'Bhūmi / Pathavī',
      ],
      'မြို့ရွာနှင့် နေရာဌာနများ': [
        'Nagara / Pura',
        'Gāma',
        'Vihāra / Ārāma',
        'Āpaṇa',
        'Magga',
        'Sālā',
        'Nivesana / Geha',
        'Raṭṭha / Janapada',
        'Tittha',
        'Uyyāna',
      ],
      'အချိန်နှင့် ကာလများ': [
        'Kāla',
        'Divasa / Aha',
        'Ratti',
        'Pubbaṇha',
        'Majjhanha',
        'Sāyaṇha',
        'Māsa',
        'Saṃvacchara / Vassa',
        'Khaṇa',
        'Utu',
      ],
      'နေ့ရက်များ': [
        'Ravivāra / Sūriyavāra',
        'Candavāra',
        'Aṅgāravāra',
        'Budhavāra',
        'Guruvāra / Brahassapativāra',
        'Sukkavāra',
        'Sanivāra',
      ],
      'ရာသီများ': [
        'Gimhautu / Gimha',
        'Vassānautu / Vassāna',
        'Hemantautu / Hemanta',
        'Saradautu / Sarada',
      ],
      'အသက်မွေးဝမ်းကျောင်းနှင့် လူပုဂ္ဂိုလ်များ': [
        'Ācariya',
        'Sissa',
        'Bāṇija',
        'Kassaka',
        'Vejja',
        'Bhūpāla / Rājā',
        'Sūpakāra',
        'Rajaka',
        'Suvaṇṇakāra',
        'Gopālaka',
        'Cora',
        'Nāvika',
        'Kumbhakāra',
        'Vaḍḍhaki',
        'Yodha',
        'Yācaka',
        'Mālākāra',
        'Veṇika',
        'Dūta',
        'Gaṇaka',
      ],
    };

    for (final entry in expectedWords.entries) {
      final chapter = nouns.subCategories.firstWhere(
        (category) => category.titleMm == entry.key,
      );
      final words = chapter.vocabList!
          .map((item) => _withoutGenderMarker(item.paliRoman))
          .toSet();

      expect(chapter.vocabList, hasLength(entry.value.length));
      expect(words, containsAll(entry.value));
      expect(chapter.vocabList!.every((item) => item.example != null), isTrue);
    }
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

  test('Physical action verbs include all ten requested examples', () {
    final verbs = appData[1].subCategories.firstWhere(
      (category) =>
          category.titleMm ==
          'ခန္ဓာကိုယ်လှုပ်ရှားမှုနှင့် အမူအယာဆိုင်ရာ ကြိယာများ',
    );
    final vocabList = verbs.vocabList!;

    expect(vocabList, hasLength(10));
    expect(
      vocabList.map((item) => item.paliRoman),
      containsAll([
        'Uṭṭhāti',
        'Nisīdati',
        'Pasāreti',
        'Samiñjeti',
        'Āliṅgati',
        'Sirasā namassati',
        'Sīsaṃ kampeti',
        'Hatthaṃ dhunāti',
        'Akkhiṃ nimeseti',
        'Aṅguliṃ cāleti',
      ]),
    );
    expect(vocabList.every((item) => item.example != null), isTrue);
  });

  test('Governance and conflict verbs include all twenty examples', () {
    final verbs = appData[1].subCategories.firstWhere(
      (category) =>
          category.titleMm ==
          'ဥပဒေ၊ အုပ်ချုပ်ရေးနှင့် တိုက်ခိုက်ရေးဆိုင်ရာ ကြိယာများ',
    );
    final vocabList = verbs.vocabList!;

    expect(vocabList, hasLength(20));
    expect(
      vocabList.map((item) => item.paliRoman),
      containsAll([
        'Pasāsati',
        'Rakkhati',
        'Jināti',
        'Parājeti',
        'Yujjhati',
        'Pakkhandati',
        'Nicchayaṃ karoti',
        'Āṇāpeti',
        'Niggaṇhāti',
        'Paggaṇhāti',
        'Bandhati',
        'Muñcati',
        'Hanati',
        'Pāleti',
        'Codeti',
        'Daṇḍeti',
        'Rundhati',
        'Vihiṃsati',
        'Khamāpeti',
        'Sandhiṃ karoti',
      ]),
    );
    expect(vocabList.every((item) => item.example != null), isTrue);
  });

  test('Religious and spiritual verbs include all twenty examples', () {
    final verbs = appData[1].subCategories.firstWhere(
      (category) =>
          category.titleMm == 'တရားဓမ္မ၊ ဘာဝနာနှင့် သာသနာရေးဆိုင်ရာ ကြိယာများ',
    );
    final vocabList = verbs.vocabList!;

    expect(vocabList, hasLength(20));
    expect(
      vocabList.map((item) => item.paliRoman),
      containsAll([
        'Pūjeti',
        'Bhāveti',
        'Jhāyati',
        'Vandati',
        'Deseti',
        'Suṇāti',
        'Sarati',
        'Pabbajati',
        'Sīlaṃ rakkhati',
        'Deti',
        'Anumodati',
        'Khamāpeti',
        'Sallakkheti',
        'Vipassati',
        'Sajjhāyati',
        'Pattheti',
        'Samāpajjati',
        'Pātimokkhaṃ uddisati',
        'Pattiṃ dadāti',
        'Saccāni bujjhati',
      ]),
    );
    expect(vocabList.every((item) => item.example != null), isTrue);
  });

  test('New verb chapters include twenty unique entries and examples', () {
    const chapterTitles = [
      'ကုန်ကူးသန်းရောင်းဝယ်ရေးနှင့် စီးပွားရေးဆိုင်ရာ ကြိယာများ',
      'သတိ၊ အသိပညာနှင့် အတွေးအခေါ်ဆိုင်ရာ ကြိယာများ',
      'ပိုင်ဆိုင်မှု၊ ရယူခြင်းနှင့် စွန့်လွှတ်ခြင်းဆိုင်ရာ ကြိယာများ',
      'သဘာဝတ္ထုနှင့် ရာသီဥတု ဖြစ်ပျက်မှုဆိုင်ရာ ကြိယာများ',
      'သန့်ရှင်းရေးနှင့် ပြုပြင်ထိန်းသိမ်းခြင်းဆိုင်ရာ ကြိယာများ',
      'ပြောင်းလဲခြင်းနှင့် ဖြစ်ပေါ်လာခြင်းဆိုင်ရာ ကြိယာများ',
      'အစားအသောက်နှင့် သောက်သုံးခြင်းဆိုင်ရာ ကြိယာများ',
      'နေထိုင်မှုနှင့် အိပ်စက်ခြင်းဆိုင်ရာ ကြိယာများ',
    ];
    final verbs = appData[1];

    for (final title in chapterTitles) {
      final chapter = verbs.subCategories.firstWhere(
        (category) => category.titleMm == title,
      );
      final vocabList = chapter.vocabList!;

      expect(chapter.titleEn, isNotEmpty, reason: title);
      expect(vocabList, hasLength(20), reason: title);
      expect(
        vocabList.map((item) => item.paliRoman).toSet(),
        hasLength(20),
        reason: title,
      );
      expect(vocabList.every((item) => item.example != null), isTrue);
    }
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
        Theme.of(tester.element(find.text('ပိတာ (ပု)'))).colorScheme.primary,
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

    expect(find.text('Pitā (M)'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });

  testWidgets('Search finds vocabulary using Myanmar text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PaliLearningApp());

    await tester.tap(find.text('ရှာရန်'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'အဖေ');
    await tester.pumpAndSettle();

    expect(find.text('ပိတာ (ပု)'), findsOneWidget);
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

    expect(find.text('ပိတာ (ပု)'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('saved_pali_words'), contains('Pitā (M)'));
  });

  test('Data manifest exposes every split data set with a valid hash', () {
    expect(AppDataRepository.datasets, hasLength(6));
    for (final dataset in AppDataRepository.datasets) {
      expect(dataset.sha256, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(dataset.bytes, greaterThan(0), reason: dataset.id);
      expect(
        AppDataRepository.statusOf(dataset),
        DatasetStatus.upToDate,
        reason: dataset.id,
      );
    }
  });

  test(
    'A cached copy older than the manifest is reported as outdated',
    () async {
      final original = await rootBundle.loadString(
        'assets/pali_data/nouns.json',
      );
      final stale = original.replaceFirst(
        '"titleEn": "Nouns (Nāma)"',
        '"titleEn": "Nouns (older cached copy)"',
      );
      expect(stale, isNot(original));
      final staleHash = sha256.convert(utf8.encode(stale)).toString();

      SharedPreferences.setMockInitialValues({
        'pali_dataset_json_nouns': stale,
        'pali_dataset_sha256_nouns': staleHash,
      });
      await AppDataRepository.loadBundled();

      final nouns = AppDataRepository.datasets.firstWhere(
        (dataset) => dataset.id == 'nouns',
      );
      expect(AppDataRepository.hasDownloadedCopy(nouns), isTrue);
      expect(AppDataRepository.statusOf(nouns), DatasetStatus.updateAvailable);
      expect(AppDataRepository.updatesAvailable, 1);

      // Restore the pristine bundled state for the tests that follow.
      SharedPreferences.setMockInitialValues({});
      await AppDataRepository.loadBundled();
    },
  );

  test('downloadDataset verifies the hash, caches it and notifies', () async {
    final bytes = utf8.encode(
      await rootBundle.loadString('assets/pali_data/dialogues.json'),
    );
    final hash = sha256.convert(bytes).toString();

    // The test binding stubs HTTP with status 400; talk to the loopback
    // server for real instead.
    final savedOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response
        ..statusCode = 200
        ..add(bytes);
      request.response.close();
    });

    final dataset = DatasetInfo(
      id: 'dialogues_download_test',
      titleMm: 'စမ်းသပ်',
      titleEn: 'Dialogue download test',
      icon: Icons.record_voice_over_rounded,
      asset: 'assets/pali_data/dialogues.json',
      url: 'http://127.0.0.1:${server.port}/dialogues.json',
      sha256: hash,
      bytes: bytes.length,
    );

    var notifications = 0;
    void listener() => notifications++;
    appDataRevision.addListener(listener);
    try {
      expect(
        AppDataRepository.statusOf(dataset),
        DatasetStatus.updateAvailable,
      );
      expect(await AppDataRepository.downloadDataset(dataset), isTrue);
      expect(notifications, 1);
      expect(AppDataRepository.statusOf(dataset), DatasetStatus.upToDate);

      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString('pali_dataset_sha256_dialogues_download_test'),
        hash,
      );
      expect(
        preferences.getString('pali_dataset_json_dialogues_download_test'),
        isNotNull,
      );

      // A second call is a no-op because the stored hash already matches.
      expect(await AppDataRepository.downloadDataset(dataset), isFalse);
      expect(notifications, 1);
    } finally {
      appDataRevision.removeListener(listener);
      await server.close(force: true);
      HttpOverrides.global = savedOverrides;
    }
  });

  test('downloadDataset rejects a file whose hash does not match', () async {
    final bytes = utf8.encode(
      await rootBundle.loadString('assets/pali_data/dialogues.json'),
    );
    final savedOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response
        ..statusCode = 200
        ..add(bytes);
      request.response.close();
    });

    final dataset = DatasetInfo(
      id: 'dialogues_bad_hash',
      titleMm: 'စမ်းသပ်',
      titleEn: 'Bad hash test',
      icon: Icons.record_voice_over_rounded,
      asset: 'assets/pali_data/dialogues.json',
      url: 'http://127.0.0.1:${server.port}/dialogues.json',
      sha256: List<String>.filled(64, '0').join(),
      bytes: bytes.length,
    );

    try {
      await expectLater(
        AppDataRepository.downloadDataset(dataset),
        throwsA(isA<DataUpdateException>()),
      );
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString('pali_dataset_json_dialogues_bad_hash'),
        isNull,
      );
    } finally {
      await server.close(force: true);
      HttpOverrides.global = savedOverrides;
    }
  });

  testWidgets('Settings shows data downloads and lists every data set', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const PaliLearningApp());

    await tester.tap(find.text('မြန်မာ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Data downloads'), findsOneWidget);
    expect(find.text('Auto update'), findsOneWidget);
    expect(find.text('All data is up to date'), findsOneWidget);

    await tester.tap(find.text('Data downloads'));
    await tester.pumpAndSettle();

    expect(find.text('Nouns (Nāma)'), findsOneWidget);
    expect(find.text('Finite Verbs (Ākhyāta)'), findsOneWidget);
    expect(find.textContaining('sha256'), findsWidgets);
    expect(find.text('Up to date'), findsWidgets);

    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Pāḷi Dialogues'), findsOneWidget);
  });

  testWidgets('Auto update switch persists the user preference', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const PaliLearningApp());

    await tester.tap(find.text('မြန်မာ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Auto update'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('pali_auto_update_enabled'), isTrue);
  });
}
