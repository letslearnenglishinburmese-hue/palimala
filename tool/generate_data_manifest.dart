// Regenerates the data distribution files from the split per-category
// source files in `assets/pali_data/`.
//
// Run it from the project root after adding or editing any data file:
//
//     dart run tool/generate_data_manifest.dart
//
// It rewrites:
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

const _dataDir = 'assets/pali_data';
const _manifestPath = 'assets/pali_data_manifest.json';
const _legacyDataPath = 'assets/pali_data.json';
const _legacyVersionPath = 'assets/pali_data_version.json';

const _rawBase =
    'https://raw.githubusercontent.com/letslearnenglishinburmese-hue/'
    'palimala/refs/heads/main/assets';

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
  final dir = Directory(_dataDir);
  if (!dir.existsSync()) {
    stderr.writeln('Missing directory: $_dataDir');
    exitCode = 1;
    return;
  }

  String idOf(File file) =>
      file.uri.pathSegments.last.replaceAll(RegExp(r'\.json$'), '');

  final files = dir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.json'))
      .toList();
  final ids = files.map(idOf).toList()
    ..sort((a, b) {
      final indexA = _order.indexOf(a);
      final indexB = _order.indexOf(b);
      return (indexA == -1 ? _order.length : indexA).compareTo(
        indexB == -1 ? _order.length : indexB,
      );
    });

  final remoteDir = '$_rawBase/${_dataDir.replaceFirst('assets/', '')}';
  final datasets = <Map<String, Object?>>[];
  final legacyCategories = <Object?>[];

  for (final id in ids) {
    final file = files.firstWhere((candidate) => idOf(candidate) == id);
    final bytes = file.readAsBytesSync();
    final category = jsonDecode(utf8.decode(bytes));
    if (category is! Map<String, dynamic>) {
      stderr.writeln('${file.path} must contain a JSON object.');
      exitCode = 1;
      return;
    }

    final digest = sha256.convert(bytes).toString();
    datasets.add({
      'id': id,
      'titleMm': category['titleMm'],
      'titleEn': category['titleEn'],
      'icon': category['icon'],
      'asset': '$_dataDir/$id.json',
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
    'version': DateTime.now().toUtc().toIso8601String().substring(0, 10),
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

void _write(String path, String contents) {
  File(path).writeAsStringSync(contents);
}
