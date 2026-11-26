import 'package:flutter/material.dart';
import '../main.dart' show AppLanguage;

class LanguageModeSwitcher extends StatelessWidget {
  final AppLanguage currentLang;
  final VoidCallback onLanguageToggle;

  const LanguageModeSwitcher({
    super.key,
    required this.currentLang,
    required this.onLanguageToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isMm = currentLang == AppLanguage.myanmar;

    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: IconButton.filledTonal(
        tooltip: isMm ? 'Switch to English' : 'မြန်မာဘာသာသို့ ပြောင်းရန်',
        icon: Icon(
          Icons.language_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
        onPressed: onLanguageToggle,
      ),
    );
  }
}
