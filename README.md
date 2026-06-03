# ✿ Datefit — AI 데이트 코스 추천 앱

이지민_찐최종 + 이윤서 브랜치 합본 (Flutter Web)

## 📁 구조
```
lib/main.dart        ← 단일 파일 (전체 앱)
web/index.html       ← 카카오맵 SDK 포함
assets/
  spots.json         ← 서울 관광지 데이터 (선택)
  restaurants.json   ← 맛집 데이터 (선택)
run.ps1              ← Windows 실행 스크립트
run.sh               ← Mac/Linux 실행 스크립트
```

## 🚀 실행 방법

### Windows
```powershell
.\run.ps1
```

### Mac / Linux
```bash
bash run.sh
```

### 수동 실행
```bash
flutter pub get
flutter run -d chrome --web-port=8080 \
  --dart-define=GROQ_API_KEY=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 \
  --dart-define=NAVER_CLIENT_ID=vBNJQC1zTEGhrFTUMYDm \
  --dart-define=NAVER_CLIENT_SECRET=bzG4DPc5cu \
  --web-browser-flag="--disable-web-security"
```

> ⚠️ `--web-browser-flag="--disable-web-security"` 는 Naver API CORS 우회용으로 개발 환경에서만 사용

## 🗂️ 화면 구성
| 탭 | 내용 |
|---|---|
| 🏠 홈 | 추천 코스 배너, 친구 목록, 저장된 코스 |
| ✨ AI 코스 | 장소 검색 + AI 챗봇 + 코스 생성 + 카카오맵 |
| 💬 타임라인 | 피드, 게시물 작성, 방 초대코드 |
| 👤 MY | 프로필, 저장한 코스, 친구 관리, 알림 설정 |

## 🔑 API 키 정보
- **Kakao Map**: `94624b0c7c18e3edd28a76e451500573` (JS SDK)
- **Kakao REST**: `8ddff68bae409484fe211e99220c0bd1`
- **Naver**: ID `vBNJQC1zTEGhrFTUMYDm` / Secret `bzG4DPc5cu`
- **Groq**: `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`
