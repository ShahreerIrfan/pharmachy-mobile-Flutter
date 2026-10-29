# Bangladesh Pharmacy Mobile Manager (Flutter 3.x)

Executive Owner & Branch Manager mobile application built with **Flutter 3.x and Dart 3.x**.
Ready to be pushed as its own independent GitHub repository (`pharmacy-mobile`).

---

## 1. Architecture & Capabilities
- **UI Design System:** Cupertino/iOS-inspired restrained aesthetics, purposeful whitespace, native vector icons (`CupertinoIcons`), zero emoji controls.
- **Role-Based Boundaries:** Dedicated views for Tenant Owners and Branch Managers with strict cross-tenant blocking.
- **Fast Executive KPIs:** Instantaneous loading backed by Redis cached analytics warmed by background Celery tasks.
- **Financial Precision:** Strict string decimal formatting avoiding floating-point precision drift.
- **Bilingual Localization:** English and Bengali interface with Asia/Dhaka timestamps.

---

## 2. Build & Test Commands
```bash
# Fetch dependencies
flutter pub get

# Run static analysis
flutter analyze

# Run unit and widget test suite
flutter test

# Run application on emulator/device
flutter run
```
