import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'state/app_settings.dart';
import 'ui/library_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();
  final settings = await AppSettings.load();
  runApp(BookSnippetsApp(settings: settings));
}

class BookSnippetsApp extends StatelessWidget {
  const BookSnippetsApp({super.key, required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'Book Snippets',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF3F51B5),
          brightness: settings.theme.brightness,
        ),
        home: LibraryScreen(settings: settings),
      ),
    );
  }
}
