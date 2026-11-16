# Windows PowerShell setup for Book Snippets.
# Run from PowerShell inside the book_snippets folder:
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1
$ErrorActionPreference = 'Stop'

function Run($exe, [string[]]$argList) {
    & $exe @argList
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $exe $($argList -join ' ')" }
}

$Here = $PSScriptRoot
$App  = Join-Path $Here 'book_snippets_app'

if (-not (Test-Path (Join-Path $Here 'lib'))) {
    throw "Run this from the unzipped book_snippets folder (the one containing lib\)."
}
if (Test-Path $App) {
    throw "$App already exists. Delete that folder and run this script again."
}

Run flutter @('create', '--org', 'com.vishal', '--project-name', 'book_snippets', '--platforms=android', $App)

Remove-Item -Recurse -Force (Join-Path $App 'lib')
Remove-Item -Force (Join-Path $App 'test\widget_test.dart') -ErrorAction SilentlyContinue
Copy-Item -Recurse (Join-Path $Here 'lib') (Join-Path $App 'lib')
Copy-Item -Recurse -Force (Join-Path $Here 'test\*') (Join-Path $App 'test')

Set-Location $App
Run flutter @('pub', 'add', 'pdfrx:2.4.7', 'file_picker', 'path_provider', 'shared_preferences', 'google_mlkit_text_recognition')

# ML Kit needs minSdk 23 or higher.
foreach ($f in @('android\app\build.gradle.kts', 'android\app\build.gradle')) {
    $p = Join-Path $App $f
    if (Test-Path $p) {
        $text = [IO.File]::ReadAllText($p)
        $text = $text -replace 'minSdk(Version)?\s*=?\s*flutter\.minSdkVersion', 'minSdk = 23'
        [IO.File]::WriteAllText($p, $text, (New-Object System.Text.UTF8Encoding($false)))
    }
}

Run flutter @('test')

Write-Host ""
Write-Host "Done. Start the emulator (or plug in your phone), then run:"
Write-Host "  cd `"$App`"; flutter run"
