# =====================================================
# 실행 전 아래 API 키를 본인 키로 채워주세요.
# 이 파일을 복사해서 run.ps1 로 저장한 뒤 실행하세요.
#
# 필요한 API 키:
#   GROQ_API_KEY         : https://console.groq.com
#   NAVER_CLIENT_ID      : https://developers.naver.com (지역 검색 API)
#   NAVER_CLIENT_SECRET  : 위 동일
#   (카카오 JS 키는 web/index.html 의 appkey= 부분에 직접 입력)
# =====================================================

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
flutter run -d chrome --web-port=$port `
    --dart-define=GROQ_API_KEY=여기에_GROQ_키_입력 `
    --dart-define=NAVER_CLIENT_ID=여기에_네이버_클라이언트_ID `
    --dart-define=NAVER_CLIENT_SECRET=여기에_네이버_시크릿 `
    --web-browser-flag="--disable-web-security"
