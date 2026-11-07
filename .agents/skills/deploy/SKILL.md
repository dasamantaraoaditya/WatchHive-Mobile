---
name: deploy
description: Step-by-step procedures for building and releasing WatchHive Mobile APKs, App Bundles (AAB), and iOS builds.
---

# Deploy Skill — WatchHive Mobile

## Build Targets

### 1. Android Release Build (AAB / APK)
- Build Android App Bundle for Google Play Console:
  ```bash
  flutter build appbundle --release
  ```
- Build Android APK for direct distribution / testing:
  ```bash
  flutter build apk --release
  ```
- Binary outputs located in: `build/app/outputs/flutter-apk/` and `build/app/outputs/bundle/release/`.

### 2. iOS Release Build (IPA / TestFlight)
- Build iOS release archive:
  ```bash
  flutter build ipa --release
  ```
- Open Xcode workspace for signing & TestFlight upload:
  ```bash
  open ios/Runner.xcworkspace
  ```

## Pre-Release Verification Checklist
1. Verify static analysis passes with 0 warnings:
   ```bash
   flutter analyze
   ```
2. Verify all widget and unit tests pass:
   ```bash
   flutter test
   ```
3. Verify version code and name bumped in `pubspec.yaml` (`version: x.y.z+build`).
4. Ensure `.env` is loaded with production backend endpoint (`https://watchhive-api-production.up.railway.app/api/v1`).
