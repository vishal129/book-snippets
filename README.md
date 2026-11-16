# Book Snippets

Upload a PDF, get a vertical swipe feed of short cards (Inshorts-style).

## Run it

1. Install Flutter (3.35+) and Android Studio.
2. `bash setup.sh`  (creates `book_snippets_app/`, adds packages, runs the chunker tests)
3. `cd book_snippets_app && flutter run`
4. Release APK: `flutter build apk --release`

## How it works

- `services/pdf_importer.dart`: reads each page with PDFium (pdfrx). Pages with almost no
  text are rendered to an image and read with Google ML Kit OCR (Latin script).
- `services/chunker.dart`: removes page numbers and repeated headers/footers, un-hyphenates and
  joins wrapped lines, finds paragraphs and headings, splits sentences (abbreviation-aware),
  then packs them into cards of about 70 words (35 min, 110 max). Headings start a new card.
  Sentences that cross a page break are kept together.
- `services/library_store.dart`: book list in SharedPreferences, snippets as JSON per book.
- `ui/reader_screen.dart`: vertical `PageView`; tap to show/hide controls, slider to jump,
  progress saved automatically and restored on reopen.
- Tune card size in `ChunkerConfig` (target/min/max words).

## Known limits

- Everything is offline. Nothing leaves the phone.
- OCR is Latin script only. For Hindi/Devanagari switch to `TextRecognitionScript.devanagiri`.
- Two-column layouts and tables can come out in odd order.
- Books are stored as text only; the original PDF is not kept.
