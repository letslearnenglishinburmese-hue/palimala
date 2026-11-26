import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UploaderService {
  static Future<void> uploadJsonToFirestore(BuildContext context) async {
    try {
      final manifestJson = await rootBundle.loadString(
        'assets/pali_data_manifest.json',
      );
      final manifest = jsonDecode(manifestJson);
      if (manifest is! Map<String, dynamic> || manifest['datasets'] is! List) {
        throw const FormatException('The data manifest is invalid.');
      }

      final datasets = manifest['datasets'] as List<dynamic>;
      for (final dataset in datasets) {
        if (dataset is! Map<String, dynamic> || dataset['asset'] is! String) {
          throw const FormatException('A data manifest entry is invalid.');
        }
        final categoryJson = await rootBundle.loadString(
          dataset['asset'] as String,
        );
        final category = jsonDecode(categoryJson);
        if (category is! Map<String, dynamic>) {
          throw const FormatException(
            'Each category file must contain an object.',
          );
        }
        await FirebaseFirestore.instance.collection('lessons').add(category);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploaded ${datasets.length} lessons.')),
      );
    } on Object catch (error) {
      debugPrint('Failed to upload lessons to Firestore: $error');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload lessons: $error')),
      );
    }
  }
}
