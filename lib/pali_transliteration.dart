/// Transliteration helper: Pāḷi Roman (IAST) -> Kannada script.
///
/// Pāḷi Roman uses diacritics: ā ī ū ṃ ṅ ñ ṇ ṭ ḍ ḷ
/// Kannada is phonetic, so it pronounces Pāḷi much more accurately
/// than an English TTS voice reading Roman letters.
String paliRomanToKannada(String input) {
  if (input.isEmpty) return input;

  // Grammatical gender labels are display metadata, not part of the lemma.
  // Keep the source/UI string intact and remove only known labels for speech.
  final spokenInput = input
      .replaceAll(
        RegExp(
          r'\s*\((?:m|n|f|masc(?:uline)?|fem(?:inine)?|neut(?:er)?)(?:\.)?\)\s*',
          caseSensitive: false,
        ),
        ' ',
      )
      .trim();
  if (spokenInput.isEmpty) return '';

  const virama = '್';

  // Independent vowels (when a syllable starts with a vowel).
  // NOTE: Pāḷi e / o are short (unlike Sanskrit long ē / ō),
  // so they map to Kannada short ಎ / ಒ for correct chanting length.
  const independentVowels = <String, String>{
    'a': 'ಅ',
    'ā': 'ಆ',
    'i': 'ಇ',
    'ī': 'ಈ',
    'u': 'ಉ',
    'ū': 'ಊ',
    'e': 'ಎ',
    'o': 'ಒ',
  };

  // Dependent vowel signs (added after a consonant).
  // 'a' is inherent, so it is an empty sign.
  const vowelSigns = <String, String>{
    'a': '',
    'ā': 'ಾ',
    'i': 'ಿ',
    'ī': 'ೀ',
    'u': 'ು',
    'ū': 'ೂ',
    'e': 'ೆ',
    'o': 'ೊ',
  };

  // Base consonant letters (without virama).
  const consonants = <String, String>{
    'k': 'ಕ',
    'kh': 'ಖ',
    'g': 'ಗ',
    'gh': 'ಘ',
    'ṅ': 'ಙ',
    'c': 'ಚ',
    'ch': 'ಛ',
    'j': 'ಜ',
    'jh': 'ಝ',
    'ñ': 'ಞ',
    'ṭ': 'ಟ',
    'ṭh': 'ಠ',
    'ḍ': 'ಡ',
    'ḍh': 'ಢ',
    'ṇ': 'ಣ',
    't': 'ತ',
    'th': 'ಥ',
    'd': 'ದ',
    'dh': 'ಧ',
    'n': 'ನ',
    'p': 'ಪ',
    'ph': 'ಫ',
    'b': 'ಬ',
    'bh': 'ಭ',
    'm': 'ಮ',
    'y': 'ಯ',
    'r': 'ರ',
    'l': 'ಲ',
    'v': 'ವ',
    'w': 'ವ',
    's': 'ಸ',
    'h': 'ಹ',
  };

  // Retroflex ḷ has no single Kannada letter; write it asಳ (la + virama
  // is handled by the conjunct logic, plain "ḷa" -> "ಳ").
  const retroflexLa = 'ಳ';

  // Homorganic nasal assimilation: e.g. ṅ before k/kh/g/gh is written
  // with anusvara (ಸಂಘ) just like standard Kannada books, instead of
  // ಸಙ್ಘ. Geminates (mm, nn, ññ, ...) are kept as-is.
  const nasalVargas = <String, Set<String>>{
    'ṅ': {'k', 'kh', 'g', 'gh'},
    'ñ': {'c', 'ch', 'j', 'jh'},
    'ṇ': {'ṭ', 'ṭh', 'ḍ', 'ḍh'},
    'n': {'t', 'th', 'd', 'dh'},
    'm': {'p', 'ph', 'b', 'bh'},
  };

  // Vowels ordered longest-first so 'ā' wins over 'a', etc.
  const vowelsByLength = <String>['ā', 'ī', 'ū', 'a', 'i', 'u', 'e', 'o'];

  // Consonant keys ordered longest-first so 'ṭh' wins over 'ṭ', etc.
  // 'ḷ' is handled separately (see retroflexLa branch below).
  final consonantKeys = consonants.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  final lower = spokenInput.toLowerCase();
  final chars = lower.runes.map((r) => String.fromCharCode(r)).toList();
  // Keep original-codepoint chars for pass-through so indexes always match
  // (lowercasing can change length for some Unicode chars).
  final originalChars = spokenInput.runes
      .map((r) => String.fromCharCode(r))
      .toList();
  final buffer = StringBuffer();

  String? matchConsonantAt(int index) {
    for (final key in consonantKeys) {
      if (index + key.length > chars.length) continue;
      var ok = true;
      for (var k = 0; k < key.length; k++) {
        if (chars[index + k] != key[k]) {
          ok = false;
          break;
        }
      }
      if (ok) return key;
    }
    return null;
  }

  String? matchVowelAt(int index) {
    for (final v in vowelsByLength) {
      if (index + v.length > chars.length) continue;
      var ok = true;
      for (var k = 0; k < v.length; k++) {
        if (chars[index + k] != v[k]) {
          ok = false;
          break;
        }
      }
      if (ok) return v;
    }
    return null;
  }

  var i = 0;
  while (i < chars.length) {
    final ch = chars[i];

    // Anusvara / niggahīta: ṃ or ṁ -> ಂ
    if (ch == 'ṃ' || ch == 'ṁ') {
      // Before a homorganic stop the anusvara assimilates in speech,
      // but keep the written anusvara: "saṃ + gha" -> "ಸಂಘ".
      buffer.write('ಂ');
      i++;
      continue;
    }

    // Retroflex ḷ (e.g. in "bāḷhaṃ", "soḷasa").
    // Kannada has no dedicated ḷ letter; traditional Kannada Pāḷi books
    // write it as ಳ. "ḷh" is aspirated: ಳ್ಹ.
    if (ch == 'ḷ') {
      final vKey = matchVowelAt(i + 1);
      buffer.write(retroflexLa);
      if (vKey != null) {
        buffer.write(vowelSigns[vKey]);
        i += 1 + vKey.length;
      } else if (i + 1 < chars.length && chars[i + 1] == 'h') {
        // ḷh conjunct cluster: ಳ್ + ಹ (+ following vowel).
        buffer.write(virama);
        buffer.write(consonants['h']);
        final vAfterH = matchVowelAt(i + 2);
        if (vAfterH != null) {
          buffer.write(vowelSigns[vAfterH]);
          i += 2 + vAfterH.length;
        } else {
          buffer.write(virama);
          i += 2;
        }
      } else {
        buffer.write(virama);
        i++;
      }
      continue;
    }

    // Consonant + (optional) vowel.
    final cKey = matchConsonantAt(i);
    if (cKey != null) {
      final afterConsonant = i + cKey.length;
      final vKey = matchVowelAt(afterConsonant);

      // Homorganic nasal before its own varga stop (and not a geminate):
      // write anusvara, e.g. saṅgha -> ಸಂಘ, pañca -> ಪಂಚ,
      // kaṇṭaka -> ಕಂಟಕ. Geminates like mm/nn stay doubled (sammā -> ಸಮ್ಮಾ).
      if (nasalVargas.containsKey(cKey) && vKey == null) {
        final nextC = matchConsonantAt(afterConsonant);
        if (nextC != null &&
            nextC != cKey &&
            nasalVargas[cKey]!.contains(nextC)) {
          buffer.write('ಂ');
          i = afterConsonant;
          continue;
        }
      }

      final base = consonants[cKey]!;
      if (vKey != null) {
        // e.g. kh + ā -> ಖಾ, k + a -> ಕ
        buffer.write(base);
        buffer.write(vowelSigns[vKey]);
        i = afterConsonant + vKey.length;
      } else {
        // No vowel follows (conjunct or word-final): keep halant.
        // e.g. "buddha" -> ಬುದ್ಧ : first "d" gives ದ್, then "dha" gives ಧ.
        buffer.write(base);
        buffer.write(virama);
        i = afterConsonant;
      }
      continue;
    }

    // Standalone vowel.
    final vKey = matchVowelAt(i);
    if (vKey != null) {
      buffer.write(independentVowels[vKey]);
      i += vKey.length;
      continue;
    }

    // Anything else (spaces, punctuation, digits, already-Kannada,
    // Myanmar, etc.) passes through using the original casing/char.
    buffer.write(originalChars[i]);
    i++;
  }

  return buffer.toString();
}
