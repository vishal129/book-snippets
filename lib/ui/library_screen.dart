import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/library_store.dart';
import '../services/pdf_importer.dart';
import '../state/app_settings.dart';
import 'reader_screen.dart';
import 'settings_sheet.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.settings});
  final AppSettings settings;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _store = LibraryStore();
  List<Book>? _books;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final books = await _store.loadBooks();
    if (mounted) setState(() => _books = books);
  }

  Future<void> _addBook() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;

    final progress = ValueNotifier<String>('Opening PDF…');
    final fraction = ValueNotifier<double?>(null);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Preparing your book'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<double?>(
                valueListenable: fraction,
                builder: (_, v, __) => LinearProgressIndicator(value: v),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<String>(
                valueListenable: progress,
                builder: (_, v, __) => Text(v),
              ),
            ],
          ),
        ),
      ),
    );

    String? error;
    String? note;
    try {
      final result = await PdfImporter().import(path, onProgress: (done, total, stage) {
        progress.value = stage;
        fraction.value = total == 0 ? null : done / total;
      });
      if (result.snippets.isEmpty) {
        error = 'No readable text found in this PDF.';
      } else {
        final book = Book(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: result.title,
          totalPages: result.totalPages,
          snippetCount: result.snippets.length,
          addedAt: DateTime.now(),
        );
        await _store.addBook(book, result.snippets);
        if (result.ocrPages > 0) {
          note = '${result.ocrPages} scanned page(s) were read with OCR; '
              'expect a few errors.';
        }
      }
    } catch (e) {
      error = 'Could not import this PDF: $e';
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // close progress dialog
    final msg = error ?? note;
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
    await _refresh();
  }

  Future<void> _open(Book book) async {
    final snippets = await _store.loadSnippets(book.id);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ReaderScreen(
        book: book,
        snippets: snippets,
        store: _store,
        settings: widget.settings,
      ),
    ));
    await _refresh();
  }

  Future<void> _confirmDelete(Book book) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove book?'),
        content: Text('"${book.title}" and your reading progress will be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) {
      await _store.deleteBook(book.id);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final books = _books;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: () => showSettingsSheet(context, widget.settings),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBook,
        icon: const Icon(Icons.upload_file),
        label: const Text('Add PDF'),
      ),
      body: books == null
          ? const Center(child: CircularProgressIndicator())
          : books.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: books.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final b = books[i];
                    return Card(
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.fromLTRB(16, 8, 4, 8),
                        title: Text(b.title,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LinearProgressIndicator(value: b.progress),
                              const SizedBox(height: 6),
                              Text('${(b.progress * 100).round()}% read  ·  '
                                  '${b.snippetCount} snippets  ·  ${b.totalPages} pages'),
                            ],
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmDelete(b),
                        ),
                        onTap: () => _open(b),
                      ),
                    );
                  },
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded,
                size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('No books yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Add a PDF and it will be split into bite-sized cards '
              'you can swipe through.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
