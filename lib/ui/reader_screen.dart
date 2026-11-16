import 'dart:async';

import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/library_store.dart';
import '../state/app_settings.dart';
import 'settings_sheet.dart';

/// Inshorts-style reader: one snippet per full-screen card, swipe up for next.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.book,
    required this.snippets,
    required this.store,
    required this.settings,
  });

  final Book book;
  final List<Snippet> snippets;
  final LibraryStore store;
  final AppSettings settings;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late final PageController _controller;
  late int _index;
  bool _chromeVisible = true;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _index = widget.book.lastIndex.clamp(0, widget.snippets.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    widget.store.updateProgress(widget.book.id, _index);
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    setState(() => _index = i);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600),
        () => widget.store.updateProgress(widget.book.id, i));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        final theme = widget.settings.theme;
        final fg = theme.foreground;
        final total = widget.snippets.length;
        final snippet = widget.snippets[_index];

        return Scaffold(
          backgroundColor: theme.background,
          body: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _chromeVisible = !_chromeVisible),
                child: PageView.builder(
                  controller: _controller,
                  scrollDirection: Axis.vertical,
                  itemCount: total,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (_, i) => _SnippetCard(
                    snippet: widget.snippets[i],
                    fontSize: widget.settings.fontSize,
                    color: fg,
                  ),
                ),
              ),
              // Thin progress bar, always visible.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: LinearProgressIndicator(
                    value: total <= 1 ? 1 : _index / (total - 1),
                    minHeight: 3,
                    color: fg.withValues(alpha: 0.7),
                    backgroundColor: fg.withValues(alpha: 0.08),
                  ),
                ),
              ),
              _chrome(
                visible: _chromeVisible,
                alignment: Alignment.topCenter,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        BackButton(color: fg),
                        Expanded(
                          child: Text(
                            widget.book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: fg,
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.text_fields, color: fg),
                          onPressed: () =>
                              showSettingsSheet(context, widget.settings),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _chrome(
                visible: _chromeVisible,
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Slider(
                          value: _index.toDouble(),
                          min: 0,
                          max: (total - 1).clamp(1, total).toDouble(),
                          onChanged: total <= 1
                              ? null
                              : (v) => setState(() => _index = v.round()),
                          onChangeEnd: (v) => _controller.jumpToPage(v.round()),
                        ),
                        Text(
                          'Snippet ${_index + 1} of $total  ·  '
                          'page ${snippet.page} of ${widget.book.totalPages}',
                          style: TextStyle(
                              color: fg.withValues(alpha: 0.7), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chrome({
    required bool visible,
    required Alignment alignment,
    required Widget child,
  }) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: child,
        ),
      ),
    );
  }
}

class _SnippetCard extends StatelessWidget {
  const _SnippetCard({
    required this.snippet,
    required this.fontSize,
    required this.color,
  });

  final Snippet snippet;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 88, 28, 96),
      child: LayoutBuilder(
        builder: (context, box) => Center(
          // Scales text down if a big font would overflow, so a card never
          // needs its own scrolling (which would fight the vertical swipe).
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: box.maxWidth,
              child: Text(
                snippet.text,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: fontSize,
                  height: 1.55,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
