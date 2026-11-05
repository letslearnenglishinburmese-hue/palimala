# PaliMala Dynamic App Config

## အလုပ်လုပ်ပုံ

- Lesson file အသစ်များ၊ download URL နှင့် SHA-256 တို့ကို မူလ `assets/pali_data_manifest.json` က ဆက်လက်ထိန်းချုပ်သည်။
- App အပြင်အဆင်၊ category အမည်၊ icon၊ မြင်ရ/မမြင်ရ၊ အစီအစဉ်နှင့် Home အစိတ်အပိုင်းများကို `assets/app_config.json` က ထိန်းချုပ်သည်။ Lesson URL/hash ကို config ထဲ ထပ်မထည့်ပါ။
- App က bundled config ကို အရင်ဖတ်သည်။ နောက်ဆုံးမှန်ကန်ခဲ့သော config ကို device ထဲတွင် cache လုပ်ထားပြီး အင်တာနက်မရှိလျှင် အသုံးပြုသည်။ GitHub မှ config ရယူမှုကို ၅ စက္ကန့်အတွင်း မပြီးပါက သို့မဟုတ် schema မှားနေပါက နောက်ဆုံးမှန်ကန်သော config ကို ဆက်သုံးသည်။
- Firebase ချိတ်ဆက်မှုကို app ဖွင့်ပြီးနောက် နောက်ကွယ်တွင် စတင်သည်။ Firebase သို့မဟုတ် GitHub မရသည့်အခါ local lessons နှင့် cached data ဖြင့် app ကို ဖွင့်နိုင်သည်။

## Remote URL စစ်ဆေးချက်

App သုံးမည့် URL သည် `https://raw.githubusercontent.com/letslearnenglishinburmese-hue/palimala/main/assets/app_config.json` ဖြစ်သည်။ 2026-11-03 တွင် config နှင့် manifest URL နှစ်ခုစလုံး HTTP `200` ပြန်ကြောင်း live စစ်ဆေးထားသည်။

## Config ပြင်ဆင်ခြင်း

`assets/app_config.json` ကို UTF-8 JSON အဖြစ်သာ ပြင်ပါ။ Root field များမှာ `schemaVersion`, `categories`, `theme`, `home` ဖြစ်ပြီး version ကို `1` ထားပါ။ မသိသော field၊ duplicate category ID/order၊ မှားသော color၊ သတ်မှတ်မထားသော icon သို့မဟုတ် မသိသော Home option ပါလျှင် app က config တစ်ခုလုံးကို လက်မခံပါ။

Category တစ်ခုစီတွင် အောက်ပါ field အားလုံး လိုအပ်သည်။

```json
{
  "id": "nouns",
  "titleMm": "နာမ်ပုဒ်များ",
  "titleEn": "Nouns (Nāma)",
  "icon": "menu_book_rounded",
  "visible": true,
  "order": 10
}
```

`id` သည် manifest ထဲက dataset ID နှင့် တူရမည်။ `order` သည် မတူညီသော 0 မှ 10000 အတွင်း integer ဖြစ်ရမည်။ လက်ရှိ icon ခွင့်ပြုစာရင်းမှာ `menu_book_rounded`, `directions_run_rounded`, `auto_awesome_rounded`, `speed_rounded`, `auto_awesome_mosaic_rounded`, `record_voice_over_rounded`, `category_rounded`, `school_rounded` ဖြစ်သည်။ Icon အသစ်တစ်ခု ထည့်လိုလျှင် app code ထဲရှိ allow-list ကိုလည်း update လုပ်ပြီး app version အသစ် ထုတ်ရမည်။

Theme တစ်ခုစီတွင် `primary`, `secondary`, `surface`, `background` အားလုံးကို `#RRGGBB` ပုံစံဖြင့် သတ်မှတ်ပါ။ Home တွင် လက်ရှိထောက်ပံ့သော option များမှာ `showDailyWord`, `showStatistics`, `showExploreHeading` (true/false) နှင့် `columns` (2 သို့မဟုတ် 3) ဖြစ်သည်။ App code မထောက်ပံ့သေးသော UI control အသစ်ကို JSON တစ်ခုတည်းဖြင့် ထည့်မရပါ။

## Lesson အသစ်ထုတ်ဝေခြင်း

1. `assets/lessons/<id>/` အောက်တွင် lesson source နှင့် subcategory file များထည့်ပါ။ Category ID တွင် အင်္ဂလိပ်စာလုံးအသေး၊ ဂဏန်း၊ `_` သို့မဟုတ် `-` ကိုသာ သုံးပါ။
2. Project ၏ manifest generator ကို အသုံးပြုပြီး `assets/pali_data/<id>.json` နှင့် `assets/pali_data_manifest.json` ကို ထုတ်လုပ်ပါ။ Generator သည် dataset URL နှင့် SHA-256 ကို manifest ထဲတွင်သာ ထည့်ရမည်။
3. `assets/app_config.json` ထဲတွင် ထို ID အတွက် bilingual title, ခွင့်ပြုထားသော icon, `visible` နှင့် မတူသော `order` ကို ထည့်ပါ။
4. Config သာပြောင်းလျှင် `assets/app_config.json` ကိုသာ GitHub `main` တွင် ထုတ်ဝေပါ။ Lesson အသစ်တင်မှသာ အဲဒီ dataset file၊ `assets/pali_data_manifest.json` နှင့် category ကိုဖော်ပြထားသော `assets/app_config.json` ကို ထည့်ပါ။ မသက်ဆိုင်သော dataset များကို ပြန်မတင်ပါနှင့်။
5. စစ်ဆေးပြီးမှ repository ၏ `main` branch တွင် ဖိုင်များကို ထုတ်ဝေပါ။ App က public GitHub raw HTTPS လိပ်စာကိုသာ ဖတ်ပြီး private token မလိုပါ။
6. Config ပြောင်းလဲမှုကို App က နောက်တစ်ကြိမ် စတင်ချိန်တွင် ရယူမည်။ Lesson အသစ်ထည့်ထားလျှင် Settings မှ `Check for updates` ကို ရွေးပြီး ထို dataset ကိုသာ download လုပ်ပါ။

ဒီအလုပ်အတွက် local feature branch နှင့် backup branch ကို ဖန်တီးထားသည်။ GitHub သို့ push သို့မဟုတ် production data ကို ပြောင်းလဲမထားပါ။ Push ခွင့်ရပြီးနောက် feature branch ကို review လုပ်၍ `main` သို့ merge/publish လုပ်ရန် လိုသည်။

## ထုတ်ဝေရန် ဖိုင်စာရင်း

| အလုပ် | လိုအပ်သောဖိုင်များ |
| --- | --- |
| Dynamic config ကို ရရှိပြီးသား App ထဲ ထုတ်ဝေခြင်း | `assets/app_config.json` တစ်ဖိုင်တည်း |
| Remote config ကို ပထမဆုံး အသုံးပြုမည့် App version | App source ပြင်ဆင်ချက်များ၊ `pubspec.yaml`, `assets/app_config.json`, Android/iOS project configuration နှင့် release binary |
| Lesson dataset တစ်ခု အသစ်တင်ခြင်း | Lesson source, `assets/pali_data/<id>.json`, `assets/pali_data_manifest.json`; legacy app များကို ဆက်ထောက်ပံ့ရန် `assets/pali_data.json` နှင့် `assets/pali_data_version.json` |
| Category title/order/icon ကို remote ဖြင့်ပြောင်းခြင်း | `assets/app_config.json` |

Furniture lesson၊ nouns dataset/manifest နှင့် legacy aggregate/version ကို GitHub `main` သို့ ထုတ်ဝေထားသည်။ Remote အဟောင်းတွင် Furniture မပါသည့် asset များဖြင့် live test လုပ်ရာ manifest ရယူခြင်း၊ SHA-256 စစ်ခြင်း၊ dataset download/cache လုပ်ခြင်းနှင့် offline ပြန်ဖွင့်ခြင်း အောင်မြင်သည်။ Dynamic app code နှင့် UI config ကိုအသုံးပြုမည့် app binary ကို သီးခြား release မလုပ်မချင်း လက်ရှိထည့်သွင်းပြီးသား app များတွင် အဲဒီ code အသစ် မပါနိုင်ပါ။

## စစ်ဆေးမှု

Config test များသည် မှန်သော config, invalid icon/color, duplicate ID, unknown field, category order/visibility/title/icon, light/dark theme, Home layout, offline cache, invalid-cache fallback နှင့် invalid remote config ကို cache မအစားထိုးကြောင်း စစ်သည်။ Dataset download စနစ်က SHA-256 မကိုက်ပါက download ကို မသိမ်းပါ။ iOS တွင် HTTP cleartext exception မထည့်ထားဘဲ HTTPS သုံးပြီး Android manifest တွင် Internet permission ထည့်ထားသည်။

2026-11-03 စစ်ဆေးမှုတွင် `flutter analyze` အောင်မြင်ပြီး full `flutter test` တွင် ၅၈ ခု အောင်မြင်၊ live-only test ၂ ခု ပုံမှန် run မှာ skip ဖြစ်သည်။ Live integration run နှင့် Furniture မပါသည့် အရင် asset bundle ဖြင့် run သည့် remote test နှစ်ခုစလုံး အောင်မြင်သည်။ SHA verification mismatch, invalid manifest/config rejection, offline/cache fallback, category order/visibility/title/icon, allowed theme colors, Home options စမ်းသပ်မှုများ ပါဝင်သည်။ Android debug APK build အောင်မြင်သည်။ Release AAB build သည် production signing မရှိသဖြင့် ရည်ရွယ်ချက်ရှိရှိ ရပ်တန့်သည်။ iOS release compile အောင်မြင်သော်လည်း `--no-codesign` ဖြစ်သည်။

## Android APK ဖြန့်ဝေခြင်း (Google Drive / Telegram)

လက်ရှိ `android/app/build.gradle.kts` သည် release signing အတွက် `android/key.properties` ရှိ production keystore ကိုသာ လက်ခံသည်။ ဖိုင်မရှိပါက release build ကို fail-closed လုပ်သည်။ ဒီစက်တွင် keystore မရှိသေးသောကြောင့် APK/AAB production artifact မထုတ်ထားပါ။ Keystore ကို source control ထဲ မထည့်ပါနှင့်။ Root `.gitignore` တွင် `key.properties`, `*.keystore`, `*.jks` ကို လျစ်လျူရှုထားသည်။ Keystore/password ကို လုံခြုံသော password manager သို့မဟုတ် encrypted backup ထဲတွင် ထိန်းပါ။

Production signing ကို developer တစ်ဦးက လုံခြုံသောစက်ပေါ်တွင် ပြင်ဆင်ပြီးမှ:

1. Release APK ကို `flutter build apk --release` ဖြင့် တည်ဆောက်ပါ။
2. Android SDK ၏ `apksigner verify --print-certs` ဖြင့် signature ကိုစစ်ပြီး ထွက်လာသော certificate သည် production key ဖြစ်ကြောင်း အတည်ပြုပါ။ APK ကို သန့်ရှင်းသော Android ဖုန်းတွင် install လုပ်ပြီး update လမ်းကြောင်းပါ စမ်းပါ။
3. APK ၏ SHA-256 ကို ရယူပါ (macOS တွင် `shasum -a 256 <apk-file>` ကိုသုံးနိုင်သည်)။ Version number, release notes နှင့် အက်ပ်ကို တရားဝင် link မှသာ ရယူရန် ရှင်းပြချက်ကို ရေးပါ။ `pubspec.yaml` ထဲရှိ version/build number ကို မတင်မီ တိုးမြှင့်ပါ။
4. Google Drive တွင် သတ်မှတ်ထားသော release folder သို့ APK တင်ပါ။ ဖြန့်ချိမည့်သူများအတွက်သာ ကြည့်ရှုခွင့်ရှိသော link ကို မျှဝေပါ။ Telegram တွင်လည်း APK ကို ဖိုင်အဖြစ်တွဲပြီး အဲဒီ SHA-256, version နှင့် release notes ကို ထည့်ပါ။
5. APK နှင့်အတူ hash, version, signing certificate fingerprint ကို ထိန်းသိမ်းပါ။ APK များကို ပြောင်းလဲပြီးပြန်တင်ခြင်းမလုပ်ဘဲ version အသစ်တိုင်းတွင် ထပ်စစ်ပါ။

ဒီအဆင့်မှာ APK ကို Drive/Telegram သို့ မတင်ရသေးပါ။ App install ခွင့်ပြုချက်များကို Android က ပြသမည်ဖြစ်သောကြောင့် အသုံးပြုသူများကို တရားဝင် release source နှင့် ထုတ်ဝေသူအကြောင်း ဖော်ပြပါ။

## iOS ဖြန့်ချိခြင်း

iOS `main` တွင် Bundle ID သည် `com.example.palimala` ဖြစ်ပြီး production အတွက် placeholder ဖြစ်သည်။ Owner က ID ကို အတည်ပြုပြီးမှ Apple Developer Team၊ Distribution certificate နှင့် provisioning profile ကို သတ်မှတ်ပါ။ Release မတိုင်မီ Xcode မှ signed archive တည်ဆောက်၍ App Store Connect/TestFlight ဖြင့် စမ်းပါ။ ယခု စစ်ဆေးမှုသည် `--no-codesign` compile သာဖြစ်ပြီး ဖြန့်ချိနိုင်သော build မဟုတ်ပါ။
