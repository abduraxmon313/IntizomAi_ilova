# IntizomAI — mobil ilova (Android + iOS)

Flutter ilova. MyFit bilan bir xil tuzilma va dizayn uslubi (Inter shrift,
neytral fon, bitta ko'k aksent).

## Qanday ishlaydi

```
Flutter ilova ──HTTPS──▶ Ilova backend (IntizomAi_ilova_database, Railway) ──▶ o'z PostgreSQL bazasi
                                   │  faqat obuna sotib olishda (HMAC imzo)
                                   ▼
                         Bot backend (IntizomAi_Bot_Pro_Copy) ──▶ Paylov
```

- Ilovaning o'z backend'i va bazasi bor; bot foydalanuvchilari bilan aralashmaydi.
  Hamma so'rovlar `/api/v1/*` ga `Authorization: Bearer <token>` bilan boradi.
- Kirish: **iOS — Apple yoki Google**, **Android — Google**.
- Birinchi kirishda foydalanuvchi ism, yosh va username kiritadi.
- Premium ilova ichida sotib olinadi (Payme / Click / Uzum / Paylov). To'lovni bot
  backend'i Paylov orqali qabul qiladi, natija ilova backend'iga keladi va Premium avtomatik ochiladi.
- Guruhlar faqat ilova ichida: ega do'stini **username** orqali taklif qiladi, u taklifni qabul qiladi.

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
  Kelgan takliflar ro'yxat tepasida (qabul qilish / rad etish / bloklash). Ega "Taklif qilish" orqali username yozadi.
  Guruh sozlamalari (Umumiy / A'zolar: pauza, chiqarish, egalikni topshirish) va ruxsatlar — pastdan ochiladigan varaqlarda.

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
- `lib/widgets/feedback.dart` — xato xabarlari, `ErrorRetry`.
- `lib/widgets/paywall.dart` — Premium sotib olish oynasi (tarif, to'lov usuli, promokod, to'lovni kutish).

Interfeys 320–412 px kenglikdagi ekranlarga mo'ljallangan.

## Kod tuzilmasi

```
lib/
  main.dart            ilova, mavzu, kirish ↔ asosiy ekran
  config/              API manzili, Google client ID'lar, sotuv sozlamasi
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

1. **iOS**: «Apple orqali kirish» yoki «Google orqali kirish». **Android**: faqat Google.
2. Ilova provayderdan ID token oladi va `POST /api/v1/auth/{google|apple}` ga yuboradi.
   Server tokenni tekshirib, o'z sessiya tokenini qaytaradi (qurilmaning xavfsiz xotirasida, 180 kun).
3. Yangi foydalanuvchi **onboarding** sahifasida ism, yosh (13+) va username kiritadi
   (username bandligi yozish paytida tekshiriladi). Ixtiyoriy: taklif qilgan do'stning username'i.
4. Keyin bildirishnomalarga ruxsat so'raladi. Bildirishnomadagi **Bajarildi** tugmasi
   reja/odatni ilovani ochmasdan belgilaydi.
5. Chiqishda sessiya serverda ham bekor qilinadi. Hisobni o'chirish: Profil → Hisobni o'chirish.

## Premium

Profil → Premium kartasi yoki istalgan qulflangan imkoniyat → tarif tanlash → to'lov usuli →
(promokod) → **To'lash**. To'lov sahifasi brauzerda ochiladi; ilovaga qaytganda holat avtomatik
tekshiriladi. Obuna avtomatik yangilanmaydi.

Sotuv tugmalarini build vaqtida o'chirish kerak bo'lsa: `--dart-define=HIDE_PURCHASES=true`.

## APK yig'ish (Codemagic)

`codemagic.yaml` → `android-apk` workflow. `main`ga har push bo'lganda APK avtomatik yig'iladi.

Codemagic → IntizomAi_ilova → **Environment variables**, guruh nomi **`IntizomAi`**:

| O'zgaruvchi | Qiymat |
|---|---|
| `ANDROID_KEYSTORE_PASSWORD` | Imzo kaliti paroli (Secure) |
| `API_BASE_URL` | Ilova backend'i manzili, masalan `https://intizom-app-production.up.railway.app` |
| `GOOGLE_SERVER_CLIENT_ID` | Google Cloud → OAuth client (Web application) ID |
| `GOOGLE_IOS_CLIENT_ID` | Google Cloud → OAuth client (iOS) ID (iOS workflow uchun) |

Android'da Google orqali kirish ishlashi uchun Google Cloud'da **Android** OAuth client yarating:
paket `uz.intizomai.intizom_ai` va `intizomai-upload.p12` kalitining SHA-1'i
(`keytool -list -v -keystore android/app/intizomai-upload.p12 -storetype pkcs12`).
Play Market'ga chiqarilsa, Play App Signing kalitining SHA-1'ini ham qo'shing.

### Yangilash (qayta o'rnatmasdan)

APK har doim `android/app/intizomai-upload.p12` kaliti bilan imzolanadi va
`versionCode` Codemagic build raqamidan olinadi. Shuning uchun yangi APK eski
ilova ustiga **Yangilash** sifatida o'rnatiladi, ma'lumotlar saqlanadi.

`intizomai-upload.p12` faylini o'chirmang va almashtirmang: kalit o'zgarsa,
telefondagi ilovani yangilab bo'lmaydi (o'chirib qayta o'rnatish kerak bo'ladi).

## iOS

`ios/` papkasi Flutter shablonidan yaratilgan (bundle ID `uz.intizomai.intizomAi`).
iPhone'ga o'rnatish uchun Apple Developer imzosi kerak (Codemagic iOS workflow yoki Xcode).

- `ios/Runner/Runner.entitlements` — **Sign in with Apple** huquqi. Apple Developer → Identifiers
  → `uz.intizomai.intizomAi` → Sign In with Apple yoqilgan bo'lishi kerak.
- Google uchun reversed client ID URL sxemasi Codemagic'da `GOOGLE_IOS_CLIENT_ID`dan Info.plist'ga qo'shiladi.
  Xcode'da lokal yig'ishda uni `Info.plist → CFBundleURLTypes` ga qo'lda qo'shing.
- Sideloadly (bepul Apple ID) bilan o'rnatilgan buildda Apple orqali kirish ishlamaydi — Google ishlaydi.

## Lokal ishga tushirish

```bash
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=https://xxx.up.railway.app \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=xxx.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=yyy.apps.googleusercontent.com
```
