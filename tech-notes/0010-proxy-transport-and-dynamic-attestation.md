# 0010 — Dynamic Credential Resolution & Reverse Proxying with ProxyTransport

- **Date**: 2026-09-26
- **Author**: Peter Friese
- **Framework**: `FoundationModels` (iOS 27.0+, macOS 27.0+), `Security`, `Network`, `JevFoundationModels`
- **Upstream**: Apple App Attest (`DeviceCheck`), Firebase App Check, Cloudflare Turnstile, OAuth 2.0 / OIDC, TypeSafe AI Jev

---

## Context

Production mobile deployments of System One decision models face a critical security requirement: **client-side applications must never bundle long-lived upstream cloud API keys (`TYPESAFE_API_KEY`) within their application binary**.

Static secrets embedded in compiled Mach-O binaries are readily recoverable through binary disassembly tools (`strings`, Hopper, Ghidra) or runtime memory analysis. Furthermore, client-side HTTPS traffic can be inspected on supervised or jailbroken devices using local proxy tools (Proxyman, Charles, mitmproxy). A leaked master key exposes the organisation's TypeSafe AI account quota, billing balances, and proprietary decision configurations to abuse.

To eliminate this threat vector, mobile clients must route their decision queries through an **authenticated reverse proxy gateway** (such as Firebase Cloud Functions v2, Cloudflare Workers, AWS API Gateway, or a corporate Kubernetes ingress) that validates client authenticity before injecting the secret master key server-side.

Historically, bridging this flow into `JevFoundationModels` presented an architectural challenge:
1. **The Dependency Dilemma (Tech Note 0005):** As documented in [Tech Note 0005](0005-spm-dependency-isolation-and-vendor-transports.md), `JevFoundationModels` enforces a strict mandate of **Zero External Third-Party Runtime Dependencies**. Directly linking vendor SDKs (e.g., `firebase-ios-sdk`, AWS SDK, or Auth0) in `Package.swift` would force all consumers to resolve large transitive dependency trees, increasing clean build times from ~1 second to over 45 seconds.
2. **Maintenance Overhead of Reference Code:** Previously, developers were directed to copy an unmanaged reference file (`FirebaseAppCheckTransport.swift`) from an `Integrations/` directory directly into their app targets. While this bypassed SPM target sandboxing, it forced developers to manually maintain boilerplate transport logic, HTTP error handling, timing metrics, and retry backoff.
3. **Token Rotation & Stale Retries:** Authenticated gateways frequently rely on dynamic, short-lived, or consumable credentials:
   - **Apple App Attest / Firebase App Check tokens:** Valid for up to 1 hour, or consumable single-use tokens valid for a single request.
   - **OAuth 2.0 / OIDC access tokens:** Ephemeral bearer tokens subject to automated refresh cycles.
   - **Dynamic HMAC signatures:** Calculated per-request timestamps and nonce non-replay headers.

If an HTTP transport caches a single static token at initialization, network retries against rate limits (`429 Too Many Requests`) or token expiration (`401 Unauthorized`) will repeatedly fail with stale credentials.

This tech note documents the design and architecture of `ProxyTransport`, a built-in, zero-dependency transport in `JevFoundationModels` providing **dynamic credential resolution**, **per-attempt token re-acquisition**, and **resilient reverse proxying**.

---

## Findings

### 1. The Architecture of `ProxyTransport`

`ProxyTransport` conforms to `JevTransport` and `Sendable`, residing directly within `Sources/JevFoundationModels/Transport/ProxyTransport.swift`:

```swift
public struct ProxyTransport: JevTransport, Sendable {
    public enum Credential: Sendable {
        case bearer(@Sendable () async throws -> String)
        case header(name: String, prefix: String? = nil, provider: @Sendable () async throws -> String)
        case custom(@Sendable (inout URLRequest) async throws -> Void)
    }

    public let proxyEndpoint: URL
    public let credential: Credential
    public let session: URLSession
    public let timeoutInterval: TimeInterval
    public var retryPolicy: RetryPolicy

    public init(
        proxyEndpoint: URL,
        credential: Credential,
        session: URLSession = .shared,
        timeoutInterval: TimeInterval = 30,
        retryPolicy: RetryPolicy = .default
    ) { ... }
}
```

Key architectural characteristics:
- **Universal Gateway Redirection:** All outbound requests serialize standard `JevRequest` JSON and dispatch to `proxyEndpoint` rather than the default `api.typesafe.ai` URL.
- **Server Timing Extraction:** Automatically captures upstream execution latency from gateway proxy headers (such as `x-envoy-upstream-service-time`) and assigns it to `JevResponse.serverDurationMs`.
- **Configurable Resilience:** Integrates full `RetryPolicy` support, honouring RFC 9110 `Retry-After` headers and randomized exponential backoff with cooperative task cancellation.

### 2. The `Credential` Abstraction

The `Credential` enum decouples the transport from any specific authentication vendor, supporting three primary integration patterns:

| Case | Target Pattern | Mechanism | Example Header Output |
| :--- | :--- | :--- | :--- |
| `.bearer(provider)` | OAuth 2.0, OIDC, JWT session tokens | Evaluates async string provider closure | `Authorization: Bearer <token>` |
| `.header(name, prefix, provider)` | Firebase App Check, Cloudflare Turnstile, custom API gateways | Evaluates async string provider, formats with optional prefix | `X-Firebase-AppCheck: <token>` or `X-Custom-Key: Key <token>` |
| `.custom(modifier)` | Complex multi-tenant gateways, HMAC signatures, multi-header auth | Passes mutable `inout URLRequest` to async closure | Arbitrary headers, query parameters, or request metadata |

### 3. Per-Attempt Dynamic Token Acquisition Inside the Retry Loop

A subtle bug in naive custom transport implementations is resolving credentials once before entering the retry loop:

```swift
// ANTI-PATTERN: Resolving credentials outside the retry loop
let token = try await provider() // Evaluated once!
while attempt <= maxAttempts {
    var req = URLRequest(url: endpoint)
    req.setValue(token, forHTTPHeaderField: "Authorization")
    let (data, res) = try await session.data(for: req)
    // If res is 401 or 429, subsequent attempts reuse the expired or rejected token!
}
```

In `ProxyTransport`, credential application occurs **strictly inside the attempt loop**:

```swift
var attempt = 1
while true {
    var urlRequest = URLRequest(url: proxyEndpoint)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.timeoutInterval = timeoutInterval
    urlRequest.httpBody = requestData

    // Apply configured credentials for each attempt to support rotating/refreshed tokens
    try await applyCredential(to: &urlRequest)

    let data: Data
    let response: URLResponse
    do {
        (data, response) = try await session.data(for: urlRequest)
    } catch is CancellationError {
        throw CancellationError()
    } ...
```

This guarantees:
1. **Automatic Token Refresh:** If an OAuth token or App Check token expires during backoff or between attempts, the provider closure fetches a freshly minted or refreshed token on attempt $N+1$.
2. **Replay-Protected Consumable Tokens:** When using Firebase App Check limited-use tokens (`limitedUseToken()`), each retry attempt mints a new non-consumed token, avoiding immediate `401 Token Already Consumed` rejections on retried requests.
3. **Dynamic HMAC Timestamping:** Custom signature modifiers recalculate accurate request timestamps and nonces on each attempt.

### 4. Zero-Dependency Closure Injection Pattern (Referencing Tech Note 0005)

[Tech Note 0005](0005-spm-dependency-isolation-and-vendor-transports.md) highlighted why `#if canImport(...)` fails within SPM package targets and proved that adding vendor dependencies to `Package.swift` causes unacceptable dependency bloat.

`ProxyTransport` resolves this dilemma using **Closure-Based Inversion of Control**:
- `JevFoundationModels` compiles purely against standard Apple platform frameworks (`Foundation`, `Security`, `Network`). It imports zero third-party packages.
- The consuming application links its preferred identity and attestation frameworks (e.g. `FirebaseAppCheck`, `GoogleSignIn`, `AWSMobileClient`).
- At the initialization boundary, the app passes an inline `@Sendable () async throws -> String` closure invoking the vendor SDK.

```
┌─────────────────────────────────────────────────────────┐
│              Consuming iOS / macOS Target               │
│  • Imports FirebaseAppCheck / DeviceCheck               │
│  • Holds hardware key in Secure Enclave                 │
│  • Injects closure: { try await AppCheck.token() }      │
└────────────────────────────┬────────────────────────────┘
                             │ passes closure
                             ▼
┌─────────────────────────────────────────────────────────┐
│          JevFoundationModels (ProxyTransport)           │
│  • ZERO vendor dependencies (pure Swift + URLSession)   │
│  • Invokes closure per retry attempt                    │
│  • Dispatches payload to reverse proxy                  │
└─────────────────────────────────────────────────────────┘
```

This delivers the ideal balance:
- **Zero package dependencies** in the core SPM manifest.
- **Full first-class library support** without copying unmanaged source files into user projects.
- **Complete type safety and Swift 6 Sendability** across concurrency boundaries.

---

## Implications & Call-Site Design

### 1. Firebase App Check with Apple App Attest (Standard & Consumable)

For mobile apps routing through a Firebase Cloud Function proxy:

```swift
import FoundationModels
import JevFoundationModels
import FirebaseAppCheck

// Standard cached strategy (< 1 ms in-memory token lookup)
let cachedTransport = ProxyTransport(
    proxyEndpoint: URL(string: "https://us-central1-myproject.cloudfunctions.net/systemone")!,
    credential: .header(name: "X-Firebase-AppCheck") {
        try await AppCheck.appCheck().token(forcingRefresh: false).token
    }
)

// Single-use consumable strategy (strict replay protection for high-value decisions)
let replayProtectedTransport = ProxyTransport(
    proxyEndpoint: URL(string: "https://us-central1-myproject.cloudfunctions.net/systemone")!,
    credential: .header(name: "X-Firebase-AppCheck") {
        try await AppCheck.appCheck().limitedUseToken().token
    }
)

let session = LanguageModelSession(model: JevLanguageModel(transport: cachedTransport))
```

### 2. Corporate API Gateway with OAuth 2.0 / OIDC Bearer Tokens

For enterprise internal apps communicating with a private ingress gateway requiring dynamic user tokens:

```swift
let oauthTransport = ProxyTransport(
    proxyEndpoint: URL(string: "https://gateway.internal.company.com/v1/systemone")!,
    credential: .bearer {
        // Asynchronously retrieves or refreshes user session token
        try await AuthenticationManager.shared.validAccessToken()
    },
    timeoutInterval: 15,
    retryPolicy: RetryPolicy(maxAttempts: 3)
)

let session = LanguageModelSession(model: JevLanguageModel(transport: oauthTransport))
```

### 3. Multi-Tenant Gateway with Dynamic Signing Headers

For edge architectures requiring custom multi-tenant headers and cryptographic HMAC signatures:

```swift
let customTransport = ProxyTransport(
    proxyEndpoint: URL(string: "https://edge.api.company.com/systemone")!,
    credential: .custom { request in
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let signature = try await CryptoSigner.sign(requestBody: request.httpBody, timestamp: timestamp)
        
        request.setValue("tenant-enterprise-42", forHTTPHeaderField: "X-Tenant-ID")
        request.setValue(timestamp, forHTTPHeaderField: "X-Request-Timestamp")
        request.setValue(signature, forHTTPHeaderField: "X-Signature-SHA256")
    }
)
```

### 4. Direct Ergonomic Decision Evaluation Through Proxy

`ProxyTransport` seamlessly supports all Apple Foundation Models evaluation mechanisms, including composite `@Generable` schemas and ergonomic session shortcuts:

```swift
// Evaluates binary probability via proxy
let isFraud = try await session.probability(
    of: "Does this transaction exhibit anomalous velocity?",
    state: transactionDetails
)

// Evaluates categorical choice via proxy
let priority = try await session.choice(
    "Determine escalation level",
    from: IncidentPriority.self,
    state: serverAlertLog
)
```

---

## Sources & Cross-References

- **Tech Notes**:
  - [Tech Note 0004 — Secure Mobile Transport with Firebase App Check & Apple App Attest](0004-secure-mobile-transport-appcheck.md)
  - [Tech Note 0005 — SPM Dependency Isolation & Decoupling Vendor Transports](0005-spm-dependency-isolation-and-vendor-transports.md)
  - [Tech Note 0006 — HTTP Resilience, RFC 9110 Backoff & Calibrated Decision Routing](0006-http-resilience-and-confidence-routing.md)
  - [Tech Note 0009 — Package Traits & Ergonomic Decision Shortcuts](0009-package-traits-and-ergonomic-shortcuts.md)
- **Reference Code & Tests**:
  - `Sources/JevFoundationModels/Transport/ProxyTransport.swift`
  - `Tests/JevFoundationModelsTests/ProxyTransportTests.swift`
  - `Examples/TraitSamples/05-SecureAppCheckApp/`
- **Guides**:
  - [Mobile Security Guide](../docs/mobile-security.md)
  - [Resilience & Retries Guide](../docs/resilience-and-retries.md)
