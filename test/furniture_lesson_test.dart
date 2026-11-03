import 'package:flutter_test/flutter_test.dart';
import 'package:palimala/app_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Furniture lesson preserves its 20 provided quadruple-line entries', () async {
    final categories = await AppDataRepository.loadBundled();
    final nouns = categories.firstWhere((category) => category.id == 'nouns');
    final lesson = nouns.subCategories.firstWhere(
      (category) => category.titleMm == 'ဂေဟဘဏ္ဍာနိ',
    );
    final vocab = lesson.vocabList!;

    expect(lesson.titleEn, 'Furniture');
    expect(vocab, hasLength(20));
    expect(
      vocab
          .map(
            (item) => [
              item.paliMm,
              item.paliRoman,
              item.translateMm,
              item.translateEn,
            ],
          )
          .toList(),
      equals([
        ['မဉ္စော', 'Mañco', 'ခုတင်', 'Couch, Bedstead'],
        ['ပီဌံ', 'Pīṭhaṃ', 'ကုလားထိုင်', 'Chair'],
        ['သေယျာ', 'Seyyā', 'အိပ်ရာ', 'Bed'],
        ['ဘိသိ', 'Bhisi', 'မွေ့ယာ', 'Mattress'],
        ['ဗိမ္ဗောဟနံ', 'Bimbohanaṃ', 'ခေါင်းအုံး', 'Pillow'],
        ['ကောဇဝေါ', 'Kojavo', 'ကော်ဇော', 'Carpet'],
        ['ကိလဉ္ဇော', 'Kilañjo', 'ဖျာ၊ သင်ဖြူး', 'Mat'],
        ['အတ္ထရဏံ', 'Attharaṇaṃ', 'အခင်း', 'Bed sheet, Covering'],
        ['သာဏိ', 'Sāṇi', 'ကန့်လန့်ကာ', 'Curtain'],
        ['မကသဇာလံ', 'Makasajālaṃ', 'ခြင်ထောင်', 'Mosquito-net'],
        ['ဘောဇနဖလကော', 'Bhojanaphalako', 'စားပွဲခုံ', 'Table'],
        ['စာဋိ', 'Cāṭi', 'အိုး', 'Pot'],
        ['ထာလီ', 'Thālī', 'ထမင်းအိုး', 'Rice pot'],
        ['ဘာဇနံ', 'Bhājanaṃ', 'ခွက်၊ အိုးခွက်', 'Vessel, Container'],
        ['ထာလကော / ထာလံ', 'Thālako / Thālaṃ', 'ခွက်၊ ပန်းကန်', 'Cup, Dish'],
        ['ဃဋော', 'Ghaṭo', 'ရေအိုး', 'Water pot'],
        ['ပစ္ဆိ', 'Pacchi', 'တောင်း', 'Basket'],
        ['ကဋစ္ဆု', 'Kaṭacchu', 'ယောက်မ', 'Spoon, Ladle'],
        ['မဉ္ဇူသာ', 'Mañjūsā', 'သေတ္တာ', 'Box, Chest'],
        ['အာဒါသော', 'Ādāso', 'မှန်', 'Mirror'],
      ]),
    );
    expect(
      vocab
          .map(
            (item) => [
              item.example!.paliMm,
              item.example!.paliRoman,
              item.example!.translateMm,
              item.example!.translateEn,
            ],
          )
          .toList(),
      equals([
        [
          'သော မဉ္စေ နိပဇ္ဇတိ။',
          'So mañce nipajjati.',
          'သူ ခုတင်ပေါ်မှာ လဲလျောင်းနေတယ်။',
          'He lies down on the bedstead.',
        ],
        [
          'သီဿော ပီဌေ နိသီဒတိ။',
          'Sisso pīṭhe nisīdati.',
          'ကျောင်းသားက ကုလားထိုင်ပေါ်မှာ ထိုင်နေတယ်။',
          'The student sits on the chair.',
        ],
        [
          'သာ သုန္ဒရံ သေယျံ သဇ္ဇေတိ။',
          'Sā sundaraṃ seyyaṃ sajjeti.',
          'သူငယ်မလေးက လှပတဲ့ အိပ်ရာကို ပြင်ဆင်နေတယ်။',
          'She prepares a beautiful bed.',
        ],
        [
          'မဉ္စဿ ဥပရိ ဘိသိ အတ္ထိ။',
          'Mañcassa upari bhisi atthi.',
          'ခုတင်ပေါ်မှာ မွေ့ယာ ရှိတယ်။',
          'There is a mattress on the bed.',
        ],
        [
          'သော ဗိမ္ဗောဟနေ သီသံ ဌပေတိ။',
          'So bimbohane sīsaṃ ṭhapeti.',
          'သူ ခေါင်းအုံးပေါ် ခေါင်းတင်ထားတယ်။',
          'He rests his head on the pillow.',
        ],
        [
          'ဘူမိယံ မဟာ ကောဇဝေါ အတ္ထတော ဟောတိ။',
          'Bhūmiyaṃ mahā kojavo atthato hoti.',
          'ကြမ်းပြင်ပေါ်မှာ ကော်ဇောကြီး ခင်းထားတယ်။',
          'A large carpet is spread on the floor.',
        ],
        [
          'သော ကိလဉ္ဇေ နိသီဒတိ။',
          'So kilañje nisīdati.',
          'သူ ဖျာပေါ်မှာ ထိုင်နေတယ်။',
          'He sits on the mat.',
        ],
        [
          'သာ သေယျာယံ အတ္ထရဏံ အတ္ထရတိ။',
          'Sā seyyāyaṃ attharaṇaṃ attharati.',
          'သူငယ်မလေးက အိပ်ရာပေါ်မှာ အခင်း ခင်းနေတယ်။',
          'She spreads a sheet on the bed.',
        ],
        [
          'သော ဒွါရေ သာဏိံ လဂ္ဂေတိ။',
          'So dvāre sāṇiṃ laggeti.',
          'သူ တံခါးမှာ ကန့်လန့်ကာ ချိတ်ဆွဲထားတယ်။',
          'He hangs a curtain at the door.',
        ],
        [
          'ရတ္တိယံ သော မကသဇာလံ ဗန္ဓတိ။',
          'Rattiyaṃ so makasajālaṃ bandhati.',
          'ညဘက်မှာ သူ ခြင်ထောင် ထောင်ထားတယ်။',
          'He ties up a mosquito-net at night.',
        ],
        [
          'ဘောဇနဖလကေ အာဟာရော အတ္ထိ။',
          'Bhojanaphalake āhāro atthi.',
          'စားပွဲခုံပေါ်မှာ အစားအသောက် ရှိတယ်။',
          'There is food on the dining table.',
        ],
        [
          'သာ စာဋိယာ ဥဒကံ အာနယတိ။',
          'Sā cāṭiyā udakaṃ ānayati.',
          'သူငယ်မလေးက အိုးနဲ့ ရေ ယူလာတယ်။',
          'She brings water in a pot.',
        ],
        [
          'မာတာ ထာလိယံ ဩဒနံ ပစတိ။',
          'Mātā thāliyaṃ odanaṃ pacati.',
          'မိခင်က ထမင်းအိုးထဲမှာ ထမင်းချက်နေတယ်။',
          'The mother cooks rice in the pot.',
        ],
        [
          'သော ဘာဇနေ ခီရံ ဌပေတိ။',
          'So bhājane khīraṃ ṭhapeti.',
          'သူ ခွက်ထဲမှာ နို့ ထည့်ထားတယ်။',
          'He keeps milk in the container.',
        ],
        [
          'သော ထာလကေန သူပံ ပိဝတိ။',
          'So thālakena sūpaṃ pivati.',
          'သူ ပန်းကန်လုံးနဲ့ ဟင်းရည် သောက်နေတယ်။',
          'He drinks soup from the bowl/dish.',
        ],
        [
          'ဒါရိကာ ဃဋေန ဥဒကံ အာဟာရတိ။',
          'Dārikā ghaṭena udakaṃ āharati.',
          'မိန်းကလေးက ရေအိုးနဲ့ ရေ ခတ်လာတယ်။',
          'The girl fetches water with a water pot.',
        ],
        [
          'သာ ပစ္ဆိယံ ဖလာနိ ဌပေတိ။',
          'Sā pacchiyaṃ phalāni ṭhapeti.',
          'သူငယ်မလေးက တောင်းထဲမှာ အသီးအနှံတွေ ထည့်ထားတယ်။',
          'She keeps fruits in the basket.',
        ],
        [
          'မာတာ ကဋစ္ဆုနာ သူပံ အာလောဠေတိ။',
          'Mātā kaṭacchunā sūpaṃ āloḷeti.',
          'မိခင်က ယောက်မနဲ့ ဟင်းရည်ကို မွှေနေတယ်။',
          'The mother stirs the soup with a ladle.',
        ],
        [
          'သော မဉ္ဇူသာယံ ဝတ္ထာနိ ဌပေတိ။',
          'So mañjūsāyaṃ vatthāni ṭhapeti.',
          'သူ သေတ္တာထဲမှာ အဝတ်အထည်တွေ ထည့်ထားတယ်။',
          'He keeps clothes in the chest/box.',
        ],
        [
          'သာ အာဒါသေ မုခံ ပဿတိ။',
          'Sā ādāse mukhaṃ passati.',
          'သူငယ်မလေးက မှန်ထဲမှာ မျက်နှာ ကြည့်နေတယ်။',
          'She looks at her face in the mirror.',
        ],
      ]),
    );
  });
}
