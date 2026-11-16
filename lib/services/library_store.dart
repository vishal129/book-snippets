import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';

/// Stores the book index in SharedPreferences and each book's snippets
/// as a JSON file in the app's documents directory.
class LibraryStore {
  static const _indexKey = 'books_v1';

  Future<Directory> _bookDir(String id) async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/books/$id');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<Book>> loadBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_indexKey);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List)
        .map((e) => Book.fromJson(e as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return list;
  }

  Future<void> _saveBooks(List<Book> books) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _indexKey, jsonEncode(books.map((b) => b.toJson()).toList()));
  }

  Future<void> addBook(Book book, List<Snippet> snippets) async {
    final dir = await _bookDir(book.id);
    await File('${dir.path}/snippets.json')
        .writeAsString(jsonEncode(snippets.map((s) => s.toJson()).toList()));
    final books = await loadBooks();
    books.add(book);
    await _saveBooks(books);
  }

  Future<List<Snippet>> loadSnippets(String id) async {
    final dir = await _bookDir(id);
    final raw = await File('${dir.path}/snippets.json').readAsString();
    return (jsonDecode(raw) as List)
        .map((e) => Snippet.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateProgress(String id, int index) async {
    final books = await loadBooks();
    final i = books.indexWhere((b) => b.id == id);
    if (i < 0) return;
    books[i] = books[i].copyWith(lastIndex: index);
    await _saveBooks(books);
  }

  Future<void> deleteBook(String id) async {
    final dir = await _bookDir(id);
    if (await dir.exists()) await dir.delete(recursive: true);
    final books = await loadBooks();
    books.removeWhere((b) => b.id == id);
    await _saveBooks(books);
  }
}
