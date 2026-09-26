# 05-SecureAppCheckApp: Zero-Secret Hardware-Attested Gateway

This sample demonstrates securing TypeSafe AI decision models using **`ProxyTransport`**, **Firebase App Check (Apple App Attest)**, and **Google Cloud Secret Manager**.

Upstream API keys are **never bundled in client binaries**; requests are cryptographically signed by the device's **Apple Secure Enclave** and validated by a 2nd Gen Cloud Function before dispatching to Jev.

---

## SPM Trait Configuration

This package links **only** the `Jev` trait of `SystemOneFoundationModels`:

```swift
// Package.swift
dependencies: [
    .package(name: "SystemOneFoundationModels", path: "../../..", traits: ["Jev"])
],
targets: [
    .executableTarget(
        name: "SecureAppCheckApp",
        dependencies: [
            .product(name: "SystemOneFoundationModels", package: "SystemOneFoundationModels")
        ]
    )
]
```

---

## 🔒 Architectural Overview

```text
┌──────────────────────────────┐
│  SwiftUI App (App.swift)     │
│  ProxyTransport:             │
│  .header("X-Firebase-AppCheck")
└──────────────┬───────────────┘
               │
               ▼ HTTP POST
┌──────────────────────────────┐
│  Firebase 2nd Gen Function   │
│  (backend/functions)         │
│  1. Verifies App Check Token │
│  2. Reads TYPESAFE_API_KEY   │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│  TypeSafe AI Jev API         │
│  api.typesafe.ai/v1/systemone│
└──────────────────────────────┘
```

---

## 🚀 Quickstart: Local Emulator Mode (Offline Testing)

You can run and test the complete pipeline locally without deploying anything to Google Cloud:

### 1. Start the Firebase Emulator Suite

```bash
cd Examples/TraitSamples/05-SecureAppCheckApp/backend
firebase emulators:start --only functions,appCheck
```

The emulator suite starts:
- Functions on `http://127.0.0.1:5001`
- App Check on `http://127.0.0.1:9099`
- Emulator UI on `http://127.0.0.1:4000`

### 2. Run the SwiftUI App

In another terminal window:

```bash
cd Examples/TraitSamples/05-SecureAppCheckApp
swift run SecureAppCheckApp
```

- In the app UI, select **Local Emulator (Port 5001)** or **Simulated Gateway (Offline)**.
- Enter your project ID (or default `demo-project`).
- Click **Evaluate via Secure Proxy**.
- Watch the simulated or emulator gateway verify the App Check header and proxy the triage evaluation!

---

## 🌐 Production Deployment

To deploy to real Google Cloud infrastructure with hardware App Attest:

1. Run the interactive setup wizard:
   ```bash
   cd Examples/TraitSamples/05-SecureAppCheckApp/backend
   ./setup-firebase-project.sh
   ```

2. Register your Apple Team ID and configure debug tokens following:
   `backend/SETUP-PRODUCTION.md`

3. In the client app, select **Production Cloud Functions** and evaluate tickets directly against your live deployed gateway.
