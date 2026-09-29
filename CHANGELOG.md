# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.2.0] - 2026-09-30

### Added

- **Repository and Package Rename (`SystemOneFoundationModels`)**:
  - Renamed the repository from `jev-foundation-models` to `system-one-foundation-models` and the core SPM package and umbrella library product to `SystemOneFoundationModels`.
  - Reflects multi-model decision support across **Laya on-device Core ML** (Apple Neural Engine), **Laya self-hosted HTTP** (`laya-serve`), and hosted **TypeSafe Jev** cloud endpoints.
  - Modularized targets into focused libraries: `SystemOneCore`, `LayaOnDevice`, `LayaFoundationModels`, `JevFoundationModels`, and the umbrella `SystemOneFoundationModels`.
  - Updated all package dependency manifests, documentation, and Swift Package Index links.

- **`NutritionLabelScanner` Reference iOS Application (`Examples/NutritionLabelScannerApp/`)**:
  - Added native iOS reference application showcasing real-time camera scanning and multi-backend decision modeling for nutrition safety.
  - Implemented live Vision OCR text recognition with spatial 2D row-clustering tolerance (`NutritionLabelParser`) to accurately reconstruct horizontal lines across multi-column tables.
  - Supports multilingual label parsing for European / DACH (`Nährwertdeklaration`, `Brennwert`, `Zutaten`), French, and FDA / US (`Nutrition Facts`, `Serving Size`, `Ingredients`) standards.
  - Strongly-typed dietary safety evaluation via `@Generable` `DietarySafetyDecision` and `DietaryFlag` models, computing allergen risk (0–3) and NOVA food processing classification (0–3).
  - Configurable dietary restriction profiles (vegan, gluten-free, lactose-free, seed-oil-free, low sodium, sugar limits).
  - Features OpenFoodFacts barcode fallback resolution, dynamic bounding box viewfinder overlays, and accessible haptic/audio feedback.

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

- **Technical Notes Expansion (0003 through 0011)**:
  - Documented deep SDK findings, architectural designs, and platform nuances in `tech-notes/`:
    - **Tech Note 0003** (`tech-notes/0003-foundationmodels-dynamic-profiles.md`): Declarative dynamic profiles and session adaptation in Apple Foundation Models (`LanguageModelSession.DynamicProfile`, `DynamicProfileBuilder`, `@SessionPropertyEntry`, turn isolation).
    - **Tech Note 0004** (`tech-notes/0004-secure-mobile-transport-appcheck.md`): Production mobile architecture securing TypeSafe credentials using Apple App Attest / DeviceCheck hardware attestation, Firebase Cloud Functions proxy, and `JevTransport`.
    - **Tech Note 0005** (`tech-notes/0005-spm-dependency-isolation-and-vendor-transports.md`): SPM dependency isolation and decoupling vendor-specific transports from core targets to prevent dependency creep.
    - **Tech Note 0006** (`tech-notes/0006-http-resilience-and-confidence-routing.md`): HTTP resilience, RFC 9110 `Retry-After` parsing, exponential backoff, cooperative cancellation safety, and calibrated confidence routing for the undecided band (`0.35...0.65`).
    - **Tech Note 0007** (`tech-notes/0007-pluggable-system-one-backends-and-laya-serve.md`): Pluggable `SystemOneBackend` protocol architecture, wire protocol parity between TypeSafe Jev `/v1/systemone` and self-hosted `laya-serve`, and dynamic header injection.
    - **Tech Note 0008** (`tech-notes/0008-on-device-coreml-decision-engine.md`): On-device decision models via Core ML and Apple Neural Engine (ANE), ModernBERT/mmBERT compilation, option marker gathering, 8-bit quantization, and zero-dependency Swift tokenization.
    - **Tech Note 0009** (`tech-notes/0009-package-traits-and-ergonomic-shortcuts.md`): Architectural analysis of `AnyDecisionModel`, runtime dynamic schema synthesis (`DynamicDecisionSchema`), ergonomic shortcuts (`.probability()`, `.choice()`, `.score()`), `Choosable` protocol, and model-bounded package traits.
    - **Tech Note 0010** (`tech-notes/0010-proxy-transport-and-dynamic-attestation.md`): Zero-dependency reverse proxy transport architecture, dynamic `Credential` enum (`.bearer`, `.header`, `.custom`), per-attempt token acquisition inside retry loops, and secret-free mobile binaries.
    - **Tech Note 0011** (`tech-notes/0011-xcode-27-2-json-xcproj-format.md`): Adoption of Xcode 27.2+ native JSON project format (`project.xcproj`) replacing legacy OpenStep `.pbxproj` for human and AI agent ergonomics.

### Fixed

- **macOS Keychain Password Prompts in `KeychainService.swift`**:
  - Eliminated legacy macOS keychain queries (`SecItemCopyMatching` / `SecItemAdd` without `kSecUseDataProtectionKeychain`).
  - Prevents system password authorization dialogs when running un-entitled environments (CLI runners, test runners, Xcode previews, un-provisioned dev builds).
  - Adopted shared in-memory fallback store with thread-safe access and reset facilities for clean, isolated test runs.

---

## [0.1.0] - 2026-09-21

### Added

- Initial release of the native Apple Foundation Models bridge for TypeSafe Jev.
- Direct integration with `LanguageModel`, `LanguageModelExecutor`, and `@Generable`.
- Decision primitive mapping for boolean statements (`noul`), categorical enums (`choice`), and ordinal rubrics (`score`).
- CLI demonstration tools: `ticket-triage-demo`, `duplicate-article-demo`, and `file-organizer-demo`.
- Technical notes 0001 (`tech-notes/0001-afm-decision-model-bridging.md`) and 0002 (`tech-notes/0002-foundationmodels-generation-quirks.md`).

[0.2.0]: https://github.com/peterfriese/system-one-foundation-models/compare/0.1.0...0.2.0
[0.1.0]: https://github.com/peterfriese/system-one-foundation-models/releases/tag/0.1.0
