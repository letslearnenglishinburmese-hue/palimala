import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_data.dart';
import 'firebase_options.dart';
import 'remote_app_config.dart';
import 'screens/home_screen.dart';
import 'shorebird_update_service.dart';

export 'screens/data_download_sheet.dart';
export 'screens/detail_content_screen.dart';
export 'screens/flashcard_screen.dart';
export 'screens/home_screen.dart';
export 'screens/pali_chat_screen.dart';
export 'screens/sub_category_screen.dart';
export 'screens/vocabulary_quiz_screen.dart';
export 'services/learning_stats_service.dart';
export 'services/pali_chat_service.dart';
export 'services/tts_service.dart';
export 'widgets/language_mode_switcher.dart';

late List<MainCategory> appData;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    appData = await AppDataRepository.load();
  } on Object catch (error) {
    // Keep the shell usable even if local preferences or bundled lessons fail.
    appData = const [];
    debugPrint(
      'Local lesson bootstrap failed; opening the offline app shell: $error',
    );
  }
  try {
    await RemoteAppConfigRepository.load();
    appData = RemoteAppConfigRepository.current.apply(appData);
  } on Object catch (error) {
    debugPrint('Using built-in app defaults: $error');
  }
  runApp(const PaliLearningApp());
  unawaited(
    Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).then<void>((_) {}).catchError((Object error) {
      debugPrint(
        'Firebase initialization failed; offline features remain available: $error',
      );
    }),
  );
}

// Language Enum
enum AppLanguage { myanmar, english }

class PaliLearningApp extends StatefulWidget {
  const PaliLearningApp({super.key});

  @override
  State<PaliLearningApp> createState() => _PaliLearningAppState();
}

class _PaliLearningAppState extends State<PaliLearningApp> {
  static const _prefKeyLanguage = 'pali_pref_language';
  static const _prefKeyThemeMode = 'pali_pref_dark_mode';
  static const _prefKeyTextScale = 'pali_pref_text_scale';

  AppLanguage currentLang = AppLanguage.myanmar;
  double _textScale = 1;
  bool _isDarkMode = false;
  final Set<String> _savedWords = {};
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final ValueNotifier<int> _selectedTab = ValueNotifier<int>(0);
  final ShorebirdUpdateService _shorebird = ShorebirdUpdateService();
  bool _isCheckingShorebird = false;
  bool _isUpdatingShorebird = false;

  @override
  void initState() {
    super.initState();
    appData = RemoteAppConfigRepository.current.apply(
      AppDataRepository.categories,
    );
    appDataRevision.addListener(_handleDataChanged);
    _loadSavedWords();
    _loadSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkForShorebirdUpdate());
    });
  }

  Future<void> _loadSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final langStr = preferences.getString(_prefKeyLanguage);
    final isDark = preferences.getBool(_prefKeyThemeMode);
    final scale = preferences.getDouble(_prefKeyTextScale);
    if (!mounted) return;
    setState(() {
      if (langStr == 'english') {
        currentLang = AppLanguage.english;
      } else if (langStr == 'myanmar') {
        currentLang = AppLanguage.myanmar;
      }
      if (isDark != null) {
        _isDarkMode = isDark;
      }
      if (scale != null) {
        _textScale = scale;
      }
    });
  }

  Future<void> _checkForShorebirdUpdate() async {
    if (_isCheckingShorebird ||
        _isUpdatingShorebird ||
        !_shorebird.isAvailable ||
        !mounted) {
      return;
    }
    _isCheckingShorebird = true;
    try {
      final status = await _shorebird.check();
      if (!mounted) return;
      if (status == ShorebirdUpdateStatus.outdated) {
        await _showShorebirdUpdateAvailable();
      } else if (status == ShorebirdUpdateStatus.restartRequired) {
        await _showShorebirdRestartReady();
      }
    } on ShorebirdUpdateException catch (error) {
      if (mounted) _showCodeUpdateError(error.failure);
    } on Exception catch (error) {
      // Code push is optional; network or updater failures must not affect
      // the app shell or the separate lesson data update flow.
      debugPrint('Shorebird update check failed: $error');
      if (mounted) _showCodeUpdateError();
    } finally {
      _isCheckingShorebird = false;
    }
  }

  void _showCodeUpdateError([ShorebirdUpdateFailure? failure]) {
    final isMm = currentLang == AppLanguage.myanmar;
    final message = switch (failure) {
      ShorebirdUpdateFailure.network =>
        isMm
            ? 'အင်တာနက်ချိတ်ဆက်မှုကို စစ်ဆေးပြီး ထပ်ကြိုးစားပါ။'
            : 'Check your internet connection and try again.',
      ShorebirdUpdateFailure.server =>
        isMm
            ? 'အပ်ဒိတ်ဆာဗာတွင် ယာယီပြဿနာရှိနေပါသည်။ နောက်မှ ထပ်ကြိုးစားပါ။'
            : 'The update server is temporarily unavailable. Try again later.',
      ShorebirdUpdateFailure.download =>
        isMm
            ? 'အပ်ဒိတ်ကို ဒေါင်းလုဒ် သို့မဟုတ် တပ်ဆင်၍ မရပါ။ နောက်မှ ထပ်ကြိုးစားပါ။'
            : 'The update could not be downloaded or installed. Try again later.',
      ShorebirdUpdateFailure.noUpdate =>
        isMm
            ? 'ရယူရန် အပ်ဒိတ်မရှိတော့ပါ။ နောက်မှ ထပ်စစ်ဆေးပါ။'
            : 'No update is available now. Please check again later.',
      _ =>
        isMm
            ? 'အက်ပ်အပ်ဒိတ်ကို ယခုစစ်ဆေး၍ မရပါ။ နောက်မှ ထပ်ကြိုးစားပါ။'
            : 'App updates could not be checked. Please try again later.',
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _shorebirdDownloadError(Object error, bool isMm) {
    if (error is! ShorebirdUpdateException) {
      return isMm
          ? 'အပ်ဒိတ်ကို ဒေါင်းလုဒ်လုပ်၍ မရပါ။ နောက်မှ ထပ်ကြိုးစားပါ။'
          : 'The update could not be downloaded. Please try again later.';
    }
    return switch (error.failure) {
      ShorebirdUpdateFailure.network =>
        isMm
            ? 'အင်တာနက်ချိတ်ဆက်မှုကို စစ်ဆေးပြီး ထပ်ကြိုးစားပါ။'
            : 'Check your internet connection and try again.',
      ShorebirdUpdateFailure.server =>
        isMm
            ? 'အပ်ဒိတ်ဆာဗာတွင် ယာယီပြဿနာရှိနေပါသည်။ နောက်မှ ထပ်ကြိုးစားပါ။'
            : 'The update server is temporarily unavailable. Try again later.',
      ShorebirdUpdateFailure.download =>
        isMm
            ? 'အပ်ဒိတ်ကို ဒေါင်းလုဒ် သို့မဟုတ် တပ်ဆင်၍ မရပါ။ နောက်မှ ထပ်ကြိုးစားပါ။'
            : 'The update could not be downloaded or installed. Try again later.',
      ShorebirdUpdateFailure.noUpdate =>
        isMm
            ? 'ရယူရန် အပ်ဒိတ်မရှိတော့ပါ။ နောက်မှ ထပ်စစ်ဆေးပါ။'
            : 'No update is available now. Please check again later.',
      ShorebirdUpdateFailure.unknown =>
        isMm
            ? 'အပ်ဒိတ်အမှားကို အတည်မပြုနိုင်ပါ။ နောက်မှ ထပ်စစ်ဆေးပါ။'
            : 'The update error could not be identified. Please check again later.',
    };
  }

  Future<void> _showShorebirdUpdateAvailable() async {
    final isMm = currentLang == AppLanguage.myanmar;
    final update = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(isMm ? 'အက်ပ်အပ်ဒိတ် ရှိသည်' : 'App update available'),
        content: Text(
          isMm
              ? 'Shorebird patch အသစ်တစ်ခု ရှိပါသည်။ အပ်ဒိတ်ကို ဒေါင်းလုဒ်လုပ်ရန် ရွေးချယ်နိုင်ပါသည်။'
              : 'A new Shorebird patch is available. Download it now to use the latest app changes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(isMm ? 'နောက်မှ' : 'Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isMm ? 'ယခု အပ်ဒိတ်လုပ်ရန်' : 'Update Now'),
          ),
        ],
      ),
    );
    if (update == true && mounted) await _downloadShorebirdUpdate();
  }

  Future<void> _downloadShorebirdUpdate() async {
    final isMm = currentLang == AppLanguage.myanmar;
    if (_isUpdatingShorebird) return;
    _isUpdatingShorebird = true;
    final download = _shorebird.downloadAndVerify();
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => FutureBuilder<ShorebirdPatchState>(
          future: download,
          builder: (context, snapshot) {
            final done = snapshot.connectionState == ConnectionState.done;
            final state = snapshot.data;
            final patchNumber = state?.patchNumber;
            final stateKind =
                state?.kind == ShorebirdPatchStateKind.newPatchReady &&
                    patchNumber == null
                ? ShorebirdPatchStateKind.unknown
                : state?.kind;
            final title = !done
                ? (isMm ? 'အပ်ဒိတ်လုပ်နေသည်' : 'Downloading update')
                : snapshot.hasError
                ? (isMm ? 'အပ်ဒိတ် မအောင်မြင်ပါ' : 'Update failed')
                : switch (stateKind) {
                    ShorebirdPatchStateKind.newPatchReady =>
                      isMm ? 'အပ်ဒိတ် အဆင်သင့်ဖြစ်ပါပြီ' : 'Update ready',
                    ShorebirdPatchStateKind.rollbackPending =>
                      isMm
                          ? 'ပြန်လည်ရုပ်သိမ်းမှု အဆင်သင့်ဖြစ်ပါပြီ'
                          : 'Rollback ready',
                    ShorebirdPatchStateKind.noNextPatch =>
                      isMm ? 'အပ်ဒိတ် မရှိတော့ပါ' : 'No update pending',
                    _ =>
                      isMm ? 'အခြေအနေ မသေချာပါ' : 'Update status unconfirmed',
                  };
            final detail = !done
                ? (isMm ? 'ကျေးဇူးပြု၍ ခဏစောင့်ပါ…' : 'Please wait…')
                : snapshot.hasError
                ? _shorebirdDownloadError(snapshot.error!, isMm)
                : switch (stateKind) {
                    ShorebirdPatchStateKind.newPatchReady =>
                      isMm
                          ? 'Patch $patchNumber ကို အသုံးပြုရန် အက်ပ်ကို ပိတ်ပြီး Home Screen မှ ပြန်ဖွင့်ပါ။'
                          : 'Patch $patchNumber is ready. Close the app and reopen it from your Home Screen.',
                    ShorebirdPatchStateKind.rollbackPending =>
                      isMm
                          ? 'အက်ပ်ပြောင်းလဲမှုကို ပြန်ရုပ်သိမ်းရန် အက်ပ်ကို ပိတ်ပြီး Home Screen မှ ပြန်ဖွင့်ပါ။'
                          : 'A rollback is pending. Close the app and reopen it from your Home Screen.',
                    ShorebirdPatchStateKind.noNextPatch =>
                      isMm
                          ? 'အသုံးပြုရန် Patch အသစ်ကို အတည်မပြုနိုင်ပါ။ နောက်မှ ထပ်စစ်ဆေးပါ။'
                          : 'No new patch could be confirmed. Please check again later.',
                    _ =>
                      isMm
                          ? 'အပ်ဒိတ်အခြေအနေကို အတည်မပြုနိုင်ပါ။ နောက်မှ ထပ်စစ်ဆေးပါ။'
                          : 'The update status could not be verified. Please check again later.',
                  };
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!done) const LinearProgressIndicator(),
                  if (!done) const SizedBox(height: 16),
                  Text(detail),
                ],
              ),
              actions: [
                if (done)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(isMm ? 'နောက်မှ' : 'Later'),
                  ),
              ],
            );
          },
        ),
      );
    } finally {
      _isUpdatingShorebird = false;
    }
  }

  Future<void> _showShorebirdRestartReady() async {
    if (!mounted) return;
    final isMm = currentLang == AppLanguage.myanmar;
    final patchState = await _shorebird.readPatchState();
    if (!mounted) return;
    final stateKind =
        patchState.kind == ShorebirdPatchStateKind.newPatchReady &&
            patchState.patchNumber == null
        ? ShorebirdPatchStateKind.unknown
        : patchState.kind;
    final title = switch (stateKind) {
      ShorebirdPatchStateKind.newPatchReady =>
        isMm ? 'အပ်ဒိတ် အဆင်သင့်ဖြစ်ပါပြီ' : 'Update ready',
      ShorebirdPatchStateKind.rollbackPending =>
        isMm ? 'ပြန်လည်ရုပ်သိမ်းမှု အဆင်သင့်ဖြစ်ပါပြီ' : 'Rollback ready',
      ShorebirdPatchStateKind.noNextPatch =>
        isMm ? 'Patch အသစ် မရှိပါ' : 'No new patch pending',
      ShorebirdPatchStateKind.unknown =>
        isMm ? 'အခြေအနေ မသေချာပါ' : 'Update status unconfirmed',
    };
    final message = switch (stateKind) {
      ShorebirdPatchStateKind.newPatchReady =>
        isMm
            ? 'Patch ${patchState.patchNumber} ကို အသုံးပြုရန် အက်ပ်ကို ပိတ်ပြီး Home Screen မှ ပြန်ဖွင့်ပါ။'
            : 'Patch ${patchState.patchNumber} is ready. Close the app and reopen it from your Home Screen.',
      ShorebirdPatchStateKind.rollbackPending =>
        isMm
            ? 'အက်ပ်ပြောင်းလဲမှုကို ပြန်ရုပ်သိမ်းရန် အက်ပ်ကို ပိတ်ပြီး Home Screen မှ ပြန်ဖွင့်ပါ။'
            : 'A rollback is pending. Close the app and reopen it from your Home Screen.',
      ShorebirdPatchStateKind.noNextPatch =>
        isMm
            ? 'လက်ရှိတွင် အသုံးပြုရန် Patch အသစ် မရှိပါ။ နောက်မှ ထပ်စစ်ဆေးပါ။'
            : 'There is no new patch to apply now. Please check again later.',
      ShorebirdPatchStateKind.unknown =>
        isMm
            ? 'အပ်ဒိတ်အခြေအနေကို အတည်မပြုနိုင်ပါ။ နောက်မှ ထပ်စစ်ဆေးပါ။'
            : 'The update status could not be verified. Please check again later.',
    };
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(isMm ? 'နောက်မှ' : 'Later'),
          ),
        ],
      ),
    );
  }

  @override
  void reassemble() {
    super.reassemble();
    unawaited(AppDataRepository.reloadBundled());
  }

  /// Keeps the shared [appData] in sync when a data set is downloaded or
  /// updated from the settings screen.
  void _handleDataChanged() {
    if (!mounted) return;
    setState(
      () => appData = RemoteAppConfigRepository.current.apply(
        AppDataRepository.categories,
      ),
    );
  }

  Future<void> _loadSavedWords() async {
    final preferences = await SharedPreferences.getInstance();
    final savedWords = preferences.getStringList('saved_pali_words') ?? [];
    if (!mounted) return;
    setState(() {
      _savedWords
        ..clear()
        ..addAll(savedWords);
    });
  }

  Future<void> _toggleSavedWord(VocabItem item) async {
    setState(() {
      if (!_savedWords.add(item.paliRoman)) {
        _savedWords.remove(item.paliRoman);
      }
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList('saved_pali_words', _savedWords.toList());
  }

  void toggleLanguage() {
    setState(() {
      currentLang = currentLang == AppLanguage.myanmar
          ? AppLanguage.english
          : AppLanguage.myanmar;
    });
    SharedPreferences.getInstance().then((preferences) {
      preferences.setString(
        _prefKeyLanguage,
        currentLang == AppLanguage.english ? 'english' : 'myanmar',
      );
    });
  }

  void _updateTextScale(double value) {
    setState(() => _textScale = value);
    SharedPreferences.getInstance().then((preferences) {
      preferences.setDouble(_prefKeyTextScale, value);
    });
  }

  void _toggleTheme(bool value) {
    setState(() => _isDarkMode = value);
    SharedPreferences.getInstance().then((preferences) {
      preferences.setBool(_prefKeyThemeMode, value);
    });
  }

  @override
  void dispose() {
    appDataRevision.removeListener(_handleDataChanged);
    _selectedTab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = RemoteAppConfigRepository.current;
    final light = config.lightColors;
    final dark = config.darkColors;
    final isMm = currentLang == AppLanguage.myanmar;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pāḷi Learning App',
      theme: buildRemoteTheme(config, dark: false, isMyanmar: isMm),
      darkTheme: buildRemoteTheme(config, dark: true, isMyanmar: isMm),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(_textScale)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final navigator = _navigatorKey.currentState;
          if (navigator != null && navigator.canPop()) {
            navigator.pop();
          } else if (_selectedTab.value != 0) {
            _selectedTab.value = 0;
          } else {
            await SystemNavigator.pop();
          }
        },
        child: Scaffold(
          body: Navigator(
            key: _navigatorKey,
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              builder: (context) => HomeScreen(
                currentLang: currentLang,
                onLanguageToggle: toggleLanguage,
                selectedTab: _selectedTab,
                savedWords: _savedWords,
                onSavedWordToggle: _toggleSavedWord,
                textScale: _textScale,
                onTextScaleChanged: _updateTextScale,
                isDarkMode: _isDarkMode,
                onThemeChanged: _toggleTheme,
                onCheckCodeUpdate: _checkForShorebirdUpdate,
              ),
            ),
          ),
          bottomNavigationBar: ValueListenableBuilder<int>(
            valueListenable: _selectedTab,
            builder: (context, selectedIndex, _) => NavigationBar(
              selectedIndex: selectedIndex,
              height: 60,
              labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
              backgroundColor: _isDarkMode ? dark['surface'] : light['surface'],
              indicatorColor: (_isDarkMode ? dark['primary'] : light['primary'])!
                  .withValues(alpha: 0.14),
              onDestinationSelected: (index) {
                _navigatorKey.currentState?.popUntil((route) => route.isFirst);
                _selectedTab.value = index;
              },
                destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home_rounded),
                  label: currentLang == AppLanguage.myanmar ? 'ပင်မ' : 'Home',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.search_rounded),
                  label: currentLang == AppLanguage.myanmar
                      ? 'ရှာရန်'
                      : 'Search Word',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.forum_outlined),
                  selectedIcon: const Icon(Icons.forum_rounded),
                  label: currentLang == AppLanguage.myanmar
                      ? 'စကားပြောခန်း'
                      : 'Chat',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.bookmark_border_rounded),
                  selectedIcon: const Icon(Icons.bookmark_rounded),
                  label: currentLang == AppLanguage.myanmar
                      ? 'မှတ်ထားသည်များ'
                      : 'Saved',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings_rounded),
                  label: currentLang == AppLanguage.myanmar
                      ? 'ဆက်တင်'
                      : 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
