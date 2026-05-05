#!/usr/bin/env bash
set -o errexit

FLUTTER_VERSION="3.29.0"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

if [ ! -d "flutter" ]; then
  echo "==> Descargando Flutter $FLUTTER_VERSION..."
  curl -o flutter.tar.xz $FLUTTER_URL
  tar xf flutter.tar.xz
  rm flutter.tar.xz
fi

export PATH="$PATH:`pwd`/flutter/bin"

echo "==> Configurando Flutter..."
flutter config --no-analytics
flutter config --enable-web

echo "==> Limpiando y obteniendo dependencias..."
flutter clean
flutter pub get
echo "==> Iniciando Build..."
flutter build web --release --dart-define=API_BASE_URL=https://game-tracker-back.onrender.com