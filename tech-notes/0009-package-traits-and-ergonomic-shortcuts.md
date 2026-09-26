# 0009 — Package Traits & Ergonomic Decision Shortcuts in System One Foundation Models

- **Date**: 2026-09-26
- **Author**: Peter Friese
- **Framework**: `PackageDescription` (Swift 6.1+), `FoundationModels` (iOS 27.0+, macOS 27.0+), `SystemOneCore`
- **Upstream**: Swift Evolution SE-0402 (Package Traits), TypeSafe AI Jev, NandhaKishorM/laya

---

## Context

The initial integration of System One decision models with Apple's Foundation Models framework established a strictly typed, macro-driven developer workflow: developers defined a `@Generable struct` or `@Generable enum`, provided `@Guide` annotations, and invoked `session.respond(to:generating:)`.

While this model-driven approach is ideal for multi-field schemas and composite domain models (such as `CustomerTriage` or `EmailClassification`), real-world applications frequently require evaluating isolated, ad-hoc decisions against contextual state:
1. **Ad-hoc binary assertions**: "Is this incoming message spam?" or "Does this transaction exceed risk limits?"
2. **Ad-hoc discrete categorization**: Picking one option among a small set of dynamic strings or a Swift enum without declaring a `@Generable` schema.
3. **Ad-hoc rubric scoring**: Rating a customer frustration score on a 1–5 scale or evaluating code complexity.

Forcing developers to define dedicated boilerplate types for one-off decisions creates cognitive overhead and verbose code.

Simultaneously, as the package expanded to support multiple distinct execution environments—on-device Core ML (`LayaOnDevice`), self-hosted HTTP daemon (`LayaFoundationModels` via `laya-serve`), and hosted cloud API (`JevFoundationModels`)—package dependency management faced binary footprint and build-time challenges. Consumers deploying to air-gapped on-device mobile environments should not compile or link remote HTTP clients or cloud secret handlers; conversely, server-side Swift CLI tools running on Linux or macOS should not link Core ML neural engine binaries or tokenizers.

This tech note documents the design and implementation of:
1. **Ergonomic decision shortcuts** on `LanguageModelSession` (`.probability()`, `.choice()`, `.score()`), the `Choosable` protocol, and dynamic schema synthesis with `DynamicDecisionSchema`.
2. **Model-bounded package traits** in `Package.swift` adopting Swift 6.1 Package Traits (SE-0402), detailing the architectural rationale for slicing traits along **model boundaries** rather than infrastructure boundaries.

---

## Findings

### 1. Ergonomic Decision Shortcuts on `LanguageModelSession`

To eliminate the ceremony of declaring intermediate `@Generable` types for common decision tasks, `SystemOneCore` introduces direct evaluation methods on `LanguageModelSession`:

```swift
// 1. Binary probability shortcut
let isLeaking = try await session.probability(
    of: "Is this database connection leaking memory?",
    state: "Worker pool thread #4 holding 1.2 GB unreleased allocations."
) // -> Double (e.g. 0.94)

// 2. Strongly-typed Choosable enum shortcut
let choice = try await session.choice(
    "Select the triage priority",
    from: TicketPriority.self,
    state: "System database is down across all regions."
) // -> Choice<TicketPriority>

// 3. Dynamic string options shortcut
let selected = try await session.choice(
    "Select target department",
    options: ["billing", "support", "sales"],
    state: "Need refund for invoice #402."
) // -> Choice<String>

// 4. Ordinal rubric scoring shortcut
let scoreResult = try await session.score(
    "Rate the urgency of this support request",
    levels: ["Low", "Medium", "High", "Critical"],
    state: "Production server is completely unresponsive."
) // -> ScoreResult
```

#### A. Probability Evaluation (`.probability`)
- Evaluates the probability of truth for an assertion against contextual state.
- Supports optional evaluation criteria `(whenTrue: String, whenFalse: String)` to steer calibration.
- Maps internally to a System One `noul` primitive (0.0 to 1.0 calibrated truth probability).
- Automatically unpacks response probability metadata from `response.probability(for: "decision")`, falling back to `response.probabilities` or the boolean content value.

#### B. Categorical Choice (`.choice`)
- Offers two overloads:
  1. **Strongly-typed enum**: `choice(_:from:state:)` where the enum conforms to `Choosable`.
  2. **Dynamic strings**: `choice(_:options:state:)` taking an array of candidate strings.
- Returns a `Choice<Option>` container holding:
  - `value: Option`: The selected winning option.
  - `confidence: Double`: Calibrated model confidence in the decision (0.0 to 1.0).
  - `distribution: [Option: Double]`: Probability mass assigned to each evaluated candidate option.
  - `rawContent: GeneratedContent`: Raw Foundation Models response payload.
  - Helper method `probability(of: Option) -> Double`.

#### C. Rubric Scoring (`.score`)
- Evaluates an ordinal rubric given an array of ordered level labels (e.g. `["Low", "Medium", "High", "Critical"]`).
- Maps to a bounded integer range `0...(levels.count - 1)` with full level descriptions synthesized into the instruction prompt.
- Returns a `ScoreResult` containing:
  - `value: Double`: Probability-weighted continuous mean score (e.g. `2.8` across levels 0...3).
  - `mostLikelyIndex: Int`: Zero-based index of the highest-probability level.
  - `mostLikelyLevel: String`: Descriptive label of the winning level.
  - `probabilities: [Double]`: Calibrated probability distribution across all levels.
  - `confidence: Double`: Overall calibrated confidence score.
  - `levels: [String]`: The evaluated rubric levels.

---

### 2. The `Choosable` Protocol & Dynamic Enum Bridging

To enable clean enum categorization without requiring `@Generable`, `SystemOneCore` defines the `Choosable` protocol:

```swift
public protocol Choosable: CaseIterable, Hashable, Sendable {
    var optionIdentifier: String { get }
    var optionDescription: String? { get }
}
```

#### Default Implementations
1. **RawRepresentable Enums**:
   For enums conforming to `RawRepresentable where RawValue == String`, `optionIdentifier` defaults to `rawValue`, and `optionDescription` defaults to `nil`.
2. **General Enums**:
   For standard Swift enums, `optionIdentifier` defaults to `"\(self)"`.
3. **Semantic Guidance**:
   Developers can optionally override `optionDescription` to provide natural language context for each case, which `DynamicDecisionSchema` automatically synthesizes into the schema instructions.

```swift
enum TicketPriority: String, Choosable {
    case critical = "CRITICAL"
    case high = "HIGH"
    case normal = "NORMAL"
    case low = "LOW"

    var optionDescription: String? {
        switch self {
        case .critical: "Outage affecting all active users"
        case .high: "Core workflow degraded"
        case .normal: "Standard inquiry"
        case .low: "Minor cosmetic issue"
        }
    }
}
```

---

### 3. Dynamic Schema Synthesis with `DynamicDecisionSchema`

The ergonomic shortcuts do not bypass Apple Foundation Models' schema validation pipeline. Instead, they leverage `DynamicGenerationSchema` to construct runtime `GenerationSchema` instances that cleanly translate into System One decision questions:

```swift
public enum DynamicDecisionSchema {
    public static func makeBinarySchema(
        instructions: String,
        whenTrue: String? = nil,
        whenFalse: String? = nil
    ) throws -> GenerationSchema

    public static func makeChoiceSchema(
        instructions: String,
        options: [(name: String, description: String?)]
    ) throws -> GenerationSchema

    public static func makeScoreSchema(
        instructions: String,
        levels: [String]
    ) throws -> GenerationSchema
}
```

#### Translation Mapping
- **Binary Schema**: Creates an object schema named `BinaryDecision` with a single required `Bool` property named `decision`. `SchemaTranslator` recognizes this and generates a single `noul` question with the qualified instructions.
- **Choice Schema**: Creates a root schema named `Choice` with an `anyOf` list of candidate option names. When descriptions are present, `DynamicDecisionSchema` embeds an option glossary into the instructions (e.g. `(Options: CRITICAL: Outage...; HIGH: Core...)`). `SchemaTranslator` translates this into a System One `choice` question.
- **Score Schema**: Creates an object schema named `ScoreDecision` with an integer property constrained by `.range(0...maxLevel)`. Rubric descriptions are synthesized into the instruction string (e.g. `(Rubric: 0: Low, 1: Medium, 2: High)`). `SchemaTranslator` translates this into a System One `score` question.

This ensures uniform execution across all backends (`LayaOnDeviceBackend`, `LayaHTTPBackend`, `JevBackend`, and `MockSystemOneBackend`).

---

### 4. Package Traits Architecture (Swift 6.1 / SE-0402)

Swift 6.1 introduced Package Traits (SE-0402), allowing Swift packages to define modular, conditionally enabled capabilities. In `Package.swift`, `SystemOneFoundationModels` organizes traits into model-bounded capabilities and user-facing persona traits:

```swift
traits: [
    .trait(
        name: "Jev",
        description: "Enables TypeSafe Jev hosted API client"
    ),
    .trait(
        name: "Laya",
        description: "Enables on-device Laya decision models via Core ML and Apple Neural Engine"
    ),
    .trait(
        name: "LayaServe",
        description: "Enables HTTP transport for self-hosted laya-serve instances"
    ),
    .trait(
        name: "OnDevice",
        description: "Enables on-device decision model capabilities",
        enabledTraits: ["Laya"]
    ),
    .trait(
        name: "Remote",
        description: "Enables remote hosted and self-hosted decision model clients",
        enabledTraits: ["Jev", "LayaServe"]
    ),
    .trait(
        name: "All",
        description: "Enables all System One model backends and transports",
        enabledTraits: ["Jev", "Laya", "LayaServe"]
    ),
    .default(enabledTraits: ["Jev"])
]
```

#### Trait Matrix

| Trait | Category | Included Capabilities | Intended Deployment |
| :--- | :--- | :--- | :--- |
| `Jev` | Model Boundary | `JevFoundationModels`, hosted API client | Cloud / hosted decision services |
| `Laya` | Model Boundary | `LayaOnDevice`, Core ML engine, ANE tokenization | Offline mobile, air-gapped edge apps |
| `LayaServe` | Model Boundary | `LayaFoundationModels`, local/remote HTTP client | Self-hosted daemons, on-prem clusters |
| `OnDevice` | Persona / Shorthand | Enables `["Laya"]` | Mobile developers requiring zero network |
| `Remote` | Persona / Shorthand | Enables `["Jev", "LayaServe"]` | Server/client apps using networked models |
| `All` | Persona / Shorthand | Enables `["Jev", "Laya", "LayaServe"]` | Multi-backend apps (e.g. MailTriageApp) |
| *default* | Default Trait | Enables `["Jev"]` | Out-of-the-box backward compatibility |

---

### 5. Architectural Rationale: Model Boundaries vs. Infrastructure Boundaries

When designing package traits, an alternative approach is to partition traits along **infrastructure boundaries** (e.g. `CoreML`, `Networking`, `Tokenization`, `HTTP`, `HardwareANE`).

`SystemOneFoundationModels` intentionally rejects infrastructure boundaries in favor of **model boundaries** (`Jev`, `Laya`, `LayaServe`). The architectural rationale rests on four key principles:

#### A. Developer Mental Model
Developers do not evaluate architectural infrastructure in isolation; they choose **which model to run and where to run it**:
- *"I want to evaluate Laya locally on the device with zero network calls."* $\to$ Trait: `Laya` or `OnDevice`.
- *"I want to connect to our private self-hosted laya-serve instance."* $\to$ Trait: `LayaServe` or `Remote`.
- *"I want to use TypeSafe's hosted Jev API."* $\to$ Trait: `Jev`.

Dividing traits into `CoreML`, `URLSession`, `JSONParser`, or `Tokenizer` leaks internal implementation details to the caller and creates confusing trait combinations (e.g., enabling `Networking` without specifying whether it targets Jev or Laya-Serve).

#### B. Cohesive Vertical Slices
Each decision model backend is a cohesive vertical slice of functionality:
- `LayaOnDevice`: Requires Core ML model execution, ModernBERT/mmBERT BPE tokenization, option marker positioning, and ANE shape bucketing.
- `LayaFoundationModels`: Requires HTTP networking, wire-format serialization matching `laya-serve` PR #31, endpoint presets, and bearer token handling.
- `JevFoundationModels`: Requires RFC 9110 retry backoff, exponential jitter, API key header formatting, and cloud error decoding.

Cutting along infrastructure boundaries would fragment these vertical slices, introducing fragile inter-trait dependencies and combinatorial build configurations that are difficult to test and maintain.

#### C. Binary Footprint & Sandboxing
Cutting along model boundaries allows consumers to strictly control their binary size and linkage:
- An iOS app enabling only `OnDevice` links `LayaOnDevice` and `SystemOneCore`. It contains zero cloud endpoints, zero API key logic, and zero network transport code.
- A Linux or macOS server CLI enabling only `LayaServe` or `Jev` avoids linking Apple Neural Engine or Core ML dependencies.

#### D. Persona Trait Composition
To prevent trait fatigue, the package provides high-level persona traits (`OnDevice`, `Remote`, `All`) that compose underlying model traits. A consumer configuring their dependency can write:

```swift
.package(url: "https://github.com/peterfriese/jev-foundation-models.git", from: "0.2.0", traits: ["OnDevice"])
```

This delivers an intuitive, self-documenting declaration that aligns directly with the app's architectural requirements.

---

## Implications

1. **Radical Ergonomic Simplicity**:
   Common decision patterns (boolean checks, classifications, rubric ratings) drop from multi-line struct declarations to concise one-line async calls:
   ```swift
   let isSpam = try await session.probability(of: "Is this message spam?", state: emailBody)
   ```
2. **Preserved Telemetry & Calibration**:
   Even without explicit `@Generable` schemas, returned results retain full access to calibrated uncertainty via `Choice.distribution`, `ScoreResult.probabilities`, and `ScoreResult.value`.
3. **Zero Binary Bloat via Targeted Traits**:
   Consumers can opt into exactly the backends they require via Swift 6.1 traits, keeping application binaries lean and focused.
4. **Complete Backwards Compatibility**:
   Existing `@Generable` code, custom `SystemOneBackend` implementations, and default package imports continue to function unchanged.

---

## Sources & References

- Swift Evolution: [SE-0402 — Package Access Modifiers & Package Traits](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0402-package-traits.md)
- Apple Developer: [Foundation Models Framework Documentation](https://developer.apple.com/documentation/foundationmodels)
- Tech Note 0001: [Bridging Decision Models into Apple Foundation Models via Channel Synthesis](0001-afm-decision-model-bridging.md)
- Tech Note 0007: [Pluggable System One Backends & Wire Compatibility with Laya HTTP Serving](0007-pluggable-system-one-backends-and-laya-serve.md)
- Tech Note 0008: [On-Device Decision Models via Core ML, Apple Neural Engine, and Native Tokenization](0008-on-device-coreml-decision-engine.md)
