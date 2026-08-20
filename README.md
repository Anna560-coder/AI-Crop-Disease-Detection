# AI-Driven Mobile Crop Disease Detection System

**for Small-Scale Farmers in Nketoana Local Municipality**

IPJ527C: Advanced Research Project B — Assignment 1 (Alpha Version Demonstration)

**Student:** Anna Mapakiso Mosala | **Student Number:** 220008504 | **Supervisor:** Dr Paulina Phoobane

**Repository:** https://github.com/Anna560-coder/AI-Crop-Disease-Detection

---

## Overview

A mobile application that lets small-scale farmers in Nketoana Local Municipality photograph a crop leaf and receive an AI-generated disease diagnosis (label, symptoms, severity and confidence score), along with plain-language, AI-generated treatment advice. Every diagnosis is saved to the farmer's personal detection history for future reference.

This is the **Alpha version**: it demonstrates the core, prioritised end-to-end workflow approved in IPJ517C — account creation, photo-based disease detection, diagnosis, AI advisory recommendations, and detection history — running on a real device/emulator with a live Firebase backend.

## Technology Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (cross-platform mobile) |
| Authentication & Database | Firebase (Authentication, Cloud Firestore) |
| AI Disease Detection | TensorFlow Lite — MobileNet model, fine-tuned for 3 disease classes |
| AI Advisory | Groq API (llama-3.1-8b-instant) |

## Functions Implemented (Alpha Version)

- User registration and login (Firebase Authentication), including handling of duplicate-email and invalid-credential errors
- Image capture (camera) and image upload (gallery)
- AI-based disease detection across 3 classes: Gall Midge, Healthy, Sooty Mould (98–99% confidence in testing)
- Structured diagnosis (symptoms, severity level, crop type) via a Firestore reference lookup joined to the model's output
- AI-generated treatment recommendations via the Groq API
- Detection history, scoped to the logged-in farmer, with delete functionality
- Farmer requirements survey conducted to inform the design (Google Forms, submitted under IPJ517C)

> See the Requirements & Feature Checklist in the Alpha Version Documentation Trio for the full traceability of each item back to the approved IPJ517C objectives.

## How to Run / Access the System

1. Clone the repository:
   ```
   git clone https://github.com/Anna560-coder/AI-Crop-Disease-Detection.git
   ```
2. Install Flutter dependencies:
   ```
   flutter pub get
   ```
3. Ensure `firebase_options.dart` is present and configured for the project's Firebase instance (included in the repository so the marker does not need to create a separate Firebase project).
4. Connect an Android emulator or a physical Android device.
5. Run the app:
   ```
   flutter run
   ```
6. From the app's welcome screen, either create a new farmer account via Sign Up, or sign in directly using the test login details below.

> If a live device/emulator cannot be set up before marking, the same workflow is shown end-to-end in the live demonstration on 21 August 2026, and in the presentation's demo section.

## Test Login Details

| Field | Value |
|---|---|
| Email | malucky@gmail.com |
| Password | Test1234 |

> This account already has sample detection history saved, so you can view the Detection History screen without first running a diagnosis.

## Incomplete Functions / Known Limitations

- **Agriculture Expert role** — not yet implemented. Planned as a second user role, alongside Farmer, able to post market price updates, seasonal advice and alerts for farmers to view. Deferred because it also requires role-based access control beyond the current Alpha scope.
- **Weather forecast** — not yet implemented. Planned integration with a third-party weather API (e.g. OpenWeatherMap) so farmers can see a local forecast alongside their diagnosis, supporting decisions on spraying, planting and harvest timing.
- **UI/UX visual polish** — the interface is functional but not yet visually refined. A more polished, consistent, farmer-friendly design is planned before final submission.
- **Role-based Firestore security rules** — partially implemented. Current rules permit any authenticated user full read/write access. This is functional for the Alpha demo but must be scoped by role and record ownership before the Agriculture Expert role above can be safely introduced.
- **AI advisory provider** — implemented using the Groq API (llama-3.1-8b-instant) rather than the Gemini API originally specified in the approved IPJ517C proposal. Functionally equivalent; disclosed here as a scope adjustment, not a defect.
- **Single-turn AI advisory** — "Ask for More Recommendations" currently sends one fixed prompt and returns a single static response. A planned upgrade ("Ask the AI Anything") will let farmers type their own follow-up questions in an open, multi-turn conversation.
- **API key handling** — the Groq API key is currently referenced directly in source code rather than in secure/server-side storage. Migrating this is a prioritised next step before any production deployment.
- **Disease class coverage** — currently limited to 3 classes (Gall Midge, Healthy, Sooty Mould). Expanding coverage is a priority for the next development stage.

## Testing Summary

7 functional test cases were run against the core workflow (registration, login, image capture, disease detection, diagnosis, AI advisory, detection history) — all passed. 5 defects were found and resolved during development (an expired Firestore test-mode rule, an expired Groq API key, a duplicated function silently blocking history saves, a Firestore data-entry error, and one confirmed non-defect). Full test cases, inputs/outputs and defect records are documented in the Alpha Version Documentation Trio submitted alongside this README.

## Ethical, Privacy and Security Considerations

- Farmer data (diagnosis records, images) is stored in Cloud Firestore and is currently accessible to any authenticated user under the Alpha version's rules (see Limitations above — role/ownership scoping is a prioritised next step).
- No personally identifying information beyond account email is collected by the app itself; farmer survey data was collected separately under IPJ517C ethical clearance.
- API keys and credentials should not remain in source code in a public repository long-term; this is addressed as a prioritised next step.

## Prioritised Next Steps

- Implement the Agriculture Expert role and role-based Firestore security rules together, so market updates can be introduced safely.
- Integrate weather forecast functionality.
- Upgrade AI advisory to a multi-turn, farmer-driven chat ("Ask the AI Anything").
- Refine the UI/UX with a more polished, farmer-accessible visual design.
- Expand disease classification coverage beyond the current three classes.
- Migrate API key handling out of source code into secure storage.


