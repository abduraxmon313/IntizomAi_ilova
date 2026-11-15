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
