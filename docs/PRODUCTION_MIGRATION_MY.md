# PaliMala App ID Migration Status: `com.example.palimala` မှ `com.palimala.app`

ဤစာတမ်းသည် migration အခြေအနေနှင့် owner ဘက်မှ စစ်ဆေးရမည့်အချက်များကို မှတ်တမ်းတင်သည်။ Local project code/config တွင် Android နှင့် iOS ID ကို `com.palimala.app` သို့ ပြောင်းထားပြီးဖြစ်သည်။ Firebase production data၊ account၊ store listing သို့မဟုတ် signing credential များကို ဤအလုပ်တွင် မပြောင်း/မဖန်တီးထားပါ။

## စစ်ဆေးတွေ့ရှိချက်

- Android လက်ရှိ `namespace` နှင့် `applicationId` သည် `com.palimala.app` ဖြစ်ပြီး Activity source သည် `android/app/src/main/kotlin/com/palimala/app/MainActivity.kt` တွင်ရှိသည်။ Release build သည် local `android/key.properties` production keystore မရှိပါက fail-closed လုပ်သည်။
- iOS Runner Bundle ID သည် Xcode Runner configurations တွင် `com.palimala.app` ဖြစ်ပြီး RunnerTests တွင် `.RunnerTests` suffix သုံးထားသည်။ `ios/Runner/Info.plist` သည် `$(PRODUCT_BUNDLE_IDENTIFIER)` ကို သုံးသည်။
- Firebase project သည် ရှိပြီးသား `palimala-18c4c` ဖြစ်သည်။ Android `google-services.json` တွင် `.example` နှင့် `.app` package နှစ်ခုလုံးအတွက် entries ရှိပြီး iOS plist သည် `.app` ကို ရည်ညွှန်းသည်။ Firebase Console ပိုင်ဆိုင်မှု/ခွင့်ပြုချက်ကို ဤ local စစ်ဆေးမှုက အတည်မပြုနိုင်ပါ။
- iOS project တွင် Apple Team မသတ်မှတ်ထားပါ။ Release build စမ်းသပ်မှုကို `--no-codesign` ဖြင့်သာ အောင်မြင်စွာ ပြုလုပ်ထားသည်။
- Firebase ကို initialize လုပ်ထားသည်။ `cloud_firestore` package နှင့် `lib/Services/uploader_service.dart` တွင် lesson များကို Firestore `lessons` collection ထဲ `add` လုပ်သည့် code ရှိသည်။ `UploaderService` ကို app အခြားနေရာမှ လက်ရှိခေါ်နေကြောင်း မတွေ့ပါ။ Repository ထဲတွင် Firestore security rules ဖိုင် မတွေ့ပါ။ Firebase project ဘက်ရှိ rules များကို ဒီ local စစ်ဆေးမှုက မမြင်နိုင်ပါ။
- `firebase_auth`, `google_sign_in`, Firebase Messaging, Analytics, Crashlytics သို့မဟုတ် Storage package/use ကို `pubspec.yaml` နှင့် app code ထဲတွင် မတွေ့ပါ။ လက်ရှိ app တွင် Authentication နှင့် Google Sign-in feature မရှိပါ။ နောက်ပိုင်း ထည့်သွင်းပါက သီးခြား code, OAuth setup နှင့် security review လိုအပ်မည်။
- `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `firebase.json`, `lib/firebase_options.dart` သည် လက်ရှိ Firebase app registrations ကို ညွှန်သည်။ ဒီတန်ဖိုးများကို ကိုယ်တိုင် အစားထိုးမထည့်ပါနှင့်။

## Owner မှ အတည်ပြုရန် ဖိုင်/ဝန်ဆောင်မှုစာရင်း

### Android

| ဖိုင်/နေရာ | လုပ်ဆောင်ရန် (migration ခွင့်ပြုပြီးနောက်) |
| --- | --- |
| `android/app/build.gradle.kts` | `namespace`/`applicationId` ကို `.app` သတ်မှတ်ပြီးဖြစ်သည်။ Owner က package ပိုင်ဆိုင်မှုကို အတည်ပြုရန်။ Release signing အတွက် local key setup လုပ်ရန်။ |
| `android/app/src/main/kotlin/com/palimala/app/MainActivity.kt` | `.app` Kotlin package/path သတ်မှတ်ပြီးဖြစ်သည်။ Android release/install smoke test လုပ်ရန်။ |
| `android/app/google-services.json` | `.app` Firebase Android entry ပါရှိသည်။ Owner က Firebase Console ထဲရှိ registration ကို အတည်ပြုပြီး ထို entry နှင့်ကိုက်ညီကြောင်း စစ်ရန်။ |
| `firebase.json` | FlutterFire app mapping ကို ထုတ်ဝေမည့် Android/iOS registration နှင့် တိုက်စစ်ရန်။ အခြား platform mappings များကို မလိုအပ်ဘဲ မပြောင်းရန်။ |
| `lib/firebase_options.dart` | `.app` platform option များကို Firebase Console registration နှင့် အတည်ပြုရန်။ အခြား platform option များကို ထိန်းထားရန်။ |

### iOS

| ဖိုင်/နေရာ | လုပ်ဆောင်ရန် (migration ခွင့်ပြုပြီးနောက်) |
| --- | --- |
| `ios/Runner.xcodeproj/project.pbxproj` | Runner Bundle ID `.app` သတ်မှတ်ပြီးဖြစ်သည်။ Owner က Apple Developer Team/App Store Connect record နှင့် ကိုက်ညီကြောင်း အတည်ပြုပြီးမှ Team/signing သတ်မှတ်ရန်။ |
| `ios/Runner/Info.plist` | လက်ရှိ `$(PRODUCT_BUNDLE_IDENTIFIER)` မှ ID ယူသည်။ သီးခြားရေးထားသော ID ကို ပြောင်းရန်မလိုသော်လည်း build setting နှင့် ကိုက်ညီကြောင်း အတည်ပြုရန်။ |
| `ios/Runner/GoogleService-Info.plist` | Bundle ID `.app` ပါရှိသည်။ Owner က Firebase Console registration နှင့် ကိုက်ညီကြောင်း အတည်ပြုရန်။ |
| `firebase.json` | Firebase iOS app ID/file mapping ကို update လုပ်ရန်။ macOS သည် သီးခြားရွေးချယ်မှုမရှိပါက လက်ရှိ mapping ကို ထိန်းရန်။ |
| `lib/firebase_options.dart` | FlutterFire CLI ဖြင့် iOS option အသစ် generate လုပ်ရန်။ macOS က ယခု iOS Firebase app ID/config ကို မျှဝေသုံးနေသောကြောင့် macOS ရည်ရွယ်ချက်နှင့် config မပျက်ကြောင်း အထူး diff စစ်ရန်။ |
| `ios/Runner.xcodeproj` build signing settings | Apple Developer Team, automatic/manual signing, provisioning profile နှင့် Distribution signing ကို owner က မိမိ Apple Developer account တွင် သတ်မှတ်ပြီး archive/TestFlight ကို စစ်ဆေးရန်။ ဤ project တွင် ယခုအထိ မသတ်မှတ်ရသေးပါ။ |

### သက်ရောက်မှုရှိသော်လည်း ယခုမပြောင်းရမည့် desktop ရည်ညွှန်းချက်များ

- `macos/Runner/Configs/AppInfo.xcconfig`, `macos/Runner/GoogleService-Info.plist`, `macos/Runner.xcodeproj/project.pbxproj` နှင့် `linux/CMakeLists.txt` တွင် `com.example.palimala` ရည်ညွှန်းချက်များ ရှိသည်။ ဤအလုပ်၏ target သည် Android/iOS ဖြစ်သဖြင့် macOS/Linux ကို migration scope ထဲ မထည့်ပါနှင့်။ FlutterFire reconfigure လုပ်သောအခါ platform မရွေးချယ်မိစေရန် အထူးသတိပြုပါ။
- `ios/Runner/Info.plist` သည် Bundle ID ကို build setting မှယူပြီး, `AndroidManifest.xml` သည် `.MainActivity` ကို သုံးသည်။ အဲဒီ files တွင် hard-coded `com.example.palimala` တန်ဖိုးမတွေ့ပါ။
- Full-text scan ကို 2026-11-04 တွင် ပြုလုပ်ပြီးဖြစ်သည်။ Android/iOS အတွက် `com.palimala.app` ကို တွေ့ရှိပြီး၊ ကျန်ရှိသော `com.example.palimala` ရည်ညွှန်းချက်များမှာ ယခု migration scope ပြင်ပရှိ macOS/Linux configuration များတွင် ဖြစ်သည်။ OAuth URL scheme နှင့် provisioning profile ရည်ညွှန်းချက်များကို လက်ရှိ scan တွင် မတွေ့ရှိပါ။

## Firebase migration

လက်ရှိ local configuration တွင် Firebase project `palimala-18c4c` အတွင်းရှိ Android app ID နှင့် iOS app ID အသစ်များကို ရည်ညွှန်းထားပြီး၊ `google-services.json`, `GoogleService-Info.plist` နှင့် `firebase_options.dart` တို့တွင် `com.palimala.app` ကို သတ်မှတ်ထားသည်။ သို့သော် Firebase Console ထဲတွင် registration များ၏ လက်ရှိအခြေအနေနှင့် အသုံးပြုခွင့်ကို project owner က အတည်ပြုရမည်။ အတည်ပြုပြီးသား registration များကို ထပ်မံဖန်တီးရန် မလိုပါ။ Config ဖိုင်များ၏ App ID များသည် Firebase Console ရှိ app registration များနှင့် ကိုက်ညီကြောင်း စစ်ဆေးပါ။ Same Firebase project ကို ဆက်သုံးပါက Firestore backend တူညီနေမည်။ ဤ migration အတွင်း Firestore data သို့မဟုတ် Rules ကို မပြောင်းပါနှင့်။

အကြံပြု migration အဆင့်များ:

1. Project owner က Firebase Console ထဲရှိ project တူတူတွင် Android/iOS app အသစ်များဖန်တီးခွင့်ကို အတည်ပြုပါ။ App အသစ်များ register လုပ်ခြင်းသည် existing app registrations ကို ဖျက်ရန် မလိုပါ။
2. Android package နှင့် iOS Bundle ID အသစ်များကို Firebase Console တွင် အတိအကျထည့်ပါ။ Google Play signing certificate SHA-1/SHA-256 လိုအပ်သော OAuth/API integration ရှိမှသာ fingerprint များကို သက်ဆိုင်ရာ Firebase/Google configuration ထဲ ထည့်ရန်။
3. `flutterfire configure --platforms=android,ios` ဖြင့် Android/iOS app registration အသစ်များကို ရွေးပြီး config ထုတ်ပါ။ Firebase CLI/FlutterFire account ကို owner ကိုယ်တိုင် ထိန်းချုပ်ပါ။ macOS app mapping ကို migration scope ထဲ မထည့်ပါက generated diff တွင် macOS config မတော်တဆ မပြောင်းကြောင်း စစ်ဆေးပါ။
4. Firebase generated config files များကို စစ်ဆေးပြီးမှ source control ထဲ ထည့်ပါ။ ၎င်းတို့တွင် app အလိုက် non-secret identifier/config များပါဝင်သည်; private signing key/password မပါဝင်သင့်ပါ။
5. Staging/test device build ဖြင့် Firebase initialize ဖြစ်ကြောင်း၊ Firestore ကို မရည်ရွယ်ဘဲ write မလုပ်ကြောင်း စစ်ပါ။ `UploaderService` သုံးစွဲမည်ဆိုပါက Auth လိုအပ်ချက်နှင့် Firestore rules ကို production project တွင် အတည်ပြုပြီးမှ အသုံးပြုပါ။ ဒီ migration အတွက် Firestore data/rules မပြင်ပါနှင့်။

Authentication/Firestore/Google Sign-in သက်ရောက်မှု:

- ယခု source တွင် Firebase Auth နှင့် Google Sign-in မပါသေးသောကြောင့် user sign-in flow, OAuth Client ID, URL scheme ပြောင်းရမည့် code ကို မတွေ့ပါ။ နောက်ပိုင်းထည့်ပါက Android app ID နှင့် signing SHA fingerprint, iOS Bundle ID/URL scheme များကို OAuth provider ထဲ ပြန်ချိတ်ရန် လိုနိုင်သည်။
- Firestore uploader code သည် lesson documents ကို `lessons` collection သို့ ရေးနိုင်သော်လည်း codebase ထဲမှ call site မတွေ့ပါ။ Android/iOS Firebase app အသစ်များကို project တူတူ register လုပ်ခြင်းက collection/data migration မဟုတ်သကဲ့သို့ data ကို မပြောင်းပါ။ Firebase Console ထဲရှိ Firestore Rules ကို project owner သာ စစ်ဆေးနိုင်သည်။
- Same Firebase project ကို သုံးပါက Firebase UID/Firestore data ကို cloud side တွင် တူညီသည့် project အတွင်း ဆက်ရှိစေနိုင်သည်; သို့သော် ယခု app တွင် Auth UI မရှိ၍ user accounts ကို အတည်မပြုနိုင်ပါ။ Authentication feature အနာဂတ်တွင်ပါမည်ဆိုလျှင် provider configuration နှင့် security rules ကို သီးခြားပြင်ဆင်/test လုပ်ရမည်။

## ရှိပြီးသား install နှင့် local user data

Android က app ကို `applicationId` ဖြင့် ခွဲခြားပြီး update လုပ်ရာတွင် ID တူညီမှု၊ signing certificate ကိုက်ညီမှု၊ version code မလျော့မှု လိုအပ်သည်။ ထို့ကြောင့် `com.example.palimala` မှ `com.palimala.app` သို့ ပြောင်းပါက Android အတွက် **app အသစ်** ဖြစ်မည်။ ယခင် App ကို တူညီသောစက်တွင် ဆက်ထားနိုင်ပြီး အသစ်ကိုလည်း သီးခြားထည့်နိုင်သော်လည်း Play Store က package အသစ်ကို ယခင် listing ၏ update အဖြစ် မပေးနိုင်ပါ။

iOS Bundle ID အသစ်လည်း App Store Connect တွင် app အသစ်အဖြစ် မှတ်ပုံတင်ရမည်။ ယခင် bundle ID install ကို App Store မှ update လုပ်ရန် Bundle ID တူရမည်။ ထို့ကြောင့် `com.example.palimala` မှ `com.palimala.app` သို့ ပြောင်းခြင်းသည် iOS app အသစ်နှင့် သီးခြား container ဖြစ်စေသည်။

ဒီ app ၏ Saved words, settings, cached lessons နှင့် Remote Config cache တို့သည် app သီးသန့် sandbox/shared preferences ထဲတွင် သိမ်းထားသည်။ Application ID/Bundle ID အသစ်သို့ အဲဒီ local ဖိုင်များ အလိုအလျောက် မရွှေ့ပါ။ App အဟောင်းကို မဖျက်လျှင် အဲဒီ app ထဲတွင် ဒေတာများ ကျန်နေမည်။ လက်ရှိတွင် user data ကို account/cloud ထဲ backup သို့မဟုတ် app အသစ်သို့ ရွှေ့ပေးသည့် code မရှိသောကြောင့် local user data အလိုအလျောက်ပြောင်းမည်ဟု အာမခံမရပါ။ Firebase project တူတူသုံးခြင်းက local data ကို မရွှေ့ပေးပါ။ ရှိပြီးသားအသုံးပြုသူများကို app အသစ်မတင်ဘဲ update ဆက်ပေးရန် လိုအပ်ပါက ID ကိုမပြောင်းဘဲ `com.example.palimala` ကို ဆက်သုံးရန် ရွေးချယ်ရမည်။

## Android signing, Play AAB နှင့် APK

- Google Play အတွက် production artifact ကို Android App Bundle (`flutter build appbundle --release`) အဖြစ် ထုတ်ရန်။ Google Play အသစ်ထုတ်ဝေမှုတွင် Play App Signing ကို အသုံးပြုပြီး AAB ကို upload key ဖြင့် sign လုပ်ကာ Play က user များထံ ပို့မည့် APK များကို app signing key ဖြင့် sign လုပ်သည်။
- Drive/Telegram direct distribution အတွက် APK (`flutter build apk --release`) ထုတ်ရန်။ Play ဖြန့်ဝေ APK နှင့် direct APK ကို အပြန်အလှန် update လုပ်နိုင်စေလိုလျှင် Play App Signing setup အချိန် **ကိုယ်ပိုင် app signing key ပေးမည်လား** ဆုံးဖြတ်ပါ။ Google က ကိုင်ထားသော app signing private key ကို download မရနိုင်သဖြင့် Google-generated Play key ဖြင့် Play က sign လုပ်သည့် APK နှင့် သင့်ကိုယ်ပိုင် upload key ဖြင့် sign လုပ်ထားသည့် APK များမှာ signer မတူနိုင်ပါ။ ဒီဆုံးဖြတ်ချက်က နောက်ပိုင်း update compatibility ကို သက်ရောက်သည်။
- Play Store နှင့် Drive/Telegram အားလုံးတွင် အနာဂတ် update အတွက် `applicationId` တူ၊ Android signer အပြန်အလှန်အသိအမှတ်ပြုနိုင်၊ version code တိုးတက်နေရမည်။ Play ဖြင့် install လုပ်ထားသူထံ nonmatching signer ဖြင့် signed APK install လုပ်လျှင် update အစား conflict/error ဖြစ်မည်။ Channel တစ်ခုက version code ပိုမြင့်နေပါက နိမ့်သော code ဖြင့် update မတက်ပါ။
- `pubspec.yaml` `version: A.B.C+N` တွင် `A.B.C` ကို public version၊ `N` ကို Android `versionCode`/iOS build number အဖြစ် တိုးပါ။ Play Console မှာ version code အဟောင်း ပြန်သုံး၍မရ။ `1.0.1+2` သည် format ဥပမာသာဖြစ်ပြီး owner သဘောတူညီမှုမရှိဘဲ လက်ရှိ version ကို မပြောင်းပါနှင့်။
- Play ထုတ်ဝေမှုအစီအစဉ်: Play Console app record ဖန်တီးရန်, Play App Signing key ဆုံးဖြတ်ရန်, upload certificate ထိန်းသိမ်းရန်, internal testing track တွင် AAB တင်ရန်, pre-launch/device test ဖြတ်ရန်, store listing/privacy/data safety declarations ပြင်ဆင်ရန်, owner review ပြီးမှ production rollout လုပ်ရန်။
- Drive/Telegram အစီအစဉ်: Play signing strategy နှင့်အညီ signed APK တည်ဆောက်ရန်, `apksigner verify --verbose --print-certs` ဖြင့် signature/fingerprint စစ်ရန်, APK SHA-256 မှတ်တမ်းတင်ရန်, clean install နှင့် upgrade test လုပ်ရန်, owner approval ပြီးမှ Drive restricted link/Telegram release post ထုတ်ရန်။ APK, version, SHA-256 နှင့် release notes ကို တူညီအောင် ဖော်ပြပါ။ လက်ရှိ debug-signed APK ကို ဖြန့်ဝေမသုံးပါနှင့်။

## iOS TestFlight နှင့် App Store

1. App Store Connect တွင် `com.palimala.app` Bundle ID နှင့်ကိုက်ညီသော App record အသစ်ဖန်တီးပါ။ Bundle ID သည် upload ပြီးသော build တစ်ခုတွင် ပြောင်း၍မရသောကြောင့် ပထမ upload မတိုင်မီ အတည်ပြုပါ။
2. Apple Developer account တွင် explicit App ID ဖန်တီးပြီး လိုအပ်သော capability များကို ဖွင့်ပါ။ Xcode Runner target တွင် Apple Team ကို ရွေးပါ။ Distribution certificate နှင့် App Store provisioning profile ကို owner က Apple account/Xcode signing workflow မှတစ်ဆင့် သတ်မှတ်ပါ။
3. App version နှင့် iOS build number (Flutter `+N`) ကို တိုးပြီး Release archive ထုတ်ပါ။ Validate လုပ်ပြီး App Store Connect သို့ တင်ပါ။
4. TestFlight internal/external tester များဖြင့် install, offline config, saved words, lesson update နှင့် Firebase initialize ကို စစ်ပါ။ Privacy details, age/content rating, screenshots, description, support/privacy-policy URL နှင့် store listing အချက်အလက်များကို owner က ပြင်ဆင်ပါ။
5. TestFlight စစ်ဆေးမှု ပြီး၍ owner အတည်ပြုပြီးနောက် App Store review သို့ တင်ပါ။ Review နှင့် ရရှိနိုင်မည့်ဒေသဆိုင်ရာ setting များကို owner က ရွေးချယ်ပါ။

iOS app ကို Google Drive/Telegram မှ Android APK ကဲ့သို့ အသုံးပြုသူများထံ ဖြန့်ချိမရပါ။ Development/Ad Hoc IPA တွင် signing, provisioning နှင့် ခွင့်ပြုထားသော device များဆိုင်ရာ ကန့်သတ်ချက်များရှိသဖြင့် အများပြည်သူသုံး store ဖြန့်ချိမှုကို အစားမထိုးနိုင်ပါ။ iOS ၏ အဓိကဖြန့်ချိရာနေရာမှာ TestFlight/App Store ဖြစ်သည်.

## Migration ပြီးမှ ပြုလုပ်မည့် Test နှင့် rollback

- Build ကို ID အသစ်နှင့် ဖြတ်ပြီး Android APK/AAB, iOS archive တို့၏ app identity မှန်ကြောင်း စစ်ရန်။ Firebase initialize နှင့် platform options မှန်ကြောင်း, Android/iOS app registration တူညီသော Firebase project သို့ ချိတ်ကြောင်း စစ်ရန်။
- Android: Play Internal track မှ install/upgrade စမ်းရန်။ Direct APK channel ကိုပါ သုံးမည်ဆိုလျှင် Drive APK သည် Play install နှင့် signer compatibility ရှိကြောင်း တကယ်စမ်းရန်။ Old `com.example.palimala` app ကို မဖျက်ဘဲ new app ကို side-by-side install လုပ်စမ်းရန်။
- iOS: TestFlight မှ install လုပ်ရန်၊ old app ရှိစဉ် side-by-side behavior/အသုံးပြုသူများထံရှင်းပြမှုကို စစ်ရန်။ App Store record/BID Team signing ကို validate လုပ်ရန်။
- Migration လမ်းကြောင်းကို rollback လုပ်ရန် store listing အဟောင်းနှင့် ID/signer အဟောင်းဖြင့် ထုတ်ထားသော release များကို ထိန်းသိမ်းပါ။ ID အသစ်သည် app အဟောင်းကို update မလုပ်နိုင်သောကြောင့် rollback လုပ်လျှင် app အဟောင်းအတွက် ID နှင့် signer အဟောင်းကိုက်ညီသော release အသစ် ထုတ်ရမည်။ Firebase project တူတူရှိ data ကို ပြောင်းရွှေ့/ပြင်ဆင်ထားပါက owner ၏ ခွင့်ပြုချက်မရှိဘဲ ပြန်မပြောင်းပါနှင့်။

## Project owner ထံမှ လိုအပ်သော ဆုံးဖြတ်ချက်များ

- Owner သည် Android နှင့် iOS နှစ်ခုလုံးအတွက် `com.palimala.app` ကို အသုံးပြုရန် အတည်ပြုပြီးဖြစ်သည်။ Firebase၊ Google Play နှင့် Apple Developer/App Store Connect တို့တွင် registration နှင့် အသုံးပြုခွင့်ကို release မတိုင်မီ စစ်ဆေးပါ။
- `com.example.palimala` ရှိပြီးသား အသုံးပြုသူများကို `com.palimala.app` app အသစ်သို့ ပြောင်းရွှေ့ရန် အသိပေးပြီး local data အတွက် လိုအပ်သော backup/export လမ်းညွှန် ပေးရန်။
- Firebase project `palimala-18c4c` ထဲရှိ Android/iOS app registrations နှင့် လက်ရှိ App ID များကို Firebase Console တွင် အတည်ပြုရန်၊ Firebase Console ကို စီမံနိုင်သည့် owner နှင့် macOS target ကိုလည်း နောင်တွင် ပြောင်းမပြောင်း။
- Play App Signing တွင် သင့်ကိုယ်ပိုင် app signing key ကို ပေးသုံးမည်လား၊ Google က key ဖန်တီး/ထိန်းသိမ်းမည်လား။ Play Store နှင့် APK sideload နှစ်မျိုးလုံးကို သုံးလိုပါက signer compatibility သည် အဓိကဆုံးဖြတ်ချက်ဖြစ်သည်။ Signing secrets ကို မပေးပါနှင့်။
- Google Play Console account, Apple Developer Program/Team, App Store Connect access, privacy policy/support URL နှင့် store listing content ကို တာဝန်ယူမည့်သူ။
- Google Drive release folder/view access, Telegram channel/group နှင့် release approval ကို ဘယ်သူပေးမည်။

ID ပြောင်းခြင်း, Firebase app registration အသစ်, signing, Play/App Store publish, Firebase data ပြောင်းလဲခြင်း, Drive/Telegram upload တို့ကို ယခု မလုပ်ထားပါ။ Rogo dataset ကို မပြင်ထားပါ။

## Official setup references

- [FlutterFire: Firebase ကို Flutter project တွင် setup လုပ်ခြင်း](https://firebase.google.com/docs/flutter/setup)
- [Android: App update လုပ်နိုင်ရန်လိုအပ်ချက်များ](https://developer.android.com/google/play/app-updates)
- [Android: App signing နှင့် Play App Signing](https://developer.android.com/studio/publish/app-signing)
- [Android: Play Console သို့ AAB တင်ခြင်း](https://developer.android.com/studio/publish/upload-bundle)
- [Apple: App ID ဖန်တီးခြင်း](https://developer.apple.com/help/account/identifiers/register-an-app-id)
- [Apple: App Store Connect app information နှင့် Bundle ID](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/)
- [Apple: TestFlight/App Store ဖြန့်ချိရန်ပြင်ဆင်ခြင်း](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution)
