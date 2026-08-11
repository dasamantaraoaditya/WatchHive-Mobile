# WatchHive Mobile 🎬

A Flutter mobile app for WatchHive — Track Movies, Anime, K-Drama & Series.

## Stack
- **Flutter 3.x** (iOS + Android)
- **Riverpod** — State management
- **Dio** — HTTP client with JWT refresh
- **GoRouter** — Declarative navigation
- **Firebase Messaging** — Push notifications
- **flutter_secure_storage** — JWT token storage
- **cached_network_image** — TMDB poster caching

## Setup

### 1. Prerequisites

```bash
# Install Flutter (via Homebrew)
brew install --cask flutter

# Install Java JDK for Android
brew install --cask temurin

# Install Xcode from Mac App Store, then:
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# Install Android Studio from https://developer.android.com/studio
```

### 2. Verify Installation

```bash
flutter doctor
```

### 3. Clone & Configure

```bash
cd /Users/adityadasamantharao/Documents/Repos/watchhive_mobile

# Copy and configure environment
cp .env .env.local  # Edit with your values
```

### 4. Set up Firebase (Push Notifications)

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a project and add iOS/Android apps
3. Download `GoogleService-Info.plist` → `ios/Runner/`
4. Download `google-services.json` → `android/app/`
5. Run: `flutterfire configure`

### 5. Set up Google Sign-In

1. Get your OAuth client ID from [Google Cloud Console](https://console.cloud.google.com)
2. Add to `.env`: `GOOGLE_WEB_CLIENT_ID=your_id_here`
3. For iOS: add URL scheme in `ios/Runner/Info.plist`

### 6. Download Inter Font

Download Inter from [Google Fonts](https://fonts.google.com/specimen/Inter) and place in `assets/fonts/`:
- `Inter-Regular.ttf`
- `Inter-Medium.ttf`
- `Inter-SemiBold.ttf`
- `Inter-Bold.ttf`

### 7. Install & Run

```bash
flutter pub get
flutter run                    # Pick device from list
flutter run -d "iPhone 15"     # iOS Simulator
flutter run -d emulator        # Android Emulator
```

## Project Structure

```
lib/
├── main.dart              # Entry point
├── app.dart               # Root widget
├── core/
│   ├── api/               # Dio HTTP client + endpoint constants
│   ├── auth/              # JWT token manager
│   ├── theme/             # Dark theme + color palette
│   └── router/            # GoRouter with auth guards
├── features/
│   ├── auth/              # Login, Signup, Splash, Forgot Password
│   ├── feed/              # Social feed
│   ├── entries/           # Watch log + Add/Edit sheet + Movie details
│   ├── search/            # TMDB search + User search
│   ├── profile/           # Own profile + other user profiles
│   └── notifications/     # Notification list
└── shared/
    ├── models/            # User, Entry, MediaResult, Notification
    └── widgets/           # Reusable UI components
```

## Environment Variables (`.env`)

```
WATCHHIVE_API_URL=https://watchhive-api-production.up.railway.app/api/v1
TMDB_IMAGE_BASE_URL=https://image.tmdb.org/t/p/w500
GOOGLE_WEB_CLIENT_ID=your_google_client_id
```
