# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.2.0] - 2026-09-26

### Added

- **Ergonomic Decision Shortcuts on `LanguageModelSession` (`SystemOneCore/Ergonomics`)**:
  - Implemented high-level ergonomic extensions on Apple's `LanguageModelSession` enabling ad-hoc queries without declaring boilerplate `@Generable` schema types:
    - `session.probability(of:state:criteria:)`: Direct truth probability evaluation ($0.0 \dots 1.0$) for statements against state with optional criteria guidance.
    - `session.choice(_:from:state:)`: Strongly-typed categorical selection across cases of any Swift enum conforming to `Choosable`.
    - `session.choice(_:options:state:)`: Categorical selection among dynamic runtime string arrays.
    - `session.score(_:levels:state:)`: Ordinal rubric scoring returning discrete winner indices and continuous probability-weighted mean scores.
  - Introduced the `Choosable` protocol (`CaseIterable & Hashable & Sendable`) with automatic default identifiers and optional natural-language option descriptions.
  - Introduced `Choice<Option>` container encapsulating winning value, calibrated confidence score, and candidate probability distribution.
  - Introduced `ScoreResult` container encapsulating continuous expected value, winning level index, level label, and complete rubric probability distribution.
  - Implemented `DynamicDecisionSchema` for runtime generation of `GenerationSchema` instances, ensuring ad-hoc queries undergo standard schema translation and retain backend parity across `LayaCoreMLEngine`, `LayaHTTPBackend`, `JevBackend`, and `MockSystemOneBackend`.

- **Swift 6.1 Package Traits Partitioned by Model Boundaries (SE-0402 / SE-0450)**:
  - Upgraded `Package.swift` to `swift-tools-version: 6.1` and adopted package traits.
  - Partitioned traits strictly along **model boundaries** matching developer intent:
    - `Jev`: Enables hosted TypeSafe Jev cloud decision API client (`JevFoundationModels`).
    - `Laya`: Enables on-device Core ML and Apple Neural Engine execution (`LayaOnDevice`).
    - `LayaServe`: Enables HTTP client for self-hosted private `laya-serve` instances (`LayaFoundationModels`).
  - Added convenient persona shorthands:
    - `OnDevice`: Activates `["Laya"]` for zero-network, zero-secret local edge deployments.
    - `Remote`: Activates `["Jev", "LayaServe"]` for networked clients without Core ML neural binaries.
    - `All`: Activates `["Jev", "Laya", "LayaServe"]` for multi-backend showcase applications.
  - Configured `.default(enabledTraits: ["Jev"])` for seamless backwards compatibility.

- **Zero-Dependency `ProxyTransport` for Mobile Reverse Proxies (`JevFoundationModels`)**:
  - Added `ProxyTransport` conforming to `JevTransport` and `Sendable` in `Sources/JevFoundationModels/Transport/ProxyTransport.swift`.
  - Supports zero-trust mobile architectures routing through reverse proxies (e.g., Firebase Cloud Functions, Cloudflare Workers, AWS API Gateway) without embedding API keys in Mach-O binaries.
  - Provides dynamic closure-based `Credential` resolution:
    - `.bearer`: Dynamic OAuth 2.0 / OIDC / Firebase Auth token injection.
    - `.header`: Named header injection (e.g., `X-Firebase-AppCheck` with Apple App Attest / DeviceCheck).
    - `.custom`: In-place request mutations for dynamic HMAC signatures and replay nonces.
  - Evaluates credential resolution **per attempt inside the retry loop**, guaranteeing fresh tokens on retries for consumable single-use or rotating credentials.
  - Features jittered exponential backoff respecting RFC 9110 `Retry-After` headers and latency telemetry via `x-envoy-upstream-service-time`.

- **Standalone Trait Sample Applications (`Examples/TraitSamples/`)**:
  - `01-OfflineLayaApp`: 100% offline document classifier using `LayaOnDevice` and `Choosable` enum categories (`traits: ["Laya"]`).
  - `02-CloudJevWorker`: Lean ticket triage worker querying hosted Jev API with zero ML linkage (`traits: ["Jev"]`).
  - `03-PrivateLayaServer`: Internal VPC cluster ordinal vulnerability scoring (`ScoreResult`) over private HTTP (`traits: ["LayaServe"]`).
  - `04-HybridRouter`: Local-first edge execution escalating to cloud Jev when confidence falls below 0.80 (`traits: ["All"]`).
  - `05-SecureAppCheckApp`: SwiftUI and CLI application utilizing `ProxyTransport` with hardware-backed Firebase App Check (Apple App Attest). Includes production Cloud Function reference, automated deployment wizard `setup-firebase-project.sh`, and `SETUP-PRODUCTION.md`.

- **Technical Notes**:
  - **Tech Note 0009** (`tech-notes/0009-package-traits-and-ergonomic-shortcuts.md`): Architectural analysis of Mattt's `AnyDecisionModel`, dynamic schema generation, and package trait partitioning along model boundaries.
  - **Tech Note 0010** (`tech-notes/0010-proxy-transport-and-dynamic-attestation.md`): Zero-dependency reverse proxy transport architecture, dynamic credential resolution, consumable token retry semantics, and hardware attestation.

### Fixed

- **macOS Keychain Password Prompts in `KeychainService.swift`**:
  - Eliminated legacy macOS keychain queries (`SecItemCopyMatching` / `SecItemAdd` without `kSecUseDataProtectionKeychain`).
  - Prevents system password authorization dialogs when running un-entitled environments (CLI runners, test runners, Xcode previews, un-provisioned dev builds).
  - Adopted shared in-memory fallback store with thread-safe access and reset facilities for clean, isolated test runs.
