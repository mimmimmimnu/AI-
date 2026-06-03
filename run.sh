#!/bin/bash
flutter pub get
flutter run -d chrome --web-port=8080 \
  --dart-define=GROQ_API_KEY=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 \
  --dart-define=NAVER_CLIENT_ID=vBNJQC1zTEGhrFTUMYDm \
  --dart-define=NAVER_CLIENT_SECRET=bzG4DPc5cu \
  --web-browser-flag="--disable-web-security"
