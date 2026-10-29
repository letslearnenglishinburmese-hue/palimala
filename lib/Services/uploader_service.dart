import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UploaderService {
  static Future<void> uploadJsonToFirestore(BuildContext context) async {
    try {
      final jsonString = await rootBundle.loadString('assets/lessons.json');
      final decodedJson = jsonDecode(jsonString);
      if (decodedJson is! List) {
        throw const FormatException('The lessons asset must contain a list.');
      }

      for (final lesson in decodedJson) {
        if (lesson is! Map<String, dynamic>) {
          throw const FormatException('Each lesson must be a JSON object.');
        }
        final id = lesson['id'];
        if (id == null) {
          await FirebaseFirestore.instance.collection('lessons').add(lesson);
        } else {
          await FirebaseFirestore.instance
              .collection('lessons')
              .doc(id.toString())
              .set(lesson);
        }
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploaded ${decodedJson.length} lessons.')),
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
