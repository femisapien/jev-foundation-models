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

This sample requires a valid **TypeSafe AI API key** (`TYPESAFE_API_KEY`) to evaluate real System One decision models in the cloud. In accordance with the project's strict real execution directive, synthetic mock bypasses are not used; if the environment variable is missing, the application terminates immediately with a formatted configuration error banner and remediation instructions.

```bash
cd Examples/TraitSamples/02-CloudJevWorker

# Set your API key and run:
export TYPESAFE_API_KEY="your-api-key"
swift run
```

### Missing Configuration Output

If `TYPESAFE_API_KEY` is not set:

```text
=== 02-CloudJevWorker: Lightning-Fast Cloud Ticket Triage ===
Backend: TypeSafe AI Jev Decision API (System One Cloud)
Binary footprint: Ultra-lean (Zero Core ML, PyTorch, or weights linked)
================================================================================
  ⚠️  CONFIGURATION ERROR: MISSING TYPESAFE_API_KEY
================================================================================
  This example application requires a valid TypeSafe AI API key to evaluate
  real System One decision models in the cloud. Synthetic mock bypasses are
  not permitted.

  Remediation:
    export TYPESAFE_API_KEY="your-typesafe-api-key"
================================================================================
```

### Sample Output (Live Cloud API)

```text
=== 02-CloudJevWorker: Lightning-Fast Cloud Ticket Triage ===
Backend: TypeSafe AI Jev Decision API (System One Cloud)
Binary footprint: Ultra-lean (Zero Core ML, PyTorch, or weights linked)
Mode: Live TypeSafe Cloud API (Key: ts_l...)

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
