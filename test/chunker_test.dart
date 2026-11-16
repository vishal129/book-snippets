import 'package:book_snippets/services/chunker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sentence =
      'The quick brown fox jumps over the lazy dog while the sun sets slowly. ';

  test('splits a long page into cards of reasonable size', () {
    final text = List.filled(40, sentence).join();
    final out = chunkBook([PageText(1, text)]);
    expect(out.length, greaterThan(3));
    for (final s in out) {
      expect(wordCount(s.text), lessThanOrEqualTo(130));
    }
  });

  test('does not lose or invent words', () {
    final text = List.filled(30, sentence).join();
    final out = chunkBook([PageText(1, text)]);
    final total = out.fold<int>(0, (a, s) => a + wordCount(s.text));
    expect(total, wordCount(text));
  });

  test('joins hyphenated line breaks and hard-wrapped lines', () {
    const text = 'This is an exam-\nple of a hard wrapped\nparagraph that ends here.';
    final out = chunkBook([const PageText(1, text)]);
    expect(out.single.text,
        'This is an example of a hard wrapped paragraph that ends here.');
  });

  test('does not split after abbreviations', () {
    const text = 'Dr. Smith went home. He slept well.';
    final out = chunkBook([const PageText(1, text)]);
    expect(out.single.text, text);
  });

  test('removes page numbers and repeated running headers', () {
    final pages = [
      for (var i = 1; i <= 10; i++)
        PageText(i, 'My Book Title\n\n${sentence * 3}\n\n$i'),
    ];
    final cleaned = stripRunningHeadersAndPageNumbers(pages);
    for (final p in cleaned) {
      expect(p.text.contains('My Book Title'), isFalse);
      expect(RegExp(r'^\d+$', multiLine: true).hasMatch(p.text), isFalse);
    }
  });

  test('sentence continuing across a page break stays together', () {
    final out = chunkBook([
      const PageText(1, 'The story continues and the hero walks slowly into the'),
      const PageText(2, 'dark forest at night. Nothing happens next.'),
    ]);
    expect(out.single.text.contains('walks slowly into the dark forest'), isTrue);
  });

  test('records the starting page of each card', () {
    final p1 = List.filled(12, sentence).join();
    final p2 = List.filled(12, sentence).join();
    final out = chunkBook([PageText(1, p1), PageText(2, p2)]);
    expect(out.first.page, 1);
    expect(out.last.page, 2);
  });
}
