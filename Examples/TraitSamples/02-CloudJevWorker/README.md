# 02-CloudJevWorker: Ultra-Lean Cloud Decision Worker

This standalone sample demonstrates lightning-fast CLI ticket triage using **`JevLanguageModel`**, **`session.probability(...)`**, and **`session.choice(...)`** connecting to the **TypeSafe AI Jev decision API**.

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
        name: "CloudJevWorker",
        dependencies: [
            .product(name: "SystemOneFoundationModels", package: "SystemOneFoundationModels")
        ]
    )
]
```

### Architectural Benefits
1. **Zero ML Framework Linkage**: Eliminates `CoreML.framework`, `Accelerate.framework`, and multi-hundred-megabyte model weight bundles from the binary.
2. **Sub-Second Incremental Compilation**: Lean dependencies and pure networking logic compile in fractions of a second, perfect for serverless microservices, Lambda containers, and CLI tools.
3. **Resilient HTTP Communication**: Built-in `URLSessionTransport` with jittered exponential backoff and `Retry-After` RFC 9110 compliance.
4. **Ergonomic Native Apple APIs**: Uses standard `LanguageModelSession` shortcuts (`probability(of:state:)`, `choice(_:from:state:)`).

---

## Running the Sample

Execute with or without an API key:

```bash
cd Examples/TraitSamples/02-CloudJevWorker

# Run in offline mock mode:
swift run

# Run with live TypeSafe AI cloud API:
TYPESAFE_API_KEY="your-api-key" swift run
```

### Sample Output

```text
=== 02-CloudJevWorker: Lightning-Fast Cloud Ticket Triage ===
Backend: TypeSafe AI Jev Decision API (System One Cloud)
Binary footprint: Ultra-lean (Zero Core ML, PyTorch, or weights linked)
Mode: Deterministic Offline Mock Transport (Set TYPESAFE_API_KEY for live cloud API)

--- Incoming Ticket ---
INCIDENT #89412
Title: Production Postgres read-replica pool exhausted in us-east-1
Reported By: Datadog Alert Bot
Details: P99 query latency climbed from 12ms to 4200ms. Connection poolers reporting 100% saturation.
Multiple API endpoints returning HTTP 500 to customer requests. Immediate remediation needed.
-----------------------

Evaluating triage decisions via LanguageModelSession...

=== Triage Decisions ===
• Urgent P0 Outage Probability: 94.0% (🚨 CRITICAL ESCALATION)
• Assigned Team: Infrastructure & SRE
• Routing Confidence: 92.0%
• Alternative Candidate Probabilities:
    - Infrastructure & SRE: 92.0%
    - Security Operations: 5.0%
    - Billing & Payments: 2.0%
    - Mobile & Frontend: 1.0%

Evaluation successfully completed via Jev Foundation Models.
```
