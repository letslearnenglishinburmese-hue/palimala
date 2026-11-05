# PaliMala Production Release လမ်းညွှန်

ဒီစာတမ်းက release ပြင်ဆင်သူအတွက် အဆင့်လိုက်လမ်းညွှန်ဖြစ်သည်။ Production signing password၊ private key၊ certificate သို့မဟုတ် Apple account အချက်အလက်ကို chat ထဲပို့ရန် မလိုပါ။ ကိုယ်တိုင်ထိန်းချုပ်သည့် developer စက်နှင့် password manager ထဲတွင်သာ စီမံပါ။

ဤ feature branch ၏ လက်ရှိ Android Application ID နှင့် iOS Bundle ID သည် `com.palimala.app` ဖြစ်သည်။ Production အသုံးမပြုမီ Play Console/App Store Connect နှင့် Firebase registration တို့တွင် ဒီ ID များကို ပိုင်ဆိုင်/ထိန်းချုပ်ထားကြောင်း ထပ်မံစစ်ဆေးပါ။ ID ပြောင်းလဲမှုသည် လက်ရှိ install များကို update မရစေနိုင်သည်။

## လက်ရှိတွေ့ရှိချက်

- Android `applicationId` နှင့် namespace သည် `com.palimala.app` ဖြစ်သည်။ `android/app/google-services.json` သည် အတည်ပြုထားသော Firebase Android registration ကို ရည်ညွှန်းသည်။ Play Console listing ပိုင်ဆိုင်မှုကို local project စစ်ဆေးမှုက အတည်မပြုနိုင်ပါ။
- Android release signing သည် `android/key.properties` မှ local production keystore ကိုသာ ဖတ်သည်။ ဖိုင်/keystore မရှိပါက release build ကို ရပ်တန့်စေပြီး debug key ဖြင့် အစားထိုးမသုံးပါ။ လက်ရှိစက်တွင် properties နှင့် keystore မရှိပါ။
- iOS Bundle ID သည် `com.palimala.app` ဖြစ်သည်။ Xcode project တွင် Apple Team/Distribution signing မသတ်မှတ်ရသေးပါ။ `flutter build ios --release --no-codesign` ဖြင့်သာ build လုပ်နိုင်ပြီး ဖြန့်ချိရန် မသုံးနိုင်ပါ။
- `pubspec.yaml` version သည် `1.0.0+1` ဖြစ်သည်။ အရှေ့ပိုင်း `1.0.0` သည် user မြင်ရသော version၊ `+1` သည် build number ဖြစ်သည်။ ထုတ်ဝေမှုအသစ်တိုင်း build number ကို တိုးပါ။
- `main/assets/app_config.json` နှင့် lesson manifest raw URL များကို 2026-11-03 တွင် HTTP 200 ဖြင့် စစ်ဆေးပြီး remote config နှင့် lesson update flow ကို automated test ဖြင့် အတည်ပြုခဲ့သည်။

## ၁။ Android ID နှင့် Production Signing

### အရင်ဆုံး ဆုံးဖြတ်ရန်

1. အတည်ပြုထားသော ID `com.palimala.app` ကို Play Console app listing နှင့် Firebase Android registration တို့တွင် တိတိကျကျ ကိုက်ညီကြောင်း owner က စစ်ပါ။
2. လက်ရှိ `google-services.json` သည် `com.palimala.app` နှင့် Firebase Project `palimala-18c4c` အတွက် ဖြစ်သည်။ Firebase Production data/accounts ကို မပြောင်းပါနှင့်။
3. Application ID ပြောင်းလဲခြင်းသည် install ရှိပြီးသား App ကို update မလုပ်နိုင်စေဘဲ App အသစ်လို ဖြစ်စေနိုင်သည်။ ID ကို အတည်ပြုပြီးနောက်မှသာ store listing ထုတ်ပါ။

### ကိုယ်တိုင်သော့တည်ဆောက်ခြင်းနှင့် လုံခြုံစွာထားခြင်း

1. Google Play အတွက် ပထမဆုံး App ဖြစ်ပါက Play App Signing ကို အသုံးပြုရန် စီစဉ်ပြီး **upload key** ကို ကိုယ်ပိုင် Mac ပေါ်တွင် ဖန်တီးပါ။ App signing key နှင့် upload key ကို သီးခြားထားပါက Play က အသုံးပြုသူများထံ ဖြန့်မည့် App ကို ၎င်း၏ app signing key ဖြင့် လက်မှတ်ထိုးပြီး၊ သင်က AAB ကို upload key ဖြင့် လက်မှတ်ထိုးမည်။
   Google Play မှ ဖြန့်သော App နှင့် Drive/Telegram မှ sideload လုပ်သော APK တို့ကို အပြန်အလှန် update လုပ်စေလိုပါက signing certificate တူညီရမည်။ Play-managed app signing ကိုရွေးလျှင် Play အပြင်ဘက်ဖြန့်မည့် APK အတွက် signer ကို သီးခြားစီစဉ်ပြီး upgrade လမ်းကြောင်းကို စမ်းသပ်ပါ။
2. Mac ၏ Terminal တွင် အောက်ပါအတိုင်း key folder ကို ဖန်တီးပြီး permission ကို ကန့်သတ်ပါ။ ဒီလမ်းကြောင်းသည် project folder အပြင်ဘက်ဖြစ်သည်။

   ```sh
   mkdir -p "$HOME/Library/Application Support/PaliMala/signing"
   chmod 700 "$HOME/Library/Application Support/PaliMala/signing"
   ```

3. Android Studio/Android SDK ပါလာသော `keytool` ဖြင့် upload keystore အသစ်ကို ဖန်တီးပါ။ Password များကို command ထဲ မရေးပါနှင့်။ `keytool` မေးသည့်အခါ Terminal ၌ ကိုယ်တိုင်ရိုက်ထည့်ပါ။ Terminal တွင် ပြသမည့် အမည်/အဖွဲ့အချက်အလက်များကို ကိုယ်တိုင်ဆုံးဖြတ်ပါ။

   ```sh
   keytool -genkeypair -v \
     -keystore "$HOME/Library/Application Support/PaliMala/signing/palimala-upload.jks" \
     -storetype JKS \
     -alias palimala-upload \
     -keyalg RSA -keysize 2048 -validity 10000
   ```

4. Keystore password နှင့် key password ကို ခိုင်မာပြီး မတူညီစွာထားကာ password manager ထဲသိမ်းပါ။ Keystore ကို ကုဒ်ဝှက်ထားသော offline backup နေရာတွင် ထပ်မံသိမ်းပါ။ Keystore ပျောက်ခြင်းသည် upload အသစ်များ လက်မှတ်ထိုးရာတွင် အခက်အခဲဖြစ်စေနိုင်သည်။
5. Keystore နှင့် password ကို repository ထဲ မထည့်ပါနှင့်။ `.gitignore` က `android/key.properties`, `*.jks`, `*.keystore`, `*.p12`, `*.pfx` နှင့် `*.mobileprovision` ကို ignore လုပ်ထားသည်။
6. Mac ပေါ်တွင် `android/key.properties` ကို ကိုယ်တိုင်ဖန်တီးပြီး အောက်ပါပုံစံအတိုင်း ဖြည့်ပါ။ Password အစား placeholder စာသားကို မထားပါနှင့်။ ဖိုင်ကို share မလုပ်၊ GitHub သို့ မတင်ပါနှင့်။ `storeFile` ကို keystore ၏ project အပြင်ဘက် path အပြည့်ဖြင့် သတ်မှတ်ပါ။

   ```properties
   storeFile=/Users/သင့်-Mac-အကောင့်/Library/Application Support/PaliMala/signing/palimala-upload.jks
   storePassword=ကိုယ်တိုင်သတ်မှတ်ထားသော-store-password
   keyAlias=palimala-upload
   keyPassword=ကိုယ်တိုင်သတ်မှတ်ထားသော-key-password
   ```

   `android/key.properties` ကို စာသားတည်းဖြတ်စက်ဖြင့် သိမ်းပြီး file permission ကို ကိုယ်တိုင်သာဖတ်နိုင်စေရန် `chmod 600 android/key.properties` လုပ်ပါ။ Gradle က local file ကိုဖတ်ပြီး လိုအပ်ချက်မပြည့်ပါက release build ကို fail-closed လုပ်ထားသည်။
7. CI အသုံးပြုပါက secrets ကို CI secret store မှသာ ပေးပါ။ Secret ကို build log ထဲ echo မလုပ်ပါနှင့်။ လက်ရှိအဆင့်တွင် CI secret များမသတ်မှတ်ရသေးပါ။

ဒီစစ်ဆေးမှုတွင် keystore/password မဖန်တီးထား၊ မဖတ်ရှု၊ မသိမ်းထားပါ။ လက်ရှိ `android/key.properties` နှင့် keystore မရှိသေးသဖြင့် signed AAB ကို တည်ဆောက်ရန် မဖြစ်နိုင်ပါ။ Owner က အထက်ပါအဆင့်များကို မိမိ Mac ပေါ်တွင် လုံခြုံစွာ ပြီးစီးပြီးနောက် local AAB build/signature စစ်ဆေးမှုကို ပြန်လုပ်ပါ။

## ၂။ iOS Bundle ID နှင့် Apple Signing

1. App Store အတွက် အတည်ပြုထားသော Bundle ID `com.palimala.app` ကို Apple Developer Team နှင့် App Store Connect record တွင် ပိုင်ဆိုင်/မှတ်ပုံတင်ထားကြောင်း စစ်ပါ။
2. Xcode ၏ Runner target > Signing & Capabilities တွင် သင့် Team ကို ရွေးပါ။ App Store ဖြန့်ချိမည်ဆိုလျှင် Automatic Signing သို့မဟုတ် စီမံထားသော Distribution certificate နှင့် App Store provisioning ကိုသုံးပါ။ Ad Hoc သည် သတ်မှတ်ထားသော device များအတွက်သာဖြစ်သည်။
3. Associated Domains, Push, Keychain စသည့် capability များ အသုံးပြုပါက သက်ဆိုင်ရာ entitlement နှင့် provisioning မှန်ကြောင်း စစ်ပါ။ မသုံးသော capability များ မထည့်ပါနှင့်။
4. Apple Distribution certificate ကို Xcode/Apple Developer ၏ လုံခြုံသောလုပ်ငန်းစဉ်မှတစ်ဆင့် release owner က မိမိစက်တွင် သတ်မှတ်ပါ။ `.p12`, private key သို့မဟုတ် provisioning profile ကို repository/chat ထဲ မထည့်ပါနှင့်။ `.gitignore` သည် `.mobileprovision` ဖိုင်များကို ကာကွယ်ထားသည်။ Certificate/profile နှင့် account ကို project owner ကသာ စီမံပါ။
5. Release archive ကို Xcode Organizer သို့မဟုတ် သင့်အဖွဲ့၏ signing CI ဖြင့် တည်ဆောက်ပြီး Validate App လုပ်ပါ။ Internal စမ်းသပ်ရန် TestFlight internal group၊ public release အတွက် App Store review ကို သုံးပါ။ `--no-codesign` build သည် device ဖြန့်ချိရန် လုံလောက်ခြင်းမရှိပါ။

ဒီ project တွင် Apple Team, production Bundle ID, Distribution certificate နှင့် provisioning profile မသတ်မှတ်ရသေးပါ။ ကိုယ်ပိုင် Apple Developer account လိုအပ်ချက်များကို app owner က ဖြည့်ဆည်းရပါမည်။

## ၃။ Version၊ AAB/APK စစ်ဆေးခြင်းနှင့် Upgrade Test

1. `pubspec.yaml` ရှိ `version: A.B.C+N` ကို ပြင်ဆင်ပါ။ ဥပမာ user မြင်ရသော version ကို `1.0.1` သတ်မှတ်လျှင် build number ကို ယခင်ကထက် ကြီးသော `+2` သို့မဟုတ် ထိုထက်ကြီးသည့် တန်ဖိုးထားပါ။ Android `versionCode` နှင့် iOS `CFBundleVersion` တို့သည် build number ကို အသုံးပြုသည်။ Android update လုပ်နိုင်ရန် `applicationId` နှင့် production signer တူညီရမည်။
2. Production signing သတ်မှတ်ပြီးနောက် `flutter build appbundle --release` ဖြင့် Android App Bundle ထုတ်ပါ။ Output သည် `build/app/outputs/bundle/release/app-release.aab` ဖြစ်သည်။
3. AAB ကို `jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab` ဖြင့် စစ်ပါ။ Verify အောင်မြင်ကြောင်း အတည်ပြုပြီးမှ ဆက်လုပ်ပါ။ `jarsigner` output တွင် public certificate အချက်အလက်သာ ပါရမည်။ Private key/password ကို command argument ထဲ မရေးပါနှင့်။
4. AAB အတွက် `shasum -a 256 build/app/outputs/bundle/release/app-release.aab` ဖြင့် SHA-256 ရယူပါ။ AAB ကို Play Console သို့ မတင်မီ owner က ပြန်လည်စစ်ဆေးအတည်ပြုပါ။
5. APK လိုအပ်ပါက `flutter build apk --release` ဖြင့် universal APK ထုတ်ပါ။ APK ကို `build/app/outputs/flutter-apk/app-release.apk` မှ ရယူပြီး Android SDK `apksigner verify --verbose --print-certs <APK-path>` ဖြင့် signature စစ်ပါ။
6. APK/AAB ဖိုင်အတွက် SHA-256 ရယူပါ။ Google Drive/Telegram ပို့မည့်ဖိုင်နှင့် လက်ခံသူရရှိသောဖိုင် hash တူကြောင်း စစ်ပါ။ APK bytes ကို edit/rebuild လုပ်လျှင် hash ပြောင်းမည်။
7. Upgrade test ကို Android သန့်ရှင်းသည့် test phone/emulator ပေါ်တွင်လုပ်ပါ။ တူညီသော production signer ဖြင့် sign ထားသော ယခင် APK မှ candidate ကို upgrade လုပ်ပြီး app data နှင့် saved items မပျောက်ကြောင်း၊ App လုပ်ဆောင်ချက်များ မှန်ကန်ကြောင်း စစ်ပါ။ Debug key ဖြင့်တင်ထားသော App ကို production signer ဖြင့် တိုက်ရိုက် upgrade မလုပ်နိုင်နိုင်ပါ။
8. Release record တွင် version, build number, APK/AAB SHA-256, certificate fingerprint, build date, approvals နှင့် upgrade test ရလဒ်ကို မှတ်တမ်းတင်ပါ။

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

- Google Play Console တွင် `com.palimala.app` ကို အသုံးပြုနိုင်မှုနှင့် Play App Signing အတွက် Google-managed သို့မဟုတ် owner-managed app signing key ရွေးချယ်မှု။
- Android production release ကို ထိန်းမည့်သူနှင့် keystore ကို လုံခြုံစွာဖန်တီး၊ backup လုပ်မည့် စက်/နေရာ။ Signing secrets များကို owner ကသာ စီမံရန်။
- iOS အတွက် Apple Developer Team ရှိ/မရှိနှင့် App Store/TestFlight/Ad Hoc ဖြန့်ချိမည့်ပုံစံ။ Team ID သို့မဟုတ် certificate များကို chat ထဲ မပို့ပါနှင့်။
- Google Drive release folder ကို စီမံမည့်သူ၊ အခွင့်အရေးပေးမည့်လက်ခံသူများ၊ Telegram ဖြန့်ချိမည့် channel/group နှင့် release အတည်ပြုသူ။
- GitHub `main` သို့ publish/merge လုပ်ရန် သီးခြားခွင့်ပြုချက်နှင့် release approval။ Dataset ပြောင်းလဲမည်ဆိုလျှင် သီးခြား Pali content review လည်းလိုသည်။
- Release version/build number နှင့် Android/iOS ထုတ်ဝေမှုကို တပြိုင်တည်းလုပ်မလား ဆုံးဖြတ်ချက်။

Rogo data ကို ဤစာတမ်းအတွက် မပြောင်းထားပါ။ နောက်ဆုံး local Flutter test run တွင် tests အားလုံးအောင်မြင်ခဲ့သည်။ Dynamic Config/Furniture data commit `0152bbf6920e3e1a7ca460f32bfa675952ed77cb` ကို GitHub `main` တွင် ထုတ်ဝေထားသည်။ ဤ Android signing အဆင့်တွင် Production Deployment၊ Firebase Production ပြောင်းလဲမှုနှင့် Drive/Telegram upload မလုပ်ပါ။
