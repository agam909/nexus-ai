param(
    [string]$Device = "windows",
    [string]$ApiBaseUrl = "http://localhost:8000"
)

if ($Device -eq "emulator") {
    $ApiBaseUrl = "http://10.0.2.2:8000"
}

flutter pub get
flutter run -d $Device --dart-define=API_BASE_URL=$ApiBaseUrl
