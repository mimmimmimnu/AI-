# 키 파일 불러오기
if (-not (Test-Path .\secret.ps1)) {
    Write-Host "secret.ps1 파일이 없습니다. secret.ps1을 만들고 키를 입력하세요." -ForegroundColor Red
    exit 1
}
. .\secret.ps1

$port = 8080
$process = netstat -ano | Select-String ":$port " | Select-String "LISTENING" | ForEach-Object { ($_ -split "\s+")[-1] } | Select-Object -First 1
if ($process) {
    Write-Host "포트 $port 사용 중인 프로세스 종료 중... (PID: $process)"
    Stop-Process -Id $process -Force -ErrorAction SilentlyContinue
}
Write-Host "패키지 설치 중..."
flutter pub get | Out-Null
Write-Host "Datefit 앱 시작..."
flutter run -d chrome --web-port=$port `
  --dart-define=NAVER_CLIENT_ID=$env:NAVER_CLIENT_ID `
  --dart-define=NAVER_CLIENT_SECRET=$env:NAVER_CLIENT_SECRET `
  --dart-define=TMAP_API_KEY=$env:TMAP_API_KEY `
  --dart-define=GROQ_API_KEY=$env:GROQ_API_KEY `
  --web-browser-flag="--disable-web-security"
