import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pali_transliteration.dart';

// Global Text To Speech Service
//
// Pāḷi has no native TTS voice, but Kannada is phonetic and covers the
// same sounds (ā ī ū ṃ ṅ ñ ṇ ṭ ḍ ḷ ...), so we transliterate Pāḷi Roman
// into Kannada script and speak it with the Kannada ("kn-IN") voice.
// Example: "Buddhaṃ saraṇaṃ gacchāmi" -> "ಬುದ್ಧಂ ಸರಣಂ ಗಚ್ಛಾಮಿ".
class TtsService {
  static final FlutterTts _flutterTts = FlutterTts();
  static bool _isInit = false;
  static double _speechRate = 0.45;
  static const _ratePrefKey = 'pali_pref_tts_rate';

  static final ValueNotifier<bool> isSpeaking = ValueNotifier<bool>(false);
  static bool? _cachedVoiceAvailable;

  static double get currentRate => _speechRate;
  static double get speechRate => _speechRate;

  static Future<void> init() async {
    if (!_isInit) {
      final prefs = await SharedPreferences.getInstance();
      _speechRate = prefs.getDouble(_ratePrefKey) ?? 0.45;

      _flutterTts.setStartHandler(() => isSpeaking.value = true);
      _flutterTts.setCompletionHandler(() => isSpeaking.value = false);
      _flutterTts.setCancelHandler(() => isSpeaking.value = false);
      _flutterTts.setErrorHandler((_) => isSpeaking.value = false);

      try {
        await _flutterTts.awaitSpeakCompletion(true);
      } catch (_) {}
      await _flutterTts.setLanguage("kn-IN"); // Kannada voice for Pali pronunciation
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setPitch(1.0);
      _isInit = true;
    }
  }

  /// Checks whether the device has the Kannada ("kn-IN") TTS voice used
  /// for Pāḷi pronunciation. Returns `true` if available or undetermined.
  static Future<bool> isVoiceAvailable() async {
    if (_cachedVoiceAvailable != null) return _cachedVoiceAvailable!;
    try {
      await init();
      final result = await _flutterTts.isLanguageAvailable("kn-IN");
      final available = result == true || result == 1;
      _cachedVoiceAvailable = available;
      return available;
    } catch (_) {
      return true;
    }
  }

  /// Sets audio playback speed (e.g. 0.3x for slow learning, 0.45x standard, 0.6x fast)
  static Future<void> setSpeechRate(double rate) async {
    await init();
    _speechRate = rate;
    await _flutterTts.setSpeechRate(_speechRate);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_ratePrefKey, rate);
  }

  /// Speaks a Pāḷi Roman line by converting it to Kannada script first.
  static Future<void> speakPali(String paliRoman, {double? rate}) async {
    await init();
    final kannadaText = paliRomanToKannada(paliRoman);
    if (kannadaText.isNotEmpty) {
      await _flutterTts.stop();
      await _flutterTts.setLanguage("kn-IN");
      if (rate != null) {
        await _flutterTts.setSpeechRate(rate);
      } else {
        await _flutterTts.setSpeechRate(_speechRate);
      }
      isSpeaking.value = true;
      await _flutterTts.speak(kannadaText);
    }
  }

  /// Speaks a Pāḷi Roman line and awaits completion (when supported by platform).
  static Future<void> speakPaliAndWait(String paliRoman, {double? rate}) async {
    await speakPali(paliRoman, rate: rate);
    isSpeaking.value = false;
  }

  static Future<void> speak(String text) async {
    await init();
    if (text.isNotEmpty) {
      await _flutterTts.stop();
      isSpeaking.value = true;
      await _flutterTts.speak(text);
    }
  }

  static Future<void> stop() async {
    isSpeaking.value = false;
    await _flutterTts.stop();
  }
}
