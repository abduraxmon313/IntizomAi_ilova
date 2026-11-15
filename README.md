# IntizomAI — Mobil Ilova

**IntizomAI** — shaxsiy intizom va o'sish ilovasi. Kundalik rejalar, odatlar, maqsadlar,
gamifikatsiya (XP, daraja, streak), AI Coach va guruh funksiyalari.

## 📱 Platformalar

- ✅ Android (APK va Play Store)
- ✅ iOS (App Store)

## 🏗️ Texnologiya

- **Flutter** (Dart) — bitta kod bazasi, ikki platforma
- **Railway** backend — PostgreSQL (Telegram bot bilan bitta DB)
- **Telegram** orqali autentifikatsiya
- **Dizayn** — MyFit uslubidagi professional, zamonaviy ko'rinish

## 📂 Loyiha strukturasi

```
lib/
├── main.dart                         # App entry point
├── config/app_config.dart            # API URL, konstantalar
├── l10n/app_localizations.dart       # Uz/Ru/En tarjimalar
├── theme/app_theme.dart              # Dizayn tizimi (ranglar, shrift)
├── models/                           # Ma'lumot modellari
│   ├── user_profile.dart
│   ├── plan.dart
│   ├── habit.dart
│   ├── goal.dart
│   ├── checkin.dart
│   └── achievement.dart
├── services/                         # Railway API bilan aloqa
│   ├── api_client.dart               # REST API klient
│   ├── auth_store.dart               # Token saqlash
│   ├── appearance_store.dart         # Tema saqlash
│   ├── locale_store.dart             # Til saqlash
│   ├── user_service.dart
│   ├── plan_service.dart
│   ├── habit_service.dart
│   ├── goal_service.dart
│   └── coach_service.dart
├── screens/                          # Sahifalar
│   ├── auth/login_page.dart          # Telegram login
│   ├── home_page.dart                # Tab navigatsiya
│   ├── dashboard/dashboard_page.dart # Streak, XP, discipline
│   ├── plans/plans_page.dart         # Rejalar
│   ├── habits/habits_page.dart       # Odatlar
│   ├── goals/goals_page.dart         # Maqsadlar
│   ├── coach/coach_page.dart         # AI Coach chat
│   └── profile/profile_page.dart     # Profil, sozlamalar
└── widgets/app_ui.dart               # AppCard, AppIconTile, ...
```

## 🚀 Ishga tushirish

```bash
# Dependentsiyalarni o'rnatish
flutter pub get

# Debug rejimda ishga tushirish
flutter run

# APK yaratish (yangilash uchun)
flutter build apk --release

# Production API bilan
flutter run --dart-define=API_BASE_URL=https://your-app.up.railway.app
```

## 📦 APK Yangilash

Yangi versiya chiqganda:
1. `pubspec.yaml` dagi `version` ni oshiring (masalan `1.0.1+2`)
2. `flutter build apk --release`
3. APK ni qurilmaga yuboring va o'rnating — eski versiya ustiga yangilanadi ✅

## 🔐 Autentifikatsiya

Bot orqali login:
1. Foydalanuvchi ilovada "Telegram orqali kirish" tugmasini bosadi
2. Telegram ochiladi → IntizomAI bot
3. Bot auth token beradi
4. Ilova token bilan API'ga kiradi

## 💎 Premium

To'lov ilovada EMAS, Telegram bot ichida amalga oshiriladi.
Bu App Store/Google Play komisiyasini oldini oladi.
