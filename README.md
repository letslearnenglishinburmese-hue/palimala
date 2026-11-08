# PaliMala

PaliMala is a bilingual learning app for studying Pāḷi through structured
lessons, topic-based vocabulary, grammar and particles, everyday dialogues,
and Pāḷi stories. Learners can search words, save vocabulary, listen to
pronunciation, and practice with lesson quizzes. Lessons are available offline,
with optional GitHub-based data updates in Settings.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Pāḷi data files

The editable lesson source is organized by category, with a separate JSON file
for each subcategory:

```
assets/lessons/
  nouns/
    category.json
    subcategories/
      01-*.json
      02-*.json
  verbs/
    category.json
    subcategories/
      01-*.json
  conversation_patterns/
    category.json
    subcategories/
      01-*.json
  ...
```

`category.json` stores the category title, icon, and ordered list of its
subcategory file paths. Each subcategory file holds that subcategory's words or
dialogues or conversation patterns. Conversation-pattern lessons can include
paired Burmese and English explanations, with each example's pronunciation
available through its audio button. The app bundles and reads these lesson
source files directly at startup, so edits in `assets/lessons/` are visible
after a full app restart or
rebuild, even when a device has an older data set cached. Generated category
files in `assets/pali_data/` remain the baseline for the online update system;
edit the lesson source files rather than these generated copies.

`assets/pali_data_manifest.json` is the index published to GitHub. It lists,
for every data set, the raw URL and the SHA-256 of the file, so an installed app
can tell whether the copy on the device is older than the published one and let
the user download only the chapters they need.

### Publishing a data update

1. Edit a category's `category.json` or the relevant file under its
   `subcategories/` directory. Add its path to `subCategoryFiles` when adding a
   subcategory. Restart or rebuild the app to see local edits.
2. To publish changes for existing installs, regenerate the app data, manifest,
   and legacy compatibility files:

   ```sh
   dart run tool/generate_data_manifest.dart
   ```

3. Commit and push. The manifest now advertises the new hashes, so existing
   installs will offer the update. The app checks the manifest on launch, and
   downloads automatically when the user enabled **Settings → Auto update**.

Do not edit `assets/pali_data_manifest.json`, `assets/pali_data.json` or
`assets/pali_data_version.json` by hand — they are generated.

### Legacy compatibility

App builds made before the split still read `assets/pali_data.json` and
`assets/pali_data_version.json`. The generator keeps both files up to date from
the split sources so those older builds can still detect and download new data.
They are intentionally **not** bundled by the current app (see `pubspec.yaml`).
