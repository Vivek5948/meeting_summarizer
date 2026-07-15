#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter not found. Installing Flutter SDK..."
  git clone --depth 1 https://github.com/flutter/flutter.git "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
else
  echo "Using existing Flutter installation"
fi

flutter --version
flutter config --enable-web
flutter pub get
flutter build web --release

echo "Flutter web build completed at build/web"
