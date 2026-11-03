# PaliMala Production Release လမ်းညွှန်

ဒီစာတမ်းက release ပြင်ဆင်သူအတွက် အဆင့်လိုက်လမ်းညွှန်ဖြစ်သည်။ Production signing password၊ private key၊ certificate သို့မဟုတ် Apple account အချက်အလက်ကို chat ထဲပို့ရန် မလိုပါ။ ကိုယ်တိုင်ထိန်းချုပ်သည့် developer စက်နှင့် password manager ထဲတွင်သာ စီမံပါ။

လက်ရှိ GitHub `main` တွင် Android Application ID နှင့် iOS Bundle ID သည် owner အတည်ပြုထားသော `com.palimala.app` ဖြစ်သည်။ Android/iOS Firebase registrations သည် ရှိပြီးသား `palimala-18c4c` project ထဲတွင် ရှိကြောင်း owner အတည်ပြုပြီး၊ local config များနှင့် ကိုက်ညီကြောင်း စစ်ထားသည်။ Apple Team၊ Store account နှင့် signing ကို သီးခြား owner က စီစဉ်ရမည်။ ယခင် `com.example.palimala` install များကို `.app` ID ဖြင့် update မလုပ်နိုင်ပါ။

## လက်ရှိတွေ့ရှိချက်

- Android `applicationId` နှင့် namespace သည် `com.palimala.app` ဖြစ်သည်။ `google-services.json` နှင့် FlutterFire mapping တွင် ဒီ package အတွက် `palimala-18c4c` registration ပါရှိသည်။ Google Play Console ပိုင်ဆိုင်မှုကို local build ဖြင့် အတည်မပြုနိုင်ပါ။
- Android release signing သည် `android/key.properties` ရှိ production keystore ကိုသာ သုံးရန် ပြင်ဆင်ထားသည်။ ဖိုင်/keystore မရှိပါက release build ကို ရပ်တန့်စေပြီး debug key ဖြင့် ဆက်မလုပ်ပါ။ ယခု စက်တွင် signing ဖိုင်မရှိပါ။
- iOS Bundle ID သည် `com.palimala.app` ဖြစ်သည်။ Firebase plist/FlutterFire mapping တွင် ဒီ ID အတွက် `palimala-18c4c` registration ပါရှိသည်။ Xcode project တွင် Apple Team မသတ်မှတ်ထားပါ။ `flutter build ios --release --no-codesign` ဖြင့်သာ အောင်မြင်ပြီး ထွက်လာသော app ကို ဖြန့်ချိရန် မသုံးနိုင်ပါ။
- `pubspec.yaml` version သည် `1.0.0+1` ဖြစ်သည်။ အရှေ့ပိုင်း `1.0.0` သည် user မြင်ရသော version၊ `+1` သည် build number ဖြစ်သည်။ ထုတ်ဝေမှုအသစ်တိုင်း build number ကို တိုးပါ။
- `main/assets/app_config.json` နှင့် lesson manifest raw URL များကို 2026-11-03 တွင် HTTP 200 ဖြင့် စစ်ဆေးပြီး remote config နှင့် lesson update flow ကို automated test ဖြင့် အတည်ပြုခဲ့သည်။

## ၁။ Android ID နှင့် Production Signing

### အရင်ဆုံး ဆုံးဖြတ်ရန်

1. Owner အတည်ပြုထားသော `com.palimala.app` ကို Google Play Console app record ထဲတွင် အသုံးပြုခွင့်ရှိကြောင်း စစ်ပါ။ ယခင် `.example` ID ဖြင့် install ရှိပါက ၎င်းတို့သည် သီးခြား app အဖြစ် ရှိနေမည်ဖြစ်ပြီး update အဖြစ် အစားထိုးမရပါ။
2. ဒီ ID အတွက် Firebase Android registration/config ရှိပြီးသားဖြစ်သည်။ `google-services.json` နှင့် Firebase Production data/accounts ကို မပြင်ပါနှင့်။
3. လက်ရှိ `applicationId` နှင့် namespace ကို အသုံးပြုမည့် store listing/Firebase Android app နှင့် ကိုက်ညီကြောင်း စစ်ပါ။ Application ID ပြောင်းခြင်းသည် အသုံးပြုသူများ၏ ယခင် install ကို update မလုပ်နိုင်စေဘဲ app အသစ်လို ဖြစ်စေနိုင်သည်။

### ကိုယ်တိုင်သော့တည်ဆောက်ခြင်းနှင့် လုံခြုံစွာထားခြင်း

1. Release owner က ကိုယ်ပိုင် developer စက်တွင် Android Studio/Android SDK ၏ `keytool` ဖြင့် upload/release keystore တစ်ခု တည်ဆောက်ပါ။ Keystore password နှင့် key password တို့ကို ခိုင်မာပြီး မတူညီသော password များထား၍ password manager ထဲသိမ်းပါ။ Chat, email, source code, shared drive ထဲ plain text ဖြင့် မထားပါနှင့်။
2. Keystore ကို ကုဒ်ဝှက်ထားသော offline နေရာတွင် လုံခြုံစွာ backup လုပ်ပါ။ Keystore ပျောက်ခြင်း/ပျက်ခြင်းသည် လက်ရှိ install များကို update ထုတ်နိုင်ခြင်းကို ထိခိုက်နိုင်သည်။
3. Keystore နှင့် password ကို repository ထဲ မထည့်ပါနှင့်။ ဒီ project ၏ `.gitignore` တွင် `android/key.properties`, `*.jks`, `*.keystore`, `*.p12`, `*.pfx` နှင့် `*.mobileprovision` ကို လျစ်လျူရှုရန် ထည့်ထားသည်။ Ignore ဖြစ်မဖြစ်ကို Git status တွင် စစ်ပါ။
4. App owner က မိမိစက်တွင် `android/key.properties` ဖိုင်ကို ဖန်တီးပြီး `storeFile`, `storePassword`, `keyAlias`, `keyPassword` ကို ထည့်ပါ။ ဒီဖိုင်ကို မမျှဝေ၊ GitHub သို့ မတင်ပါနှင့်။ Gradle က အဲဒီ local ဖိုင်ကို ဖတ်ပြီး လိုအပ်သော setting မရှိပါက release build ကို fail-closed လုပ်ထားသည်။
5. CI အသုံးပြုပါက secrets ကို CI secret store မှသာ ပေးပါ။ Secret ကို build log ထဲ echo မလုပ်ပါနှင့်။ လက်ရှိအဆင့်တွင် CI secret များမသတ်မှတ်ရသေးပါ။

ဒီအဆင့်တွင် keystore/password မဖန်တီးထား၊ မသိမ်းထားပါ။ Production signing ကို စတင်ရန် owner က အဆိုပြုထားသော Application ID ကို အတည်ပြုပြီး keystore ထိန်းသိမ်းမည့် release owner ကို ရွေးချယ်ကာ local secure setup ကို ကိုယ်တိုင်ပြုလုပ်ရပါမည်။

## ၂။ iOS Bundle ID နှင့် Apple Signing

1. `com.palimala.app` ကို Apple Developer Team ထိန်းချုပ်နိုင်ပြီး App Store Connect တွင် မှတ်ပုံတင်နိုင်ကြောင်း owner က အတည်ပြုပါ။ iOS Firebase registration ရှိပြီးသားဖြစ်သော်လည်း Apple App ID/Store record ကို သီးခြားစစ်ရမည်။
2. Xcode ၏ Runner target > Signing & Capabilities တွင် သင့် Team ကို ရွေးပါ။ App Store ဖြန့်ချိမည်ဆိုလျှင် Automatic Signing သို့မဟုတ် စီမံထားသော Distribution certificate နှင့် App Store provisioning ကိုသုံးပါ။ Ad Hoc သည် သတ်မှတ်ထားသော device များအတွက်သာဖြစ်သည်။
3. Associated Domains, Push, Keychain စသည့် capability များ အသုံးပြုပါက သက်ဆိုင်ရာ entitlement နှင့် provisioning မှန်ကြောင်း စစ်ပါ။ မသုံးသော capability များ မထည့်ပါနှင့်။
4. Apple Distribution certificate ကို Xcode/Apple Developer ၏ လုံခြုံသောလုပ်ငန်းစဉ်မှတစ်ဆင့် release owner က မိမိစက်တွင် သတ်မှတ်ပါ။ `.p12`, private key သို့မဟုတ် provisioning profile ကို repository/chat ထဲ မထည့်ပါနှင့်။ `.gitignore` သည် `.mobileprovision` ဖိုင်များကို ကာကွယ်ထားသည်။ Certificate/profile နှင့် account ကို project owner ကသာ စီမံပါ။
5. Release archive ကို Xcode Organizer သို့မဟုတ် သင့်အဖွဲ့၏ signing CI ဖြင့် တည်ဆောက်ပြီး Validate App လုပ်ပါ။ Internal စမ်းသပ်ရန် TestFlight internal group၊ public release အတွက် App Store review ကို သုံးပါ။ `--no-codesign` build သည် device ဖြန့်ချိရန် လုံလောက်ခြင်းမရှိပါ။

ဒီ project တွင် Apple Team, production Bundle ID, Distribution certificate နှင့် provisioning profile မသတ်မှတ်ရသေးပါ။ ကိုယ်ပိုင် Apple Developer account လိုအပ်ချက်များကို app owner က ဖြည့်ဆည်းရပါမည်။

## ၃။ Version၊ APK စစ်ဆေးခြင်းနှင့် Upgrade Test

1. `pubspec.yaml` ရှိ `version: A.B.C+N` ကို ပြင်ဆင်ပါ။ ဥပမာ user မြင်ရသော version ကို `1.0.1` သတ်မှတ်လျှင် build number ကို ယခင်ကထက် ကြီးသော `+2` သို့မဟုတ် ထိုထက်ကြီးသည့် တန်ဖိုးထားပါ။ Android `versionCode` နှင့် iOS `CFBundleVersion` တို့သည် build number ကို အသုံးပြုသည်။ Android update လုပ်နိုင်ရန် `applicationId` နှင့် production signer တူညီရမည်။
2. Production signing သတ်မှတ်ပြီးနောက် `flutter build apk --release` ဖြင့် universal APK ထုတ်ပါ။ APK ကို `build/app/outputs/flutter-apk/app-release.apk` မှ ရယူပါ။
3. Android SDK `apksigner` ဖြင့် `verify --verbose --print-certs` စစ်ပါ။ Command က verify အောင်မြင်ကြောင်း၊ signer certificate SHA-256 fingerprint ကို ထုတ်ပြကြောင်း အတည်ပြုပါ။ Fingerprint ကို release record တွင်သာ ထည့်ပါ။ Signing password များကို မထည့်ပါနှင့်။
4. APK file အတွက် macOS `shasum -a 256 <APK-path>` ဖြင့် SHA-256 ရယူပါ။ Google Drive/Telegram ပို့မည့် APK တစ်ခုတည်း၏ hash နှင့် ပို့ပြီးရရှိသူ ထံမှပြန်ရသော hash တူရမည်။ APK ကို ပြန် compress/rename လုပ်ခြင်းက အကြောင်းမဲ့ မပြောင်းလဲစေသော်လည်း APK bytes ကို edit/rebuild လုပ်လျှင် hash ပြောင်းမည်။
5. Upgrade test ကို Android သန့်ရှင်းသည့် test phone/emulator ပေါ်တွင်လုပ်ပါ။ Release signer ဖြင့် sign ထားသော ယခင် APK တင်၊ sample saved words/settings ကို စမ်းပြီး production candidate ကို အပေါ်က install လုပ်ပါ။ “update” အဖြစ် တက်ကြောင်း၊ app data နှင့် saved items မပျောက်ကြောင်း၊ app launch/search/dictionary/TTS/lesson download အလုပ်လုပ်ကြောင်း စစ်ပါ။ Version code လျော့မသွားကြောင်းလည်း စစ်ပါ။ Debug key ဖြင့် တင်ထားသော လက်ရှိ APK ကို production signer ဖြင့် တိုက်ရိုက် upgrade မလုပ်နိုင်နိုင်ပါ။ Production upgrade test အတွက် release signer အဟောင်းရှိပြီးသား APK ကို အသုံးပြုပါ။
6. Release record တစ်ခုစီတွင် version, build number, APK SHA-256, signing certificate fingerprint, build date, release notes, approval, Drive link/Telegram post reference နှင့် upgrade test အခြေအနေကို မှတ်တမ်းတင်ပါ။

### ဖြန့်ချိမည့် build အတွက် release notes မူကြမ်း

Version/build number ကို owner အတည်ပြုပြီး app update ပါဝင်ကြောင်း စစ်ပြီးမှ အသုံးပြုရန်။

- ယခုအခါ သင်ခန်းစာအသစ်များကို အွန်လိုင်းမှ ရယူနိုင်သည်။
- Lesson data ကို စစ်ဆေးထားသော SHA-256 ဖြင့် အတည်ပြုသည်။
- နောက်ဆုံးရယူထားသော သင်ခန်းစာများကို အင်တာနက်မရှိချိန်တွင်လည်း ဖတ်ရှုနိုင်သည်။
- ခွင့်ပြုထားသော app configuration ဖြင့် category၊ theme နှင့် ပင်မစာမျက်နှာရွေးချယ်စရာများကို ပြောင်းလဲနိုင်သည်။
- New lessons can be downloaded and verified before use.
- Downloaded lessons remain available offline.
- The app supports validated remote category, theme, and home-screen settings.

## ၄။ Google Drive နှင့် Telegram ဖြန့်ချိခြင်း

Upload မပြုမီ release owner က APK signature၊ hash၊ clean install နှင့် upgrade test အားလုံးကို အတည်ပြုပါ။ Owner ခွင့်ပြုချက်မရှိဘဲ Drive/Telegram သို့ မတင်ပါနှင့်။

1. Google Drive ရှိ release folder တစ်ခုတွင် version အလိုက် immutable copy သိမ်းပါ။ ဖြန့်ဝေရန်လိုသောသူများကိုသာ view/download access ပေးပါ။ Public edit access မပေးပါနှင့်။
2. Telegram တွင် APK ကို document အဖြစ်တွဲတင်ပြီး app version/build, SHA-256, signing fingerprint ၏ နောက်ဆုံးအပိုင်း/အပြည့်အစုံအဖွဲ့သတ်မှတ်ချက်နှင့် download ရင်းမြစ်တို့ကို ထည့်ပါ။ အတည်မပြုရသေးသော file ကို forward/re-upload မလုပ်ပါနှင့်။
3. လက်ခံသူများကို မတင်မီ file SHA-256 စစ်ဆေးရန်၊ Android ၏ sideload permission ကို တရားဝင် file source အတွက်သာ ဖွင့်ရန်၊ install ပြီးပါက ခွင့်ပြုချက်ကို ပြန်ပိတ်ရန် ညွှန်ကြားပါ။ Android warning ကို ကျော်ခိုင်းခြင်း မပြုပါနှင့်။
4. Release ပြီးသည့်နောက် hash နှင့် signature fingerprint ကို release record ထဲတွင် ထိန်းသိမ်းပါ။ နောက် version အသစ်ဖြင့် ဖြန့်ချိပါက Drive link ဟောင်းကို အစားထိုးမထားဘဲ history ကို ထိန်းပါ။

## ၅။ GitHub `main` တွင် Config/Lesson ထုတ်ဝေခြင်း

### ထုတ်ဝေမီ ပြင်ဆင်ခြင်း

1. Feature branch ကို review ပြီး အတည်ပြုပါ။ မူလ staged changes ကို သီးခြားစစ်ပါ။ ဒီ project ၏ staged manifest timestamp/generator changes နှင့် `tool/generate_data_manifest.dart.save` ကို Dynamic Config အလုပ်အတွက် အလိုအလျောက် မပို့ပါနှင့်။
2. `assets/app_config.json` ကို JSON parse + app tests ဖြင့် စစ်ပါ။ Category ID သည် dataset ID နှင့်ကိုက်၊ category order မထပ်၊ icon allow-list ထဲကဖြစ်၊ color ပုံစံမှန်ပြီး unsupported key မရှိရပါ။
3. Config တစ်ခုတည်းဆို `assets/app_config.json` ကိုသာ publish လုပ်ပါ။ Dataset အသစ်/ပြင်ဆင်မှုဆို လိုအပ်သည့် `assets/pali_data/<id>.json`, အသစ်ထုတ်ထားသော `assets/pali_data_manifest.json` နှင့် category entry ပါသော `assets/app_config.json` ကိုသာ ထည့်ပါ။ မပြောင်းသော dataset များကို ထပ်မတင်ပါနှင့်။
4. Lesson တစ်ခုချင်းစီအတွက် manifest SHA-256 ကို local file hash နှင့် နှိုင်းပါ။ Production အတွက် အဓိပ္ပာယ်အရ မှန်ကန်ကြောင်း Pali review မပြီးသေးသော data (လက်ရှိ `Rogo` အပါအဝင်) ကို မပြောင်း၊ မထုတ်ဝေပါနှင့်။

### ဖြန့်ချိမှုအစီအစဉ်

- App code/config feature ကို အတည်ပြုထားသော release commit မှ App binary ထုတ်ပြီး လက်ခံစမ်းသပ်ပါ။ ပထမ App release က bundled config ကိုလည်း မှန်ကန်စွာ ပါဝင်စေရမည်။
- GitHub `main` ထုတ်ဝေခွင့် ရပြီးမှ approved commit/PR ကို merge/publish လုပ်ပါ။ Remote Config သည် `assets/app_config.json` တစ်ခုတည်းဖြင့်သီးခြားပြောင်းနိုင်သည်။ Lesson ပြင်ဆင်မှုကို manifest+dataset ပြင်ဆင်မှုတို့နှင့်အတူ တစ်ခုတည်းသော commit တွင် ထုတ်ဝေပါ။
- Publish ပြီး raw HTTPS Config နှင့် Manifest URL များ HTTP 200 ပြန်ကြောင်း၊ JSON/schema မှန်ကြောင်း၊ Config ရရှိပြီး App restart လုပ်သောအခါ apply ဖြစ်ကြောင်း၊ dataset download ပြီး hash match ဖြစ်ကြောင်း read-only/read tests ဖြင့် စစ်ပါ။
- Config update သည် app ကို reinstall မလိုပါ။ App သည် startup အချိန် remote config ကို fetch လုပ်ပြီး offline အခါ last valid cached/bundled config ကို သုံးသည်။ Lesson update ကို App Settings မှ Check for updates/ရွေးချယ်ထားသော dataset download ဖြင့် ရယူပါ။

App Config နှင့် Furniture lesson data raw URL များကို GitHub `main` တွင် တင်ပြီး HTTP 200 ဖြင့် စစ်ဆေးထားသည်။ Dynamic app code ကိုပါဝင်သည့် Android/iOS release binary မထုတ်ရသေးပါ။

## ၆။ Rollback အစီအစဉ်

Rollback အတွက် ယခင်ထုတ်ဝေမှု၏ config၊ manifest၊ dataset bytes၊ commit hash နှင့် APK ကို release archive တွင် သိမ်းထားပါ။ ထုတ်ဝေတိုင်း backup မရှိဘဲ အဟောင်းကို overwrite မလုပ်ပါနှင့်။

### Config ပြဿနာဖြစ်လျှင်

1. App Config ကို parse/schema check ပြန်လုပ်ပါ။ Invalid config ဖြစ်ပါက app က နောက်ဆုံးမှန်ကန်သော cached သို့မဟုတ် bundled config ကို ဆက်သုံးသင့်သည်။
2. GitHub `main` တွင် `assets/app_config.json` ကို နောက်ဆုံးအတည်ပြုထားသော JSON အကြောင်းအရာနှင့် ပြန်ထုတ်ဝေပါ။ ဒီနည်းသည် config ကိုသာ rollback လုပ်ပြီး App binary/data ကို မထိပါ။
3. HTTP 200 နှင့် JSON အတည်ပြုပြီးမှ online test device တွင် App restart လုပ်ပါ။ Offline test တစ်ခုမှာ cache fallback ဆက်အလုပ်လုပ်ကြောင်း စစ်ပါ။

### Lesson data ပြဿနာဖြစ်လျှင်

1. ပြဿနာရှိ dataset ကို ထပ်မဒေါင်းလုဒ်စေရန် သက်ဆိုင်ရာ category ကို App Config တွင် ယာယီ `visible:false` လုပ်နိုင်သည်။ ဤနည်းသည် data ကို မပြင်ဘဲ UI မှ ဖျောက်ထားခြင်းသာ ဖြစ်သည်။
2. Dataset ပြန်လှည့်ရန် ယခင်အတည်ပြုပြီးသော dataset bytes ကို သီးခြား version သတ်မှတ်ထားသည့် HTTPS URL တွင် ပြန်တင်ပြီး manifest entry ကို အဲဒီ URL နှင့် တိကျသည့် SHA-256 သို့ ပြောင်းပါ။ ယခင် hash ကိုသာ ထည့်ပြီး URL မှာ bytes အသစ်ထားပါက SHA စစ်ဆေးမှုက download ကို ငြင်းပယ်မည်။
3. Manifest ရှိ date/version သည် app ထဲတွင်ပါသော manifest ထက် နောက်ကျသောအခါ App က အဟောင်း manifest ကို ရွေးမသုံးရန် ကာကွယ်ထားသည်။ Production rollback အဖြစ် ယခင် dataset ကို ပြန်ထုတ်ရာတွင် ယခင်ထက် နောက်ကျသော manifest date အသစ်တစ်ခု ထုတ်ပြီး အတည်ပြုထားသော dataset hash/URL ကို ညွှန်ပါ။ Dataset URL ကို version သီးခြားရှိပြီး မပြောင်းလဲသည့်ပုံစံထားပါ။
4. ရှိပြီးသား device ထဲတွင် မကောင်းသော dataset cache ရောက်သွားလျှင် ယခင်မှန်ကန်သော hash ကို ထုတ်ပြန်ပြီး အသုံးပြုသူက update ပြန်ဒေါင်းလုဒ်လုပ်ရန် လိုနိုင်သည်။ အမှားရှိသော data ကို အတည်ပြုမထားဘဲ client cache ဖျက်ခြင်း မလုပ်ပါနှင့်။

### App binary ပြဿနာဖြစ်လျှင်

APK ကို server မှ အဝေးထိန်းဖျက်၍ မရပါ။ ဖြေရှင်းပြီးသော build ကို **versionCode/build number အသစ်၊ တူညီသော application ID နှင့် တူညီသော production signer** ဖြင့် ထုတ်ပြီး ယခင် install များအပေါ် upgrade လုပ်ပါ။ iOS တွင် တူညီသော Bundle ID/Team ဖြင့် ပြင်ဆင်ထားသော build ကို TestFlight/App Store ဖြင့် ဆက်ထုတ်ပါ။ ယခု production-signed upgrade baseline မရှိသေးပါ။

## ၇။ Release မစတင်မီ လိုအပ်သော အတည်ပြုချက်များ

Project owner က အောက်ပါအချက်များကို ကိုယ်တိုင်ပေး/ဆုံးဖြတ်ရမည်။ Password, private key, certificate file သို့မဟုတ် account login ကို မပေးပါနှင့်။

- Android အတွက် ပိုင်ဆိုင်/ထိန်းချုပ်သော application ID နှင့် ထို ID ရှိပြီးသား user install များကို update လုပ်ရမရ ဆုံးဖြတ်ချက်။
- Android production release ကို ထိန်းမည့်သူနှင့် keystore ကို လုံခြုံစွာဖန်တီး၊ backup လုပ်မည့် စက်/နေရာ။ Signing secrets များကို owner ကသာ စီမံရန်။
- iOS အတွက် Apple Developer Team ရှိ/မရှိ၊ ရွေးချယ်မည့် unique Bundle ID၊ App Store/TestFlight/Ad Hoc ဖြန့်ချိမည့်ပုံစံ။ Team ID သို့မဟုတ် certificate များကို chat ထဲ မပို့ပါနှင့်။
- Google Drive release folder ကို စီမံမည့်သူ၊ အခွင့်အရေးပေးမည့်လက်ခံသူများ၊ Telegram ဖြန့်ချိမည့် channel/group နှင့် release အတည်ပြုသူ။
- GitHub `main` သို့ publish/merge လုပ်ရန် သီးခြားခွင့်ပြုချက်နှင့် release approval။ Dataset ပြောင်းလဲမည်ဆိုလျှင် သီးခြား Pali content review လည်းလိုသည်။
- Release version/build number နှင့် Android/iOS ထုတ်ဝေမှုကို တပြိုင်တည်းလုပ်မလား ဆုံးဖြတ်ချက်။

Rogo data ကို ဤစာတမ်းအတွက် မပြောင်းထားပါ။ Full test suite တွင် Rogo gender-marker စမ်းသပ်မှု ဆက်လက်မအောင်မြင်နေသည်ကို မှန်ကန်သည့်အတိုင်း ထားရှိသည်။ GitHub push/merge, Production Deployment, Firebase Production ပြောင်းလဲမှုနှင့် Drive/Telegram upload မလုပ်ရသေးပါ။
