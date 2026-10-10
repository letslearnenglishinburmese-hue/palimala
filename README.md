# palimala

A new Flutter project.

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

The lesson content is split into one file per top-level category so it can be
edited and shipped independently:

```
assets/pali_data/
  nouns.json        # Nouns (Nāma)
  verbs.json        # Finite Verbs (Ākhyāta)
  adjectives.json   # Adjectives
  adverbs.json      # Adverbs
  particles.json    # Invariable Words & Particles (Nipāta)
  dialogues.json    # Pāḷi Dialogues
```

Each file holds a single category object with the same shape as the entries of
the old combined `assets/pali_data.json`.

`assets/pali_data_manifest.json` is the index published to GitHub. It lists,
for every data set, the raw URL and the SHA-256 of the file, so an installed app
can tell whether the copy on the device is older than the published one and let
the user download only the chapters they need.

### Publishing a data update

1. Edit the relevant file(s) under `assets/pali_data/` (and add a new file for
   a new category).
2. Regenerate the manifest (and the legacy compatibility files):

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
