# WatchHive Mobile — Agent Context & Architectural Guidelines

> **Repository Master Reference**  
> Runtime: Flutter 3.x (Dart SDK ≥3.3.0)  
> Platforms: iOS (Xcode), Android (Gradle), macOS  
> State Management: Flutter Riverpod 2.6.x  
> Routing: GoRouter 14.8.x (`lib/core/router/app_router.dart`)  
> HTTP Client: Dio 5.11.x with JWT interceptors & TMDb SWR cache (`lib/core/api/api_client.dart`)  
> Persistence: `flutter_secure_storage` + `sqflite` (offline storage)  
> Push Notifications: Firebase Cloud Messaging + `flutter_local_notifications`

---

## 🏛️ 1. Architecture & Directory Layout

```
lib/
├── main.dart                       # App initialization (dotenv, Firebase, runApp)
├── app.dart                        # WatchHiveApp, MaterialApp.router, offline banner
├── core/
│   ├── api/
│   │   ├── api_client.dart         # Singleton Dio with auth retry & TMDb SWR cache
│   │   └── api_endpoints.dart      # Centralized backend & TMDb URL definitions
│   ├── auth/
│   │   └── auth_manager.dart       # Secure storage of access/refresh tokens & user
│   ├── router/
│   │   ├── app_router.dart         # GoRouter routes, redirects, deep link normalization
│   │   └── app_route_observer.dart
│   ├── theme/
│   │   ├── app_theme.dart          # Light theme matching Web PWA design
│   │   └── app_colors.dart         # Warm honey palette constants
│   └── services/                   # Offline sync, connectivity, app update
├── features/                       # Modular feature structure
│   ├── auth/                       # Login, signup, verify email, splash
│   ├── entries/                    # Watch logging, watchlist, episode tracking, detail screen
│   ├── feed/                       # Social activity feed, SmartSuggest carousel
│   ├── mindlens/                   # Taste profile, Shannon entropy radar charts
│   ├── notifications/              # In-app notification center
│   ├── profile/                    # User profile, history, stats, settings
│   ├── rankings/                   # Cinematic stacks & tier lists
│   └── scanner/                    # QR scanner for profile sharing
└── shared/
    ├── models/                     # User, Entry, Media, Episode, Notification models
    └── widgets/                    # WHSkeletonBox, BeeLoadingScreen, AppShell, buttons
```

---

## 🎨 2. UI/UX Rules & Palette Tokens (`lib/core/theme/app_colors.dart`)

1. **Colors**:
   - `AppColors.primary`: `0xFFFFB700` (Honey Gold)
   - `AppColors.primaryLight`: `0xFFFFDA40`
   - `AppColors.primaryDark`: `0xFFE59700`
   - `AppColors.background`: `0xFFFFF9F0` (Warm Cream matching Web PWA)
   - `AppColors.surface`: `0xFFFFFFFF` (Pure White)
   - `AppColors.surfaceElevated`: `0xFFFFF3E0`
   - `AppColors.textPrimary`: `0xFF2D2926` (Charcoal Black)
   - `AppColors.textSecondary`: `0xFF525252`
   - `AppColors.textMuted`: `0xFF737373`
   - `AppColors.border`: `0xFFE5E5E5`
2. **The Golden Contrast Rule**:
   - All text and icon colors on gold, amber, or cream surfaces MUST be black (`AppColors.textPrimary` or `Colors.black`). NEVER use white text on gold buttons!
3. **Loader Hierarchy**:
   - **Primary**: `WHSkeletonBox` shimmer placeholder. Used everywhere data is loading (cards, carousels, lists, stats).
   - **Secondary**: `BeeLoadingScreen` / animated bee loader. Used ONLY on splash screen, initial boot, or blocking operations.
4. **Ratings**:
   - 10-point scale (0.5 to 10.0), displayed as 5 dual-halved golden stars.

---

## ⚡ 3. API Client & SWR Caching (`lib/core/api/api_client.dart`)

- **TMDb Caching Interceptor**:
  - Automatically caches TMDb endpoints in-memory for 10m to 7 days.
  - Single-flight deduplication awaits in-flight identical calls.
  - Stale cache fallback ensures offline resilience.
- **Silent Auth Refresh**:
  - Automatically intercepts 401s, attempts silent token refresh with `authManager.refreshTokens()`, and replays requests.

---

## 🔗 4. Deep Linking & Routing (`lib/core/router/app_router.dart`)

- Custom scheme: `watchershive://` or `watchhive://`
- Web URLs: Handles incoming links from `watchershive.com`, `watchhive-web.vercel.app`, and redirects:
  - `/movie/:id` or `/tv/:id` → `/details/:mediaType/:tmdbId`
  - `/user/:id` → `/profile/:id`
  - Deep links captured during cold boot are preserved in `_pendingDeepLink` and redirected after auth.

---

## 🛠️ 5. Standard Commands

- Run on iOS Simulator: `flutter run -d <simulator_id>`
- Run on Android Emulator: `flutter run -d <emulator_id>`
- Run tests: `flutter test`
- Static analysis: `flutter analyze`
- Build Android debug APK: `flutter build apk --debug`
- Build Android release APK: `flutter build apk --release`
- Build iOS Simulator: `flutter build ios --simulator`
