# IntizomAI — mobil ilova (Android + iOS)

Flutter ilova. MyFit bilan bir xil tuzilma va dizayn uslubi (Inter shrift,
neytral fon, bitta ko'k aksent).

## Qanday ishlaydi

```
Flutter ilova ──HTTPS──▶ Railway (IntizomAi_Bot_Pro_Copy, webapp/app.py) ──▶ PostgreSQL
                              ▲
                     Telegram bot (o'sha server, o'sha baza)
```

- Alohida backend yo'q. Ilova Mini App ishlatadigan `/api/webapp/*`
  endpointlariga `Authorization: Bearer <token>` bilan murojaat qiladi.
  Premium cheklovlari, ball/streak hisob-kitobi va vaqt qoidalari bot va
  Mini App bilan bir xil.
- To'lov faqat bot ichida. Ilovadagi "Premium" tugmalari botni ochadi.

## Ekranlar va navigatsiya

Pastki navigatsiyada 5 bo'lim:

| Bo'lim | Ichida | "+" tugmasi |
|---|---|---|
| **Bugun** | salomlashish, kun xulosasi, bugungi rejalar va odatlar, oy maqsadlari, kayfiyat/energiya | yangi reja |
| **Rejalar** | Kunlik / Oylik / Yillik | kunlikda — reja, oylik/yillikda — maqsad |
| **Odatlar** | odatlar ro'yxati, seriyalar | yangi odat |
| **Natijalar** | Shaxsiy (statistika, yutuqlar) / Do'stlar (guruhlar) / Reyting | yo'q |
| **Murabbiy** | AI suhbat | yo'q |

- **Profil** — Bugun sarlavhasidagi avatar orqali: hisob, Premium, tungi rejim, eslatmalar, aloqa.
- Har bo'limda bitta "qo'shish" amali bor — pastdagi "+" tugmasi.
- **Tahrirlash va o'chirish**: element bosilsa tahrirlash varag'i ochiladi, "O'chirish" faqat shu varaq ichida
  (odat o'chirilishidan oldin tasdiq so'raladi).
- **Bajarildi** belgilanganda pastda "Qaytarish" tugmali xabar chiqadi.
- **Do'stlar**: guruhlar ro'yxati → guruh → a'zoning kuni. Orqaga tugmasi (va tizim "orqaga"si) shu tartibda qaytaradi.
  Guruh sozlamalari (Umumiy / Hisobot / A'zolar) va ruxsatlar — pastdan ochiladigan varaqlarda.

## Dizayn tizimi

Barcha qiymatlar `lib/theme/app_theme.dart` da. Ekranlarda alohida `TextStyle(...)`,
`Color(0x...)` yoki `fontSize` yozilmaydi — faqat shu tokenlar va mavzu ranglari (`ColorScheme`).

| Token | Vazifasi |
|---|---|
| `AppType` | `display`, `title`, `heading`, `body`, `bodyStrong`, `label`, `caption`, `micro`, `overline` (Inter) |
| `AppPalette` | brend, neytral fon/chiziqlar, holat ranglari; `ember` — seriya, `gold` — Premium, `bronze` — reytingda 3-o'rin |
| `AppPalette.textTone` | och fonda ember/gold/bronze matnni WCAG AA kontrastgacha to'qlashtiradi |
| `AppRadius`, `AppSpace`, `AppShadows`, `AppMotion` | burchaklar, oraliqlar, soyalar, animatsiya vaqtlari |

Qorong'i va yorug' rejim bitta `ColorScheme` dan quriladi. Kichik kulrang matn `onSurfaceVariant`
rangida (fonga nisbatan kamida 4.5:1).

Umumiy komponentlar:

- `lib/widgets/ui_kit.dart` — `PageHeader`, `SegmentTabs`, `SectionBar`, `TaskRow`, `CheckCircle`,
  `GroupCard`, `SettingTile`, `SheetScaffold`, `showFormSheet`, `ChoiceChipBox`, `MetaTag`, `Pill`,
  `EmptyView`, `PremiumGate`, `AddFab`, `toast`, `confirmAction`.
- `lib/widgets/app_ui.dart` — `AppCard`, `surfaceDecoration`, `AppIconTile`, `AppProgressBar`,
  `ProgressRing`, `BrandMark`, `HabitGlyph`.
- `lib/widgets/feedback.dart` — xato xabarlari, Premium oynasi, `ErrorRetry`.

Interfeys 320–412 px kenglikdagi ekranlarga mo'ljallangan.

## Kod tuzilmasi

```
lib/
  main.dart            ilova, mavzu, kirish ↔ asosiy ekran
  config/              API manzili, bot nomi
  l10n/                tillar
  models/              server javoblari (Plan, Habit, Goal, Profile, Stats, friends ...)
  services/            ApiClient, IntizomApi, kirish va saqlash
  state/app_state.dart umumiy holat (profil, odatlar, statistika)
  theme/app_theme.dart dizayn tokenlari va ThemeData
  utils/dates.dart     Toshkent vaqti, sana formatlari
  widgets/             umumiy komponentlar (yuqorida)
  screens/
    home_page.dart     pastki navigatsiya va "+" tugmasi
    forms.dart         reja / odat / maqsad varaqlari
    auth/ today/ plans/ habits/ stats/ achievements/ friends/ coach/ profile/
```

## Kirish

1. Ilovada **Telegram orqali kirish** bosiladi. Ilova bir martalik kod yaratadi va
   `t.me/intizomAi_bot?start=applogin_<kod>` ochiladi.
2. Botda **✅ Ilovaga kirishni tasdiqlash** bosiladi.
3. Ilova `/api/webapp/app-auth/poll` orqali tasdiqni kutadi va tokenni o'zi oladi.
   Token qurilmaning xavfsiz xotirasida saqlanadi (180 kun).

## APK yig'ish (Codemagic)

`codemagic.yaml` → `android-apk` workflow. `main`ga har push bo'lganda APK avtomatik yig'iladi.

Codemagic → IntizomAi_ilova → **Environment variables**, guruh nomi **`IntizomAi`**:

| O'zgaruvchi | Qiymat |
|---|---|
| `ANDROID_KEYSTORE_PASSWORD` | Imzo kaliti paroli (Secure) |

Server manzili (`API_BASE_URL`) `codemagic.yaml` ichida yozilgan:
`https://intizom-aibot-production.up.railway.app`.

### Yangilash (qayta o'rnatmasdan)

APK har doim `android/app/intizomai-upload.p12` kaliti bilan imzolanadi va
`versionCode` Codemagic build raqamidan olinadi. Shuning uchun yangi APK eski
ilova ustiga **Yangilash** sifatida o'rnatiladi, ma'lumotlar saqlanadi.

`intizomai-upload.p12` faylini o'chirmang va almashtirmang: kalit o'zgarsa,
telefondagi ilovani yangilab bo'lmaydi (o'chirib qayta o'rnatish kerak bo'ladi).

## iOS

`ios/` papkasi Flutter shablonidan yaratilgan (bundle ID `uz.intizomai.intizomAi`).
iPhone'ga o'rnatish uchun Apple Developer imzosi kerak (Codemagic iOS workflow yoki Xcode).

## Lokal ishga tushirish

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://xxx.up.railway.app
```
