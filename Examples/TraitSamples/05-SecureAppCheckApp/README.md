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

## 🚀 Quickstart: Local Emulator Mode (Firebase Emulator Suite)

This sample requires either the local **Firebase Emulator Suite** or a deployed **Google Cloud Function** gateway. In accordance with the project's strict real execution directive, synthetic mock bypasses are not used; if the local emulator is unreachable on port 5001, the application fails fast with a formatted configuration error banner and remediation instructions.

### Missing Configuration Output

If the emulator is not running when running locally:

```text
================================================================================
  ⚠️  CONFIGURATION ERROR: FIREBASE EMULATOR NOT REACHABLE
================================================================================
  The Firebase Local Emulator is required on port 5001 to evaluate the
  App Check secure proxy. Synthetic mock bypasses are not permitted.

  Remediation:
    ./run-emulator-and-cli.sh
    # Or start manually:
    # cd Examples/TraitSamples/05-SecureAppCheckApp/backend
    # firebase emulators:start --only functions
================================================================================
```

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

- In the app UI, select **Local Emulator (Port 5001)** or **Production Cloud Functions**.
- Enter your project ID (or default `demo-project`).
- Click **Evaluate via Secure Proxy**.
- Watch the emulator gateway verify the App Check header and proxy the triage evaluation!

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

---

## 🛠️ CLI Runner & Automated Emulator Testing

You can evaluate the secure proxy directly via the command line or with automated scripts:

### Single Command: Start Emulator & Run CLI
To start the emulator, poll for readiness, execute the CLI decision evaluation, and shut down cleanly:
```bash
./run-emulator-and-cli.sh
```

### Standalone CLI Execution
Run the CLI against an existing emulator or live backend:
```bash
# Against local emulator:
swift run SecureAppCheckApp --cli --emulator

# Against live production gateway:
swift run SecureAppCheckApp --cli --live

# Auto-detects local emulator (requires running emulator on port 5001):
swift run SecureAppCheckApp --cli
```

### Xcode Project (`SecureAppCheckApp.xcodeproj`)
Open `SecureAppCheckApp.xcodeproj` in Xcode 27+ to run the native SwiftUI app on macOS or iOS simulator.
Build with FlowDeck:
```bash
flowdeck build -w Examples/TraitSamples/05-SecureAppCheckApp/SecureAppCheckApp.xcodeproj -s SecureAppCheckApp -D "My Mac"
flowdeck build -w Examples/TraitSamples/05-SecureAppCheckApp/SecureAppCheckApp.xcodeproj -s SecureAppCheckApp -S "iPhone 18 Pro"
```

