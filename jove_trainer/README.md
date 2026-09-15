# JoE.V Trainer App

**Flutter mobile application for JoE.V fitness platform trainers.**

Package: `com.example.jove_trainer` | Version: `1.0.0+1`

---

## 📱 About

The JoE.V Trainer app allows certified personal trainers to:
- View their assigned clients
- Check daily schedule & appointments
- Log client visit notes
- Monitor client health progress
- Support diet consultations

---

## 🛠️ Setup

### Requirements
- Flutter SDK `^3.12.2`
- Android SDK / iOS 14+
- Firebase project: `joev-fintess`

### Install dependencies
```bash
flutter pub get
```

### Run (debug)
```bash
flutter run
```

### Build release APK
```bash
flutter build apk --release
```

---

## 🔐 Firebase

The trainer app uses Firebase:
- **Firestore** – Client & session data
- **Firebase Auth** – Trainer authentication
- **FCM** – Push notifications

Firebase config: `android/app/google-services.json`

---

## 📂 Structure

```
jove_trainer/
├── android/
│   └── app/
│       ├── google-services.json   # Firebase config
│       └── build.gradle.kts
├── ios/
├── lib/
│   ├── main.dart
│   └── screens/
└── pubspec.yaml
```

---

## 📦 Key Dependencies

| Package | Purpose |
|---------|---------|
| `firebase_auth` | Authentication |
| `cloud_firestore` | Database |
| `firebase_messaging` | Push notifications |
| `firebase_storage` | File uploads |
