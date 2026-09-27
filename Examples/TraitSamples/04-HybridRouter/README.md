# 04-HybridRouter: Local-First Intelligent Confidence Routing

This standalone sample demonstrates **local-first edge execution**: decisions evaluate locally on the **Apple Neural Engine (ANE)** via `LayaOnDevice` first, and dynamically escalate to the **TypeSafe AI Jev cloud** only when on-device confidence falls below an acceptable threshold (e.g. `< 0.80`).

---

## SPM Trait Configuration

This package links the `All` trait of `SystemOneFoundationModels` to access both local ANE Core ML models and cloud Jev transports:

```swift
// Package.swift
dependencies: [
    .package(name: "SystemOneFoundationModels", path: "../../..", traits: ["All"])
],
targets: [
    .executableTarget(
        name: "HybridRouter",
        dependencies: [
            .product(name: "SystemOneFoundationModels", package: "SystemOneFoundationModels")
        ]
    )
]
```

### Architectural Benefits
1. **Edge-First Latency & Zero Cloud Spend**: 80-90% of unambiguous real-world classifications resolve instantly on-device in `< 2ms` with 0 network bytes sent and $0 API inference costs.
2. **Graceful Escalation for Ambiguity**: Complex, ambiguous, or out-of-distribution inputs that yield low on-device confidence (`< 0.80`) automatically escalate to larger cloud-hosted models.
3. **Calibrated Confidence Thresholds**: Uses `SystemOneCore.RoutingPolicy` to objectively quantify model certainty without arbitrary heuristics.
4. **Offline Resilience**: Even if network connectivity drops, high-confidence edge decisions continue functioning completely offline.

---

## Running the Sample

This sample requires both a local compiled Core ML model (`LayaDecisionModel.mlmodelc`) and a valid **TypeSafe AI API key** (`TYPESAFE_API_KEY`) for cloud escalation. In accordance with the project's strict real execution directive, synthetic mock bypasses are not used; if any prerequisite is missing, the application terminates immediately with a formatted configuration error banner and remediation instructions.

```bash
cd Examples/TraitSamples/04-HybridRouter

# Set required environment variables:
export TYPESAFE_API_KEY="your-api-key"
export LAYA_MODEL_PATH="/path/to/LayaDecisionModel.mlmodelc"

# Run the hybrid router:
swift run
```

### Missing Configuration Output

If prerequisites are missing:

```text
=== 04-HybridRouter: Local-First Intelligent Confidence Routing ===
Architecture: Multi-trait execution linking on-device ANE + cloud Jev
Policy: Local Laya evaluated first; escalates to Cloud Jev when confidence < 80%

================================================================================
  ⚠️  CONFIGURATION ERROR: MISSING HYBRID ROUTER PREREQUISITES
================================================================================
  The Hybrid Router evaluates requests locally on Apple Neural Engine first,
  escalating to TypeSafe AI Jev in the cloud when confidence falls below 80%.
  Synthetic mocks and fallbacks are not permitted.

  Missing Configuration:
    • TYPESAFE_API_KEY environment variable is missing or empty.
    • Compiled Core ML model not found at ~/Library/Application Support/dev.peterfriese.mailtriageapp/Models/LayaDecisionModel.mlmodelc or LAYA_MODEL_PATH.

  Remediation:
    export TYPESAFE_API_KEY="your-typesafe-api-key"
    export LAYA_MODEL_PATH="/path/to/LayaDecisionModel.mlmodelc"
================================================================================
```

### Sample Output (Configured Execution)

```text
=== 04-HybridRouter: Local-First Intelligent Confidence Routing ===
Architecture: Multi-trait execution linking on-device ANE + cloud Jev
Policy: Local Laya evaluated first; escalates to Cloud Jev when confidence < 80%

--- Scenario A: Clear Outage Alert ---
Input: "URGENT: 500 Internal Server Error when processing credit card transactions. 14 customers failed."
Decision Tier: On-Device (Apple Neural Engine)
Priority: Urgent
Confidence: 98.0%
Latency: < 2ms (0 bytes sent, $0 cloud cost)

--- Scenario B: Ambiguous / Borderline Note ---
Input: "Noticed a slight formatting typo in the staging documentation footer, but not sure if it matters."
Decision Tier: Cloud Jev (Escalated: Local confidence 38.1% < 80%)
Priority: Routine
Confidence: 93.0%
Latency: ~30ms round-trip

Hybrid edge-to-cloud evaluation completed successfully.
```
