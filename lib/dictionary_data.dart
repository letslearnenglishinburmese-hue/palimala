import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DictionaryEntry {
  final String word;
  final String normalizedWord;
  final String definition;

  const DictionaryEntry({
    required this.word,
    required this.normalizedWord,
    required this.definition,
  });
}

class DictionaryRepository {
  static Future<List<DictionaryEntry>>? _bundledEntries;

  static Future<List<DictionaryEntry>> loadBundled({bool reload = false}) {
    if (reload || _bundledEntries == null) {
      _bundledEntries = _readBundled();
    }
    return _bundledEntries!;
  }

  static Future<List<DictionaryEntry>> _readBundled() async {
    final data = await rootBundle.load('assets/mmdict.json');
    final json = utf8.decode(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    return compute(_parseDictionary, json);
  }

  @visibleForTesting
  static List<DictionaryEntry> parseJson(String source) =>
      _parseDictionary(source);
}

List<DictionaryEntry> _parseDictionary(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! List) {
    throw const FormatException('The dictionary data must be a JSON list.');
  }

  return decoded
      .map((record) {
        if (record is! Map<String, dynamic> ||
            record['word'] is! String ||
            record['definition'] is! String) {
          throw const FormatException(
            'A dictionary entry has an invalid format.',
          );
        }

        final word = record['word'] as String;
        return DictionaryEntry(
          word: word,
          normalizedWord: word.toLowerCase(),
          definition: _htmlToText(record['definition'] as String),
        );
      })
      .toList(growable: false);
}

String _htmlToText(String html) {
  final text = html
      .replaceAll(
        RegExp(r'</(p|div|li|ul|ol|h[1-6])\s*>', caseSensitive: false),
        '\n',
      )
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");

  return text
      .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
        final codePoint = int.tryParse(match[1]!);
        return codePoint == null ? match[0]! : String.fromCharCode(codePoint);
      })
      .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
        final codePoint = int.tryParse(match[1]!, radix: 16);
        return codePoint == null ? match[0]! : String.fromCharCode(codePoint);
      })
      .replaceAll(RegExp(r'[ \t]*\n[ \t]*'), '\n')
      .replaceAll(RegExp(r'\n{2,}'), '\n')
      .trim();
}
