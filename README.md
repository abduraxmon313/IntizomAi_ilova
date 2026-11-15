# IntizomAI — Mobil Ilova

**IntizomAI** — shaxsiy intizom va o'sish ilovasi. Kundalik rejalar, odatlar, maqsadlar,
gamifikatsiya (XP, daraja, streak), AI Coach va guruh funksiyalari.

## 📱 Platformalar

- ✅ Android (APK — Codemagic orqali)
- ✅ iOS (Codemagic orqali)

## 🏗️ Arxitektura

```
📱 Flutter Ilova ←→ 🌐 Railway (mavjud webapp/app.py) ←→ 🗄️ PostgreSQL
                          ↑
                    🤖 Telegram Bot (SHU BIR server, SHU BIR DB)
```

**Alohida backend YO'Q** — ilova to'g'ridan-to'g'ri bot'ning mavjud Railway
serveriga ulanadi. API route'lar `webapp/routes/app_api.py` da, `/api/v1/` prefiksi bilan.

## 🔐 Kirish oqimi

1. Foydalanuvchi ilovada **"Telegram orqali kirish"** tugmasini bosadi
2. Telegram ochiladi → IntizomAI bot → `/start app_login`
3. Bot **JWT token** generatsiya qilib xabar sifatida yuboradi
4. Foydalanuvchi tokenni **nusxalab** ilovaga kiritadi
5. Ilova token bilan `/api/v1/*` endpointlariga so'rov yuboradi ✅

## 💎 Premium va To'lov

To'lov **faqat Telegram bot** ichida — App Store/Google Play komisiyasi yo'q!
Ilovada "Premium olish" tugmasi → Telegram bot'ga yo'naltiradi.

## 📦 APK yaratish (Codemagic)

1. [codemagic.io](https://codemagic.io) da GitHub repo'ni bog'lang
2. Environment variables qo'shing: `API_BASE_URL` = Railway URL
3. Build boshlang → APK tayyor!
4. Yangilash: versiya oshirib push → yangi APK → eski ustiga o'rnatiladi ✅

## 🚀 Lokal ishga tushirish

```bash
# Dependentsiyalar
flutter pub get

# Debug
flutter run --dart-define=API_BASE_URL=https://your-app.up.railway.app

# Release APK
flutter build apk --release --dart-define=API_BASE_URL=https://your-app.up.railway.app
```

## 📂 Loyiha strukturasi

```
lib/
├── main.dart                         # App entry point
├── config/app_config.dart            # API URL (Railway)
├── l10n/app_localizations.dart       # Uz/Ru/En tarjimalar
├── theme/app_theme.dart              # MyFit uslubidagi dizayn
├── models/                           # Ma'lumot modellari
├── services/                         # Railway API bilan aloqa
│   ├── api_client.dart               # REST klient + JWT auth
│   ├── auth_store.dart               # Token xavfsiz saqlash
│   └── ...                           # plan, habit, goal, coach
├── screens/                          # Sahifalar
│   ├── auth/login_page.dart          # Telegram login + token kiritish
│   ├── home_page.dart                # Tab navigatsiya
│   ├── dashboard/                    # Streak, XP, discipline
│   ├── plans/                        # Rejalar
│   ├── habits/                       # Odatlar
│   ├── goals/                        # Maqsadlar
│   ├── coach/                        # AI Coach chat
│   └── profile/                      # Profil, sozlamalar
└── widgets/app_ui.dart               # AppCard, DisciplineGauge, ...
```

## ⚙️ Railway sozlamalari

Bot repo'ga qo'shilgan fayllar (`IntizomAi_Bot_Pro_Copy`):
- `bot/config.py` — `JWT_SECRET` qo'shildi
- `bot/services/app_auth.py` — JWT token yaratish/tekshirish
- `bot/handlers/start.py` — `app_login` deep link handler
- `webapp/routes/app_api.py` — Mobil ilova API endpointlari
- `webapp/app.py` — `/api/v1` route registratsiyasi
- `requirements.txt` — `python-jose` qo'shildi

**Railway env'ga qo'shing:**
```
JWT_SECRET=<random-64-char-string>
```
