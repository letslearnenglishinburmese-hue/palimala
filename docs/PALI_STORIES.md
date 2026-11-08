# Pali story lessons

Story lessons use the existing category and dataset pipeline. The source files
live at `assets/lessons/pali_stories/`; generated and downloadable data lives at
`assets/pali_data/pali_stories.json`. No story content is included yet.

Each story subcategory must use this versioned format:

```json
{
  "contentType": "story",
  "schemaVersion": 1,
  "titleMm": "ပုံပြင်ခေါင်းစဉ်",
  "titleEn": "Story title",
  "storyList": [
    {
      "paliMm": "ပါဠိစာကြောင်း။",
      "paliRoman": "Pāḷi sentence.",
      "translateMm": "မြန်မာဘာသာပြန်။",
      "translateEn": "English translation."
    }
  ]
}
```

Each `storyList` item is one aligned sentence; keep all four text fields
together in that object. Story titles and sentence fields must be non-empty,
`storyList` must contain at least one sentence, and `schemaVersion` must be `1`.
Do not mix `storyList` with `vocabList` or `dialogueList`. Existing vocabulary
and dialogue files keep their existing formats. Story lessons show the whole
story and aligned sentence-by-sentence translations; learners can play the
complete Pāḷi reading or listen to each sentence separately.

To add another story:

1. Add its JSON file under `assets/lessons/pali_stories/subcategories/` and add
   its relative path to `assets/lessons/pali_stories/category.json`.
2. Run `dart run tool/generate_data_manifest.dart` from the project root.
3. Run `flutter analyze` and `flutter test`.
4. Publish `assets/pali_data/pali_stories.json`,
   `assets/pali_data_manifest.json`, and `assets/app_config.json` for apps that
   already support remote categories and story rendering. Publish
   `assets/pali_data.json` and `assets/pali_data_version.json` too if older
   pre-split app builds must continue receiving updates.

The app verifies each remote dataset against the SHA-256 in the manifest and
caches valid downloads for offline reading.
