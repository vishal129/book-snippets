#!/usr/bin/env bash
# Creates the Android project shell, drops in our code, adds dependencies.
# Requires: Flutter SDK (3.35+), Android SDK / Android Studio.
set -euo pipefail

# Folder this script lives in (works whether run with bash, sourced, or pasted).
SCRIPT="${BASH_SOURCE[0]:-}"
if [ -n "$SCRIPT" ] && [ -f "$SCRIPT" ]; then
  HERE="$(cd -- "$(dirname -- "$SCRIPT")" && pwd)"
else
  HERE="$(pwd)"
fi
if [ ! -d "$HERE/lib" ]; then
  echo "Run this from inside the unzipped book_snippets folder (the one containing lib/)." >&2
  exit 1
fi
APP="$HERE/book_snippets_app"

flutter create --org com.vishal --project-name book_snippets --platforms=android "$APP"

rm -rf "$APP/lib" "$APP/test/widget_test.dart"
cp -r "$HERE/lib" "$APP/lib"
cp -r "$HERE/test/." "$APP/test/"

cd "$APP"
flutter pub add pdfrx:2.4.7 file_picker path_provider shared_preferences google_mlkit_text_recognition

# ML Kit needs a higher minSdk than Flutter's default.
for f in android/app/build.gradle.kts android/app/build.gradle; do
  [ -f "$f" ] && sed -i -E 's/minSdk(Version)? ?=? ?flutter\.minSdkVersion/minSdk = 23/' "$f"
done

flutter test
echo
echo "Done. Connect a phone (USB debugging) or start an emulator, then:"
echo "  cd $APP && flutter run"
