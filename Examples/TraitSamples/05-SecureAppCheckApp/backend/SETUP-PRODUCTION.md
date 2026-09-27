# Production Setup: Apple App Attest, Firebase App Check & Jev Proxy

This guide walks through configuring end-to-end hardware-backed device attestation for production iOS/macOS applications using **Apple App Attest**, **Firebase App Check**, and the **Jev Cloud Function Proxy**.

---

## 🏛️ Architecture Flow

```text
┌─────────────────────────┐
│   Native Apple Client   │
│ (iOS 17+ / macOS 14+)   │
└────────────┬────────────┘
             │ 1. Attests device hardware with Apple Secure Enclave
             ▼
┌─────────────────────────┐
│   Firebase App Check    │
│  (Apple App Attest API) │
└────────────┬────────────┘
             │ 2. Issues short-lived signed App Check JWT
             ▼
┌─────────────────────────────────────────────────────────────┐
│  Cloud Function Gateway (`jevProxy`)                        │
│  - Verifies X-Firebase-AppCheck JWT cryptographically        │
│  - Fetches TYPESAFE_API_KEY from GCP Secret Manager         │
└────────────┬────────────────────────────────────────────────┘
             │ 3. Forward request with Bearer API Key
             ▼
┌─────────────────────────┐
│  TypeSafe AI Jev API    │
│  (api.typesafe.ai)      │
└─────────────────────────┘
```

**Zero API keys are embedded into the client binary or IPA package.**

---

## Step 1: Apple Developer Portal Configuration

1. Log in to [developer.apple.com/account](https://developer.apple.com/account).
2. Note your **10-character Team ID** from the top right corner of the portal.
3. Under **Certificates, Identifiers & Profiles** $\to$ **Identifiers**, select your App ID (e.g. `com.company.SecureAppCheckApp`).
4. Ensure the following capabilities are enabled:
   - **App Attest**
   - **Keychain Sharing** (optional, recommended for token persistence)
5. Save and regenerate your provisioning profiles.

---

## Step 2: Firebase App Check Configuration

1. Navigate to the **Firebase Console** $\to$ **Build** $\to$ **App Check**.
2. Select the **Apps** tab and click on your Apple iOS/macOS app.
3. Choose the attestation provider:
   - **App Attest** (Primary for iOS 14+ on physical hardware with Secure Enclave)
   - **DeviceCheck** (Secondary fallback for older devices or specific macOS builds)
4. Enter:
   - **Apple Team ID**: `ABC123XYZ4`
   - **Bundle ID**: `com.company.SecureAppCheckApp`
5. Set token TTL (default is 1 hour).
6. Click **Save**.

---

## Step 3: Development & Simulator Debug Tokens

The Apple Neural Engine and App Attest APIs require real hardware. In development and on Xcode Simulators, you use **App Check Debug Providers**:

### 1. Enable Debug Provider in Client
When initializing Firebase in your Swift codebase:

```swift
#if DEBUG
let providerFactory = AppCheckDebugProviderFactory()
AppCheck.setAppCheckProviderFactory(providerFactory)
#endif
```

### 2. Retrieve Debug Secret from Simulator Logs
Launch the app in the Simulator. In Xcode Console or FlowDeck logs, search for:

```text
[Firebase/AppCheck] Firebase App Check Debug Token:
7A531C28-40F1-4A59-86BC-8A09695C5C2F
```

### 3. Register Debug Token in Firebase Console
1. In Firebase Console $\to$ **App Check** $\to$ **Apps**, click the three vertical dots next to your Apple app.
2. Select **Manage debug tokens**.
3. Click **Add debug token**, paste the UUID from above, and give it a label (e.g. `Peter M4 MacBook Simulator`).
4. Click **Save**.

---

## Step 4: Storing `TYPESAFE_API_KEY` in Secret Manager

Ensure the Cloud Function has access to your production TypeSafe AI key:

```bash
# Using the Firebase CLI
firebase functions:secrets:set TYPESAFE_API_KEY --project <your-project-id>

# Or using Google Cloud CLI
echo -n "ts_live_your_actual_key" | gcloud secrets create TYPESAFE_API_KEY \
    --data-file=- \
    --project <your-project-id> \
    --replication-policy="automatic"
```

Grant Cloud Functions service account permission to read the secret:

```bash
gcloud secrets add-iam-policy-binding TYPESAFE_API_KEY \
    --member="serviceAccount:<project-id>@appspot.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor" \
    --project <your-project-id>
```

---

## Step 5: Deploying & Enforcing App Check

1. Deploy the proxy function:
   ```bash
   cd Examples/TraitSamples/05-SecureAppCheckApp/backend
   firebase deploy --only functions:jevProxy
   ```

2. Test live verification:
   - In the SwiftUI app (`SecureAppCheckApp`), select **Production Cloud Functions** and input your Project ID.
   - Click **Evaluate via Secure Proxy**.
   - Check Cloud Function logs in Google Cloud Console $\to$ Logging:
     ```text
     [Production] Verified App Check claims for app ID: 1:123456789:ios:abc...
     ```

3. **App Check Enforcement**:
   - In the Firebase Console App Check dashboard, review the metrics.
   - Once verified client traffic accounts for 100% of legitimate requests, toggle **Enforcement** to **ON** for Cloud Functions.
   - Unauthenticated requests from bots, curls, or modified binaries will immediately receive `401 Unauthorized` at the Google edge before any compute is consumed.
