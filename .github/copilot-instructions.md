# Copilot instructions

## Build, test, and lint

Run these commands from the repository root:

```sh
flutter pub get
flutter analyze
flutter test
```

Run one test by matching its `test`/`testWidgets` description:

```sh
flutter test test/widget_test.dart --plain-name "Dialogue chapters provide a working practice exercise"
```

Use `flutter run -d chrome` to run the web app locally and `flutter build web` to build it. Linting is provided by `flutter_lints` through `analysis_options.yaml`; `flutter analyze` is the project lint and static-analysis command.

## Architecture

- This is a Flutter Pāḷi-learning app. The main implementation and learning content currently live together in `lib/main.dart`.
- `PaliLearningApp` owns app-wide state: selected bottom-navigation tab, Myanmar/English language, text scale, theme, and saved vocabulary. It persists saved Pāḷi words with `SharedPreferences` under `saved_pali_words`, then passes state and callbacks down to `HomeScreen` and its routes.
- The learning content is a hierarchy: `appData` contains `MainCategory` values; each has `SubCategory` values with either `vocabList` (`VocabItem`) or `dialogueList` (`DialogueSpeaker`). `DetailContentScreen` renders a subcategory, and its practice quiz uses that subcategory's own vocabulary or dialogue entries.
- The app supports web as well as Flutter mobile targets. Dependencies are Flutter, `flutter_tts`, and `shared_preferences`; bundled logo and fonts are registered in `pubspec.yaml`.
- `test/widget_test.dart` covers both content data and user-visible navigation/flows, including quizzes, language switching, search, saved words, and settings.

## Repository-specific conventions

- Keep Burmese and English labels paired wherever user-facing text is added or changed. UI language is represented by `AppLanguage`; content models likewise keep `titleMm`/`titleEn` and paired translation fields.
- Treat `appData` as the source of truth for learning content. When changing a chapter's material, update its model entry rather than adding duplicate screen-only data. Existing content tests check exact category/word counts and duplicate Pāḷi romanizations, so adjust those assertions when intentionally changing the curriculum.
- Preserve the existing ownership flow for app-wide state: screens receive the current value and callback from `PaliLearningApp`; saved-word changes are persisted through the root callback.
- Keep chapter practice scoped to its selected `SubCategory`. Vocabulary chapters use `vocabList`; dialogue chapters adapt their dialogue entries for quiz questions.
- The app theme currently uses the system `sans-serif` family; `GentiumPlus` is explicitly used for the Pāḷimālā Drawer wordmark. Bundled `Pyidaungsu` and `SourceSans3` fonts are registered in `pubspec.yaml`. Add new images/fonts to the Flutter asset/font declarations there before referencing them.
- Widget tests initialize the real app and exercise navigation; use `SharedPreferences.setMockInitialValues({})` in tests that read/write saved-word preferences.
