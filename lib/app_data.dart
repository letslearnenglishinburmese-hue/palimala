import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
              .map((value) => VocabItem.fromJson(_object(value, 'vocabList[]')))
              .toList(),
      dialogueList: dialogueList == null
          ? null
          : _array(dialogueList, 'dialogueList')
              .map(
                (value) =>
                    DialogueSpeaker.fromJson(_object(value, 'dialogueList[]')),
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
            (value) =>
                SubCategory.fromJson(_object(value, 'subCategories[]')),
          )
          .toList(),
    );
  }
}

final class AppDataRepository {
  AppDataRepository._();

  static const _bundledDataAsset = 'assets/pali_data.json';
  static const _manifestUrl =
      'https://raw.githubusercontent.com/your-username/your-repository/main/assets/pali_data_version.json';
  static const _cachedDataKey = 'pali_app_data_json';
  static const _cachedHashKey = 'pali_app_data_sha256';
  static const _requestTimeout = Duration(seconds: 8);

  static Future<List<MainCategory>> load() async {
    final bundledJson = await rootBundle.loadString(_bundledDataAsset);
    var currentJson = bundledJson;
    var currentData = _decodeData(bundledJson);
    final preferences = await SharedPreferences.getInstance();

    final cachedJson = preferences.getString(_cachedDataKey);
    final cachedHash = preferences.getString(_cachedHashKey);
    if (cachedJson != null &&
        cachedHash != null &&
        _sha256(utf8.encode(cachedJson)) == cachedHash) {
      currentJson = cachedJson;
      currentData = _decodeData(cachedJson);
    }

    try {
      final manifestResponse = await http
          .get(Uri.parse(_manifestUrl))
          .timeout(_requestTimeout);
      if (manifestResponse.statusCode != 200) {
        throw DataUpdateException(
          'Manifest request returned HTTP ${manifestResponse.statusCode}.',
        );
      }

      final manifestJson = jsonDecode(utf8.decode(manifestResponse.bodyBytes));
      final manifest = _object(manifestJson, 'manifest');
      final expectedHash = _stringField(manifest, 'sha256').toLowerCase();
      final dataUrl = _stringField(manifest, 'dataUrl');
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedHash)) {
        throw const FormatException('Manifest sha256 must be a SHA-256 hex digest.');
      }

      if (_sha256(utf8.encode(currentJson)) != expectedHash) {
        final dataResponse = await http
            .get(Uri.parse(dataUrl))
            .timeout(_requestTimeout);
        if (dataResponse.statusCode != 200) {
          throw DataUpdateException(
            'Data request returned HTTP ${dataResponse.statusCode}.',
          );
        }
        final downloadedHash = _sha256(dataResponse.bodyBytes);
        if (downloadedHash != expectedHash) {
          throw DataUpdateException(
            'Downloaded data SHA-256 does not match the manifest.',
          );
        }

        final downloadedJson = utf8.decode(dataResponse.bodyBytes);
        final downloadedData = _decodeData(downloadedJson);
        await preferences.setString(_cachedDataKey, downloadedJson);
        await preferences.setString(_cachedHashKey, downloadedHash);
        currentJson = downloadedJson;
        currentData = downloadedData;
      }
    } on http.ClientException catch (error) {
      debugPrint('Pāḷi data update failed: $error');
    } on TimeoutException catch (error) {
      debugPrint('Pāḷi data update timed out: $error');
    } on FormatException catch (error) {
      debugPrint('Pāḷi data update has an invalid JSON format: $error');
    } on DataUpdateException catch (error) {
      debugPrint('Pāḷi data update failed: $error');
    }

    return currentData;
  }

  static List<MainCategory> _decodeData(String source) {
    final decoded = jsonDecode(source);
    return _array(decoded, 'data')
        .map((value) => MainCategory.fromJson(_object(value, 'data[]')))
        .toList();
  }

  static String _sha256(List<int> bytes) => sha256.convert(bytes).toString();
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

IconData _iconForName(String name) => switch (name) {
  'menu_book_rounded' => Icons.menu_book_rounded,
  'directions_run_rounded' => Icons.directions_run_rounded,
  'auto_awesome_rounded' => Icons.auto_awesome_rounded,
  'speed_rounded' => Icons.speed_rounded,
  'auto_awesome_mosaic_rounded' => Icons.auto_awesome_mosaic_rounded,
  'record_voice_over_rounded' => Icons.record_voice_over_rounded,
  _ => throw FormatException('Unknown category icon "$name".'),
};
