# Development of an AI-Driven Mobile Crop Disease Detection System for Small-Scale Farmers in Nketoana Local Municipality

IPJ527C: Advanced Research Project B — Assessment 3 (Beta Version Demonstration)

**Student:** Anna Mapakiso Mosala | **Student Number:** 220008504 | **Supervisor:** Dr Paulina Phoobane

**Repository:** https://github.com/Anna560-coder/AI-Crop-Disease-Detection

---

## Overview

**Crop Doctor** is an Android app that lets small-scale farmers in Nketoana Local Municipality photograph a mango leaf and get an on-device AI diagnosis (disease, severity, symptoms and treatment), plain-language AI advice they can ask follow-up questions about, a history of every scan, and market prices, seasonal tips and disease alerts posted by Agriculture Experts.

This is the **Beta version**. It completes the core scope approved in IPJ517C and adds the Agriculture Expert role, which was outstanding at the Alpha stage.

## Beta Access for the Lecturer

**Install:** download the APK from the link submitted on eThuto, open it on an Android phone and allow "Install unknown apps" when asked.

| Role | Email | Password |
|---|---|---|
| Farmer | lecturer.farmer@cropdoctor.test | CropDemo#2026 |
| Agriculture Expert | lecturer.expert@cropdoctor.test | CropDemo#2026 |

These are dedicated test accounts. You can also create your own farmer account with **Create a free account**.

**Suggested test:** log in as the expert and post an Alert with a photo; log in as the farmer, see the red badge on Market Updates, then check a leaf (place one leaf on white paper) and ask the AI a follow-up question.

## Core Functions and Status

| Function | Status |
|---|---|
| Farmer registration, login, password reset | Implemented |
| Photo capture (camera) and upload (gallery) | Implemented |
| On-device disease detection, 8 mango leaf classes | Implemented (98.8% on held-out test leaves) |
| "Not a leaf" rejection of non-leaf photos | Implemented (beta addition) |
| Structured diagnosis: severity, symptoms, treatment | Implemented |
| AI advisory with follow-up questions ("Ask the AI") | Implemented (beta addition) |
| Detection history with details and delete | Implemented |
| Agriculture Expert role: post updates with photos, expiry and delete | Implemented (outstanding at Alpha) |
| Farmer market updates feed with unread badge | Implemented |
| Role-based security rules | Implemented and deployed |
| First-launch guide and farmer-friendly interface | Implemented (supervisor feedback) |
| Weather forecast | Outstanding |
| Admin tools inside the app | Partially implemented (managed in Firebase console) |

## Technology Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Android first) |
| Authentication & Database | Firebase Authentication, Cloud Firestore with security rules |
| Disease detection | TensorFlow Lite, MobileNetV2 transfer learning, 8 leaf classes + "Not a leaf", runs offline on the phone ([method and results](tools/model_training/README.md)) |
| AI advisory | Groq API, model openai/gpt-oss-20b |

## Scope Changes Since IPJ517C

- **AI provider:** Groq (openai/gpt-oss-20b) instead of the Gemini API in the proposal; the function (plain-language treatment advice) is the same.
- **Disease classes:** expanded from 3 classes at Alpha to the 8 MangoLeafBD classes, plus a "Not a leaf" class added after testing showed the model named a disease for any photo.
- **Expert photos** are stored inside the post (resized to 800 px) rather than in Firebase Storage, to avoid extra storage configuration.

## Run from Source

1. `git clone https://github.com/Anna560-coder/AI-Crop-Disease-Detection.git`
2. `flutter pub get`
3. Copy `env.example.json` to `env.json` and add a Groq API key (`env.json` is git-ignored).
4. Connect an Android emulator or phone and run `flutter run --dart-define-from-file=env.json` (in VS Code, F5 does this).

Firebase is already configured in `lib/firebase_options.dart`. Security rules are in `firestore.rules` (deploy with `firebase deploy --only firestore:rules`).

## Testing Summary

- **Beta:** 17 automated unit tests (`flutter test`), 36 security-rule tests on the Firestore emulator, and a model evaluation on held-out images: 98.8% of 489 test leaves classified correctly (original model 90.6%) and 80 of 80 independent non-leaf images rejected (original model 0 of 80).
- **Alpha:** 7 functional test cases on the core workflow passed; 5 defects found and resolved (documented in the Alpha documentation).

## Known Limitations

- The model was trained on single leaves photographed on a plain background; leaves photographed on the tree are untested, so the app asks farmers to lay the leaf on white paper.
- Leaves from other crops are not recognised as "not a mango leaf".
- The Groq API key is kept out of the repository but is embedded in the compiled app; a server-side proxy is planned.
- AI chat conversations are not saved after the screen is closed.

## Ethical, Privacy and Security Considerations

- Each farmer can read only their own detection history; only experts can post and only their own posts can be deleted; nobody can change their own role (enforced by `firestore.rules`).
- Leaf photos from scans stay on the farmer's phone; only the diagnosis is stored online.
- AI answers carry a note to consult the local agricultural extension officer for serious problems.

## Next Steps

- Weather forecast for spraying and planting decisions.
- Sesotho language support.
- Test and retrain the model with leaves photographed in the field.
- Move Groq calls behind a server-side function; save AI chats.
- Admin tools in the app for managing experts and disease information.
