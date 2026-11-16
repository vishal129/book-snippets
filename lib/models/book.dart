class Snippet {
  const Snippet(this.text, this.page);

  final String text;

  /// 1-based PDF page the snippet starts on.
  final int page;

  Map<String, dynamic> toJson() => {'t': text, 'p': page};

  factory Snippet.fromJson(Map<String, dynamic> j) =>
      Snippet(j['t'] as String, j['p'] as int);
}

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.totalPages,
    required this.snippetCount,
    required this.addedAt,
    this.lastIndex = 0,
  });

  final String id;
  final String title;
  final int totalPages;
  final int snippetCount;
  final DateTime addedAt;

  /// Index of the snippet the reader was last on.
  final int lastIndex;

  double get progress =>
      snippetCount <= 1 ? 0 : (lastIndex / (snippetCount - 1)).clamp(0.0, 1.0);

  Book copyWith({int? lastIndex}) => Book(
        id: id,
        title: title,
        totalPages: totalPages,
        snippetCount: snippetCount,
        addedAt: addedAt,
        lastIndex: lastIndex ?? this.lastIndex,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'totalPages': totalPages,
        'snippetCount': snippetCount,
        'addedAt': addedAt.toIso8601String(),
        'lastIndex': lastIndex,
      };

  factory Book.fromJson(Map<String, dynamic> j) => Book(
        id: j['id'] as String,
        title: j['title'] as String,
        totalPages: j['totalPages'] as int,
        snippetCount: j['snippetCount'] as int,
        addedAt: DateTime.parse(j['addedAt'] as String),
        lastIndex: (j['lastIndex'] as int?) ?? 0,
      );
}
