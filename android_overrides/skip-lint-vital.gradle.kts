
// Release builds run "lintVital" on every plugin; it crashes on some third-party
// plugins (a lint bug), so skip it. Our own code is still checked by flutter analyze.
subprojects {
    tasks.matching { it.name.startsWith("lintVital") }.configureEach { enabled = false }
}
