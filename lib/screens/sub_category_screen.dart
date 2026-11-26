import 'package:flutter/material.dart';
import '../app_data.dart';
import '../main.dart' show AppLanguage;
import '../widgets/language_mode_switcher.dart';
import 'detail_content_screen.dart';

// SubCategory Grid Screen
class SubCategoryScreen extends StatefulWidget {
  final MainCategory category;
  final AppLanguage currentLang;
  final VoidCallback onLanguageToggle;
  final Set<String> savedWords;
  final ValueChanged<VocabItem> onSavedWordToggle;

  const SubCategoryScreen({
    super.key,
    required this.category,
    required this.currentLang,
    required this.onLanguageToggle,
    required this.savedWords,
    required this.onSavedWordToggle,
  });

  @override
  State<SubCategoryScreen> createState() => _SubCategoryScreenState();
}

class _SubCategoryScreenState extends State<SubCategoryScreen> {
  late AppLanguage _currentLang;

  @override
  void initState() {
    super.initState();
    _currentLang = widget.currentLang;
  }

  void _toggleLanguage() {
    setState(() {
      _currentLang = _currentLang == AppLanguage.myanmar
          ? AppLanguage.english
          : AppLanguage.myanmar;
    });
    widget.onLanguageToggle();
  }

  IconData _iconForSubCategory(SubCategory subCat) {
    final text = subCat.titleEn.toLowerCase();
    if (text.contains('relatives') || text.contains('family')) {
      return Icons.family_restroom_rounded;
    }
    if (text.contains('color')) return Icons.palette_rounded;
    if (text.contains('classroom') || text.contains('school')) {
      return Icons.school_rounded;
    }
    if (text.contains('aquatic')) return Icons.water_rounded;
    if (text.contains('land') || text.contains('animal')) {
      return Icons.pets_rounded;
    }
    if (text.contains('bird') || text.contains('flying')) {
      return Icons.flutter_dash_rounded;
    }
    if (text.contains('apparel') ||
        text.contains('cloth') ||
        text.contains('accessor')) {
      return Icons.checkroom_rounded;
    }
    if (text.contains('food') || text.contains('drink')) {
      return Icons.restaurant_rounded;
    }
    if (text.contains('fruit')) return Icons.eco_rounded;
    if (text.contains('tree') || text.contains('plant')) {
      return Icons.park_rounded;
    }
    if (text.contains('body')) return Icons.accessibility_new_rounded;
    if (text.contains('household')) return Icons.kitchen_rounded;
    if (text.contains('weather') || text.contains('nature')) {
      return Icons.wb_sunny_rounded;
    }
    if (text.contains('place') ||
        text.contains('town') ||
        text.contains('village')) {
      return Icons.location_city_rounded;
    }
    if (text.contains('time') || text.contains('duration')) {
      return Icons.schedule_rounded;
    }
    if (text.contains('day') || text.contains('week')) {
      return Icons.calendar_today_rounded;
    }
    if (text.contains('season')) return Icons.ac_unit_rounded;
    if (text.contains('occupation') || text.contains('people')) {
      return Icons.work_outline_rounded;
    }
    if (text.contains('disease')) return Icons.medical_services_outlined;
    if (text.contains('house')) return Icons.home_outlined;
    if (text.contains('furniture')) return Icons.chair_rounded;
    if (subCat.story != null) return Icons.auto_stories_rounded;
    if (subCat.dialogueList != null) return Icons.record_voice_over_rounded;
    return widget.category.icon;
  }

  @override
  Widget build(BuildContext context) {
    final isMm = _currentLang == AppLanguage.myanmar;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isMm ? widget.category.titleMm : widget.category.titleEn),
        actions: [
          LanguageModeSwitcher(
            currentLang: _currentLang,
            onLanguageToggle: _toggleLanguage,
          ),
        ],
      ),
      body: widget.category.subCategories.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 48,
                      color: colors.secondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isMm
                          ? 'ဤအမျိုးအစားတွင် သင်ခန်းစာ မရှိသေးပါ။'
                          : 'No lessons in this category yet.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: widget.category.subCategories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (context, index) {
                final subCat = widget.category.subCategories[index];
                final icon = _iconForSubCategory(subCat);
                return Card(
                  margin: EdgeInsets.zero,
                  elevation: 1.5,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: colors.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailContentScreen(
                            subCategory: subCat,
                            currentLang: _currentLang,
                            onLanguageToggle: _toggleLanguage,
                            savedWords: widget.savedWords,
                            onSavedWordToggle: widget.onSavedWordToggle,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: colors.secondaryContainer.withValues(
                                alpha: 0.75,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              icon,
                              size: 26,
                              color: colors.onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isMm ? subCat.titleMm : subCat.titleEn,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
