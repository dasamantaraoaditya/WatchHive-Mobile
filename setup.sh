#!/usr/bin/env bash
# WatchHive Mobile — First-time setup script
# Run this after installing Flutter, Xcode, Android Studio, and Java.

set -e
cd "$(dirname "$0")"

echo "🎬 WatchHive Mobile Setup"
echo "========================="
echo ""

# Check Flutter
if ! command -v flutter &> /dev/null; then
  echo "❌ Flutter not found. Install with: brew install --cask flutter"
  exit 1
fi

echo "✅ Flutter: $(flutter --version --machine | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['frameworkVersion'])" 2>/dev/null || echo 'found')"

# Get dependencies
echo ""
echo "📦 Installing packages..."
flutter pub get

# Check for font files
echo ""
if [ ! -f "assets/fonts/Inter-Regular.ttf" ]; then
  echo "⚠️  Inter fonts not found in assets/fonts/"
  echo "   Download from https://fonts.google.com/specimen/Inter"
  echo "   Place Inter-Regular.ttf, Inter-Medium.ttf, Inter-SemiBold.ttf, Inter-Bold.ttf"
else
  echo "✅ Inter fonts found"
fi

# Check for Firebase files
echo ""
if [ ! -f "ios/Runner/GoogleService-Info.plist" ]; then
  echo "⚠️  Firebase iOS config not found (ios/Runner/GoogleService-Info.plist)"
  echo "   Add your Firebase app at https://console.firebase.google.com"
fi

if [ ! -f "android/app/google-services.json" ]; then
  echo "⚠️  Firebase Android config not found (android/app/google-services.json)"
fi

# Check .env
if [ ! -f ".env" ]; then
  echo "⚠️  .env file not found. Creating from template..."
  cat > .env << 'EOF'
WATCHHIVE_API_URL=https://watchhive-api-production.up.railway.app/api/v1
TMDB_IMAGE_BASE_URL=https://image.tmdb.org/t/p/w500
GOOGLE_WEB_CLIENT_ID=YOUR_CLIENT_ID_HERE
EOF
  echo "   Edit .env with your Google client ID."
fi

echo ""
echo "🚀 Ready! Run the app with:"
echo "   flutter run"
