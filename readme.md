# 🏋️ JoE.V – Smart Home Fitness Platform

> **Experience the Next Level of Fitness**

JoE.V is a modern fitness platform that connects clients with certified personal trainers for personalized home-based fitness coaching. The platform provides a seamless experience for clients, trainers, and administrators through dedicated Flutter mobile apps and a React.js web admin panel.

---

## 📱 Apps

| App | Package | Platform | Description |
|-----|---------|----------|-------------|
| **JoE.V Client** | `com.joev.fitness` | Android / iOS | Client-facing Flutter app |
| **JoE.V Trainer** | `com.example.jove_trainer` | Android / iOS | Trainer-facing Flutter app |
| **Admin Panel** | Web | Browser | React.js admin dashboard |

---

## 🚀 Features

### 👤 Client App (`jove_client`)
- Phone & Google Sign-In (Firebase Authentication)
- Book, Reschedule & Cancel Training Sessions
- Track Weight, BMI, Water Intake, Sleep & Daily Steps
- Personalized Diet Plans from Trainer
- Progress Analytics & Charts
- Secure Online Payments (Razorpay)
- Push Notifications (FCM)
- Multilingual Support (English & Malayalam)
- Bluetooth Device Integration

### 💪 Trainer App (`jove_trainer`)
- Manage Assigned Clients
- View Daily Schedule & Appointments
- Update Client Visit Notes
- Monitor Client Progress & Health Metrics
- Diet Consultation Support

### 🛠️ Admin Panel (`admin`)
- Dashboard & Analytics
- Manage Clients & Trainers
- Appointment Management
- Subscription & Payment Tracking
- Reports & Insights
- Notification Management

---

## 🏗️ Tech Stack

### Mobile
- **Flutter** (Dart) – Cross-platform mobile (Android & iOS)
- **Firebase** – Auth, Firestore, Cloud Functions, Storage, FCM
- **Razorpay** – Payment gateway

### Web Admin
- **React.js** – Admin dashboard
- **Firebase Firestore** – Real-time database

### Backend
- **Firebase Cloud Functions** (Node.js) – Serverless backend

### Authentication
- Firebase Phone Authentication (OTP)
- Google Sign-In
- Firebase App Check (Play Integrity)

---

## 📂 Project Structure

```
JoE.V_Fitness/
│
├── jove_client/         # Flutter Client App (com.joev.fitness)
│   ├── android/         # Android-specific config
│   │   ├── app/
│   │   │   ├── google-services.json
│   │   │   ├── upload-keystore.jks
│   │   │   └── build.gradle.kts
│   │   └── key.properties
│   ├── ios/             # iOS-specific config
│   ├── lib/             # Dart source code
│   │   ├── screens/     # UI screens
│   │   ├── widgets/     # Reusable widgets
│   │   └── main.dart
│   └── pubspec.yaml
│
├── jove_trainer/        # Flutter Trainer App (com.example.jove_trainer)
│   ├── android/
│   ├── ios/
│   └── lib/
│
├── admin/               # React.js Admin Dashboard
│
├── functions/           # Firebase Cloud Functions (Node.js)
│
├── firestore.rules      # Firestore Security Rules
├── firestore.indexes.json
├── firebase.json
└── README.md
```

---

## 🔐 Firebase Configuration

### SHA Certificate Fingerprints (`com.joev.fitness`)

| Type | Usage | SHA |
|------|-------|-----|
| Debug SHA-1 | Local dev | `88:FA:67:74:EA:7F:C9:55:CC:CF:AC:D2:61:4A:40:D6:27:FA:46:3E` |
| Release SHA-1 | Upload key | `F4:6F:BE:7D:F4:C0:07:79:56:30:30:4A:1C:1A:3E:5A:DD:49:12:EE` |
| Play Store SHA-256 | Production (Play Integrity / Phone Auth) | `51:F9:C8:CA:26:AC:E9:12:AF:0D:B4:C8:3B:10:DD:31:C7:59:D8:CF:58:BF:D1:1B:CD:9F:7A:A6:DB:1A:01:C0` |

> ⚠️ All SHA fingerprints must be registered in **Firebase Console → Project Settings → Your Apps → com.joev.fitness** for Google Sign-In and Phone Auth to work on Play Store builds.

### App Check
- **Status:** Monitoring (not enforced) — allows all builds to authenticate
- **Play Integrity** is used for Phone Auth verification

---

## 🛠️ Local Development Setup

### Prerequisites
- Flutter SDK (3.x)
- Android Studio / VS Code
- Firebase CLI
- Node.js (for Cloud Functions)

### Client App
```bash
cd jove_client
flutter pub get
flutter run
```

### Trainer App
```bash
cd jove_trainer
flutter pub get
flutter run
```

### Build Release AAB (Client)
```bash
cd jove_client
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

---

## 🚀 Deployment

### Android (Google Play)
1. Build AAB: `flutter build appbundle --release`
2. Upload to **Google Play Console** → Closed Testing / Production
3. Google Play signs the app with **Play App Signing**

> **Important:** After uploading a new release, download the updated `google-services.json` from Firebase Console and replace it in `jove_client/android/app/` before building again.

### Firebase
```bash
firebase deploy --only functions
firebase deploy --only firestore:rules
```

---

## 🔮 Future Enhancements

- 🤖 AI-based Fitness Recommendations
- ⌚ Wearable Device Integration
- 📹 Video Consultation
- 🎥 Live Workout Sessions
- 🏆 Fitness Challenges & Rewards
- 🍽️ AI Diet Planner
- 📋 Health Report Generation

---

## 📄 License

This project is licensed under the MIT License.

---

## 👨‍💻 Developed By

**JoE.V Development Team** — Building the future of personalized home fitness.
