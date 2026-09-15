# JoE.V Client App

**Flutter mobile application for JoE.V fitness platform clients.**

Package: `com.joev.fitness` | Version: `1.0.0+5`

---

## 📱 About

The JoE.V Client app allows fitness clients to:
- Sign in with Phone (OTP) or Google
- Book & manage personal training sessions
- Track health metrics (weight, BMI, water, sleep, steps)
- View personalized diet plans
- Make secure payments via Razorpay
- Receive push notifications
- Use the app in English or Malayalam

---

## 🛠️ Setup

### Requirements
- Flutter SDK `^3.12.2`
- Android SDK 36 / iOS 14+
- Firebase project: `joev-fintess`

### Install dependencies
```bash
flutter pub get
```

### Run (debug)
```bash
flutter run
```

### Build release AAB
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

---

## 🔐 Firebase & Google Sign-In

The app uses Firebase Authentication with:
- **Phone Auth** (Play Integrity verified)
- **Google Sign-In** (with explicit `serverClientId`)

### SHA Fingerprints registered in Firebase (`com.joev.fitness`):
| Type | SHA |
|------|-----|
| Debug SHA-1 | `88:FA:67:74:...:46:3E` |
| Release SHA-1 | `F4:6F:BE:7D:...:12:EE` |
| Play Store SHA-256 | `51:F9:C8:CA:...:01:C0` |

> After adding new SHA fingerprints to Firebase, always download and replace `android/app/google-services.json`.

---

## 📂 Structure

```
jove_client/
├── android/
│   ├── app/
│   │   ├── google-services.json   # Firebase config
│   │   ├── upload-keystore.jks    # Release signing key
│   │   └── build.gradle.kts
│   └── key.properties             # Keystore credentials
├── ios/
├── lib/
│   ├── main.dart
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   ├── otp_screen.dart
│   │   │   └── sign_up_screen.dart
│   │   └── ...
│   └── widgets/
└── pubspec.yaml
```

---

## 📦 Key Dependencies

| Package | Purpose |
|---------|---------|
| `firebase_auth` | Phone & Google Authentication |
| `cloud_firestore` | Database |
| `firebase_storage` | File uploads |
| `google_sign_in` | Google OAuth |
| `razorpay_flutter` | Payments |
| `firebase_messaging` | Push notifications |
| `easy_localization` | i18n (EN/ML) |
| `flutter_blue_plus` | Bluetooth devices |
