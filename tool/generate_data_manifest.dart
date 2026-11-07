// Regenerates the app data files from category and subcategory source files in
// `assets/lessons/`.
//
// Run it from the project root after adding or editing any data file:
//
//     dart run tool/generate_data_manifest.dart
//
// It rewrites:
//   * assets/pali_data/<category>.json -> generated app data combining one
//     category index with its subcategory files.
//   * assets/pali_data_manifest.json  -> the per-dataset index the new app
//     fetches from GitHub. Each entry carries the file's SHA-256 so the app
//     can tell whether a dataset on device is older than the published one.
//   * assets/pali_data.json           -> legacy single-file blob, kept only so
//     already-installed builds made before the split can still detect and
//     download newer data.
//   * assets/pali_data_version.json   -> legacy manifest for those builds.
//
// The split files are the single source of truth; never edit the three
// generated files by hand.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _sourceDir = 'assets/lessons';
const _builtDir = 'assets/pali_data';
const _manifestPath = 'assets/pali_data_manifest.json';
const _legacyDataPath = 'assets/pali_data.json';
const _legacyVersionPath = 'assets/pali_data_version.json';

const _rawBase =
    'https://raw.githubusercontent.com/letslearnenglishinburmese-hue/palimala/refs/heads/main/assets';

/// Display order used by the app. Unknown files are appended alphabetically.
const _order = <String>[
  'nouns',
  'verbs',
  'adjectives',
  'adverbs',
  'particles',
  'dialogues',
];

void main() {
  final dir = Directory(_sourceDir);
  if (!dir.existsSync()) {
    stderr.writeln('Missing directory: $_sourceDir');
    exitCode = 1;
    return;
  }

  String idOf(Directory categoryDir) =>
      categoryDir.uri.pathSegments.where((segment) => segment.isNotEmpty).last;

  final categoryDirs = dir.listSync().whereType<Directory>().toList();
  final ids = categoryDirs.map(idOf).toList()
    ..sort((a, b) {
      final indexA = _order.indexOf(a);
      final indexB = _order.indexOf(b);
      return (indexA == -1 ? _order.length : indexA).compareTo(
        indexB == -1 ? _order.length : indexB,
      );
    });

  final remoteDir = '$_rawBase/${_builtDir.replaceFirst('assets/', '')}';
  final datasets = <Map<String, Object?>>[];
  final legacyCategories = <Object?>[];

  for (final id in ids) {
    final categoryDir = categoryDirs.firstWhere(
      (candidate) => idOf(candidate) == id,
    );
    final indexFile = File('${categoryDir.path}/category.json');
    if (!indexFile.existsSync()) {
      stderr.writeln('Missing category index: ${indexFile.path}');
      exitCode = 1;
      return;
    }

    final index = jsonDecode(indexFile.readAsStringSync());
    if (index is! Map<String, dynamic> || index['subCategoryFiles'] is! List) {
      stderr.writeln('${indexFile.path} must contain subCategoryFiles.');
      exitCode = 1;
      return;
    }
    final category = Map<String, dynamic>.from(index)
      ..remove('subCategoryFiles');
    category['subCategories'] = <Object?>[];
    for (final relativePath in index['subCategoryFiles'] as List<dynamic>) {
      if (relativePath is! String) {
        stderr.writeln(
          'Subcategory paths in ${indexFile.path} must be strings.',
        );
        exitCode = 1;
        return;
      }
      final subcategoryFile = File('${categoryDir.path}/$relativePath');
      if (!subcategoryFile.existsSync()) {
        stderr.writeln('Missing subcategory file: ${subcategoryFile.path}');
        exitCode = 1;
        return;
      }
      final subcategory = jsonDecode(subcategoryFile.readAsStringSync());
      if (subcategory is! Map<String, dynamic>) {
        stderr.writeln('${subcategoryFile.path} must contain a JSON object.');
        exitCode = 1;
        return;
      }
      _validateLesson(subcategory, subcategoryFile.path);
      (category['subCategories'] as List<Object?>).add(subcategory);
    }

    final encoder = const JsonEncoder.withIndent('  ');
    final bytes = utf8.encode('${encoder.convert(category)}\n');
    _write('$_builtDir/$id.json', utf8.decode(bytes));

    final digest = sha256.convert(bytes).toString();
    datasets.add({
      'id': id,
      'titleMm': category['titleMm'],
      'titleEn': category['titleEn'],
      'icon': category['icon'],
      'asset': '$_builtDir/$id.json',
      'url': '$remoteDir/$id.json',
      'sha256': digest,
      'bytes': bytes.length,
    });
    legacyCategories.add(category);

    final label = '$id.json'.padRight(20);
    final size = bytes.length.toString().padLeft(8);
    stdout.writeln('$label$size bytes  $digest');
  }

  const encoder = JsonEncoder.withIndent('  ');

  final manifest = {
    // Keep enough precision that two edits published on the same day can be
    // ordered against a cached manifest from an earlier build.
    'version': DateTime.now().toUtc().toIso8601String(),
    'datasets': datasets,
  };
  _write(_manifestPath, encoder.convert(manifest));

  // Legacy aggregate + manifest so pre-split app builds keep working.
  final legacyJson = '${encoder.convert(legacyCategories)}\n';
  _write(_legacyDataPath, legacyJson);
  final legacyDigest = sha256.convert(utf8.encode(legacyJson)).toString();
  _write(
    _legacyVersionPath,
    encoder.convert({
      'sha256': legacyDigest,
      'dataUrl': '$_rawBase/pali_data.json',
    }),
  );

  stdout.writeln('\nWrote $_manifestPath (${datasets.length} datasets).');
  stdout.writeln('Wrote $_legacyDataPath (legacy compatibility).');
  stdout.writeln('Wrote $_legacyVersionPath (legacy compatibility).');
}

void _validateLesson(Map<String, dynamic> lesson, String path) {
  final contentType = lesson['contentType'];
  if (contentType == null) return; // Existing vocabulary/dialogue format.
  if (contentType != 'story') {
    throw FormatException('$path has unsupported contentType "$contentType".');
  }
  for (final field in ['titleMm', 'titleEn']) {
    if (lesson[field] is! String || (lesson[field] as String).trim().isEmpty) {
      throw FormatException('$path requires a non-empty $field.');
    }
  }
  if (lesson['schemaVersion'] != 1) {
    throw FormatException('$path has unsupported story schemaVersion.');
  }
  if (lesson.containsKey('vocabList') || lesson.containsKey('dialogueList')) {
    throw FormatException('$path mixes story and legacy lesson content.');
  }
  final sentences = lesson['storyList'];
  if (sentences is! List || sentences.isEmpty) {
    throw FormatException(
      '$path storyList must contain at least one sentence.',
    );
  }
  const sentenceFields = ['paliMm', 'paliRoman', 'translateMm', 'translateEn'];
  for (var i = 0; i < sentences.length; i++) {
    final sentence = sentences[i];
    if (sentence is! Map<String, dynamic>) {
      throw FormatException('$path storyList[$i] must be a JSON object.');
    }
    for (final field in sentenceFields) {
      if (sentence[field] is! String ||
          (sentence[field] as String).trim().isEmpty) {
        throw FormatException(
          '$path storyList[$i] requires a non-empty $field.',
        );
      }
    }
  }
}

void _write(String path, String contents) {
  File(path).writeAsStringSync(contents);
}
