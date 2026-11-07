import 'package:flutter_test/flutter_test.dart';
import 'package:palimala/pali_transliteration.dart';

void main() {
  test('removes noun gender labels from spoken transliteration', () {
    expect(paliRomanToKannada('Rūpa (M)'), paliRomanToKannada('Rūpa'));
    expect(paliRomanToKannada('Citta (N)'), paliRomanToKannada('Citta'));
    expect(paliRomanToKannada('Itthī (F)'), paliRomanToKannada('Itthī'));
    expect(
      paliRomanToKannada('Buddhaṃ (masculine)'),
      paliRomanToKannada('Buddhaṃ'),
    );
  });

  test('preserves ordinary words, phrases, and punctuation', () {
    expect(paliRomanToKannada('Buddhaṃ saraṇaṃ gacchāmi'), isNotEmpty);
    expect(paliRomanToKannada('dhamma, saṅgha!'), contains(','));
  });
}
