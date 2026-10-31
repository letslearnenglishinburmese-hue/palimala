import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Bumped whenever the in-memory data set changes so widgets can rebuild and
/// pick up freshly downloaded chapters.
final ValueNotifier<int> appDataRevision = ValueNotifier<int>(0);

class ExampleSentence {
  final String paliMm;
  final String paliRoman;
  final String translateMm;
  final String translateEn;

  ExampleSentence({
    required this.paliMm,
    required this.paliRoman,
    required this.translateMm,
    required this.translateEn,
  });

  factory ExampleSentence.fromJson(Map<String, dynamic> json) {
    return ExampleSentence(
      paliMm: _stringField(json, 'paliMm'),
      paliRoman: _stringField(json, 'paliRoman'),
      translateMm: _stringField(json, 'translateMm'),
      translateEn: _stringField(json, 'translateEn'),
    );
  }
}

class VocabItem {
  final String paliMm;
  final String paliRoman;
  final String translateMm;
  final String translateEn;
  final ExampleSentence? example;

  VocabItem({
    required this.paliMm,
    required this.paliRoman,
    required this.translateMm,
    required this.translateEn,
    this.example,
  });

  factory VocabItem.fromJson(Map<String, dynamic> json) {
    final example = json['example'];
    return VocabItem(
      paliMm: _stringField(json, 'paliMm'),
      paliRoman: _stringField(json, 'paliRoman'),
      translateMm: _stringField(json, 'translateMm'),
      translateEn: _stringField(json, 'translateEn'),
      example: example == null
          ? null
          : ExampleSentence.fromJson(_object(example, 'example')),
    );
  }
}

class DialogueSpeaker {
  final String speakerMm;
  final String speakerEn;
  final String paliMm;
  final String paliRoman;
  final String translateMm;
  final String translateEn;

  DialogueSpeaker({
    required this.speakerMm,
    required this.speakerEn,
    required this.paliMm,
    required this.paliRoman,
    required this.translateMm,
    required this.translateEn,
  });

  factory DialogueSpeaker.fromJson(Map<String, dynamic> json) {
    return DialogueSpeaker(
      speakerMm: _stringField(json, 'speakerMm'),
      speakerEn: _stringField(json, 'speakerEn'),
      paliMm: _stringField(json, 'paliMm'),
      paliRoman: _stringField(json, 'paliRoman'),
      translateMm: _stringField(json, 'translateMm'),
      translateEn: _stringField(json, 'translateEn'),
    );
  }
}

class SubCategory {
  final String titleMm;
  final String titleEn;
  final List<VocabItem>? vocabList;
  final List<DialogueSpeaker>? dialogueList;

  SubCategory({
    required this.titleMm,
    required this.titleEn,
    this.vocabList,
    this.dialogueList,
  });

  factory SubCategory.fromJson(Map<String, dynamic> json) {
    final vocabList = json['vocabList'];
    final dialogueList = json['dialogueList'];
    return SubCategory(
      titleMm: _stringField(json, 'titleMm'),
      titleEn: _stringField(json, 'titleEn'),
      vocabList: vocabList == null
          ? null
          : _array(vocabList, 'vocabList')
                .map(
                  (value) => VocabItem.fromJson(_object(value, 'vocabList[]')),
                )
                .toList(),
      dialogueList: dialogueList == null
          ? null
          : _array(dialogueList, 'dialogueList')
                .map(
                  (value) => DialogueSpeaker.fromJson(
                    _object(value, 'dialogueList[]'),
                  ),
                )
                .toList(),
    );
  }
}

class MainCategory {
  final String titleMm;
  final String titleEn;
  final IconData icon;
  final List<SubCategory> subCategories;

  MainCategory({
    required this.titleMm,
    required this.titleEn,
    required this.icon,
    required this.subCategories,
  });

  factory MainCategory.fromJson(Map<String, dynamic> json) {
    final iconName = _stringField(json, 'icon');
    return MainCategory(
      titleMm: _stringField(json, 'titleMm'),
      titleEn: _stringField(json, 'titleEn'),
      icon: _iconForName(iconName),
      subCategories: _array(json['subCategories'], 'subCategories')
          .map(
            (value) => SubCategory.fromJson(_object(value, 'subCategories[]')),
          )
          .toList(),
    );
  }
}

/// A single downloadable chapter of the app data.
///
/// Generated data is published as one file per top-level category under
/// `assets/pali_data/` and indexed by `assets/pali_data_manifest.json`. Each
/// dataset carries its own SHA-256 so the app can tell whether the copy on
/// device is older than the one on GitHub and offer only the chapters the user
/// actually needs.
class DatasetInfo {
  final String id;
  final String titleMm;
  final String titleEn;
  final IconData icon;
  final String asset;
  final String url;
  final String sha256;
  final int bytes;

  const DatasetInfo({
    required this.id,
    required this.titleMm,
    required this.titleEn,
    required this.icon,
    required this.asset,
    required this.url,
    required this.sha256,
    required this.bytes,
  });

  factory DatasetInfo.fromJson(Map<String, dynamic> json) {
    return DatasetInfo(
      id: _stringField(json, 'id'),
      titleMm: _stringField(json, 'titleMm'),
      titleEn: _stringField(json, 'titleEn'),
      icon: _iconForName(_stringField(json, 'icon')),
      asset: _stringField(json, 'asset'),
      url: _stringField(json, 'url'),
      sha256: _stringField(json, 'sha256').toLowerCase(),
      bytes: _intField(json, 'bytes'),
    );
  }

  /// Human readable size, e.g. "142 KB".
  String get sizeLabel {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  /// First 12 characters of the published hash, shown in the download sheet.
  String get shortHash =>
      sha256.length <= 12 ? sha256 : sha256.substring(0, 12);
}

enum DatasetStatus {
  /// The copy on device matches the published hash.
  upToDate,

  /// A newer version is published on GitHub.
  updateAvailable,
}

/// Loads, caches and updates the Pāḷi data sets.
///
/// Editable category and subcategory JSON files under `assets/lessons/` are
/// loaded directly, so saving those files and rebuilding the app updates the
/// bundled lesson data without a manual generation step. Generated datasets
/// remain the baseline for the online update flow. Downloaded datasets are
/// stored in [SharedPreferences] and used when the local lesson sources have
/// not changed from that generated baseline.
final class AppDataRepository {
  AppDataRepository._();

  static const _manifestAsset = 'assets/pali_data_manifest.json';
  static const _manifestUrl =
      'https://raw.githubusercontent.com/letslearnenglishinburmese-hue/palimala/refs/heads/main/assets/pali_data_manifest.json';
  static const _cachedJsonPrefix = 'pali_dataset_json_';
  static const _cachedHashPrefix = 'pali_dataset_sha256_';
  static const _cachedManifestKey = 'pali_data_manifest_json';
  static const _autoUpdateKey = 'pali_auto_update_enabled';
  static const _requestTimeout = Duration(seconds: 8);

  static List<DatasetInfo> _datasets = const [];
  static final Map<String, String> _activeJson = <String, String>{};
  static final Map<String, String> _activeHash = <String, String>{};
  static final Map<String, String> _activeSource = <String, String>{};
  static List<MainCategory> _categories = const [];
  static bool _autoUpdate = false;
  static bool _initialized = false;

  static List<DatasetInfo> get datasets => _datasets;
  static List<MainCategory> get categories => _categories;
  static bool get autoUpdateEnabled => _autoUpdate;
  static bool get initialized => _initialized;

  static int get updatesAvailable => _datasets
      .where((dataset) => statusOf(dataset) == DatasetStatus.updateAvailable)
      .length;

  static DatasetStatus statusOf(DatasetInfo dataset) {
    if (_activeSource[dataset.id] == 'lessons' ||
        _activeHash[dataset.id] == dataset.sha256) {
      return DatasetStatus.upToDate;
    }
    return DatasetStatus.updateAvailable;
  }

  /// Whether the on-device copy came from a previous download rather than the
  /// bundled asset.
  static bool hasDownloadedCopy(DatasetInfo dataset) {
    final source = _activeSource[dataset.id];
    return source == 'cached' || source == 'downloaded';
  }

  /// Loads the bundled data and, when reachable, checks GitHub for newer
  /// datasets. Outdated datasets are downloaded automatically only when the
  /// user enabled auto-update.
  static Future<List<MainCategory>> load() async {
    final preferences = await SharedPreferences.getInstance();
    _autoUpdate = preferences.getBool(_autoUpdateKey) ?? false;
    _datasets = _parseManifest(await _fetchManifest(preferences));
    await _resolveDatasets(preferences);
    if (_autoUpdate) {
      await _downloadOutdated(preferences);
    }
    _categories = _buildCategories();
    _initialized = true;
    return _categories;
  }

  /// Loads local lesson assets without touching the network or using a
  /// downloaded dataset cache.
  static Future<List<MainCategory>> loadBundled() async {
    final preferences = await SharedPreferences.getInstance();
    _autoUpdate = preferences.getBool(_autoUpdateKey) ?? false;
    _datasets = _parseManifest(await rootBundle.loadString(_manifestAsset));
    await _resolveDatasets(preferences, preferBundled: true);
    _categories = _buildCategories();
    _initialized = true;
    return _categories;
  }

  /// Re-reads the manifest and refreshes the per-dataset status without
  /// downloading anything (unless auto-update is enabled).
  static Future<void> checkForUpdates() async {
    final preferences = await SharedPreferences.getInstance();
    _datasets = _parseManifest(await _fetchManifest(preferences));
    await _resolveDatasets(preferences);
    if (_autoUpdate) {
      await _downloadOutdated(preferences);
    }
    _categories = _buildCategories();
    _initialized = true;
    _notify();
  }

  static Future<void> setAutoUpdate(bool enabled) async {
    _autoUpdate = enabled;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_autoUpdateKey, enabled);
  }

  /// Downloads (or updates) a single dataset. Throws [DataUpdateException]
  /// when the file is unreachable or does not match the published hash.
  static Future<bool> downloadDataset(DatasetInfo dataset) async {
    final preferences = await SharedPreferences.getInstance();
    final updated = await _download(dataset, preferences);
    if (updated) _refresh();
    return updated;
  }

  /// Downloads every dataset whose published hash differs from the device
  /// copy. Returns how many datasets were updated.
  static Future<int> downloadAllUpdates() async {
    final preferences = await SharedPreferences.getInstance();
    var updated = 0;
    for (final dataset in List<DatasetInfo>.of(_datasets)) {
      if (statusOf(dataset) != DatasetStatus.updateAvailable) continue;
      try {
        if (await _download(dataset, preferences)) updated++;
      } on Object catch (error) {
        debugPrint('Updating "${dataset.id}" failed: $error');
      }
    }
    if (updated > 0) _refresh();
    return updated;
  }

  static Future<String> _fetchManifest(SharedPreferences preferences) async {
    final bundled = await rootBundle.loadString(_manifestAsset);
    try {
      final response = await http
          .get(Uri.parse(_manifestUrl))
          .timeout(_requestTimeout);
      if (response.statusCode != 200) {
        throw DataUpdateException(
          'Manifest request returned HTTP ${response.statusCode}.',
        );
      }
      final manifestJson = utf8.decode(response.bodyBytes);
      _parseManifest(manifestJson); // Validate before trusting the manifest.
      if (_manifestVersion(manifestJson).compareTo(_manifestVersion(bundled)) <
          0) {
        // GitHub can briefly lag behind a locally rebuilt app. Do not let its
        // older manifest select cached data over the newer bundled assets.
        return bundled;
      }
      await preferences.setString(_cachedManifestKey, manifestJson);
      return manifestJson;
    } on http.ClientException catch (error) {
      debugPrint('Pāḷi manifest update failed: $error');
    } on TimeoutException catch (error) {
      debugPrint('Pāḷi manifest update timed out: $error');
    } on FormatException catch (error) {
      debugPrint('Pāḷi manifest has an invalid format: $error');
    } on DataUpdateException catch (error) {
      debugPrint('Pāḷi manifest update failed: $error');
    }

    // Prefer the last manifest seen from GitHub over the bundled one: a data
    // set the user already downloaded stays "up to date" when the app starts
    // offline instead of looking older than the shipped bundle.
    final cached = preferences.getString(_cachedManifestKey);
    if (cached != null) {
      try {
        _parseManifest(cached);
        return _manifestVersion(cached).compareTo(_manifestVersion(bundled)) < 0
            ? bundled
            : cached;
      } on FormatException catch (error) {
        debugPrint('Ignoring unreadable cached manifest: $error');
      }
    }
    return bundled;
  }

  static List<DatasetInfo> _parseManifest(String source) {
    final decoded = jsonDecode(source);
    final manifest = _object(decoded, 'manifest');
    final datasets = _array(manifest['datasets'], 'datasets')
        .map((value) => DatasetInfo.fromJson(_object(value, 'datasets[]')))
        .toList();
    if (datasets.isEmpty) {
      throw const FormatException('Manifest does not list any datasets.');
    }
    for (final dataset in datasets) {
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(dataset.sha256)) {
        throw FormatException(
          'Dataset "${dataset.id}" sha256 must be a SHA-256 hex digest.',
        );
      }
      if (dataset.url.startsWith('http') == false) {
        throw FormatException('Dataset "${dataset.id}" url must be absolute.');
      }
    }
    return datasets;
  }

  static String _manifestVersion(String source) {
    final manifest = _object(jsonDecode(source), 'manifest');
    final version = manifest['version'];
    return version is String ? version : '';
  }

  static Future<void> _resolveDatasets(
    SharedPreferences preferences, {
    bool preferBundled = false,
  }) async {
    for (final dataset in _datasets) {
      final bundledJson = await rootBundle.loadString(dataset.asset);
      final bundledHash = _sha256(utf8.encode(bundledJson));
      final lessonJson = await _loadLessonDataset(dataset.id);
      final lessonHash = _sha256(utf8.encode(lessonJson));
      final cachedJson = preferences.getString('$_cachedJsonPrefix${dataset.id}');
      final cachedHash = preferences.getString('$_cachedHashPrefix${dataset.id}');
      final cachedIsValid = cachedJson != null &&
          cachedHash != null &&
          _sha256(utf8.encode(cachedJson)) == cachedHash &&
          _isReadable(cachedJson);

      // The lesson tree is the editable source of truth. If it differs from
      // the generated bundle, use it even when an older downloaded copy is
      // still cached on this device.
      if (lessonHash != bundledHash) {
        _setActive(dataset.id, lessonJson, lessonHash, 'lessons');
      } else if (preferBundled || bundledHash == dataset.sha256) {
        _setActive(dataset.id, bundledJson, bundledHash, 'bundled');
      } else if (cachedIsValid && cachedHash == dataset.sha256) {
        _setActive(dataset.id, cachedJson!, cachedHash!, 'cached');
      } else {
        _setActive(dataset.id, bundledJson, bundledHash, 'bundled');
      }
    }
  }

  static Future<String> _loadLessonDataset(String id) async {
    final indexPath = 'assets/lessons/$id/category.json';
    final index = _object(
      jsonDecode(await rootBundle.loadString(indexPath)),
      indexPath,
    );
    final relativePaths = _array(index['subCategoryFiles'], 'subCategoryFiles');
    final category = Map<String, dynamic>.from(index)
      ..remove('subCategoryFiles');
    final subCategories = <Map<String, dynamic>>[];
    for (final value in relativePaths) {
      if (value is! String || value.startsWith('/') || value.contains('..')) {
        throw FormatException('Invalid subcategory path in $indexPath.');
      }
      final path = 'assets/lessons/$id/$value';
      subCategories.add(
        _object(jsonDecode(await rootBundle.loadString(path)), path),
      );
    }
    category['subCategories'] = subCategories;
    const encoder = JsonEncoder.withIndent('  ');
    return '${encoder.convert(category)}\n';
  }

  static bool _isReadable(String source) {
    try {
      MainCategory.fromJson(_object(jsonDecode(source), 'dataset'));
      return true;
    } on FormatException catch (error) {
      debugPrint('Ignoring unreadable cached data set: $error');
      return false;
    }
  }

  static Future<void> _downloadOutdated(SharedPreferences preferences) async {
    for (final dataset in List<DatasetInfo>.of(_datasets)) {
      if (statusOf(dataset) != DatasetStatus.updateAvailable) continue;
      try {
        await _download(dataset, preferences);
      } on Object catch (error) {
        debugPrint('Auto-update of "${dataset.id}" failed: $error');
      }
    }
  }

  static Future<bool> _download(
    DatasetInfo dataset,
    SharedPreferences preferences,
  ) async {
    if (statusOf(dataset) == DatasetStatus.upToDate) return false;
    final response = await http
        .get(Uri.parse(dataset.url))
        .timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw DataUpdateException(
        '"${dataset.id}" request returned HTTP ${response.statusCode}.',
      );
    }
    final bytes = response.bodyBytes;
    final downloadedHash = _sha256(bytes);
    if (downloadedHash != dataset.sha256) {
      throw DataUpdateException(
        '"${dataset.id}" SHA-256 does not match the manifest.',
      );
    }
    final downloadedJson = utf8.decode(bytes);
    MainCategory.fromJson(_object(jsonDecode(downloadedJson), 'dataset'));
    await preferences.setString('$_cachedJsonPrefix${dataset.id}', downloadedJson);
    await preferences.setString('$_cachedHashPrefix${dataset.id}', downloadedHash);
    _setActive(dataset.id, downloadedJson, downloadedHash, 'downloaded');
    return true;
  }

  static void _setActive(String id, String json, String hash, String source) {
    _activeJson[id] = json;
    _activeHash[id] = hash;
    _activeSource[id] = source;
  }

  static List<MainCategory> _buildCategories() => [
    for (final dataset in _datasets)
      if (_activeJson[dataset.id] != null)
        MainCategory.fromJson(_object(jsonDecode(_activeJson[dataset.id]!), 'dataset')),
  ];

  static String _sha256(List<int> bytes) => sha256.convert(bytes).toString();

  /// Rebuilds the in-memory categories after a data set changes so the UI
  /// switches over to the freshly downloaded chapters immediately.
  static void _refresh() {
    _categories = _buildCategories();
    _notify();
  }

  static void _notify() => appDataRevision.value++;
}

class DataUpdateException implements Exception {
  final String message;

  const DataUpdateException(this.message);

  @override
  String toString() => message;
}

Map<String, dynamic> _object(Object? value, String field) {
  if (value is! Map) {
    throw FormatException('$field must be a JSON object.');
  }
  return Map<String, dynamic>.from(value);
}

List<dynamic> _array(Object? value, String field) {
  if (value is! List) {
    throw FormatException('$field must be a JSON array.');
  }
  return value;
}

String _stringField(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! String) {
    throw FormatException('$field must be a string.');
  }
  return value;
}

int _intField(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw FormatException('$field must be an integer.');
}

IconData _iconForName(String name) => switch (name) {
  'menu_book_rounded' => Icons.menu_book_rounded,
  'directions_run_rounded' => Icons.directions_run_rounded,
  'auto_awesome_rounded' => Icons.auto_awesome_rounded,
  'speed_rounded' => Icons.speed_rounded,
  'auto_awesome_mosaic_rounded' => Icons.auto_awesome_mosaic_rounded,
  'record_voice_over_rounded' => Icons.record_voice_over_rounded,
  _ => throw FormatException('Unknown category icon "$name".'),
};
