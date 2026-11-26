import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_data.dart';

class WordShareDialog extends StatefulWidget {
  final VocabItem word;
  final bool isMyanmar;
  final String? categoryTitle;

  const WordShareDialog({
    super.key,
    required this.word,
    required this.isMyanmar,
    this.categoryTitle,
  });

  String get shareText {
    final buffer = StringBuffer();
    buffer.writeln('🌟 ယနေ့လေ့လာရန် ပါဠိစကားလုံး (Pāḷi Word of the Day)');
    buffer.writeln('${word.paliMm} (${word.paliRoman})');
    buffer.writeln('အဓိပ္ပာယ်: ${word.translateMm} / ${word.translateEn}');
    if (word.example != null) {
      buffer.writeln('\n📖 သာဓကဝါကျ:');
      buffer.writeln('${word.example!.paliMm} (${word.example!.paliRoman})');
      buffer.writeln(
        '${word.example!.translateMm} / ${word.example!.translateEn}',
      );
    }
    buffer.writeln('\n— Pali Bank အက်ပ်ဖြင့် လေ့လာပါ');
    return buffer.toString();
  }

  @override
  State<WordShareDialog> createState() => _WordShareDialogState();
}

class _WordShareDialogState extends State<WordShareDialog> {
  final GlobalKey _cardBoundaryKey = GlobalKey();
  bool _isSharingImage = false;

  String get _shareText => widget.shareText;

  Future<void> _shareAsImage(BuildContext context) async {
    if (_isSharingImage) return;
    setState(() => _isSharingImage = true);
    try {
      final boundary =
          _cardBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Card boundary is not ready');
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Failed to encode PNG bytes');
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/pali_bank_word.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: _shareText,
        ),
      );
    } catch (_) {
      if (context.mounted) {
        await _copyToClipboard(context, fallbackNotice: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSharingImage = false);
      }
    }
  }

  Future<void> _shareToViber(BuildContext context) async {
    final uri = Uri.parse(
      'viber://forward?text=${Uri.encodeComponent(_shareText)}',
    );
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!context.mounted) return;
      if (!launched) {
        await _copyToClipboard(context, fallbackNotice: true);
      }
    } catch (_) {
      if (context.mounted) {
        await _copyToClipboard(context, fallbackNotice: true);
      }
    }
  }

  Future<void> _shareToTelegram(BuildContext context) async {
    final uri = Uri.parse(
      'https://t.me/share/url?text=${Uri.encodeComponent(_shareText)}',
    );
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!context.mounted) return;
      if (!launched) {
        await _copyToClipboard(context, fallbackNotice: true);
      }
    } catch (_) {
      if (context.mounted) {
        await _copyToClipboard(context, fallbackNotice: true);
      }
    }
  }

  Future<void> _copyToClipboard(
    BuildContext context, {
    bool fallbackNotice = false,
  }) async {
    await Clipboard.setData(ClipboardData(text: _shareText));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          fallbackNotice
              ? (widget.isMyanmar
                    ? 'အက်ပ်သို့ တိုက်ရိုက်မရောက်နိုင်ပါ။ စာသားကို Clipboard တွင် ကူးယူပြီးပါပြီ။'
                    : 'App unavailable. Text copied to clipboard!')
              : (widget.isMyanmar
                    ? 'စကားလုံး စာသားကို ကူးယူပြီးပါပြီ'
                    : 'Copied to clipboard!'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMm = widget.isMyanmar;
    final word = widget.word;
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Beautiful Shareable Image Card wrapped in RepaintBoundary for PNG export
              Padding(
                padding: const EdgeInsets.all(16),
                child: RepaintBoundary(
                  key: _cardBoundaryKey,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF762319),
                          Color(0xFF9A4329),
                          Color(0xFFB96A36),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF762319).withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              'assets/pali_bank_logo.png',
                              width: 38,
                              height: 38,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isMm
                                        ? 'Pali Bank · နေ့စဉ်ဝေါဟာရ'
                                        : 'Pali Bank · Word of the Day',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (widget.categoryTitle != null)
                                    Text(
                                      widget.categoryTitle!,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          word.paliMm,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          word.paliRoman,
                          style: TextStyle(
                            color: Colors.amber.shade200,
                            fontSize: 18,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                word.translateMm,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                word.translateEn,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (word.example != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            '“${word.example!.paliMm}”',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            word.example!.translateMm,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Pali Bank',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 10,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isMm
                          ? 'လူမှုကွန်ရက်သို့ မျှဝေရန်'
                          : 'Share to Social Media',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _isSharingImage
                          ? null
                          : () => _shareAsImage(context),
                      icon: _isSharingImage
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.image_outlined, size: 18),
                      label: Text(
                        isMm ? 'ပုံရိပ်အဖြစ် မျှဝေမည်' : 'Share as Image',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => _copyToClipboard(context),
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: Text(isMm ? 'ကူးယူရန်' : 'Copy'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => _shareToViber(context),
                            icon: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 18,
                            ),
                            label: const Text('Viber'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => _shareToTelegram(context),
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: const Text('Telegram'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(isMm ? 'ပိတ်ပါ' : 'Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
