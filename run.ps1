$port = 8080
$process = netstat -ano | Select-String ":$port " | Select-String "LISTENING" | ForEach-Object { ($_ -split "\s+")[-1] } | Select-Object -First 1
if ($process) {
    Write-Host "포트 $port 사용 중인 프로세스 종료 중... (PID: $process)"
    Stop-Process -Id $process -Force -ErrorAction SilentlyContinue
}
Write-Host "빌드 캐시 정리..."
flutter clean | Out-Null
flutter pub get | Out-Null
Write-Host "Flutter 앱 시작..."
flutter run -d chrome --web-port=$port --dart-define=GROQ_API_KEY=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 --dart-define=NAVER_CLIENT_ID=vBNJQC1zTEGhrFTUMYDm --dart-define=NAVER_CLIENT_SECRET=bzG4DPc5cu --web-browser-flag="--disable-web-security"
