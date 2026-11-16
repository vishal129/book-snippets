import '../models/book.dart';

/// Raw text of one PDF page.
class PageText {
  const PageText(this.page, this.text);
  final int page;
  final String text;
}

class ChunkerConfig {
  const ChunkerConfig({
    this.targetWords = 70,
    this.minWords = 35,
    this.maxWords = 110,
  });

  /// A card is closed once it reaches this many words.
  final int targetWords;

  /// Paragraph breaks only close a card once it has at least this many words.
  final int minWords;

  /// Hard ceiling (a single sentence longer than this is split).
  final int maxWords;
}

class _Sentence {
  _Sentence(this.text, this.page, {this.paraStart = false, this.heading = false});
  String text;
  int page;
  bool paraStart;
  bool heading;
}

final _terminal = RegExp(r'[.!?।…]["”’)\]]*$');
final _pageNumberLine =
    RegExp(r'^\s*(page\s+)?\d{1,4}(\s*(of|/)\s*\d{1,4})?\s*$', caseSensitive: false);
final _boundary =
    RegExp(r'(?<=[.!?।…]["”’)\]]?)\s+(?=["“‘(\[]?[^\sa-z])');
final _abbrev = RegExp(
    r'(\b(Mr|Mrs|Ms|Dr|Prof|Sr|Jr|St|vs|etc|No|Fig|Rs|Inc|Ltd|Co|Vol|Ch|pp|approx)|\b[A-Z]|e\.g|i\.e)\.$',
    caseSensitive: false);

int wordCount(String s) =>
    s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;

/// Turns page texts into short, readable snippets.
List<Snippet> chunkBook(List<PageText> rawPages,
    {ChunkerConfig config = const ChunkerConfig()}) {
  final pages = stripRunningHeadersAndPageNumbers(rawPages);
  final sentences = <_Sentence>[];
  var prevPageOpenEnded = false;

  for (final p in pages) {
    final paras = _paragraphs(p.text);
    if (paras.isEmpty) continue;

    // A page that ends mid-sentence continues on the next page.
    var carry = false;
    if (prevPageOpenEnded && sentences.isNotEmpty && !sentences.last.heading) {
      carry = true;
    }

    for (var i = 0; i < paras.length; i++) {
      var text = paras[i];
      var paraStart = true;
      var page = p.page;
      if (i == 0 && carry) {
        final last = sentences.removeLast();
        text = '${last.text} $text';
        paraStart = last.paraStart;
        page = last.page;
      }
      final isHeading = wordCount(text) <= 8 && !_terminal.hasMatch(text);
      if (isHeading) {
        sentences.add(_Sentence(text, page, paraStart: true, heading: true));
        continue;
      }
      final parts = _splitSentences(text, config.maxWords, config.targetWords);
      for (var j = 0; j < parts.length; j++) {
        sentences.add(_Sentence(parts[j], page, paraStart: paraStart && j == 0));
      }
    }

    final last = sentences.isEmpty ? null : sentences.last;
    prevPageOpenEnded =
        last != null && !last.heading && !_terminal.hasMatch(last.text);
  }

  return _pack(sentences, config);
}

List<Snippet> _pack(List<_Sentence> sentences, ChunkerConfig c) {
  final out = <Snippet>[];
  final buf = StringBuffer();
  var words = 0;
  var startPage = 1;
  var prevWasHeading = false;

  void flush() {
    final t = buf.toString().trim();
    if (t.isNotEmpty) out.add(Snippet(t, startPage));
    buf.clear();
    words = 0;
  }

  for (final s in sentences) {
    final w = wordCount(s.text);
    if (words > 0) {
      final paraBreak = s.paraStart && words >= c.minWords && !prevWasHeading;
      if (s.heading || paraBreak || words >= c.targetWords || words + w > c.maxWords) {
        // A heading always starts a new card so it stays with what follows.
        flush();
      }
    }
    if (words == 0) startPage = s.page;
    if (buf.isNotEmpty) buf.write(s.paraStart ? '\n\n' : ' ');
    buf.write(s.text);
    words += w;
    prevWasHeading = s.heading;
  }
  flush();

  // Merge a tiny trailing card into the previous one.
  if (out.length > 1 && wordCount(out.last.text) < 20) {
    final last = out.removeLast();
    final prev = out.removeLast();
    out.add(Snippet('${prev.text} ${last.text}', prev.page));
  }
  return out;
}

/// Splits text into paragraphs, joining hard-wrapped lines.
List<String> _paragraphs(String raw) {
  var text = raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('­', '')
      .replaceAllMapped(RegExp(r'(\w)-\n(\w)'), (m) => '${m[1]}${m[2]}');
  final lines = text.split('\n').map((l) => l.trim()).toList();
  var maxLen = 0;
  for (final l in lines) {
    if (l.length > maxLen) maxLen = l.length;
  }

  final paras = <String>[];
  final cur = StringBuffer();
  void end() {
    final t = cur.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isNotEmpty) paras.add(t);
    cur.clear();
  }

  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (l.isEmpty) {
      end();
      continue;
    }
    if (cur.isNotEmpty) cur.write(' ');
    cur.write(l);
    final shortLine = l.length < maxLen * 0.7;
    final endsSentence = _terminal.hasMatch(l);
    final looksLikeHeading = l.length < maxLen * 0.5 && wordCount(l) <= 8 && !endsSentence;
    if ((shortLine && endsSentence) || looksLikeHeading) end();
  }
  end();
  return paras;
}

List<String> _splitSentences(String para, int maxWords, int targetWords) {
  final raw = para.split(_boundary);
  final merged = <String>[];
  for (final s in raw) {
    if (merged.isNotEmpty && _abbrev.hasMatch(merged.last)) {
      merged[merged.length - 1] = '${merged.last} $s';
    } else {
      merged.add(s);
    }
  }
  final out = <String>[];
  for (final s in merged) {
    out.addAll(_splitLong(s, maxWords, targetWords));
  }
  return out;
}

/// Splits an over-long sentence near commas/semicolons.
List<String> _splitLong(String s, int maxWords, int targetWords) {
  final words = s.trim().split(RegExp(r'\s+'));
  if (words.length <= maxWords) return [s.trim()];
  final out = <String>[];
  var start = 0;
  while (words.length - start > maxWords) {
    var cut = start + targetWords;
    for (var i = start + targetWords; i > start + targetWords ~/ 2; i--) {
      final w = words[i - 1];
      if (w.endsWith(',') || w.endsWith(';') || w.endsWith(':')) {
        cut = i;
        break;
      }
    }
    out.add(words.sublist(start, cut).join(' '));
    start = cut;
  }
  out.add(words.sublist(start).join(' '));
  return out;
}

/// Removes page numbers and repeated running headers/footers.
List<PageText> stripRunningHeadersAndPageNumbers(List<PageText> pages) {
  String key(String l) => l.trim().toLowerCase().replaceAll(RegExp(r'\d+'), '#');

  // Indices of the first/last three non-empty lines of a page.
  Set<int> edgeIndices(List<String> lines) {
    final nonEmpty = <int>[];
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().isNotEmpty) nonEmpty.add(i);
    }
    return {
      ...nonEmpty.take(3),
      ...nonEmpty.skip(nonEmpty.length > 3 ? nonEmpty.length - 3 : 0),
    };
  }

  final counts = <String, int>{};
  final split = <List<String>>[];
  for (final p in pages) {
    final lines = p.text.split('\n');
    split.add(lines);
    final seen = <String>{};
    for (final i in edgeIndices(lines)) {
      final l = lines[i].trim();
      if (l.length >= 3 && l.length <= 60) seen.add(key(l));
    }
    for (final k in seen) {
      counts[k] = (counts[k] ?? 0) + 1;
    }
  }
  final threshold = pages.length >= 8 ? (pages.length * 0.25).ceil() : 1 << 30;

  final out = <PageText>[];
  for (var n = 0; n < pages.length; n++) {
    final lines = split[n];
    final edges = edgeIndices(lines);
    final kept = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (edges.contains(i) && l.trim().isNotEmpty) {
        if (_pageNumberLine.hasMatch(l)) continue;
        if (l.trim().length <= 60 && (counts[key(l)] ?? 0) >= threshold) continue;
      }
      kept.add(l);
    }
    out.add(PageText(pages[n].page, kept.join('\n')));
  }
  return out;
}
